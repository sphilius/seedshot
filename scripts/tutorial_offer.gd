# tutorial_offer.gd - the "do you remember what to do?" choice at the start of New Game +.
# Created by the arena in code and added to the HUD (so the night tint leaves it
# alone), the same way as the upgrade cards (see upgrade_picker.gd).
class_name TutorialOffer
extends Control
## HOW IT WORKS
##   New Game + opens with Canopy FM asking whether Seven remembers what to do.
##   This node shows two buttons under that line:
##       [1] Remind me     the tutorial plays again (staged first wave + tips)
##       [2] I remember    straight into the fight
##   Press 1 or 2, or click / tap a button. If the player does nothing for
##   ng_plus_refresher_seconds, it answers "I remember" by itself, so the game
##   can never sit waiting.
##
## This node only shows the buttons and reports the answer ("signal up"); the
## arena starts the wave (Arena._on_tutorial_answered).

## Emitted once with the answer: true = play the tutorial, false = skip it.
signal answered(wants_tutorial: bool)

const CONFIG: GameConfig = preload("res://config/game_config.tres")

const BUTTON_SIZE: Vector2 = Vector2(300.0, 64.0)
const BUTTON_GAP: float = 24.0
## Top edge of the two buttons, in screen pixels.
const BUTTONS_TOP: float = 420.0
const BUTTON_COLOR: Color = Color(0.05, 0.07, 0.09, 0.95)
const EDGE_COLOR: Color = Color(0.35, 0.90, 0.85)
const TITLE_COLOR: Color = Color(1.0, 0.82, 0.50)
const TEXT_COLOR: Color = Color(0.92, 0.94, 0.96)
## The two answers, left to right: [label, wants the tutorial].
const CHOICES: Array[Array] = [
	["1   Remind me", true],
	["2   I remember: skip", false],
]

## Seconds left before it answers "skip" by itself. Public so the tests can
## shorten the wait.
var time_left: float = 0.0

## True while the buttons are showing.
var _open: bool = false


## _ready runs once: hidden until offer() is called.
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# IGNORE: clicks pass through to the game except where _has_point says otherwise.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Shows the two buttons and starts the countdown.
func offer() -> void:
	_open = true
	time_left = CONFIG.ng_plus_refresher_seconds
	visible = true
	# STOP: while the buttons are up, this node takes the clicks that land on them.
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


## True while the buttons are showing.
func is_open() -> bool:
	return _open


## Answers the question. Public so the tests (and the countdown) can answer.
func choose(wants_tutorial: bool) -> void:
	if not _open:
		return
	_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	answered.emit(wants_tutorial)


## The screen rectangle of button `index` (0 = left): two buttons, centred.
func button_rect(index: int) -> Rect2:
	var width: float = CHOICES.size() * BUTTON_SIZE.x + (CHOICES.size() - 1) * BUTTON_GAP
	var left: float = (get_viewport_rect().size.x - width) / 2.0
	return Rect2(Vector2(left + index * (BUTTON_SIZE.x + BUTTON_GAP), BUTTONS_TOP), BUTTON_SIZE)


## _process runs every frame: count down, and skip when the time is up.
func _process(delta: float) -> void:
	if not _open:
		return
	time_left -= delta
	queue_redraw()  # the countdown number changes
	if time_left <= 0.0:
		choose(false)


## Keys 1 and 2 answer. (_unhandled_input: only input nothing else used.)
func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		# physical_keycode is the key's place on the keyboard, whatever the layout.
		var index: int = key.physical_keycode - KEY_1  # KEY_1 -> 0, KEY_2 -> 1
		if index >= 0 and index < CHOICES.size():
			choose(CHOICES[index][1])
			get_viewport().set_input_as_handled()


## A click or tap on a button answers. (Touches arrive as mouse clicks too.)
func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	for i: int in CHOICES.size():
		if button_rect(i).has_point(click.position):
			choose(CHOICES[i][1])
			accept_event()  # this click is used up
			return


## True if `point` (screen pixels) is on a button. _has_point decides which
## clicks this Control receives: only those on a button, so the rest of the
## screen still reaches the game.
func _has_point(point: Vector2) -> bool:
	if not _open:
		return false
	for i: int in CHOICES.size():
		if button_rect(i).has_point(point):
			return true
	return false


## _draw paints the heading, the two buttons and the countdown.
func _draw() -> void:
	if not _open:
		return
	var font: Font = ThemeDB.fallback_font
	var screen_width: float = get_viewport_rect().size.x
	draw_string(font, Vector2(0.0, BUTTONS_TOP - 16.0), "Do you remember what to do?", HORIZONTAL_ALIGNMENT_CENTER, screen_width, 22, TITLE_COLOR)
	for i: int in CHOICES.size():
		var rect: Rect2 = button_rect(i)
		draw_rect(rect, BUTTON_COLOR)
		draw_rect(rect, EDGE_COLOR, false, 2.0)  # false = outline only
		var label: String = CHOICES[i][0]
		draw_string(font, rect.position + Vector2(0.0, 40.0), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 20, TEXT_COLOR)
	# ceili rounds up, so the last second reads "1", not "0".
	var note: String = "Skips by itself in %d s   (or tap a button)" % ceili(maxf(time_left, 0.0))
	draw_string(font, Vector2(0.0, BUTTONS_TOP + BUTTON_SIZE.y + 26.0), note, HORIZONTAL_ALIGNMENT_CENTER, screen_width, 15, Color(TEXT_COLOR, 0.7))
