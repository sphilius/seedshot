# forest_tree.gd - one tree: starts as a walk-through sapling, becomes solid cover.
# It is called ForestTree because Godot already has a built-in UI class named Tree.
class_name ForestTree
extends StaticBody2D
## A tree growing where a machine fell.
##
## LIFE OF A TREE
##   1. SAPLING: drawn small, no collision, for CONFIG.sapling_time seconds.
##   2. It then ASKS the arena "may I turn solid?" by emitting ready_to_solidify.
##      (The arena says no if someone is standing on it, or if it would seal the
##      player in. A tree does not know about the grid: "signal up, call down".)
##   3. GROWN: solid. Blocks movement and seed pods, and the vine can latch on.
##
## The scene (forest_tree.tscn) puts this on physics layer 1, "world".

## Emitted when the sapling timer runs out. The arena answers by calling
## solidify(), retry_later(), or nothing (the sapling then stays a sapling).
signal ready_to_solidify(tree: ForestTree)
## Emitted just before a grown tree is removed because its HP reached zero.
signal felled(tree: ForestTree)

enum Stage { SAPLING, GROWN }

const CONFIG: GameConfig = preload("res://config/game_config.tres")
## Group that every tree joins, so the player can ask the scene tree for "all trees".
const GROUP: StringName = &"trees"

const SAPLING_COLOR: Color = Color(0.55, 0.85, 0.40)
const TRUNK_COLOR: Color = Color(0.16, 0.33, 0.20)
const CANOPY_COLOR: Color = Color(0.25, 0.55, 0.30)

## The grid cell this tree stands on. Set by the arena before the tree is added.
var cell: Vector2i
## Set to true BEFORE adding the tree to the scene to skip the sapling stage
## (used for the three hand-placed test trees).
var starts_grown: bool = false
var stage: Stage = Stage.SAPLING
var hp: int = 0

## @onready means "fill this in just before _ready runs", once the child node exists.
@onready var _collision: CollisionShape2D = $CollisionShape2D


## _ready runs once when the tree enters the scene.
func _ready() -> void:
	add_to_group(GROUP)
	hp = CONFIG.tree_hp
	# The collision square is exactly one cell, so pods cannot slip between two
	# trees standing side by side.
	(_collision.shape as RectangleShape2D).size = Vector2.ONE * float(CONFIG.cell_size)
	if starts_grown:
		stage = Stage.GROWN
	else:
		_collision.disabled = true  # saplings can be walked and shot through
		_start_timer(CONFIG.sapling_time)


## Called by the arena: become solid cover.
func solidify() -> void:
	stage = Stage.GROWN
	# set_deferred changes the property at a safe moment, after the physics engine
	# has finished its current step. Changing collision mid-step is an error.
	_collision.set_deferred(&"disabled", false)
	queue_redraw()  # ask Godot to call _draw again with the new look


## Called by the arena when someone is standing on the sapling: ask again shortly.
func retry_later() -> void:
	_start_timer(CONFIG.sapling_retry_time)


## Removes HP from a grown tree and fells it at zero. Saplings cannot be hurt.
func take_damage(amount: int) -> void:
	if stage != Stage.GROWN:
		return
	hp -= amount
	if hp <= 0:
		felled.emit(self)  # tell the arena first, so it can clear the grid cell
		queue_free()       # then remove this node at the end of the frame


## _draw is Godot's custom-drawing callback. Coordinates are relative to this node,
## so (0, 0) is the centre of the cell.
func _draw() -> void:
	var cell_px: float = float(CONFIG.cell_size)
	if stage == Stage.SAPLING:
		draw_line(Vector2(0.0, cell_px * 0.2), Vector2(0.0, -cell_px * 0.05), SAPLING_COLOR, 3.0)
		draw_circle(Vector2(-cell_px * 0.08, -cell_px * 0.1), cell_px * 0.09, SAPLING_COLOR)
		draw_circle(Vector2(cell_px * 0.08, -cell_px * 0.1), cell_px * 0.09, SAPLING_COLOR)
	else:
		var half: float = cell_px * 0.5
		draw_rect(Rect2(-half, -half, cell_px, cell_px), TRUNK_COLOR)
		draw_circle(Vector2.ZERO, cell_px * 0.36, CANOPY_COLOR)


## Waits `seconds`, then asks the arena whether this sapling may turn solid.
func _start_timer(seconds: float) -> void:
	# create_timer makes a one-shot timer; `timeout` is its signal, and connect()
	# tells Godot which function to call when the signal fires.
	get_tree().create_timer(seconds).timeout.connect(_on_timer_timeout)


## Runs when the timer above fires. If the tree is still a sapling, it emits the
## ready_to_solidify signal so the arena can decide what happens next.
func _on_timer_timeout() -> void:
	if stage == Stage.SAPLING:
		ready_to_solidify.emit(self)
