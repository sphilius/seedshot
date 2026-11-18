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

## Night colours: a dark base and a bright canopy, so the tree looks lit from
## inside. Sunroot stores the day's sun and glows with it at night.
const SAPLING_COLOR: Color = Color(0.55, 0.95, 0.55)
const TRUNK_COLOR: Color = Color(0.07, 0.17, 0.14)
const CANOPY_COLOR: Color = Color(0.36, 0.88, 0.56)

## The grid cell this tree stands on. Set by the arena before the tree is added.
var cell: Vector2i
## Set to true BEFORE adding the tree to the scene to skip the sapling stage
## (used for the three hand-placed test trees).
var starts_grown: bool = false
var stage: Stage = Stage.SAPLING
var hp: int = 0
## While true, a ring pulses on the tree: "you can vine to this". The arena
## switches it on for the first tree you grow and off after your first zip.
var show_vine_hint: bool = false

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
		_add_glow()
	else:
		_collision.disabled = true  # saplings can be walked and shot through
		_start_timer(CONFIG.sapling_time)


## Called by the arena: become solid cover.
func solidify() -> void:
	stage = Stage.GROWN
	# set_deferred changes the property at a safe moment, after the physics engine
	# has finished its current step. Changing collision mid-step is an error.
	_collision.set_deferred(&"disabled", false)
	_add_glow()
	queue_redraw()  # ask Godot to call _draw again with the new look


## Gives a grown tree its pool of light (see glow.gd). Saplings have none.
func _add_glow() -> void:
	if has_node(Glow.NODE_NAME):
		return  # already glowing
	add_child(Glow.make_sprite(CONFIG.tree_glow_radius_cells * float(CONFIG.cell_size), CONFIG.tree_glow_color))


## Called by the arena when someone is standing on the sapling: ask again shortly.
func retry_later() -> void:
	_start_timer(CONFIG.sapling_retry_time)


## Removes HP from a grown tree and fells it at zero. Saplings cannot be hurt.
func take_damage(amount: int) -> void:
	if stage != Stage.GROWN:
		return
	hp -= amount
	queue_redraw()  # the canopy shrinks as HP drops (see _draw)
	if hp <= 0:
		felled.emit(self)  # tell the arena first, so it can clear the grid cell
		queue_free()       # then remove this node at the end of the frame


## _process runs every drawn frame. Only the hinted tree needs to redraw each
## frame (its ring is animated); every other tree does nothing here.
func _process(_delta: float) -> void:
	if show_vine_hint:
		queue_redraw()


## _draw is Godot's custom-drawing callback. Coordinates are relative to this node,
## so (0, 0) is the centre of the cell.
func _draw() -> void:
	var cell_px: float = float(CONFIG.cell_size)
	var picture: Texture2D = current_texture()
	if picture != null:
		# Drawn at the same size as every other sprite (64 px), centred on the cell.
		var size: float = CONFIG.sprite_size_cells * cell_px
		draw_texture_rect(picture, Rect2(-size / 2.0, -size / 2.0, size, size), false)
		_draw_vine_hint(cell_px)
		return
	# No pictures in the config: the old shapes (a sprout, or a circle on a square).
	if stage == Stage.SAPLING:
		draw_line(Vector2(0.0, cell_px * 0.2), Vector2(0.0, -cell_px * 0.05), SAPLING_COLOR, 3.0)
		draw_circle(Vector2(-cell_px * 0.08, -cell_px * 0.1), cell_px * 0.09, SAPLING_COLOR)
		draw_circle(Vector2(cell_px * 0.08, -cell_px * 0.1), cell_px * 0.09, SAPLING_COLOR)
	else:
		var half: float = cell_px * 0.5
		draw_rect(Rect2(-half, -half, cell_px, cell_px), TRUNK_COLOR)
		# A hurt tree shows it: the canopy shrinks from full size down to 45% as
		# HP falls, so you can see at a glance which trees a Sawbot has bitten.
		var health: float = clampf(float(hp) / float(CONFIG.tree_hp), 0.0, 1.0)
		draw_circle(Vector2.ZERO, cell_px * 0.36 * lerpf(0.45, 1.0, health), CANOPY_COLOR)
		_draw_vine_hint(cell_px)


## The picture this tree shows right now: sapling, grown, or cut (a grown tree
## that has lost any HP, so you can see at a glance which trees a Sawbot has
## bitten). Null when the config has no tree pictures. Public for the tests.
func current_texture() -> Texture2D:
	if stage == Stage.SAPLING:
		return CONFIG.tree_sapling_texture
	if hp < CONFIG.tree_hp:
		return CONFIG.tree_cut_texture
	return CONFIG.tree_grown_texture


## While show_vine_hint is on, a ring that grows and fades once a second.
func _draw_vine_hint(cell_px: float) -> void:
	if not show_vine_hint:
		return
	# fmod(x, 1.0) is the part of x after the decimal point, so `beat` runs 0 -> 1 over and over.
	var beat: float = fmod(Time.get_ticks_msec() / 1000.0, 1.0)
	var ring := Color(SAPLING_COLOR, 1.0 - beat)  # same colour, fading out
	draw_arc(Vector2.ZERO, cell_px * lerpf(0.45, 0.95, beat), 0.0, TAU, 40, ring, 3.0)


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
