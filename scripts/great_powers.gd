# great_powers.gd - what GREAT SUNROOTS (tree stage 4, New Game + only) can do.
# Created by the arena in code (see arena.gd _ready). Great trees only exist in
# New Game +, so in a normal run this node finds none and does nothing.
class_name GreatPowers
extends Node2D
## Two powers that make keeping a tree alive for a whole wave worth it:
##
## 1. CANOPY LINE
##    Any two great sunroots close enough (canopy_line_range_cells) that can SEE
##    each other (no wall or other tree between their centres) string a glowing
##    vine cable between them. A machine that walks across the cable is caught
##    and bound in place for canopy_line_bind_seconds. Then that cable goes dim
##    and must recharge (canopy_line_recharge) before it can catch again.
##    Strategy: plant and protect trees in pairs across the lanes machines walk.
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
## add_trellis() when a zip goes tree to tree. The lines look after themselves
## every physics step.

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

## Cable key ("<tree id>-<tree id>") -> seconds of recharge left.
var _recharge: Dictionary[String, float] = {}
## The most recent Sunburst: where, and seconds since it went off (-1 = none showing).
var _burst_at: Vector2 = Vector2.ZERO
var _burst_time: float = -1.0


## _physics_process runs every physics step: rebuild the cables, count down the
## timers, and catch any machine that is crossing a charged cable.
func _physics_process(delta: float) -> void:
	sunburst_cooldown_left = maxf(sunburst_cooldown_left - delta, 0.0)
	for key: String in _recharge.keys():
		_recharge[key] = maxf(_recharge[key] - delta, 0.0)
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


## Finds every pair of great sunroots that are close enough and can see each
## other. There are only ever a handful of great trees, so checking every pair
## each step is cheap.
func _rebuild_lines() -> void:
	lines.clear()
	var great: Array[ForestTree] = []
	for node: Node in get_tree().get_nodes_in_group(ForestTree.GROUP):
		var tree := node as ForestTree
		if tree != null and tree.is_great and tree.stage == ForestTree.Stage.GROWN:
			great.append(tree)
	var reach: float = CONFIG.canopy_line_range_cells * CONFIG.cell_size
	for i: int in great.size():
		for j: int in range(i + 1, great.size()):
			var a: ForestTree = great[i]
			var b: ForestTree = great[j]
			if a.global_position.distance_to(b.global_position) > reach:
				continue
			if not _can_see(a, b):
				continue
			# The smaller id first, so the same pair always gets the same key.
			var ids: Array[int] = [a.get_instance_id(), b.get_instance_id()]
			ids.sort()
			lines.append({a = a, b = b, key = "%d-%d" % ids})


## True if nothing solid (wall or another grown tree) is between trees a and b.
## The ray ignores a and b themselves (their RIDs, the physics server's ids).
func _can_see(a: ForestTree, b: ForestTree) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(a.global_position, b.global_position, WORLD_MASK, [a.get_rid(), b.get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


## Binds the first free machine touching this cable, then starts the recharge.
func _catch_on(line: Dictionary) -> void:
	var a: Vector2 = (line.a as ForestTree).global_position
	var b: Vector2 = (line.b as ForestTree).global_position
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead or enemy.is_bound:
			continue
		# Geometry2D gives the point on the segment a-b nearest to the machine.
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, a, b)
		if enemy.global_position.distance_to(nearest) <= CONFIG.canopy_line_catch_px:
			# Binding "towards itself" ties it up right where it stands.
			enemy.yank_and_bind(enemy.global_position, 0.0, CONFIG.canopy_line_bind_seconds)
			_recharge[line.key] = CONFIG.canopy_line_recharge
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
