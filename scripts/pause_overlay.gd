# pause_overlay.gd - the pause button, the pause keys, and the pause menu.
# It lives in arena.tscn at Hud/PauseOverlay and must stay the LAST node in Hud:
# Godot hands input to later nodes first, so this node sees a tap before the
# touch controls do and can swallow it.
class_name PauseOverlay
extends Node2D
## Pausing, for desktop and touch.
##
##   Pause    press P or Esc, or tap/click the two-bar button (top-right corner)
##   Mute     press M, or tap/click the speaker button (left of the pause button)
##
## THE PAUSE MENU (s18; before that it was only the word "Paused"):
##   left side    five buttons: Resume, Restart this wave, Sound effects on/off,
##                Music on/off, Quit to main menu. Click or tap one, or press
##                its number. P or Esc also resumes.
##   right side   this run's numbers (wave, homes lit, trees...) and the controls.
##   Restart and Quit throw progress away, so they ask first: the first press
##   changes the button to "Sure? ...", the second press does it.
##
## This node only shows the menu and reports the choice ("signal up"): the arena
## restarts the wave or goes back to the title (see Arena._on_pause_*). The
## run's numbers are fetched from the arena through `stats_provider`.
##
## HOW PAUSING WORKS IN GODOT: `get_tree().paused = true` freezes every node's
## _process, _physics_process and input, except nodes whose process_mode says
## otherwise. This node sets PROCESS_MODE_ALWAYS on itself, so it keeps running
## while everything else is frozen. That is the only reason it can un-pause.

## Emitted when the player confirms "Restart this wave".
signal restart_wave_requested
## Emitted when the player confirms "Quit to main menu".
signal quit_requested

## The clickable/tappable button area, measured from the top-right screen corner.
## Bigger than the drawn icon, because a fingertip is not exact.
const BUTTON_SIZE: Vector2 = Vector2(72.0, 48.0)
const ICON_COLOR: Color = Color(1.0, 1.0, 1.0, 0.7)
## Much darker than the old 0.6, so the menu reads over a busy, glowing lot.
const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.84)
const PAUSED_TEXT: String = "PAUSED"
## Vector2.INF is used as "this event was not a press" (no real press is at infinity).
const NO_PRESS: Vector2 = Vector2.INF

## The menu buttons, top to bottom. The numbers are their places in the list.
enum Item { RESUME, RESTART, EFFECTS, MUSIC, QUIT }
const ITEM_COUNT: int = 5
const MENU_BUTTON_SIZE: Vector2 = Vector2(440.0, 62.0)
const MENU_BUTTON_GAP: float = 14.0
## Top-left corner of the first button, in screen pixels.
const MENU_TOP_LEFT: Vector2 = Vector2(120.0, 190.0)
## Left edge of the right-hand column (stats and controls).
const INFO_LEFT: float = 660.0
const PANEL_COLOR: Color = Color(0.05, 0.07, 0.09, 0.95)
const EDGE_COLOR: Color = Color(0.35, 0.90, 0.85)
const WARN_COLOR: Color = Color(1.0, 0.45, 0.35)
const TITLE_COLOR: Color = Color(1.0, 0.82, 0.50)
const TEXT_COLOR: Color = Color(0.92, 0.94, 0.96)
## The words that mark the bind line in the two lists below.
const BIND_MARK: String = "bind it"
const CONTROLS_KEYS: Array[String] = [
	"WASD / arrows   move",
	"Mouse   aim        Left click   shoot seeds",
	"Right click a tree   vine to it",
	"Right click a machine   bind it",
	"Q   throw a Bramble Seed        M   mute",
	"Stand by 4 grown trees   repair",
]
const CONTROLS_TOUCH: Array[String] = [
	"Left thumb   move",
	"Right thumb   aim and shoot",
	"Tap a tree   vine to it",
	"Tap a machine   bind it",
	"Stand by 4 grown trees   repair",
]

## A function the arena hands over that returns this run's numbers as lines of
## text. (A Callable is a function stored in a variable.) Empty until it is set.
var stats_provider: Callable

## True once Lucky's gift lets the vine bind machines. Until then the controls
## list leaves that line out, so it does not give the secret away. Set by the arena.
var bind_unlocked: bool = false

## The mute state the speaker icon was last drawn with (see _process).
var _drawn_muted: bool = false
## The button waiting for its second, confirming press (-1 = none).
var _armed: int = -1


## _ready runs once when the node enters the scene.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep running while the game is paused
	# Draw above everything else on the HUD. The radio panel and the upgrade cards
	# are added in code after this node, and without this they showed through.
	z_index = 100


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

	if get_tree().paused:
		_menu_input(event)
		return

	var press: Vector2 = _press_position(event)
	if press == NO_PRESS:
		return
	if mute_button_rect().has_point(press):
		Sfx.set_muted(not Sfx.is_muted)  # Sfx is the sound autoload (scripts/sfx.gd)
		queue_redraw()  # redraw the speaker with or without its cross
	elif _button_rect().has_point(press):
		set_paused(true)
	else:
		return  # an ordinary press: leave it for the game
	# set_input_as_handled stops this event here, so the press that paused the
	# game does not also fire a seed or count as a vine tap.
	get_viewport().set_input_as_handled()


## Input while the menu is up: number keys and presses on the buttons. Every
## press is swallowed, so nothing behind the menu reacts.
func _menu_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		# physical_keycode is the key's place on the keyboard, whatever the layout.
		var index: int = key.physical_keycode - KEY_1  # KEY_1 -> 0, KEY_2 -> 1, ...
		if index >= 0 and index < ITEM_COUNT:
			choose(index)
			get_viewport().set_input_as_handled()
		return
	var press: Vector2 = _press_position(event)
	if press == NO_PRESS:
		return
	for i: int in ITEM_COUNT:
		if menu_button_rect(i).has_point(press):
			choose(i)
	get_viewport().set_input_as_handled()


## Presses menu button `index` (see Item). Public so the tests can press them.
func choose(index: int) -> void:
	# Restart and Quit need two presses in a row; pressing anything else disarms.
	var needs_confirm: bool = index == Item.RESTART or index == Item.QUIT
	if needs_confirm and _armed != index:
		_armed = index
		queue_redraw()
		return
	_armed = -1
	match index:
		Item.RESUME:
			set_paused(false)
		Item.RESTART:
			set_paused(false)
			restart_wave_requested.emit()
		Item.EFFECTS:
			Sfx.effects_on = not Sfx.effects_on
		Item.MUSIC:
			CanopyFM.set_music_on(not CanopyFM.music_on)
		Item.QUIT:
			set_paused(false)
			quit_requested.emit()
	queue_redraw()


## The text on menu button `index`, with its number in front.
func menu_label(index: int) -> String:
	var text: String = ""
	match index:
		Item.RESUME:
			text = "Resume"
		Item.RESTART:
			text = "Sure? Press again to restart" if _armed == index else "Restart this wave"
		Item.EFFECTS:
			text = "Sound effects: %s%s" % ["On" if Sfx.effects_on else "Off", _muted_note()]
		Item.MUSIC:
			text = "Music: %s%s" % ["On" if CanopyFM.music_on else "Off", _muted_note()]
		Item.QUIT:
			text = "Sure? This run will be lost" if _armed == index else "Quit to main menu"
	return "%d   %s" % [index + 1, text]


## While the speaker button / M key has muted the game, the two sound rows add
## this note, so their On / Off never claims a sound you cannot hear (s19: the
## mute is a master switch on top; each row keeps its own setting underneath).
func _muted_note() -> String:
	return "   (muted: M to unmute)" if Sfx.is_muted else ""


## The screen rectangle of menu button `index` (0 = top).
func menu_button_rect(index: int) -> Rect2:
	var top: float = MENU_TOP_LEFT.y + index * (MENU_BUTTON_SIZE.y + MENU_BUTTON_GAP)
	return Rect2(Vector2(MENU_TOP_LEFT.x, top), MENU_BUTTON_SIZE)


## _draw paints the two-bar pause icon, or the pause menu when paused.
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
	draw_string(font, Vector2(MENU_TOP_LEFT.x, 130.0), PAUSED_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 64, TITLE_COLOR)

	# Left side: the buttons. An armed button (waiting for "sure?") turns red.
	for i: int in ITEM_COUNT:
		var rect: Rect2 = menu_button_rect(i)
		var edge: Color = WARN_COLOR if _armed == i else EDGE_COLOR
		draw_rect(rect, PANEL_COLOR)
		draw_rect(rect, edge, false, 2.0)  # false = outline only
		draw_string(font, rect.position + Vector2(20.0, 40.0), menu_label(i), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 40.0, 24, TEXT_COLOR)
	var hint_y: float = menu_button_rect(ITEM_COUNT - 1).end.y + 34.0
	draw_string(font, Vector2(MENU_TOP_LEFT.x, hint_y), "P or Esc also resumes. New Game + stays unlocked if you quit.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(TEXT_COLOR, 0.7))

	# Right side: this run's numbers, then the controls.
	var y: float = 130.0
	draw_string(font, Vector2(INFO_LEFT, y), "THIS RUN", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, TITLE_COLOR)
	# is_valid() is false until the arena has handed its function over.
	var stats: Array = stats_provider.call() if stats_provider.is_valid() else []
	for line: String in stats:
		y += 30.0
		draw_string(font, Vector2(INFO_LEFT, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, TEXT_COLOR)
	y += 56.0
	draw_string(font, Vector2(INFO_LEFT, y), "CONTROLS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, TITLE_COLOR)
	for line: String in controls_lines(DisplayServer.is_touchscreen_available()):
		y += 28.0
		draw_string(font, Vector2(INFO_LEFT, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(TEXT_COLOR, 0.85))


## The controls to list: the keyboard or the touch set, without the bind line
## until Lucky's gift has unlocked it. Public for the tests.
func controls_lines(touch: bool) -> Array[String]:
	var lines: Array[String] = []
	for line: String in (CONTROLS_TOUCH if touch else CONTROLS_KEYS):
		if bind_unlocked or not line.contains(BIND_MARK):
			lines.append(line)
	return lines


## Pauses or un-pauses the whole game.
func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_armed = -1  # a half-confirmed Restart or Quit never carries over
	queue_redraw()  # swap between the icon and the menu


## Where the event pressed, or NO_PRESS if it was not a press at all.
## A press is a finger landing, or a real left mouse click. Godot also makes a
## pretend mouse click out of every finger; that copy is skipped, or one tap
## would count twice.
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
