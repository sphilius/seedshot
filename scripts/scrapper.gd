# scrapper.gd - the baseline enemy: walks at the player around trees, dies in one pod.
class_name Scrapper
extends CharacterBody2D
## A rogue machine that rushes the player.
##
## HOW IT FINDS ITS WAY: a few times per second it asks the ArenaGrid for a path
## (a list of cells) from its own cell to the player's cell, then walks from cell
## centre to cell centre. Because the path is recalculated on a timer, it reacts
## when a new tree grows or the player moves.
##
## The scene (scrapper.tscn) puts it on physics layer 3, "enemies", and it collides
## with layer 1, "world" (walls and grown trees).

## Emitted once, when HP reaches zero. The arena plants a sapling where it fell.
signal died(scrapper: Scrapper)
## Emitted when a melee swing lands. The Scrapper does not touch the player's
## health itself: the arena connects this to the player ("signal up").
signal struck(damage: int)

const CONFIG: GameConfig = preload("res://config/game_config.tres")
const GROUP: StringName = &"enemies"
const FALLBACK_COLOR: Color = Color(0.72, 0.42, 0.25)
## The sprite is tinted this colour during the windup. Values above 1.0 brighten.
## Red is the one colour reserved for "an enemy is about to hurt you".
const WINDUP_TINT: Color = Color(1.9, 0.55, 0.45)
## How close (pixels) to a cell centre counts as "arrived at this waypoint".
const WAYPOINT_REACHED_DISTANCE: float = 5.0

## The grid to path over and the node to chase. Both are handed in by setup().
var _grid: ArenaGrid
var _target: Node2D
var _hp: int = 0
var _is_dead: bool = false
## Remaining cells to walk through, next one first.
var _path: Array[Vector2i] = []
## Seconds until the next path recalculation.
var _repath_time_left: float = 0.0
## True from the start of a swing's warning glow until the hit lands or misses.
## Public (no underscore) so the tests can watch it.
var is_winding_up: bool = false
## Seconds left in the current windup / until the next swing is allowed.
var _windup_time_left: float = 0.0
var _melee_cooldown_left: float = 0.0

@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _sprite: Sprite2D = $Sprite2D


## _ready runs once when the Scrapper enters the scene: join the "enemies" group,
## take starting HP from the config, and size the hit circle and sprite.
func _ready() -> void:
	add_to_group(GROUP)
	_hp = CONFIG.scrapper_hp
	(_collision.shape as CircleShape2D).radius = CONFIG.scrapper_radius_cells * CONFIG.cell_size
	# Use the placeholder sprite if the config has one; otherwise _draw paints a square.
	_sprite.texture = CONFIG.scrapper_texture
	if _sprite.texture != null:
		var wanted_px: float = CONFIG.sprite_size_cells * CONFIG.cell_size
		_sprite.scale = Vector2.ONE * (wanted_px / float(_sprite.texture.get_width()))


## Called by the arena right after creating the Scrapper ("call down").
func setup(grid: ArenaGrid, target: Node2D) -> void:
	_grid = grid
	_target = target


## _physics_process runs 60 times per second: refresh the route on a timer, then
## take one step along it.
func _physics_process(delta: float) -> void:
	# is_instance_valid guards against the target having been deleted.
	if _grid == null or not is_instance_valid(_target):
		return

	_repath_time_left -= delta
	if _repath_time_left <= 0.0:
		_repath_time_left = CONFIG.scrapper_repath_interval
		_recalculate_path()

	var distance: float = global_position.distance_to(_target.global_position)
	_update_melee(delta, distance)
	# A Scrapper commits to its swing: it stands still while winding up. It also
	# stands still once it is close enough that walking further would only shove.
	if is_winding_up or distance <= CONFIG.scrapper_stop_distance_cells * CONFIG.cell_size:
		velocity = Vector2.ZERO
		return

	var goal: Vector2 = _next_goal()
	velocity = global_position.direction_to(goal) * CONFIG.scrapper_speed
	# The art faces "up", and angle() measures from "right", hence the quarter turn.
	_sprite.rotation = velocity.angle() + PI / 2.0
	move_and_slide()  # moves by `velocity`, sliding along anything solid


## _draw paints the fallback gray-box square, only when there is no sprite texture.
func _draw() -> void:
	if CONFIG.scrapper_texture == null:
		var size: float = CONFIG.scrapper_radius_cells * CONFIG.cell_size * 2.0
		draw_rect(Rect2(-size / 2.0, -size / 2.0, size, size), FALLBACK_COLOR)


## Removes HP; at zero the Scrapper announces its death and deletes itself.
func take_damage(amount: int) -> void:
	if _is_dead:
		return
	_hp -= amount
	if _hp <= 0:
		_is_dead = true
		died.emit(self)
		queue_free()


## The melee attack, one step at a time. `distance` is how far the target is.
##   1. Target in range and the cooldown is over: start the windup (red glow).
##   2. Windup ends: if the target is STILL in range the swing lands (emit
##      `struck`); if it got away, the swing misses. Either way, cool down.
## The windup is the player's chance to react, which is what makes the hit fair.
func _update_melee(delta: float, distance: float) -> void:
	var in_range: bool = distance <= CONFIG.scrapper_melee_range_cells * CONFIG.cell_size
	_melee_cooldown_left = maxf(_melee_cooldown_left - delta, 0.0)

	if not is_winding_up:
		if in_range and _melee_cooldown_left <= 0.0:
			is_winding_up = true
			_windup_time_left = CONFIG.scrapper_melee_windup
			modulate = WINDUP_TINT  # tints this node and everything it draws
			Sfx.play(&"windup")
		return

	_windup_time_left -= delta
	if _windup_time_left > 0.0:
		return
	# The windup just ended: resolve the swing.
	is_winding_up = false
	_melee_cooldown_left = CONFIG.scrapper_melee_cooldown
	modulate = Color.WHITE  # white = "no tint"
	if in_range:
		struck.emit(CONFIG.scrapper_melee_damage)


## Asks the grid for a fresh route to the target.
func _recalculate_path() -> void:
	var my_cell: Vector2i = _grid.world_to_cell(global_position)
	var target_cell: Vector2i = _grid.world_to_cell(_target.global_position)
	_path = _grid.find_path(my_cell, target_cell)
	# The first entry is the cell we are already standing in. Drop it, or we would
	# walk backwards to our own cell's centre before setting off.
	if not _path.is_empty():
		_path.remove_at(0)


## The pixel position to walk towards right now.
func _next_goal() -> Vector2:
	# Tick off waypoints we have already reached.
	while not _path.is_empty():
		var waypoint: Vector2 = _grid.cell_to_world(_path[0])
		if global_position.distance_to(waypoint) > WAYPOINT_REACHED_DISTANCE:
			break
		_path.remove_at(0)
	# One cell (or none) left means the target is in this cell or the next one:
	# head for its exact position instead of a cell centre.
	if _path.size() <= 1:
		return _target.global_position
	return _grid.cell_to_world(_path[0])
