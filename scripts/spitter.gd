# spitter.gd - the ranged enemy: keeps its distance and fires slow shots.
# Health, dying and path-walking come from enemy.gd.
class_name Spitter
extends Enemy
## A rogue machine that shoots from range.
##
## WHY IT EXISTS (from the design): it makes cover matter. Its shots stop on
## trees, so the forest you planted is what protects you from it.
##
## WHAT IT DOES, every physics step (s18 round 2: it now fights from cover):
##   1. Winding up (red glow): stand still, then fire one shot at where the
##      player is. The glow is the warning, like the Scrapper's.
##   2. GUARDING another machine (see `ward`) and left behind: walk back to it.
##   3. Shot ready, or nearly (spitter_peek_seconds): step out and line up.
##      Clear line to the player: start winding up. No clear line: walk
##      towards the player until there is one (a guard stays put instead).
##   4. RELOADING: hide. It picks a cell near itself that one of the player's
##      own trees (or a wall) screens from the player, and waits there.
##   5. Nowhere to hide: back away if the player is too close, else stand.
## So a Spitter pops out, shoots, and ducks back behind the forest you planted.
##
## GUARDS: a Linebreaker's three escorts have that Linebreaker as their `ward`;
## an Arc Spitter picks the nearest Sawbot (`guards_sawbots`). A guard does all
## of the above but never strays more than escort_leash_cells from its ward.
## When the ward is destroyed, the guard carries on as an ordinary Spitter.
##
## "Can see" means a straight line to the player with no wall or grown tree in
## the way. The Spitter does not create its shot: it emits `spat` and the arena
## spawns it ("signal up").

## Emitted for every shot. `direction` is a unit vector (length 1).
## `electric` is true for an Arc Spitter's bolts.
signal spat(origin: Vector2, direction: Vector2, electric: bool)

const FALLBACK_COLOR: Color = Color(0.55, 0.50, 0.62)
## Tint during the windup. Values above 1.0 brighten.
const WINDUP_TINT: Color = Color(1.9, 0.55, 0.45)
## Physics layer 1 ("world") as a bit mask, for the line-of-sight ray.
const WORLD_MASK: int = 1

## True from the start of the warning glow until the shot leaves.
## Public (no underscore) so the tests can watch it.
var is_winding_up: bool = false
## True for an ARC SPITTER (from wave 7): tougher, and every shot is a fan of
## three. Set by the arena before the machine is added to the scene.
var arc: bool = false

## The machine this Spitter guards, or null for none. Set by the arena for a
## Linebreaker's escorts; picked by the Spitter itself when guards_sawbots is on.
var ward: Enemy = null
## True for an Arc Spitter: it guards whichever Sawbot is nearest.
var guards_sawbots: bool = false
## The cell it is hiding in (or heading for) while it reloads; NO_CELL = none.
## Public so the tests can read it.
var cover_cell: Vector2i = ArenaGrid.NO_CELL

## The node to shoot at. Handed in by aim_at().
var _target: Node2D
## What the current route leads to (&"ward", &"target" or &"cover"). When the
## Spitter changes its mind, the route is worked out again at once.
var _route_kind: StringName = &""
## An Arc Spitter's chosen spot to shoot from (see step 3), or NO_CELL.
var _fire_cell: Vector2i = ArenaGrid.NO_CELL
var _windup_time_left: float = 0.0
## Seconds until the next windup may start.
var _cooldown_left: float = 0.0


## _ready runs once when the Spitter enters the scene.
func _ready() -> void:
	var start_hp: int = CONFIG.arc_spitter_hp if arc else CONFIG.spitter_hp
	# An Arc Spitter has its own picture; without one it is the Spitter's picture, tinted.
	var own_picture: bool = arc and CONFIG.arc_spitter_texture != null
	_configure_body(start_hp, CONFIG.spitter_radius_cells, CONFIG.arc_spitter_texture if own_picture else CONFIG.spitter_texture, FALLBACK_COLOR)
	if arc and not own_picture:
		_sprite.self_modulate = CONFIG.arc_spitter_tint
	# A Spitter that has just walked in waits half a cooldown before its first
	# shot, so nothing fires the instant it appears.
	_cooldown_left = CONFIG.spitter_cooldown * 0.5


## How fast this machine walks, in pixels per second.
func _speed() -> float:
	return CONFIG.spitter_speed * (CONFIG.arc_spitter_speed_factor if arc else 1.0)


## Overrides Enemy._shield_color: an Arc Spitter has an electric blue force
## field (drawn by Enemy._draw_shield). A plain Spitter has none.
func _shield_color() -> Color:
	return CONFIG.arc_spitter_spark_color if arc else Color(0.0, 0.0, 0.0, 0.0)


## Overrides Enemy._shield_sparks: small lightning arcs crawl over that field.
func _shield_sparks() -> bool:
	return arc


## Called by the arena: which node to shoot at ("call down").
func aim_at(target: Node2D) -> void:
	_target = target


## _physics_process runs 60 times per second. The numbered steps match the list
## at the top of this file.
func _physics_process(delta: float) -> void:
	# is_instance_valid guards against the target having been deleted.
	if _grid == null or not is_instance_valid(_target):
		return
	if _tick_bound(delta):
		return  # tied up by the vine: do nothing this step
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	var to_target: Vector2 = _target.global_position - global_position
	var distance: float = to_target.length()

	# 1. Winding up: stand, face the player, fire when the glow ends.
	if is_winding_up:
		velocity = Vector2.ZERO
		_face(to_target)
		_windup_time_left -= delta
		if _windup_time_left <= 0.0:
			_fire(to_target)
		return

	# A few times a second (not every step, it costs physics rays) it thinks
	# again: who to guard, and where to hide.
	var think: bool = _repath_due(delta, CONFIG.spitter_repath_interval)
	if think and guards_sawbots:
		ward = _nearest_sawbot()
	# is_instance_valid guards against a ward that has been destroyed and deleted.
	var has_ward: bool = is_instance_valid(ward) and not ward.is_dead

	# 2. A guard that has been left behind walks back to its ward.
	if has_ward and global_position.distance_to(ward.global_position) > CONFIG.escort_leash_cells * CONFIG.cell_size:
		_route(&"ward", _grid.world_to_cell(ward.global_position), think)
		_walk_towards(_next_goal(ward.global_position), _speed())
		return

	# 3. Shot ready (or nearly): come out and line up.
	if _cooldown_left <= CONFIG.spitter_peek_seconds:
		var can_shoot: bool = distance <= CONFIG.spitter_max_range_cells * CONFIG.cell_size and _sees_target()
		if can_shoot:
			velocity = Vector2.ZERO
			_face(to_target)
			if _cooldown_left <= 0.0:
				is_winding_up = true
				_windup_time_left = CONFIG.spitter_windup
				modulate = WINDUP_TINT  # tints this node and everything it draws
				Sfx.play(&"windup")
			return
		if has_ward:
			# A guard does not leave its ward to hunt. An ARC SPITTER is
			# proactive, though (s18 round 4): it steps to the nearest spot,
			# still within the leash of its Sawbot, that HAS a clear line.
			if guards_sawbots:
				if think or _route_kind != &"fire":
					_fire_cell = _find_spot(true, false)
				if _fire_cell != ArenaGrid.NO_CELL and global_position.distance_to(_grid.cell_to_world(_fire_cell)) > WAYPOINT_REACHED_DISTANCE:
					_route(&"fire", _fire_cell, think)
					_walk_towards(_next_goal(_grid.cell_to_world(_fire_cell)), _speed())
					return
			# Otherwise (or once there) it waits for a clear line.
			velocity = Vector2.ZERO
			_face(to_target)
			return
		# No clear shot: close in along the grid route, like a Scrapper does.
		_route(&"target", _grid.world_to_cell(_target.global_position), think)
		_walk_towards(_next_goal(_target.global_position), _speed())
		return

	# 4. Reloading: get behind something.
	if think or _route_kind != &"cover":
		cover_cell = _find_spot(has_ward, true)
	if cover_cell != ArenaGrid.NO_CELL:
		var spot: Vector2 = _grid.cell_to_world(cover_cell)
		if global_position.distance_to(spot) > WAYPOINT_REACHED_DISTANCE:
			_route(&"cover", cover_cell, think)
			_walk_towards(_next_goal(spot), _speed())
			return
		_route_kind = &"cover"
		velocity = Vector2.ZERO
		_face(to_target)
		return

	# 5. Nowhere to hide. Player too close: step straight back, still facing them.
	_route_kind = &""
	if distance < CONFIG.spitter_min_range_cells * CONFIG.cell_size:
		velocity = -to_target.normalized() * _speed() * speed_scale * movement_factor()
		move_and_slide()  # slides along walls and trees if it backs into one
		_face(to_target)
		return
	# Otherwise it is in a good spot, waiting for the next shot.
	velocity = Vector2.ZERO
	_face(to_target)


## Works out a fresh route to `cell` when it is time to think again, or when
## the Spitter has just changed what it is walking to (`kind`).
func _route(kind: StringName, cell: Vector2i, think: bool) -> void:
	if think or kind != _route_kind:
		_route_kind = kind
		_path_to(cell)


## The nearest living Sawbot, or null if there is none. (An Arc Spitter's ward.)
func _nearest_sawbot() -> Enemy:
	var best: Enemy = null
	var best_distance: float = INF  # INF is infinity: anything is nearer than that
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var sawbot := node as Sawbot  # null for every machine that is not a Sawbot
		if sawbot == null or sawbot.is_dead:
			continue
		var distance: float = global_position.distance_to(sawbot.global_position)
		if distance < best_distance:
			best = sawbot
			best_distance = distance
	return best


## Picks the cell to hide in while reloading, or NO_CELL if there is none.
## It looks at every open cell within spitter_cover_search_cells of its own and
## keeps the ones where:
##   - a ray from the cell to the player hits a wall or a grown tree (so the
##     player cannot shoot it there, and it cannot be seen);
##   - the player is at least spitter_min_range_cells away;
##   - (for a guard) the cell is within the leash of its ward.
## Of those it takes the nearest. Its own cell counts, so a Spitter that is
## already hidden simply stays where it is.
##
## With `hidden` false it looks for the opposite: the nearest cell the player
## CAN be shot from (a clear line, and within shooting range). An Arc Spitter
## uses that to step out and cover its Sawbot.
func _find_spot(has_ward: bool, hidden: bool) -> Vector2i:
	var own: Vector2i = _grid.world_to_cell(global_position)
	var reach: int = CONFIG.spitter_cover_search_cells
	var min_range: float = CONFIG.spitter_min_range_cells * CONFIG.cell_size
	var leash: float = CONFIG.escort_leash_cells * CONFIG.cell_size
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var best: Vector2i = ArenaGrid.NO_CELL
	var best_distance: float = INF
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var cell: Vector2i = own + Vector2i(dx, dy)
			if not _grid.in_bounds(cell) or _grid.is_solid(cell):
				continue
			var spot: Vector2 = _grid.cell_to_world(cell)
			var walk: float = global_position.distance_to(spot)
			if walk >= best_distance:
				continue  # no nearer than the best so far: skip the costly checks
			if spot.distance_to(_target.global_position) < min_range:
				continue
			if has_ward and spot.distance_to(ward.global_position) > leash:
				continue
			# The ray only looks at layer 1 ("world"): an empty result means the
			# player has a clear line to this cell, so it is NOT cover.
			var ray := PhysicsRayQueryParameters2D.create(spot, _target.global_position, WORLD_MASK)
			var is_hidden: bool = not space.intersect_ray(ray).is_empty()
			if is_hidden != hidden:
				continue  # looking for cover and this is open, or the other way round
			if not hidden and spot.distance_to(_target.global_position) > CONFIG.spitter_max_range_cells * CONFIG.cell_size:
				continue  # a firing spot must be within range
			best = cell
			best_distance = walk
	return best


## Overrides Enemy._on_bound: being tied up cancels a shot that was winding up.
func _on_bound() -> void:
	is_winding_up = false


## Ends the windup and sends one shot towards the player.
func _fire(to_target: Vector2) -> void:
	is_winding_up = false
	# An Arc Spitter reloads faster: it is there to keep Seven off the Sawbots.
	_cooldown_left = CONFIG.spitter_cooldown * (CONFIG.arc_spitter_cooldown_factor if arc else 1.0)
	modulate = Color.WHITE  # white = "no tint"
	if to_target == Vector2.ZERO:
		return  # standing exactly on the target: no direction to fire in
	var direction: Vector2 = to_target.normalized()
	# Start the shot just outside our own hit circle.
	var muzzle_distance: float = CONFIG.spitter_radius_cells * CONFIG.cell_size + CONFIG.spit_radius
	spat.emit(global_position + direction * muzzle_distance, direction, arc)
	if arc:
		# An ARC SPITTER fires two more shots, turned a little to each side, in a fan.
		var spread: float = deg_to_rad(CONFIG.arc_spitter_spread_degrees)
		for turn: float in [-spread, spread]:
			var side: Vector2 = direction.rotated(turn)
			spat.emit(global_position + side * muzzle_distance, side, true)
	Sfx.play(&"spit")


## True if a straight line to the target is clear of walls and grown trees.
func _sees_target() -> bool:
	# Shoot an invisible ray at the target. It only looks at layer 1 ("world"),
	# so the player and other machines never block it. An empty result means the
	# ray reached the target without touching anything solid.
	var ray := PhysicsRayQueryParameters2D.create(global_position, _target.global_position, WORLD_MASK)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


## Turns the sprite to look along `direction`.
func _face(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		# The art faces "up", and angle() measures from "right", hence the quarter turn.
		_sprite.rotation = direction.angle() + PI / 2.0
