# great_powers.gd - what GREAT SUNROOTS (tree stage 4, New Game + only) can do.
# Created by the arena in code (see arena.gd _ready). Great trees only exist in
# New Game +, so in a normal run this node finds none and does nothing.
class_name GreatPowers
extends Node2D
## Two powers that make keeping a tree alive for a whole wave worth it:
##
## 1. CANOPY LINE
##    Two great sunroots close enough (canopy_line_range_cells) that can SEE
##    each other (no wall or other tree between their centres) string a glowing
##    vine cable between them. A machine that walks across the cable is caught
##    and bound in place for canopy_line_bind_seconds. Then that cable goes dim
##    and must recharge (canopy_line_recharge) before it can catch again.
##    Strategy: plant and protect trees in pairs across the lanes machines walk.
##    LIMITS (s18): a tree holds at most canopy_line_links_per_tree cables and
##    the lot at most canopy_line_max, shortest first (see _rebuild_lines). A
##    machine a cable has let go cannot be caught by any cable again for
##    canopy_line_immunity_seconds, so nothing is held in the web forever.
##
## 2. SUNBURST
##    Zip to a great sunroot and it flares: every machine within
##    sunburst_radius_cells is stunned (bound) for sunburst_stun_seconds and takes
##    sunburst_damage. One shared cooldown (sunburst_cooldown) for all trees.
##    Strategy: your great trees are escape hatches; zip in when swarmed.
##
## And one for EVERY tree, in any run:
##
## 3. TRELLIS (DESIGN.md's "Overgrowth idea in one rule")
##    Zip from beside one tree to another and the vine stays strung between them
##    for trellis_seconds. Each machine that crosses it is snared (bound) once.
##    Strategy: zip across a lane just before the machines walk into it.
##
## The arena calls sunburst() when the player's zip ends at a great tree, and
## add_trellis() when a zip goes tree to tree. The lines look after themselves:
## they are worked out again only when the forest changes (see _forest_signature).

const CONFIG: GameConfig = preload("res://config/game_config.tres")
## Physics layer 1 ("world"): walls and grown trees block a cable's line of sight.
const WORLD_MASK: int = 1
## How long the Sunburst's ring of light takes to spread and fade, in seconds.
const BURST_SECONDS: float = 0.5

## One entry per cable standing right now: {a: ForestTree, b: ForestTree, key: String}.
## Public so the tests can read it.
var lines: Array[Dictionary] = []
## Seconds of Sunburst cooldown left (0 = ready). Public for the tests and the HUD.
var sunburst_cooldown_left: float = 0.0
## How brightly to draw (above 1 shines through the night tint). Set by the arena.
var light_boost: float = 1.0
## Extra seconds every trellis lasts (Long Trellis upgrades). Set by the arena.
var trellis_bonus_seconds: float = 0.0

## The trellis vines strung right now: {a: Vector2, b: Vector2, time_left: float,
## caught: Dictionary of machine ids already snared}. Public for the tests.
var trellises: Array[Dictionary] = []

## True hides the cables (they still work). The arena sets this while the upgrade
## cards are up, because the bright cables showed through the cards.
var cables_hidden: bool = false
## How many times the cables have been worked out. Public so the tests can prove
## that a forest which is not changing costs nothing.
var rebuild_count: int = 0

## Cable key ("<tree id>-<tree id>") -> seconds of recharge left.
var _recharge: Dictionary[String, float] = {}
## Machine id -> seconds until a Canopy line may catch that machine again.
var _immune: Dictionary[int, float] = {}
## A number that stands for the forest as it was when the cables were last
## worked out (see _forest_signature). -1 = never worked out.
var _signature: int = -1
## The most recent Sunburst: where, and seconds since it went off (-1 = none showing).
var _burst_at: Vector2 = Vector2.ZERO
var _burst_time: float = -1.0


## _physics_process runs every physics step: count down the timers, rebuild the
## cables if the forest changed, and catch any machine crossing a charged cable.
func _physics_process(delta: float) -> void:
	sunburst_cooldown_left = maxf(sunburst_cooldown_left - delta, 0.0)
	for key: String in _recharge.keys():
		_recharge[key] = maxf(_recharge[key] - delta, 0.0)
	# Count the immunities down and forget the ones that have run out.
	# (.keys() makes a copy of the keys, so erasing while looping is safe.)
	for id: int in _immune.keys():
		_immune[id] -= delta
		if _immune[id] <= 0.0:
			_immune.erase(id)
	# Working the cables out costs a physics ray per pair of trees, so only do
	# it when something about the forest is different from last time.
	var signature: int = _forest_signature()
	if signature != _signature:
		_signature = signature
		_rebuild_lines()
	for line: Dictionary in lines:
		if is_charged(line):
			_catch_on(line)
	_tick_trellises(delta)
	if _burst_time >= 0.0:
		_burst_time += delta
		if _burst_time > BURST_SECONDS:
			_burst_time = -1.0
	queue_redraw()  # cables and the burst ring change every step


## True if this cable can catch a machine right now (not recharging).
func is_charged(line: Dictionary) -> bool:
	return _recharge.get(line.key, 0.0) <= 0.0


## True while no Canopy line may catch this machine (one let it go a moment ago).
func is_immune(enemy: Enemy) -> bool:
	return _immune.has(enemy.get_instance_id())


## One number that changes whenever the forest changes: a tree is planted, grows,
## is cut, falls, or matures into a great sunroot. Cables depend on all of those
## (an ordinary tree in the way blocks a cable), so comparing this number with
## last step's tells us whether the cables must be worked out again.
## hash() turns any value into a number; the same list always gives the same one.
func _forest_signature() -> int:
	var parts: Array[int] = []
	for node: Node in get_tree().get_nodes_in_group(ForestTree.GROUP):
		var tree := node as ForestTree
		# A tree being deleted is still in the group until the frame ends: skip it.
		if tree == null or tree.is_queued_for_deletion():
			continue
		parts.append(tree.get_instance_id())
		parts.append(tree.stage)
		parts.append(1 if tree.is_great else 0)
	return hash(parts)


## Works out which cables stand. Before s18 this linked EVERY pair of great
## sunroots in range, every physics step; with 70 great trees that was thousands
## of rays a second and a screen full of cables. Now:
##   1. list every pair of great sunroots within reach, shortest first;
##   2. walk down the list and string a cable only if both trees still have a
##      free link (canopy_line_links_per_tree), the lot is under its cap
##      (canopy_line_max), and the two trees can see each other.
## So each tree ends up tied to its nearest neighbours, and short cables win.
func _rebuild_lines() -> void:
	rebuild_count += 1
	lines.clear()
	var great: Array[ForestTree] = []
	for node: Node in get_tree().get_nodes_in_group(ForestTree.GROUP):
		var tree := node as ForestTree
		if tree != null and not tree.is_queued_for_deletion() and tree.is_great and tree.stage == ForestTree.Stage.GROWN:
			great.append(tree)

	# Step 1: every pair in reach, as {a, b, length}.
	var reach: float = CONFIG.canopy_line_range_cells * CONFIG.cell_size
	var pairs: Array[Dictionary] = []
	for i: int in great.size():
		for j: int in range(i + 1, great.size()):
			var length: float = great[i].global_position.distance_to(great[j].global_position)
			if length <= reach:
				pairs.append({a = great[i], b = great[j], length = length})
	# sort_custom sorts with our own rule: "x goes before y if x is shorter".
	pairs.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.length < y.length)

	# Step 2: hand out the cables, shortest pair first.
	var links: Dictionary[int, int] = {}  # tree id -> cables it holds so far
	for pair: Dictionary in pairs:
		if lines.size() >= CONFIG.canopy_line_max:
			break  # the lot is full
		var a: ForestTree = pair.a
		var b: ForestTree = pair.b
		var id_a: int = a.get_instance_id()
		var id_b: int = b.get_instance_id()
		if links.get(id_a, 0) >= CONFIG.canopy_line_links_per_tree or links.get(id_b, 0) >= CONFIG.canopy_line_links_per_tree:
			continue  # one of the two has no free link left
		if not _can_see(a, b):  # the ray: only cast for pairs that would get a cable
			continue
		links[id_a] = links.get(id_a, 0) + 1
		links[id_b] = links.get(id_b, 0) + 1
		# The smaller id first, so the same pair always gets the same key.
		var ids: Array[int] = [id_a, id_b]
		ids.sort()
		lines.append({a = a, b = b, key = "%d-%d" % ids})

	# Forget the recharge timers of cables that no longer stand.
	var standing: Dictionary[String, bool] = {}
	for line: Dictionary in lines:
		standing[line.key] = true
	for key: String in _recharge.keys():
		if not standing.has(key):
			_recharge.erase(key)


## True if nothing solid (wall or another grown tree) is between trees a and b.
## The ray ignores a and b themselves (their RIDs, the physics server's ids).
func _can_see(a: ForestTree, b: ForestTree) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(a.global_position, b.global_position, WORLD_MASK, [a.get_rid(), b.get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


## Binds the first free machine touching this cable, then starts the recharge.
## Machines a cable let go a moment ago are passed over (see _immune).
func _catch_on(line: Dictionary) -> void:
	# A tree can be freed between two rebuilds; never touch a freed node.
	if not is_instance_valid(line.a) or not is_instance_valid(line.b):
		return
	var a: Vector2 = (line.a as ForestTree).global_position
	var b: Vector2 = (line.b as ForestTree).global_position
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead or enemy.is_bound or is_immune(enemy):
			continue
		# Geometry2D gives the point on the segment a-b nearest to the machine.
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, a, b)
		if enemy.global_position.distance_to(nearest) <= CONFIG.canopy_line_catch_px:
			# Binding "towards itself" ties it up right where it stands.
			enemy.yank_and_bind(enemy.global_position, 0.0, CONFIG.canopy_line_bind_seconds)
			_recharge[line.key] = CONFIG.canopy_line_recharge
			# Immune from now until immunity_seconds AFTER the binding ends.
			_immune[enemy.get_instance_id()] = CONFIG.canopy_line_bind_seconds + CONFIG.canopy_line_immunity_seconds
			Sfx.play(&"bind")
			return


## Strings a trellis vine from `a` to `b` (two tree centres) for trellis_seconds.
func add_trellis(a: Vector2, b: Vector2) -> void:
	trellises.append({a = a, b = b, time_left = CONFIG.trellis_seconds + trellis_bonus_seconds, caught = {}})
	Sfx.play(&"grow")


## Counts each trellis down (dropping the spent ones) and snares any machine
## crossing one for the first time.
func _tick_trellises(delta: float) -> void:
	# Walk backwards, so removing an entry does not skip the next one.
	for i: int in range(trellises.size() - 1, -1, -1):
		var vine: Dictionary = trellises[i]
		vine.time_left -= delta
		if vine.time_left <= 0.0:
			trellises.remove_at(i)
			continue
		for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
			var enemy := node as Enemy
			if enemy == null or enemy.is_dead or enemy.is_bound or vine.caught.has(enemy.get_instance_id()):
				continue
			var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, vine.a, vine.b)
			if enemy.global_position.distance_to(nearest) <= CONFIG.canopy_line_catch_px:
				vine.caught[enemy.get_instance_id()] = true
				enemy.yank_and_bind(enemy.global_position, 0.0, CONFIG.trellis_bind_seconds)
				Sfx.play(&"bind")


## The player's zip ended at a great sunroot standing at `at`: stun and hurt every
## machine nearby. Returns how many machines it caught (0 while cooling down).
func sunburst(at: Vector2) -> int:
	if sunburst_cooldown_left > 0.0:
		return 0
	sunburst_cooldown_left = CONFIG.sunburst_cooldown
	_burst_at = at
	_burst_time = 0.0
	Sfx.play(&"wave_clear")
	var reach: float = CONFIG.sunburst_radius_cells * CONFIG.cell_size
	var caught: int = 0
	# Copy the list first: a machine that dies here leaves the group mid-loop.
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP).duplicate():
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead or enemy.global_position.distance_to(at) > reach:
			continue
		enemy.yank_and_bind(enemy.global_position, 0.0, CONFIG.sunburst_stun_seconds)
		enemy.take_damage(CONFIG.sunburst_damage)
		caught += 1
	return caught


## _draw paints the cables (bright when charged, faint while recharging) and the
## Sunburst's spreading ring.
func _draw() -> void:
	for line: Dictionary in lines:
		# Hidden while the upgrade cards are up; and never draw to a freed tree.
		if cables_hidden or not is_instance_valid(line.a) or not is_instance_valid(line.b):
			continue
		var a: Vector2 = (line.a as ForestTree).global_position
		var b: Vector2 = (line.b as ForestTree).global_position
		var color: Color = CONFIG.canopy_line_color
		if is_charged(line):
			color = Color(color * light_boost, color.a)
		else:
			color = Color(color, color.a * 0.25)
		# A slight sag: the cable dips in the middle like a real line between poles.
		var mid: Vector2 = (a + b) / 2.0 + Vector2(0.0, 10.0)
		draw_polyline(PackedVector2Array([a, mid, b]), color, 3.0, true)
		# Small buds of light along the cable.
		for t: float in [0.25, 0.5, 0.75]:
			var bud: Vector2 = (a.lerp(mid, t * 2.0) if t <= 0.5 else mid.lerp(b, t * 2.0 - 1.0))
			draw_circle(bud, 3.0, color)
	# Trellis vines: a thinner green line that fades out over its last seconds.
	for vine: Dictionary in trellises:
		var fade: float = clampf(vine.time_left / 1.5, 0.0, 1.0)
		var green: Color = CONFIG.trellis_color
		draw_line(vine.a, vine.b, Color(green * light_boost, green.a * fade), 2.0, true)
		for t: float in [0.2, 0.4, 0.6, 0.8]:
			draw_circle(vine.a.lerp(vine.b, t), 2.5, Color(green * light_boost, green.a * fade))
	if _burst_time >= 0.0:
		var share: float = _burst_time / BURST_SECONDS  # 0 at the flash, 1 when gone
		var radius: float = CONFIG.sunburst_radius_cells * CONFIG.cell_size * share
		var ring := Color(1.0 * light_boost, 0.85 * light_boost, 0.4, 1.0 - share)
		draw_arc(_burst_at, radius, 0.0, TAU, 48, ring, 6.0, true)
