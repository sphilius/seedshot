# cat_shop.gd - the shuttered shop in the arena wall that hides the lucky cat.
# The jam's mandatory restriction is "Hidden Lucky Cat": this is it.
class_name CatShop
extends StaticBody2D
## The hidden lucky cat.
##
## HOW TO FIND IT (from the design): a shuttered shop sits in the top wall, away
## from the middle of the fight. Its window glints every few seconds and a paw
## print is painted beside it. Hit the shop with three seed pods: vines grow over
## the front with each hit, then the shutter lifts and a lucky cat waves.
## REWARD: seed pods fire as a pair for the rest of the run (the arena does that
## when it hears the `opened` signal).
##
## The arena creates this node in code (CatShop.new()), so it builds its own
## collision shape and cat sprite in _ready instead of having a scene file.
## It sits on physics layer 1, "world", so seed pods stop on it like on a wall.

## Emitted once, when the last needed pod lands and the shutter lifts.
signal opened

const CONFIG: GameConfig = preload("res://config/game_config.tres")
## The shop front is two cells wide and one cell tall.
const WIDTH_CELLS: float = 2.0
## How far (pixels) the front sticks out of the wall into the arena, as a ledge.
## Without this, a pod reaches the plain wall behind at the same moment and the
## wall "wins" the hit. A pod moves 12 px per physics step (720 / 60), so the
## ledge must be deeper than that for the pod to touch the shop one step earlier.
const STICK_OUT: float = 16.0
const LEDGE_COLOR: Color = Color(0.24, 0.26, 0.28)
const GLINT_SECONDS: float = 0.35

const FRONT_COLOR: Color = Color(0.30, 0.33, 0.35)
const SHUTTER_COLOR: Color = Color(0.52, 0.56, 0.58)
const SLAT_COLOR: Color = Color(0.36, 0.40, 0.42)
const INSIDE_COLOR: Color = Color(0.10, 0.12, 0.13)
const VINE_COLOR: Color = Color(0.45, 0.85, 0.35)
const PAW_COLOR: Color = Color(0.94, 0.90, 0.78, 0.85)
const GLINT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)

## How many pods have landed so far, and whether the shutter is up.
## Public (no underscore) so the tests can read them.
var hits: int = 0
var is_open: bool = false

## Seconds until the next glint starts / left of the current glint.
var _glint_wait: float = 0.0
var _glint_left: float = 0.0
## Total seconds since the scene started, for the cat's wave.
var _time: float = 0.0
var _cat: Sprite2D


## _ready runs once when the shop enters the scene: build the collision box and
## the (hidden) cat sprite.
func _ready() -> void:
	collision_layer = 1  # "world": seed pods and enemy shots stop here
	collision_mask = 0   # the shop itself never needs to detect anything
	var cell_px: float = float(CONFIG.cell_size)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(WIDTH_CELLS * cell_px, cell_px + STICK_OUT)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, STICK_OUT / 2.0)  # shifted down, into the arena
	add_child(collision)

	_cat = Sprite2D.new()
	_cat.texture = CONFIG.cat_texture
	_cat.visible = false
	if _cat.texture != null:
		# Scale the art to 80% of the shop's height.
		_cat.scale = Vector2.ONE * (cell_px * 0.8 / float(_cat.texture.get_height()))
	add_child(_cat)
	_glint_wait = CONFIG.cat_glint_interval


## _process runs every drawn frame: time the glint and the cat's wave.
func _process(delta: float) -> void:
	_time += delta
	if is_open:
		# sin() swings smoothly between -1 and 1, so the cat rocks side to side.
		_cat.rotation = sin(_time * 4.0) * 0.18
	else:
		_glint_left = maxf(_glint_left - delta, 0.0)
		_glint_wait -= delta
		if _glint_wait <= 0.0:
			_glint_wait = CONFIG.cat_glint_interval
			_glint_left = GLINT_SECONDS
	queue_redraw()  # ask Godot to call _draw again this frame


## Called by a seed pod that lands on the shop.
func hit_by_seed() -> void:
	if is_open:
		return
	hits += 1
	Sfx.play(&"grow")
	if hits >= CONFIG.cat_hits_needed:
		is_open = true
		_cat.visible = true
		Sfx.play(&"cat")
		opened.emit()


## _draw paints the shop. (0, 0) is the centre of the shop front.
func _draw() -> void:
	var cell_px: float = float(CONFIG.cell_size)
	var half := Vector2(WIDTH_CELLS * cell_px, cell_px) / 2.0
	var front := Rect2(-half, half * 2.0)
	draw_rect(front, FRONT_COLOR)
	# The ledge: the part that sticks out of the wall line into the arena.
	draw_rect(Rect2(-half.x, half.y, half.x * 2.0, STICK_OUT), LEDGE_COLOR)
	var window: Rect2 = front.grow(-6.0)  # grow(-n) shrinks each side by n

	if is_open:
		draw_rect(window, INSIDE_COLOR)  # the cat sprite (a child node) draws on top
	else:
		# The closed shutter: a pale panel with darker slat lines across it.
		draw_rect(window, SHUTTER_COLOR)
		for i: int in range(1, 5):
			var y: float = window.position.y + window.size.y * i / 5.0
			draw_line(Vector2(window.position.x, y), Vector2(window.end.x, y), SLAT_COLOR, 2.0)
		# The hint: a bright diagonal flash across the shutter every few seconds.
		if _glint_left > 0.0:
			var slide: float = 1.0 - _glint_left / GLINT_SECONDS  # 0 at start, 1 at end
			var x: float = lerpf(window.position.x, window.end.x - 14.0, slide)
			draw_line(Vector2(x, window.end.y), Vector2(x + 14.0, window.position.y), GLINT_COLOR, 4.0)

	# One vine per pod that has landed, climbing the front.
	for i: int in mini(hits, CONFIG.cat_hits_needed):
		var vine_x: float = lerpf(-half.x + 10.0, half.x - 10.0, (i + 0.5) / float(CONFIG.cat_hits_needed))
		draw_line(Vector2(vine_x, half.y + STICK_OUT), Vector2(vine_x + 5.0, -half.y + 4.0), VINE_COLOR, 3.0)
		draw_circle(Vector2(vine_x + 6.0, -half.y + 8.0), 4.0, VINE_COLOR)
		draw_circle(Vector2(vine_x - 2.0, 2.0), 3.5, VINE_COLOR)

	# The other hint: a paw print painted on the wall just right of the shop.
	var paw := Vector2(half.x + 16.0, 4.0)
	draw_circle(paw, 5.5, PAW_COLOR)
	for toe: Vector2 in [Vector2(-6.0, -8.0), Vector2(0.0, -10.5), Vector2(6.0, -8.0)]:
		draw_circle(paw + toe, 2.6, PAW_COLOR)
