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

const CONFIG: GameConfig = preload("res://config/game_config.tres")
const GROUP: StringName = &"enemies"
const FALLBACK_COLOR: Color = Color(0.72, 0.42, 0.25)
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

	var to_target: Vector2 = _target.global_position - global_position
	if to_target.length() <= CONFIG.scrapper_stop_distance_cells * CONFIG.cell_size:
		velocity = Vector2.ZERO  # in melee range: stand still (attacks come later)
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
