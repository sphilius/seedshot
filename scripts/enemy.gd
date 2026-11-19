# enemy.gd - what every rogue machine has in common: hit points, dying (the arena
# then plants a tree where it fell), and walking a route over the arena grid.
# Scrapper and Sawbot both start with `extends Enemy`, so they get all of this
# for free and only add what makes them different.
class_name Enemy
extends CharacterBody2D
## Base class for the rogue machines.
##
## "extends" is inheritance: a Scrapper IS an Enemy, with extra behaviour on top.
## Anything written here (take_damage, the path helpers) exists on every machine,
## and code that only cares about "some enemy" (the seed pod, the wave director)
## can use the type Enemy without knowing which kind it has.
##
## Each enemy scene puts its body on physics layer 3, "enemies", and it collides
## with layer 1, "world" (walls and grown trees).

## Emitted once, when HP reaches zero. The arena plants a sapling where it fell.
signal died(enemy: Enemy)

const CONFIG: GameConfig = preload("res://config/game_config.tres")
## Group that every machine joins, so code can ask the scene tree for "all enemies".
const GROUP: StringName = &"enemies"
## How close (pixels) to a cell centre counts as "arrived at this waypoint".
const WAYPOINT_REACHED_DISTANCE: float = 5.0

## Tint while tied up by the vine (values above 1.0 brighten): leafy green.
const BOUND_TINT: Color = Color(0.6, 1.5, 0.6)
## Physics layer 1 ("world") as a bit mask, for the yank's safety sweep.
const WORLD_BODY_MASK: int = 1

## Multiplies walking speed. 1.0 is normal; later waves send faster machines.
var speed_scale: float = 1.0
## True while the player's vine has this machine tied up: it cannot walk, swing,
## shoot or saw. It can still be shot.
var is_bound: bool = false
## Physics steps left walking slowly because of a bramble patch. Public so the
## tests can read it; bramble.gd renews it every step the machine stays inside.
var _slowed_steps: int = 0
## Seconds of binding left.
var _bound_time_left: float = 0.0
var hp: int = 0
var is_dead: bool = false

## The grid to find routes over. Handed in by setup().
var _grid: ArenaGrid
## Remaining cells to walk through, next one first.
var _path: Array[Vector2i] = []
## Seconds until the next route recalculation.
var _repath_time_left: float = 0.0
## Colour of the plain square drawn when there is no sprite texture.
var _fallback_color: Color = Color.WHITE

## @onready fills these in just before _ready, once the child nodes exist.
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _sprite: Sprite2D = $Sprite2D


## Called by the arena right after creating the machine ("call down").
func setup(grid: ArenaGrid) -> void:
	_grid = grid


## Removes HP; at zero the machine announces its death and deletes itself.
func take_damage(amount: int) -> void:
	if is_dead:
		return
	hp -= amount
	if hp <= 0:
		is_dead = true
		died.emit(self)
		queue_free()


## The vine's second use: drags this machine towards `puller` in a straight line,
## stopping `stop_distance` pixels short, and ties it up for `seconds`.
## Called by the player when the vine lands on a machine instead of a tree.
func yank_and_bind(puller: Vector2, stop_distance: float, seconds: float) -> void:
	if is_dead:
		return
	is_bound = true
	_bound_time_left = seconds
	velocity = Vector2.ZERO
	modulate = BOUND_TINT
	_on_bound()  # let the machine drop whatever it was in the middle of

	var to_puller: Vector2 = puller - global_position
	var distance: float = to_puller.length()
	if distance <= stop_distance + 1.0:
		return  # already close enough: bind it where it stands
	var motion: Vector2 = (to_puller / distance) * (distance - stop_distance)

	# Same safety check as the player's zip: sweep our own hit circle along the
	# line and only travel as far as it stays clear of walls and trees.
	var sweep := PhysicsShapeQueryParameters2D.new()
	sweep.shape = _collision.shape
	sweep.transform = Transform2D(0.0, global_position)
	sweep.motion = motion
	sweep.collision_mask = WORLD_BODY_MASK
	var fractions: PackedFloat32Array = get_world_2d().direct_space_state.cast_motion(sweep)
	var travel: Vector2 = motion * (fractions[0] if fractions.size() > 0 else 1.0)
	if travel.length() < 4.0:
		return

	# A Tween slides global_position to the end point over distance / speed seconds.
	var tween: Tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)  # step in time with physics
	tween.tween_property(self, "global_position", global_position + travel, travel.length() / CONFIG.vine_yank_speed)


## Called by a bramble patch: walk slowly for the next `steps` physics steps.
func slow_for(steps: int) -> void:
	_slowed_steps = maxi(_slowed_steps, steps)


## True while a bramble is slowing this machine. Used by the tests.
func is_slowed() -> bool:
	return _slowed_steps > 0


## Called the moment the vine binds this machine. Does nothing here; a machine
## that has something to cancel (a windup, a saw cut) writes its own version.
## (This is "overriding": a child class replaces a parent's function.)
func _on_bound() -> void:
	pass


## Each machine calls this first thing in its _physics_process. It counts the
## binding down and returns true while the machine must stay frozen.
func _tick_bound(delta: float) -> bool:
	if not is_bound:
		return false
	_bound_time_left -= delta
	if _bound_time_left <= 0.0:
		is_bound = false
		modulate = Color.WHITE  # white = "no tint"
		return false
	velocity = Vector2.ZERO
	return true


## _draw paints a plain square, only when there is no sprite texture.
func _draw() -> void:
	if _sprite.texture == null:
		var size: float = (_collision.shape as CircleShape2D).radius * 2.0
		draw_rect(Rect2(-size / 2.0, -size / 2.0, size, size), _fallback_color)


## Each kind of machine calls this from its own _ready with its own numbers:
## join the "enemies" group, set HP, and size the hit circle and the sprite.
## (The leading underscore marks it as "for this class and its children only".)
func _configure_body(max_hp: int, radius_cells: float, texture: Texture2D, fallback_color: Color) -> void:
	add_to_group(GROUP)
	hp = max_hp
	_fallback_color = fallback_color
	(_collision.shape as CircleShape2D).radius = radius_cells * CONFIG.cell_size
	_sprite.texture = texture
	if texture != null:
		var wanted_px: float = CONFIG.sprite_size_cells * CONFIG.cell_size
		_sprite.scale = Vector2.ONE * (wanted_px / float(texture.get_width()))


## Counts down the repath timer. Returns true each time a fresh route is due.
func _repath_due(delta: float, interval: float) -> bool:
	_repath_time_left -= delta
	if _repath_time_left > 0.0:
		return false
	_repath_time_left = interval
	return true


## Asks the grid for a fresh route to `target_cell`. If that cell is solid (a
## tree), the route ends at the closest cell that can be reached.
func _path_to(target_cell: Vector2i) -> void:
	_path = _grid.find_path(_grid.world_to_cell(global_position), target_cell)
	# The first entry is the cell we are already standing in. Drop it, or we would
	# walk backwards to our own cell's centre before setting off.
	if not _path.is_empty():
		_path.remove_at(0)


## The pixel position to walk towards right now. `final_position` is where the
## machine really wants to end up (the player, a tree).
func _next_goal(final_position: Vector2) -> Vector2:
	# Tick off waypoints we have already reached.
	while not _path.is_empty():
		var waypoint: Vector2 = _grid.cell_to_world(_path[0])
		if global_position.distance_to(waypoint) > WAYPOINT_REACHED_DISTANCE:
			break
		_path.remove_at(0)
	# One cell (or none) left means the goal is in this cell or the next one:
	# head for its exact position instead of a cell centre.
	if _path.size() <= 1:
		return final_position
	return _grid.cell_to_world(_path[0])


## Takes one physics step towards `goal` at `speed` (times speed_scale), turning
## the sprite to face the way it is going.
func _walk_towards(goal: Vector2, speed: float) -> void:
	velocity = global_position.direction_to(goal) * speed * speed_scale
	# In a bramble patch: walk slower, and count down the steps left in the thorns.
	if _slowed_steps > 0:
		velocity *= CONFIG.bramble_slow_factor
		_slowed_steps -= 1
	# The art faces "up", and angle() measures from "right", hence the quarter turn.
	_sprite.rotation = velocity.angle() + PI / 2.0
	move_and_slide()  # moves by `velocity`, sliding along anything solid
