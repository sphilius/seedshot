# pause_overlay.gd - the pause button, the pause keys, and the "Paused" screen.
# It lives in arena.tscn at Hud/PauseOverlay and must stay the LAST node in Hud:
# Godot hands input to later nodes first, so this node sees a tap before the
# touch controls do and can swallow it.
class_name PauseOverlay
extends Node2D
## Pausing, for desktop and touch.
##
##   Pause    press P or Esc, or tap/click the two-bar button (top-right corner)
##   Resume   press P or Esc again, or tap/click anywhere
##   Mute     press M, or tap/click the speaker button (left of the pause button)
##
## HOW PAUSING WORKS IN GODOT: `get_tree().paused = true` freezes every node's
## _process, _physics_process and input, except nodes whose process_mode says
## otherwise. This node sets PROCESS_MODE_ALWAYS on itself, so it keeps running
## while everything else is frozen. That is the only reason it can un-pause.

## The clickable/tappable button area, measured from the top-right screen corner.
## Bigger than the drawn icon, because a fingertip is not exact.
const BUTTON_SIZE: Vector2 = Vector2(72.0, 48.0)
const ICON_COLOR: Color = Color(1.0, 1.0, 1.0, 0.7)
const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.6)
const PAUSED_TEXT: String = "Paused"
const RESUME_TEXT: String = "Tap, click or press P to carry on"
## Vector2.INF is used as "this event was not a press" (no real press is at infinity).
const NO_PRESS: Vector2 = Vector2.INF

## The mute state the speaker icon was last drawn with (see _process).
var _drawn_muted: bool = false


## _ready runs once when the node enters the scene.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep running while the game is paused


## _exit_tree runs when the node leaves the scene (for example on a restart).
## Un-pause, so the next arena never starts frozen.
func _exit_tree() -> void:
	get_tree().paused = false


## _input receives every input event before the rest of the game does.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
		return

	var press: Vector2 = _press_position(event)
	if press == NO_PRESS:
		return
	if get_tree().paused:
		set_paused(false)  # while paused, a press anywhere carries on
	elif mute_button_rect().has_point(press):
		Sfx.set_muted(not Sfx.is_muted)  # Sfx is the sound autoload (scripts/sfx.gd)
		queue_redraw()  # redraw the speaker with or without its cross
	elif _button_rect().has_point(press):
		set_paused(true)
	else:
		return  # an ordinary press: leave it for the game
	# set_input_as_handled stops this event here, so the press that paused or
	# resumed the game does not also fire a seed or count as a vine tap.
	get_viewport().set_input_as_handled()


## _draw paints the two-bar pause icon, and the dimmed "Paused" screen when paused.
func _draw() -> void:
	var screen: Vector2 = get_viewport_rect().size
	var font: Font = ThemeDB.fallback_font
	if not get_tree().paused:
		# Two upright bars, centred in the button area.
		var centre: Vector2 = _button_rect().get_center()
		draw_rect(Rect2(centre.x - 10.0, centre.y - 11.0, 7.0, 22.0), ICON_COLOR)
		draw_rect(Rect2(centre.x + 3.0, centre.y - 11.0, 7.0, 22.0), ICON_COLOR)
		_draw_speaker(mute_button_rect().get_center())
		return
	draw_rect(Rect2(Vector2.ZERO, screen), DIM_COLOR)
	_draw_centred(font, PAUSED_TEXT, screen.y / 2.0 - 10.0, 72)
	_draw_centred(font, RESUME_TEXT, screen.y / 2.0 + 40.0, 26)


## Pauses or un-pauses the whole game.
func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	queue_redraw()  # swap between the icon and the "Paused" screen


## Where the event pressed, or NO_PRESS if it was not a press at all.
## A press is a finger landing, or a real left mouse click. Godot also makes a
## pretend mouse click out of every finger; that copy is skipped, or one tap
## would count twice (pause, then straight away resume).
func _press_position(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch and event.pressed:
		return (event as InputEventScreenTouch).position
	if event is InputEventMouseButton and event.pressed:
		var click := event as InputEventMouseButton
		var is_real_mouse: bool = click.device != InputEvent.DEVICE_ID_EMULATION
		if is_real_mouse and click.button_index == MOUSE_BUTTON_LEFT:
			return click.position
	return NO_PRESS


## The button's area: the top-right corner of the screen.
func _button_rect() -> Rect2:
	var screen: Vector2 = get_viewport_rect().size
	return Rect2(screen.x - BUTTON_SIZE.x, 0.0, BUTTON_SIZE.x, BUTTON_SIZE.y)


## The mute button's area: the same size as the pause button, just left of it.
func mute_button_rect() -> Rect2:
	var pause_rect: Rect2 = _button_rect()
	return Rect2(pause_rect.position.x - BUTTON_SIZE.x, 0.0, BUTTON_SIZE.x, BUTTON_SIZE.y)


## Draws a small speaker: a box with a cone. When muted, a cross sits beside it;
## when sound is on, two short "sound wave" bars do.
func _draw_speaker(centre: Vector2) -> void:
	# The speaker body (a small square) and its cone (a four-cornered shape).
	draw_rect(Rect2(centre.x - 14.0, centre.y - 5.0, 7.0, 10.0), ICON_COLOR)
	var cone := PackedVector2Array([
		Vector2(centre.x - 7.0, centre.y - 5.0), Vector2(centre.x + 1.0, centre.y - 11.0),
		Vector2(centre.x + 1.0, centre.y + 11.0), Vector2(centre.x - 7.0, centre.y + 5.0),
	])
	draw_colored_polygon(cone, ICON_COLOR)
	if Sfx.is_muted:
		draw_line(Vector2(centre.x + 6.0, centre.y - 6.0), Vector2(centre.x + 16.0, centre.y + 6.0), ICON_COLOR, 3.0)
		draw_line(Vector2(centre.x + 6.0, centre.y + 6.0), Vector2(centre.x + 16.0, centre.y - 6.0), ICON_COLOR, 3.0)
	else:
		draw_rect(Rect2(centre.x + 6.0, centre.y - 4.0, 3.0, 8.0), ICON_COLOR)
		draw_rect(Rect2(centre.x + 12.0, centre.y - 8.0, 3.0, 16.0), ICON_COLOR)


## _process runs every frame: redraw if the M key changed the mute state, so the
## speaker icon always matches what the player hears.
func _process(_delta: float) -> void:
	if Sfx.is_muted != _drawn_muted:
		_drawn_muted = Sfx.is_muted
		queue_redraw()


## Draws one line of text centred left-to-right, with its baseline at `y`.
func _draw_centred(font: Font, text: String, y: float, font_size: int) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var x: float = (get_viewport_rect().size.x - width) / 2.0
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
