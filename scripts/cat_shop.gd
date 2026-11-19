# cat_shop.gd - the shuttered shop in the arena wall that hides the lucky cat.
# The jam's mandatory restriction is "Hidden Lucky Cat": this is it.
class_name CatShop
extends StaticBody2D
## The hidden lucky cat.
##
## HOW TO FIND IT: it is meant to be HARD (Sasha's call). A shuttered shop sits
## in the top wall, painted in almost the wall's own colours, so at a glance it
## is just more wall. The only tells, for a sharp eye:
##   - its shutter slats are a shade lighter than the wall around them;
##   - every few seconds two small amber CAT EYES blink between the slats;
##   - a faded paw print, barely visible, on the wall beside it;
##   - Canopy FM's DJ drops hints about it on the air.
## Nothing on the floor points at it. Hit the shop with three seed pods: vines
## grow over the front with each hit, then the shutter lifts and a lucky cat waves.
## REWARD: Lucky's clamp (the vine can bind machines) and a spare fuse. The arena
## hands them over when it hears the `opened` signal. Once open, Seven can talk
## to Lucky (E key nearby, or a tap on the shop); see lucky_lines.gd.
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

## How long the cat's eyes stay open each time they blink on, in seconds.
const EYES_SECONDS: float = 0.5

# Colours. The front and ledge match the arena wall (arena.gd WALL_COLOR), and
# the shutter is only a shade lighter, so the shop hides in the wall.
const FRONT_COLOR: Color = Color(0.19, 0.19, 0.22)
const LEDGE_COLOR: Color = Color(0.19, 0.19, 0.22)
const SHUTTER_COLOR: Color = Color(0.22, 0.22, 0.25)
const SLAT_COLOR: Color = Color(0.16, 0.16, 0.19)
const INSIDE_COLOR: Color = Color(0.10, 0.12, 0.13)
const VINE_COLOR: Color = Color(0.45, 0.85, 0.35)
## A faded paw print: low alpha (see-through), so it is barely there.
const PAW_COLOR: Color = Color(0.94, 0.90, 0.78, 0.16)
## The cat's eyes: amber, brighter than 1 so they read through the night tint.
const EYES_COLOR: Color = Color(1.6, 1.15, 0.35)
const TALK_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)

## How many pods have landed so far, and whether the shutter is up.
## Public (no underscore) so the tests can read them.
var hits: int = 0
var is_open: bool = false
## Set by the arena while Seven stands close enough to talk: shows "E: talk".
var show_talk_hint: bool = false

## Seconds until the cat's eyes next open / left of the current look.
## eyes_left is public so the tests can see when the eyes are showing.
var _eyes_wait: float = 0.0
var eyes_left: float = 0.0
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
	# The cat is drawn smaller than its 64 px art to fit the window. Smooth
	# (linear) scaling keeps its face readable; hard-pixel scaling would drop
	# whole rows of pixels at this size.
	_cat.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if _cat.texture != null:
		# Scale the art to 80% of the shop's height.
		_cat.scale = Vector2.ONE * (cell_px * 0.8 / float(_cat.texture.get_height()))
	add_child(_cat)
	_eyes_wait = CONFIG.cat_glint_interval


## _process runs every drawn frame: time the cat's eyes and its wave.
func _process(delta: float) -> void:
	_time += delta
	if is_open:
		# sin() swings smoothly between -1 and 1, so the cat rocks side to side.
		_cat.rotation = sin(_time * 4.0) * 0.18
	else:
		eyes_left = maxf(eyes_left - delta, 0.0)
		_eyes_wait -= delta
		if _eyes_wait <= 0.0:
			_eyes_wait = CONFIG.cat_glint_interval
			eyes_left = EYES_SECONDS
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
		# The hint: two small amber eyes blink open between two slats now and then.
		if eyes_left > 0.0:
			var eye_y: float = window.position.y + window.size.y * 0.5
			for eye_x: float in [-5.0, 5.0]:
				draw_rect(Rect2(Vector2(eye_x - 1.5, eye_y - 1.0), Vector2(3.0, 2.0)), EYES_COLOR)

	# One vine per pod that has landed, climbing the front.
	for i: int in mini(hits, CONFIG.cat_hits_needed):
		var vine_x: float = lerpf(-half.x + 10.0, half.x - 10.0, (i + 0.5) / float(CONFIG.cat_hits_needed))
		draw_line(Vector2(vine_x, half.y + STICK_OUT), Vector2(vine_x + 5.0, -half.y + 4.0), VINE_COLOR, 3.0)
		draw_circle(Vector2(vine_x + 6.0, -half.y + 8.0), 4.0, VINE_COLOR)
		draw_circle(Vector2(vine_x - 2.0, 2.0), 3.5, VINE_COLOR)

	# "E: talk", just under the ledge, while Seven is close to the open shop.
	if is_open and show_talk_hint:
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(-half.x, half.y + STICK_OUT + 16.0), "E: talk", HORIZONTAL_ALIGNMENT_CENTER, half.x * 2.0, 14, TALK_COLOR)

	# The other hint: a faded paw print on the wall just right of the shop.
	var paw := Vector2(half.x + 16.0, 4.0)
	draw_circle(paw, 5.5, PAW_COLOR)
	for toe: Vector2 in [Vector2(-6.0, -8.0), Vector2(0.0, -10.5), Vector2(6.0, -8.0)]:
		draw_circle(paw + toe, 2.6, PAW_COLOR)
