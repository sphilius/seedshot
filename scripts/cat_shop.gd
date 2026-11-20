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
## The phone's paw button: Lucky's pink on the radio, with a dark paw on it.
const BUTTON_COLOR: Color = Color(1.0, 0.55, 0.75)
const BUTTON_PAW_COLOR: Color = Color(0.30, 0.08, 0.16)
## The neon paw sign: hot pink above 1 so it glows through the night tint, and the
## dim colour of a tube that has dropped out.
const NEON_COLOR: Color = Color(2.2, 0.55, 1.5)
const NEON_DIM_COLOR: Color = Color(0.45, 0.12, 0.32)
## How long one dim-or-bright step of the flicker lasts, in seconds.
const NEON_STUTTER_STEP: float = 0.07

## How many pods have landed so far, and whether the shutter is up.
## Public (no underscore) so the tests can read them.
var hits: int = 0
var is_open: bool = false
## Set by the arena while Seven stands close enough to talk: shows "E: talk".
var show_talk_hint: bool = false
## Set by the arena on a phone or tablet while the shop is open: draws a paw
## button with "Tap" under the shop, in place of "E: talk".
var show_tap_button: bool = false

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
		# Lucky beckons: swap between the paw-up and paw-down pictures. int(time /
		# seconds) counts up by one every cat_wave_seconds; % 2 turns it into 0, 1, 0, 1...
		var paw_down: bool = int(_time / CONFIG.cat_wave_seconds) % 2 == 1
		if CONFIG.cat_wave_texture != null:
			_cat.texture = CONFIG.cat_wave_texture if paw_down else CONFIG.cat_texture
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


## How bright the neon paw is at `time` seconds, 0.25 (dim) to 1.0 (full). Mostly 1.0;
## at the start of every `period` it stutters between dim and bright for
## `flicker_seconds`. `fmod` is the remainder after division for decimals: it turns
## the ever-growing clock into "seconds into this period". Static and public so the
## tests can read the flicker without a shop.
static func neon_level(time: float, period: float, flicker_seconds: float) -> float:
	var phase: float = fmod(time, period)
	if phase >= flicker_seconds:
		return 1.0
	return 0.25 if int(phase / NEON_STUTTER_STEP) % 2 == 0 else 1.0


## True while the neon paw sign is lit: only after the shutter has lifted, so it
## is a reward for finding Lucky and not a clue before. Public for the tests.
func is_neon_showing() -> bool:
	return is_open


## _draw paints the shop. (0, 0) is the centre of the shop front.
func _draw() -> void:
	var cell_px: float = float(CONFIG.cell_size)
	var half := Vector2(WIDTH_CELLS * cell_px, cell_px) / 2.0
	var front := Rect2(-half, half * 2.0)
	draw_rect(front, FRONT_COLOR)
	# The same brickwork as the wall around it (props.gd), lined up with the
	# wall's bricks by passing this node's world position. Camouflage.
	Props.draw_bricks(self, front, global_position)
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
	# (Not on a phone: there the paw button below says "Tap" instead.)
	if is_open and show_talk_hint and not show_tap_button:
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(-half.x, half.y + STICK_OUT + 16.0), "E: talk", HORIZONTAL_ALIGNMENT_CENTER, half.x * 2.0, 14, TALK_COLOR)
	if is_open and show_tap_button:
		_draw_tap_button()

	# The other hint: a faded paw print on the wall just right of the shop. Once the
	# shop is open it is replaced by the flickering neon sign.
	if is_neon_showing():
		_draw_neon_paw(Vector2(half.x + 22.0, 8.0))
	else:
		_draw_paw(Vector2(half.x + 16.0, 4.0), 1.0, PAW_COLOR)


## Where the tap button's centre sits, relative to the shop's centre: just under
## the ledge. Static, so the arena can test a tap against it too.
static func button_offset() -> Vector2:
	var cell_px: float = float(CONFIG.cell_size)
	return Vector2(0.0, cell_px / 2.0 + STICK_OUT + CONFIG.lucky_button_radius_px + 6.0)


## The neon paw sign: ring-shaped tubes (a pad and four toes) with a soft glow behind
## them. While the flicker is dimmed, two toes drop out and the glow goes.
func _draw_neon_paw(at: Vector2) -> void:
	var level: float = neon_level(_time, CONFIG.neon_flicker_period, CONFIG.neon_flicker_seconds)
	var tube: Color = NEON_DIM_COLOR.lerp(NEON_COLOR, level)
	var pad: Vector2 = at + Vector2(0.0, 5.0)
	var toes: Array[Vector2] = [Vector2(-10.0, -3.0), Vector2(-4.0, -8.5), Vector2(4.0, -8.5), Vector2(10.0, -3.0)]
	if level > 0.5:  # the glow only while the sign is burning properly
		draw_circle(pad, 14.0, Color(NEON_COLOR, 0.06))
		for toe: Vector2 in toes:
			draw_circle(at + toe, 7.0, Color(NEON_COLOR, 0.07))
	draw_arc(pad, 7.0, 0.0, TAU, 28, tube, 2.0)
	for i: int in toes.size():
		var toe_tube: Color = tube if (level > 0.5 or i < 2) else NEON_DIM_COLOR
		draw_arc(at + toes[i], 3.3, 0.0, TAU, 20, toe_tube, 2.0)


## A paw print: one pad and three toes, `scale` times the wall print's size.
func _draw_paw(at: Vector2, scale: float, color: Color) -> void:
	draw_circle(at, 5.5 * scale, color)
	for toe: Vector2 in [Vector2(-6.0, -8.0), Vector2(0.0, -10.5), Vector2(6.0, -8.0)]:
		draw_circle(at + toe * scale, 2.6 * scale, color)


## The phone's "talk to Lucky" button: a pink disc with a dark paw print and the
## word "Tap", pulsing gently so it reads as something to press.
func _draw_tap_button() -> void:
	var centre: Vector2 = button_offset()
	var radius: float = CONFIG.lucky_button_radius_px
	# sin(...) swings -1..1; scaled, it makes the button breathe by up to 6%.
	var pulse: float = 1.0 + 0.06 * sin(_time * 4.0)
	draw_circle(centre, radius * pulse, Color(BUTTON_COLOR, 0.92))
	draw_arc(centre, radius * pulse, 0.0, TAU, 32, Color.WHITE, 2.5)
	_draw_paw(centre + Vector2(0.0, 3.0), radius / 12.0, BUTTON_PAW_COLOR)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, centre + Vector2(-radius, radius + 14.0), "Tap", HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 16, Color.WHITE)
