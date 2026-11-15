# spitter.gd - the ranged enemy: keeps its distance and fires slow shots.
# Health, dying and path-walking come from enemy.gd.
class_name Spitter
extends Enemy
## A rogue machine that shoots from range.
##
## WHY IT EXISTS (from the design): it makes cover matter. Its shots stop on
## trees, so the forest you planted is what protects you from it.
##
## WHAT IT DOES, every physics step:
##   1. Winding up (red glow): stand still, then fire one shot at where the
##      player is. The glow is the warning, like the Scrapper's.
##   2. Cannot see the player, or too far away: walk towards the player.
##   3. Can see the player and the shot is ready: start winding up.
##   4. Player too close: back away.
##   5. Otherwise: stand and wait for the next shot.
##
## "Can see" means a straight line to the player with no wall or grown tree in
## the way. The Spitter does not create its shot: it emits `spat` and the arena
## spawns it ("signal up").

## Emitted for every shot. `direction` is a unit vector (length 1).
signal spat(origin: Vector2, direction: Vector2)

const FALLBACK_COLOR: Color = Color(0.55, 0.50, 0.62)
## Tint during the windup. Values above 1.0 brighten.
const WINDUP_TINT: Color = Color(1.9, 0.55, 0.45)
## Physics layer 1 ("world") as a bit mask, for the line-of-sight ray.
const WORLD_MASK: int = 1

## True from the start of the warning glow until the shot leaves.
## Public (no underscore) so the tests can watch it.
var is_winding_up: bool = false

## The node to shoot at. Handed in by aim_at().
var _target: Node2D
var _windup_time_left: float = 0.0
## Seconds until the next windup may start.
var _cooldown_left: float = 0.0


## _ready runs once when the Spitter enters the scene.
func _ready() -> void:
	_configure_body(CONFIG.spitter_hp, CONFIG.spitter_radius_cells, CONFIG.spitter_texture, FALLBACK_COLOR)
	# A Spitter that has just walked in waits half a cooldown before its first
	# shot, so nothing fires the instant it appears.
	_cooldown_left = CONFIG.spitter_cooldown * 0.5


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

	# 2. No clear shot: close in along the grid route, like a Scrapper does.
	var can_shoot: bool = distance <= CONFIG.spitter_max_range_cells * CONFIG.cell_size and _sees_target()
	if not can_shoot:
		if _repath_due(delta, CONFIG.spitter_repath_interval):
			_path_to(_grid.world_to_cell(_target.global_position))
		_walk_towards(_next_goal(_target.global_position), CONFIG.spitter_speed)
		return

	# 3. Clear shot and ready: start the warning glow.
	if _cooldown_left <= 0.0:
		is_winding_up = true
		_windup_time_left = CONFIG.spitter_windup
		modulate = WINDUP_TINT  # tints this node and everything it draws
		Sfx.play(&"windup")
		return

	# 4. Player too close: step straight back, still facing the player.
	if distance < CONFIG.spitter_min_range_cells * CONFIG.cell_size:
		velocity = -to_target.normalized() * CONFIG.spitter_speed * speed_scale
		move_and_slide()  # slides along walls and trees if it backs into one
		_face(to_target)
		return

	# 5. In a good spot, waiting for the next shot.
	velocity = Vector2.ZERO
	_face(to_target)


## Overrides Enemy._on_bound: being tied up cancels a shot that was winding up.
func _on_bound() -> void:
	is_winding_up = false


## Ends the windup and sends one shot towards the player.
func _fire(to_target: Vector2) -> void:
	is_winding_up = false
	_cooldown_left = CONFIG.spitter_cooldown
	modulate = Color.WHITE  # white = "no tint"
	if to_target == Vector2.ZERO:
		return  # standing exactly on the target: no direction to fire in
	var direction: Vector2 = to_target.normalized()
	# Start the shot just outside our own hit circle.
	var muzzle_distance: float = CONFIG.spitter_radius_cells * CONFIG.cell_size + CONFIG.spit_radius
	spat.emit(global_position + direction * muzzle_distance, direction)
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
