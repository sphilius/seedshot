# touch_controls.gd - phone and tablet controls: two thumb-sticks and tap-to-vine.
# It lives in arena.tscn at Hud/TouchControls. Deleting that one node removes touch
# support completely; the mouse and keyboard controls do not depend on it.
class_name TouchControls
extends Node2D
## Touch controls, layered on top of the normal ones.
##
## THE SAME FOUR VERBS, BY FINGER
##   Move   slide a thumb on the LEFT half of the screen  (same as WASD)
##   Aim    slide a thumb on the RIGHT half               (same as moving the mouse)
##   Seed   fires for as long as the right thumb is held  (same as holding left click)
##   Vine   quick tap on a tree, anywhere on screen       (same as right click)
##
## HOW ONE TOUCH IS READ
##   Every finger starts as PENDING. If it slides further than touch_drag_threshold
##   it becomes a stick (MOVE or AIM, depending on which half it landed on). If it
##   lifts quickly without sliding, it was a tap. So a tap can never be mistaken for
##   a stick, and trees under the thumbs can still be tapped.
##
## HOW IT TALKS TO THE REST OF THE GAME ("call down")
##   Move  presses the normal move_* input actions from code, so the player script
##         cannot tell a thumb from a keyboard.
##   Aim   writes player.aim_direction and player.touch_fire_held.
##   Vine  calls player.try_vine(), the same function right click uses.
##
## Nothing here runs until a finger first touches the screen, so desktop play is
## unchanged. Moving a real mouse switches back to mouse aiming.
##
## NOTE ON GODOT'S FAKE MOUSE: Godot also turns the first finger into a pretend
## left click ("emulate mouse from touch", on by default so that menu buttons work
## on phones). The player ignores the mouse while touch_mode is on, so that pretend
## click does not fire a seed.

## What a finger is currently doing.
enum Role { PENDING, MOVE, AIM }

const CONFIG: GameConfig = preload("res://config/game_config.tres")
## After the last finger lifts, ignore mouse movement for this long. Some browsers
## send a stray mouse event right after a touch; it must not end touch mode.
const MOUSE_IGNORE_SECONDS: float = 1.0
## Where the faint "put your thumbs here" rings sit, as fractions of the screen.
const MOVE_REST_SPOT: Vector2 = Vector2(0.13, 0.76)
const AIM_REST_SPOT: Vector2 = Vector2(0.87, 0.76)
const MOVE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.55)
const AIM_COLOR: Color = Color(0.75, 0.95, 0.45, 0.60)
const REST_ALPHA: float = 0.30
const TOUCH_HINT: String = "Left thumb: move   |   Right thumb: aim + fire   |   Tap a tree: zip   |   Tap a machine: bind"
const ROTATE_TEXT: String = "Turn your phone sideways"
## The Bramble Seed button: a circle on the right side, above the aim stick's spot
## (as shares of the screen width and height), and its radius in pixels.
const BRAMBLE_SPOT: Vector2 = Vector2(0.93, 0.48)
const BRAMBLE_RADIUS: float = 42.0
const BRAMBLE_COLOR: Color = Color(0.55, 0.85, 0.40, 0.65)


## One finger on the glass. (An inner class: a small data holder that only this
## script uses, so it does not need its own file.)
class Finger:
	## Where the finger first landed. Decides left/right half and the tap target.
	var start: Vector2
	## Centre of the stick. Starts at `start`, then follows a far-sliding thumb.
	var origin: Vector2
	## Where the finger is now.
	var position: Vector2
	var role: Role = Role.PENDING
	## Seconds this finger has been down.
	var age: float = 0.0
	## Turns false the moment the finger slides too far to still be a tap.
	var can_be_tap: bool = true


## True once a finger has touched the screen (and until a real mouse moves).
var touch_mode: bool = false

## The label whose text swaps to the touch instructions. Set in arena.tscn.
@export var hint_label: Label

var _player: Player
## Fingers currently down, keyed by Godot's finger number (0 = first finger).
var _fingers: Dictionary[int, Finger] = {}
## Which finger drives each stick, or -1 if that stick is not in use.
var _move_finger: int = -1
var _aim_finger: int = -1
## Move actions this script is holding down, so it only ever releases its own.
var _held_actions: Array[StringName] = []
var _seconds_since_touch: float = MOUSE_IGNORE_SECONDS
## The label's desktop text, kept so it can be put back.
var _desktop_hint: String = ""


## _ready runs once when the node enters the scene: remember the desktop hint.
func _ready() -> void:
	if hint_label != null:
		_desktop_hint = hint_label.text


## Called by the arena once the player exists ("call down": the parent hands the
## child what it needs, so this script never has to search the tree).
func setup(player: Player) -> void:
	_player = player


## _exit_tree runs when the node leaves the scene: let go of any held actions so a
## restart never begins with the bot still walking.
func _exit_tree() -> void:
	_release_move_actions()


## _input receives every input event. Raw touch events are translated into the
## three public touch_* calls below, which hold the real logic (and which the
## headless tests call directly, because headless Godot has no touchscreen).
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			touch_down(touch.index, touch.position)
		else:
			touch_up(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		touch_moved(drag.index, drag.position)
	elif event is InputEventMouseMotion:
		# A real mouse moved: hand aiming back to it. Godot's pretend mouse (made
		# from a finger) carries the special "emulation" device number; skip those.
		var is_real_mouse: bool = event.device != InputEvent.DEVICE_ID_EMULATION
		if is_real_mouse and _fingers.is_empty() and _seconds_since_touch >= MOUSE_IGNORE_SECONDS:
			_set_touch_mode(false)


## _physics_process runs 60 times per second: age the fingers (for tap timing).
func _physics_process(delta: float) -> void:
	for finger: Finger in _fingers.values():
		finger.age += delta
	if _fingers.is_empty():
		_seconds_since_touch += delta


## _process runs every drawn frame: redraw only while the sticks are on screen.
func _process(_delta: float) -> void:
	if touch_mode:
		queue_redraw()


## _draw paints the two sticks (faint rings while idle, ring + knob while held)
## and, on a phone held upright, a request to turn it sideways.
func _draw() -> void:
	if not touch_mode:
		return
	var screen: Vector2 = get_viewport_rect().size
	_draw_stick(_move_finger, MOVE_REST_SPOT * screen, MOVE_COLOR)
	_draw_stick(_aim_finger, AIM_REST_SPOT * screen, AIM_COLOR)
	# The Bramble Seed button, with one small dot per seed in hand. Only once
	# Seven has the seeds (s24: their card unlocks them).
	if is_bramble_button_shown():
		var button: Vector2 = BRAMBLE_SPOT * screen
		draw_arc(button, BRAMBLE_RADIUS, 0.0, TAU, 40, BRAMBLE_COLOR, 3.0)
		draw_string(ThemeDB.fallback_font, button + Vector2(-BRAMBLE_RADIUS, 6.0), "bramble", HORIZONTAL_ALIGNMENT_CENTER, BRAMBLE_RADIUS * 2.0, 16, BRAMBLE_COLOR)
		for i: int in _player.bramble_charges:
			draw_circle(button + Vector2((i - 1) * 12.0, BRAMBLE_RADIUS * 0.55), 4.0, BRAMBLE_COLOR)

	# The game is a wide rectangle. On an upright phone it shrinks to a thin strip,
	# so ask for landscape. (The window is the real screen area the game was given.)
	var window_size: Vector2i = get_window().size
	if window_size.y > window_size.x:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.0, 0.0, 0.0, 0.75))
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 72
		var text_width: float = font.get_string_size(ROTATE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		var text_position := Vector2((screen.x - text_width) / 2.0, screen.y / 2.0)
		draw_string(font, text_position, ROTATE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)


## A finger touched the screen at `at` (game pixels).
func touch_down(index: int, at: Vector2) -> void:
	_set_touch_mode(true)
	_seconds_since_touch = 0.0
	var finger := Finger.new()
	finger.start = at
	finger.origin = at
	finger.position = at
	_fingers[index] = finger


## A finger that is already down slid to `at`.
func touch_moved(index: int, at: Vector2) -> void:
	var finger: Finger = _fingers.get(index)
	if finger == null:
		return
	finger.position = at

	# Slid too far to be a tap: from now on this finger is a stick (if one is free).
	if finger.can_be_tap and at.distance_to(finger.start) > CONFIG.touch_drag_threshold:
		finger.can_be_tap = false
		_give_stick(index, finger)

	# Floating stick: if the thumb outruns the ring, drag the ring along behind it.
	var offset: Vector2 = at - finger.origin
	if offset.length() > CONFIG.touch_stick_radius:
		finger.origin = at - offset.normalized() * CONFIG.touch_stick_radius
	_apply_sticks()


## A finger lifted. A quick lift that never slid is a tap: try the vine there.
func touch_up(index: int) -> void:
	var finger: Finger = _fingers.get(index)
	if finger == null:
		return
	_fingers.erase(index)
	_seconds_since_touch = 0.0
	if index == _move_finger:
		_move_finger = -1
	if index == _aim_finger:
		_aim_finger = -1
	_apply_sticks()

	var was_tap: bool = finger.can_be_tap and finger.age <= CONFIG.touch_tap_max_time
	# A tap on the Bramble button throws a Bramble Seed instead of trying the vine.
	if was_tap and _player != null and bramble_button_hit(finger.start):
		_player.throw_bramble()
		return
	if was_tap and _player != null:
		# Same function right click uses, with a fingertip-sized pick radius.
		_player.try_vine(finger.start, CONFIG.touch_vine_pick_radius_cells)


## True if screen point `at` is on the Bramble Seed button. While the button is
## hidden (s24: no seeds unlocked yet) nothing is on it, so a tap there can still
## pick a tree for the vine.
func bramble_button_hit(at: Vector2) -> bool:
	if not is_bramble_button_shown():
		return false
	return at.distance_to(BRAMBLE_SPOT * get_viewport_rect().size) <= BRAMBLE_RADIUS


## s24: true once Seven has Bramble Seeds, so the button is drawn and can be tapped.
func is_bramble_button_shown() -> bool:
	return _player != null and _player.bramble_unlocked


## Turns a sliding finger into the MOVE stick (left half) or the AIM stick (right
## half). If that stick already has a thumb on it, the finger stays PENDING and
## simply does nothing.
func _give_stick(index: int, finger: Finger) -> void:
	var landed_on_left: bool = finger.start.x < get_viewport_rect().size.x / 2.0
	if landed_on_left and _move_finger == -1:
		finger.role = Role.MOVE
		_move_finger = index
	elif not landed_on_left and _aim_finger == -1:
		finger.role = Role.AIM
		_aim_finger = index


## The direction a stick is pushed in, as a unit vector (length 1), or zero if the
## stick is not held or the thumb is resting on its centre. There is no "half
## speed": like the keyboard, the bot is either walking or stopped.
func _stick_direction(index: int) -> Vector2:
	var finger: Finger = _fingers.get(index)
	if finger == null:
		return Vector2.ZERO
	var offset: Vector2 = finger.position - finger.origin
	if offset.length() <= CONFIG.touch_drag_threshold:
		return Vector2.ZERO
	return offset.normalized()


## Pushes the current stick positions into the game. Called after every touch event.
func _apply_sticks() -> void:
	# MOVE: split the direction into the four move actions. A strength between 0
	# and 1 is how "analog" input is expressed, so the bot can walk at any angle.
	var move: Vector2 = _stick_direction(_move_finger)
	_set_move_action(&"move_right", move.x)
	_set_move_action(&"move_left", -move.x)
	_set_move_action(&"move_down", move.y)
	_set_move_action(&"move_up", -move.y)

	# AIM + SEED: fire for as long as the aim stick is pushed. When it is released
	# the bot keeps facing the way it last aimed.
	if _player == null:
		return
	var aim: Vector2 = _stick_direction(_aim_finger)
	_player.touch_fire_held = aim != Vector2.ZERO
	if aim != Vector2.ZERO:
		_player.aim_direction = aim


## Holds one move action down at `strength`, or lets go of it at zero or below.
## It only releases actions it pressed itself, so a held keyboard key is left alone.
func _set_move_action(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
		if not _held_actions.has(action):
			_held_actions.append(action)
	elif _held_actions.has(action):
		Input.action_release(action)
		_held_actions.erase(action)


## Lets go of every move action this script is holding.
func _release_move_actions() -> void:
	for action: StringName in _held_actions:
		Input.action_release(action)
	_held_actions.clear()


## Switches between touch play and mouse play.
func _set_touch_mode(active: bool) -> void:
	if touch_mode == active:
		return
	touch_mode = active
	if _player != null:
		_player.touch_mode = active
		_player.touch_fire_held = false
	if not active:
		_release_move_actions()
	if hint_label != null:
		hint_label.text = TOUCH_HINT if active else _desktop_hint
	queue_redraw()


## Draws one stick. Idle: a faint ring at its resting spot, as a hint for where
## the thumb goes. Held: a ring where the thumb landed plus a knob under the thumb.
func _draw_stick(index: int, rest_position: Vector2, color: Color) -> void:
	var radius: float = CONFIG.touch_stick_radius
	var finger: Finger = _fingers.get(index)
	if finger == null:
		var faint := Color(color, REST_ALPHA)  # same colour, lower opacity
		draw_arc(rest_position, radius, 0.0, TAU, 48, faint, 3.0)
		draw_circle(rest_position, radius * 0.35, Color(color, REST_ALPHA * 0.5))
		return
	draw_arc(finger.origin, radius, 0.0, TAU, 48, color, 3.0)
	draw_circle(finger.position, radius * 0.4, color)
