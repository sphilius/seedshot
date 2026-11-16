# block_windows.gd - the windows of the block: the story's scoreboard.
# Created by the arena in code (see arena.gd _ready). It has no input and no
# physics: it only draws small rectangles that fade between dark and lit.
class_name BlockWindows
extends Node2D
## Windows that light up as the block gets its power back.
##
## TWO ROWS
##   The block      a row of windows along the BOTTOM wall. The arena tells this
##                  node how many should be lit (set_lit); the rest stay dark.
##   The next block a row of smaller windows along the very top edge. All dark
##                  until the run is won (light_next_block), then they come on
##                  one after another: the light has jumped the wall.
##
## Windows light from both ends of the wall toward the middle. Early in a run
## the controls line sits over the middle of the bottom wall, so the first lit
## windows appear where nothing covers them.
##
## Each window has a brightness from 0.0 (dark) to 1.0 (lit) that glides toward
## its target a little every frame, so a window fades on and off, never snaps.

const CONFIG: GameConfig = preload("res://config/game_config.tres")

## Size of one window of the block, in pixels.
const WINDOW_SIZE: Vector2 = Vector2(16.0, 22.0)
## Size of one distant window of the next block, in pixels.
const FAR_WINDOW_SIZE: Vector2 = Vector2(10.0, 6.0)
## How many distant windows the next block has.
const FAR_WINDOW_COUNT: int = 56
## Brightness change per second: 3.0 means a full fade takes a third of a second.
const FADE_SPEED: float = 3.0
## Seconds for the whole next block to come on, first window to last.
const NEXT_BLOCK_SECONDS: float = 3.0
const DARK_COLOR: Color = Color(0.07, 0.07, 0.10)
const LIT_COLOR: Color = Color(1.00, 0.74, 0.32)
const FAR_LIT_COLOR: Color = Color(1.00, 0.84, 0.50)

## How many of the block's windows should be lit. Public so tests can read it.
var lit_count: int = 0
## True once the next block has been told to light. Public so tests can read it.
var next_block_lit: bool = false

## The arena's outer rectangle (walls included), in pixels. Set by setup().
var _arena_rect: Rect2
## Wall thickness in pixels: one grid cell.
var _wall_px: float = 48.0
## Current brightness of each window of the block, 0.0 to 1.0.
var _brightness: PackedFloat32Array = PackedFloat32Array()
## Current brightness of each window of the next block, 0.0 to 1.0.
var _far_brightness: PackedFloat32Array = PackedFloat32Array()
## Seconds since the next block was told to light.
var _next_block_time: float = 0.0


## Called once by the arena: tells this node where the walls are.
func setup(arena_rect: Rect2, wall_px: float) -> void:
	_arena_rect = arena_rect
	_wall_px = wall_px
	_brightness.resize(window_count())    # resize fills the new entries with 0.0
	_far_brightness.resize(FAR_WINDOW_COUNT)


## How many windows the block has: one per home, from the config.
func window_count() -> int:
	return CONFIG.homes_for_full_block


## Sets how many of the block's windows should be lit. Extra is ignored: the
## block cannot be more than fully lit.
func set_lit(count: int) -> void:
	lit_count = clampi(count, 0, window_count())


## Starts the next block's windows coming on. Called when the run is won.
func light_next_block() -> void:
	next_block_lit = true


## _process runs every drawn frame: glide each window toward dark or lit, and
## redraw only if something actually changed.
func _process(delta: float) -> void:
	var changed: bool = false
	var step: float = FADE_SPEED * delta
	for i: int in _brightness.size():
		# _light_order(i) is this window's place in the queue: 0 lights first.
		var target: float = 1.0 if _light_order(i) < lit_count else 0.0
		if _brightness[i] != target:
			_brightness[i] = move_toward(_brightness[i], target, step)
			changed = true
	if next_block_lit:
		_next_block_time += delta
		# How many distant windows have been switched on by now.
		var on: int = int(float(FAR_WINDOW_COUNT) * _next_block_time / NEXT_BLOCK_SECONDS)
		for i: int in _far_brightness.size():
			# A fixed scramble of the order, so they do not light left to right.
			var place: int = (i * 23) % FAR_WINDOW_COUNT
			if place < on and _far_brightness[i] < 1.0:
				_far_brightness[i] = move_toward(_far_brightness[i], 1.0, step)
				changed = true
	if changed:
		queue_redraw()


## _draw paints both rows of windows at their current brightness.
func _draw() -> void:
	# The block: evenly spaced along the bottom wall, centred in its height.
	var count: int = window_count()
	var pitch: float = _arena_rect.size.x / float(count)  # distance from one window to the next
	var top: float = _arena_rect.end.y - _wall_px + (_wall_px - WINDOW_SIZE.y) / 2.0
	for i: int in count:
		var left: float = _arena_rect.position.x + pitch * float(i) + (pitch - WINDOW_SIZE.x) / 2.0
		# lerp blends two colours: 0.0 gives the first, 1.0 gives the second.
		draw_rect(Rect2(Vector2(left, top), WINDOW_SIZE), DARK_COLOR.lerp(LIT_COLOR, _brightness[i]))

	# The next block: small, along the very top edge. Dark ones are not drawn at
	# all, so nothing shows there until the run is won.
	var far_pitch: float = _arena_rect.size.x / float(FAR_WINDOW_COUNT)
	for i: int in FAR_WINDOW_COUNT:
		if _far_brightness[i] <= 0.0:
			continue
		var far_left: float = _arena_rect.position.x + far_pitch * float(i) + (far_pitch - FAR_WINDOW_SIZE.x) / 2.0
		var far_color := Color(FAR_LIT_COLOR, _far_brightness[i])  # same colour, fading in
		draw_rect(Rect2(Vector2(far_left, _arena_rect.position.y + 3.0), FAR_WINDOW_SIZE), far_color)


## Where window `index` (counted left to right) stands in the lighting queue.
## The queue runs: leftmost, rightmost, second from left, second from right, ...
func _light_order(index: int) -> int:
	var from_right: int = window_count() - 1 - index
	if index <= from_right:
		return index * 2          # left half: places 0, 2, 4, ...
	return from_right * 2 + 1     # right half: places 1, 3, 5, ...
