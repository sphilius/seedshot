# player.gd - the gardener-bot: WASD to move, mouse to aim, seed pods and the vine.
class_name Player
extends CharacterBody2D
## The player's gardener-bot.
##
## VERBS
##   Move   WASD / arrow keys. Full speed or stopped (no acceleration in v1).
##   Aim    the bot always faces the mouse pointer.
##   Seed   hold the "fire" action (left click). The player does not create the
##          pod itself: it emits seed_fired and the arena spawns it ("signal up").
##   Vine   press the "vine" action (right click) on a grown tree to zip to it in
##          a straight line, stopping one cell short. Empty space does nothing.
##
## The scene (player.tscn) puts it on physics layer 2, "player", and it collides
## with layer 1, "world" (walls and grown trees).

## Emitted for every shot. `direction` is a unit vector (length 1).
signal seed_fired(origin: Vector2, direction: Vector2)
## Emitted when a vine zip finishes. (Tests wait on this with `await`.)
signal zip_finished
## Emitted whenever hit points change. The arena forwards it to the HUD pips.
signal health_changed(current: int, maximum: int)
## Emitted once, when hit points reach zero. The arena restarts the run.
signal died

const CONFIG: GameConfig = preload("res://config/game_config.tres")
## Physics layer 1 ("world") as a bit mask, for ray and shape queries.
const WORLD_MASK: int = 1
const FALLBACK_COLOR: Color = Color(0.30, 0.70, 0.72)
const VINE_COLOR: Color = Color(0.45, 0.85, 0.35)
const RETICLE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.8)
## How long the vine stays drawn after it lashes a machine.
const LASH_SHOW_SECONDS: float = 0.25

## Unit vector from the bot towards the mouse pointer.
var aim_direction: Vector2 = Vector2.RIGHT
## True while the bot is travelling along the vine. Walking is locked meanwhile.
var is_zipping: bool = false
## Set by TouchControls (scripts/touch_controls.gd) on a phone or tablet. While
## true, the bot ignores the mouse: aim_direction is written by the aim thumb-stick
## and seeds fire while touch_fire_held is true.
var touch_mode: bool = false
var touch_fire_held: bool = false
## Hit points left. Starts at CONFIG.player_max_hp.
var hp: int = 0
## True once hp reaches zero: the bot stops moving, firing and zipping.
var is_dead: bool = false

## The machine the vine last lashed, and how much longer to draw that vine.
var _lash_target: Enemy = null
var _lash_time_left: float = 0.0
## Seconds of "cannot be hurt" left after the last hit (the bot blinks meanwhile).
var _invulnerable_left: float = 0.0

## Seconds until the next seed / next vine is allowed.
var _fire_cooldown_left: float = 0.0
var _vine_cooldown_left: float = 0.0
## Centre of the tree the vine is attached to (only meaningful while zipping).
var _vine_anchor: Vector2 = Vector2.ZERO

## @onready fills these in just before _ready, once the child nodes exist.
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _sprite: Sprite2D = $Sprite2D


## _ready runs once when the player enters the scene: size the hit circle and the
## placeholder sprite from the config.
func _ready() -> void:
	hp = CONFIG.player_max_hp
	(_collision.shape as CircleShape2D).radius = CONFIG.player_radius_cells * CONFIG.cell_size
	_sprite.texture = CONFIG.player_texture
	if _sprite.texture != null:
		var wanted_px: float = CONFIG.sprite_size_cells * CONFIG.cell_size
		_sprite.scale = Vector2.ONE * (wanted_px / float(_sprite.texture.get_width()))


## _physics_process runs 60 times per second: cooldowns, aiming, walking, firing.
func _physics_process(delta: float) -> void:
	_fire_cooldown_left = maxf(_fire_cooldown_left - delta, 0.0)
	_vine_cooldown_left = maxf(_vine_cooldown_left - delta, 0.0)
	_lash_time_left = maxf(_lash_time_left - delta, 0.0)
	_update_hit_blink(delta)
	if is_dead:
		return  # a downed bot does nothing until the arena restarts
	_update_aim()

	if not is_zipping:
		# get_vector reads the four move actions and returns a direction of length
		# 0 (no keys) or 1 (any keys), so diagonals are not faster than straights.
		var input_direction: Vector2 = Input.get_vector(
			&"move_left", &"move_right", &"move_up", &"move_down"
		)
		velocity = input_direction * CONFIG.player_speed
		move_and_slide()  # moves by `velocity` and slides along walls and trees

	# `a if condition else b` picks one of two values. On touch the "fire" action
	# is ignored, because Godot presses it for every finger that lands (see the
	# note about the fake mouse in touch_controls.gd).
	var wants_fire: bool = touch_fire_held if touch_mode else Input.is_action_pressed(&"fire")
	if wants_fire:
		fire(aim_direction)


## _process runs every drawn frame: keep the reticle and vine line up to date.
func _process(_delta: float) -> void:
	queue_redraw()


## _unhandled_input receives input events that no UI element used. The vine is a
## single press (not a hold), so it is handled here as an event.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"vine"):
		try_vine(get_global_mouse_position())


## _draw paints, in order: the vine (while zipping), the fallback body square (only
## if there is no sprite), and the aiming reticle at the mouse pointer.
func _draw() -> void:
	if is_zipping:
		# to_local converts a world position into this node's own coordinates.
		draw_line(Vector2.ZERO, to_local(_vine_anchor), VINE_COLOR, 4.0)
	# The vine to a machine that was just lashed. is_instance_valid: it may have
	# been shot and deleted since.
	if _lash_time_left > 0.0 and is_instance_valid(_lash_target):
		draw_line(Vector2.ZERO, to_local(_lash_target.global_position), VINE_COLOR, 4.0)
	if CONFIG.player_texture == null:
		var size: float = CONFIG.player_radius_cells * CONFIG.cell_size * 2.0
		draw_rect(Rect2(-size / 2.0, -size / 2.0, size, size), FALLBACK_COLOR)
		draw_line(Vector2.ZERO, aim_direction * size * 0.8, FALLBACK_COLOR, 6.0)
	# The reticle sits on the mouse pointer. On touch there is no pointer, so it
	# floats a fixed distance in front of the bot instead.
	var reticle: Vector2 = get_local_mouse_position()
	if touch_mode:
		reticle = aim_direction * CONFIG.touch_reticle_distance_cells * CONFIG.cell_size
	draw_arc(reticle, 9.0, 0.0, TAU, 24, RETICLE_COLOR, 2.0)
	draw_circle(reticle, 2.0, RETICLE_COLOR)


## Fires one seed pod along `direction` if the cooldown allows.
## Returns true if a pod was fired.
func fire(direction: Vector2) -> bool:
	if is_dead or _fire_cooldown_left > 0.0 or direction == Vector2.ZERO:
		return false
	_fire_cooldown_left = CONFIG.seed_cooldown
	var unit: Vector2 = direction.normalized()
	# Start the pod just outside our own hit circle, so it never begins inside us.
	var muzzle_distance: float = CONFIG.player_radius_cells * CONFIG.cell_size + CONFIG.seed_radius
	seed_fired.emit(global_position + unit * muzzle_distance, unit)
	Sfx.play(&"fire")
	return true


## Tries to latch the vine onto the tree at `world_point` and zip to it.
## Returns true if a zip started; false means nothing happened (no tree there,
## out of range, a wall in the way, already next to it, or still cooling down).
## `pick_radius_cells` is how close `world_point` must be to a tree's centre. Leave
## it out to use the mouse value from the config; touch taps pass a bigger one.
func try_vine(world_point: Vector2, pick_radius_cells: float = -1.0) -> bool:
	if is_dead or is_zipping or _vine_cooldown_left > 0.0:
		return false
	# -1.0 is the "not given" marker (a radius can never really be negative).
	if pick_radius_cells < 0.0:
		pick_radius_cells = CONFIG.vine_pick_radius_cells
	var pick_radius: float = pick_radius_cells * CONFIG.cell_size

	# A machine under the pointer comes first: yank it over and tie it up.
	var enemy: Enemy = _pick_enemy(world_point, pick_radius)
	if enemy != null and _lash_enemy(enemy):
		return true

	var picked: ForestTree = _pick_tree(world_point, pick_radius)
	if picked == null:
		return false  # right click on empty space: do nothing

	# Shoot an invisible ray at the tree. Whatever solid thing it meets first is
	# what the vine really grabs: a nearer tree is fine, a wall means no latch.
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var ray := PhysicsRayQueryParameters2D.create(global_position, picked.global_position, WORLD_MASK)
	var hit: Dictionary = space.intersect_ray(ray)
	if hit.is_empty():
		return false
	var latched := hit["collider"] as ForestTree
	if latched == null:
		return false
	if global_position.distance_to(latched.global_position) > CONFIG.vine_range:
		return false
	return _start_zip(latched)


## Takes `amount` hit points away. Returns true if the hit counted, false if it
## was ignored (already down, or still blinking from the previous hit).
func take_damage(amount: int) -> bool:
	if is_dead or _invulnerable_left > 0.0 or amount <= 0:
		return false
	hp = maxi(hp - amount, 0)  # maxi = the larger of two whole numbers: never below 0
	health_changed.emit(hp, CONFIG.player_max_hp)
	if hp == 0:
		is_dead = true
		velocity = Vector2.ZERO
		modulate = Color(0.45, 0.45, 0.45, 0.8)  # greyed out
		Sfx.play(&"player_down")
		died.emit()
		return true
	_invulnerable_left = CONFIG.player_hit_invulnerable_time
	Sfx.play(&"hurt")
	return true


## Brings a downed bot back at full health at `world_position`. Called by the
## arena when a wave restarts. The short blink gives a moment of safety.
func revive(world_position: Vector2) -> void:
	global_position = world_position
	velocity = Vector2.ZERO
	hp = CONFIG.player_max_hp
	is_dead = false
	is_zipping = false
	modulate = Color.WHITE
	_invulnerable_left = CONFIG.player_hit_invulnerable_time
	health_changed.emit(hp, CONFIG.player_max_hp)


## Counts down the "cannot be hurt" time and blinks the bot while it lasts.
func _update_hit_blink(delta: float) -> void:
	if is_dead or _invulnerable_left <= 0.0:
		return
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	if _invulnerable_left == 0.0:
		modulate = Color.WHITE  # white = fully visible, no tint
		return
	# Flip between faint and solid about eight times a second. fmod is the
	# remainder after division, so this repeats every 0.12 s.
	var is_faint: bool = fmod(_invulnerable_left, 0.12) < 0.06
	modulate = Color(1.0, 1.0, 1.0, 0.35 if is_faint else 1.0)


## Makes the sprite (and aim_direction) point at the mouse. On touch, the aim
## thumb-stick has already written aim_direction, so only the sprite is turned.
func _update_aim() -> void:
	if not touch_mode:
		var to_mouse: Vector2 = get_global_mouse_position() - global_position
		if to_mouse.length() > 1.0:
			aim_direction = to_mouse.normalized()
	# The art faces "up", and angle() measures from "right", hence the quarter turn.
	_sprite.rotation = aim_direction.angle() + PI / 2.0


## Returns the machine nearest to `world_point`, if one is within `pick_radius`
## pixels; otherwise null.
func _pick_enemy(world_point: Vector2, pick_radius: float) -> Enemy:
	var best: Enemy = null
	var best_distance: float = pick_radius
	# Every machine adds itself to the "enemies" group.
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead:
			continue
		var distance: float = enemy.global_position.distance_to(world_point)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


## The vine's second use: lash a machine, drag it towards the bot and bind it.
## Returns false (nothing happens) if it is out of range or behind a wall or tree.
func _lash_enemy(enemy: Enemy) -> bool:
	if global_position.distance_to(enemy.global_position) > CONFIG.vine_range:
		return false
	# The vine needs a clear line: a ray that only looks at walls and trees must
	# reach the machine without touching anything.
	var ray := PhysicsRayQueryParameters2D.create(global_position, enemy.global_position, WORLD_MASK)
	if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		return false
	enemy.yank_and_bind(global_position, CONFIG.vine_yank_stop_cells * CONFIG.cell_size, CONFIG.vine_bind_time)
	_vine_cooldown_left = CONFIG.vine_cooldown
	# Remember it for a moment so _draw can show the vine reaching out.
	_lash_target = enemy
	_lash_time_left = LASH_SHOW_SECONDS
	Sfx.play(&"bind")
	return true


## Returns the grown tree nearest to `world_point`, if one is within
## `pick_radius` pixels; otherwise null.
func _pick_tree(world_point: Vector2, pick_radius: float) -> ForestTree:
	var best: ForestTree = null
	var best_distance: float = pick_radius
	# Every tree adds itself to the "trees" group, so this loop sees all of them.
	for node: Node in get_tree().get_nodes_in_group(ForestTree.GROUP):
		var tree := node as ForestTree
		if tree == null or tree.stage != ForestTree.Stage.GROWN:
			continue
		var distance: float = tree.global_position.distance_to(world_point)
		if distance <= best_distance:
			best = tree
			best_distance = distance
	return best


## Starts the straight-line zip towards `tree`. Returns false if there is nowhere to go.
func _start_zip(tree: ForestTree) -> bool:
	var to_tree: Vector2 = tree.global_position - global_position
	var distance: float = to_tree.length()
	var stop_short: float = CONFIG.vine_stop_short_cells * CONFIG.cell_size
	if distance <= stop_short + 1.0:
		return false  # already as close as the vine would bring us

	# The full move we would like to make: towards the tree, stopping one cell short.
	var motion: Vector2 = (to_tree / distance) * (distance - stop_short)

	# The tween below moves us without collision checks, so we check first: sweep
	# our own hit circle along the line and see how far it gets before touching
	# anything solid. cast_motion answers with fractions of the motion (0.0 to 1.0);
	# the first one is the furthest SAFE fraction.
	var sweep := PhysicsShapeQueryParameters2D.new()
	sweep.shape = _collision.shape
	sweep.transform = Transform2D(0.0, global_position)
	sweep.motion = motion
	sweep.collision_mask = WORLD_MASK
	var fractions: PackedFloat32Array = get_world_2d().direct_space_state.cast_motion(sweep)
	var safe_fraction: float = fractions[0] if fractions.size() > 0 else 1.0
	var travel: Vector2 = motion * safe_fraction
	if travel.length() < 4.0:
		return false  # blocked almost immediately: not worth a zip

	is_zipping = true
	velocity = Vector2.ZERO
	_vine_anchor = tree.global_position
	Sfx.play(&"zip")

	# A Tween animates a property over time. This one slides global_position to the
	# destination; the duration comes from distance / speed.
	var tween: Tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)  # step in time with physics
	tween.tween_property(
		self, "global_position", global_position + travel, travel.length() / CONFIG.vine_zip_speed
	)
	tween.finished.connect(_on_zip_tween_finished)
	return true


## Runs when the zip tween ends: unlock walking and start the vine cooldown.
func _on_zip_tween_finished() -> void:
	is_zipping = false
	_vine_cooldown_left = CONFIG.vine_cooldown
	zip_finished.emit()
