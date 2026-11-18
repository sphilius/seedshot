# block_windows.gd - the homes of the block and their windows: the story's scoreboard.
# Created by the arena in code (see arena.gd _ready). It has no input and no
# physics: it only draws small rectangles that fade between dark and lit.
class_name BlockWindows
extends Node2D
## Homes whose windows light up as the block gets its power back.
##
## TWO ROWS
##   The block      a row of homes along the BOTTOM wall. Each home has two or
##                  three windows (the config's `home_window_counts`). The arena
##                  says how many windows are lit and how strongly (set_light).
##                  The homes are packed edge to edge: one roof unit (from the
##                  concept art) over each window, 2 or 3 units to a home.
##   The next block a row of smaller windows along the very top edge. All dark
##                  until the run is won (light_next_block), then they come on
##                  one after another: the light has jumped the wall.
##
## HOW THE BLOCK FILLS: home by home, starting with the homes at the two ends of
## the wall and working toward the middle. Early in a run the controls line sits
## over the middle of the bottom wall, so the first lit homes are never covered.
##
## STRENGTH: every lit window shines at the same strength, from faint (early
## waves) to full (the last wave). A lit window also throws a soft pool of light
## onto the floor in front of it, which grows with the strength.
##
## FLICKER: when a tree is cut down the arena calls flicker(), and one lit
## window drops dark for a moment before coming back. It is the block feeling
## the loss; it does not change the count.
##
## Each window has a brightness from 0.0 to 1.0 that glides toward its target a
## little every frame, so a window fades on and off, never snaps.

const CONFIG: GameConfig = preload("res://config/game_config.tres")

## Size of one window of the block, in pixels. Small and wide, so the windows
## fit on the home's front wall under its roof.
const WINDOW_SIZE: Vector2 = Vector2(16.0, 10.0)
## THE ROW OF HOMES is built from "units": one roof seen from above with a strip
## of front wall below it, and ONE window in that strip. The units are packed
## edge to edge along the whole bottom wall, like the concept art's rooftops.
## A home is 2 or 3 neighbouring units, with a dark seam between homes.
## UNIT_WIDTH x the number of windows (24) must equal the arena's width (1248).
const UNIT_WIDTH: float = 52.0
## Height of a unit's roof; the rest of the wall cell below it is front wall.
const ROOF_HEIGHT: float = 32.0
## How many different roof designs the roof picture holds, side by side.
const ROOF_DESIGNS: int = 6
## Width of the dark seam drawn where one home ends and the next begins.
const SEAM_WIDTH: float = 2.0
## Colour of a home's front wall (dark brick brown).
const FRONT_COLOR: Color = Color(0.24, 0.16, 0.13)
## Colour of the thin frame around each window.
const FRAME_COLOR: Color = Color(0.07, 0.08, 0.08)

## Size of one distant window of the next block, in pixels.
const FAR_WINDOW_SIZE: Vector2 = Vector2(10.0, 6.0)
## How many distant windows the next block has.
const FAR_WINDOW_COUNT: int = 56
## Brightness change per second: 3.0 means a full fade takes a third of a second.
const FADE_SPEED: float = 3.0
## Seconds a flickering window stays dark before it comes back.
const FLICKER_SECONDS: float = 1.2
## Seconds for the whole next block to come on, first window to last.
const NEXT_BLOCK_SECONDS: float = 3.0

const HOME_COLOR: Color = Color(0.13, 0.13, 0.16)
const DARK_COLOR: Color = Color(0.06, 0.06, 0.09)
const LIT_COLOR: Color = Color(1.00, 0.74, 0.32)
const FAR_LIT_COLOR: Color = Color(1.00, 0.84, 0.50)

## How many of the block's windows are lit. Public so tests can read it.
var lit_count: int = 0
## How strongly a lit window shines, 0.0 to 1.0. Public so tests can read it.
var strength: float = 0.0
## How much brighter than normal the pools of light are drawn. The arena sets it
## every frame: high while the lot is dark, 1.0 once the lot is fully lit.
var light_boost: float = 1.0
## True once the next block has been told to light. Public so tests can read it.
var next_block_lit: bool = false

## The arena's outer rectangle (walls included), in pixels. Set by setup().
var _arena_rect: Rect2
## Wall thickness in pixels: one grid cell.
var _wall_px: float = 48.0
## One rectangle per window of the block, left to right, in pixels.
var _window_rects: Array[Rect2] = []
## One rectangle per home (the slightly lighter wall behind its windows).
var _home_rects: Array[Rect2] = []
## Which home each window belongs to (same order as _window_rects).
var _window_home: PackedInt32Array = PackedInt32Array()
## Each window's place in the lighting queue: 0 lights first.
var _window_order: PackedInt32Array = PackedInt32Array()
## Current brightness of each window of the block, 0.0 to 1.0.
var _brightness: PackedFloat32Array = PackedFloat32Array()
## Seconds each window still has to stay dark because of a flicker.
var _flicker_left: PackedFloat32Array = PackedFloat32Array()
## The pool of light in front of each window (see glow.gd).
var _spills: Array[Sprite2D] = []
## Current brightness of each window of the next block, 0.0 to 1.0.
var _far_brightness: PackedFloat32Array = PackedFloat32Array()
## Seconds since the next block was told to light.
var _next_block_time: float = 0.0
## Which lit window flickers next, so it is not always the same one.
var _flicker_turn: int = 0


## Called once by the arena: tells this node where the walls are, and lays the
## homes and their windows out along the bottom wall.
func setup(arena_rect: Rect2, wall_px: float) -> void:
	_arena_rect = arena_rect
	_wall_px = wall_px
	_far_brightness.resize(FAR_WINDOW_COUNT)  # resize fills new entries with 0.0

	var top: float = arena_rect.end.y - wall_px
	# Windows sit in the middle of the front wall, which is the part of the
	# wall cell below the roof.
	var window_top: float = top + ROOF_HEIGHT + (wall_px - ROOF_HEIGHT - WINDOW_SIZE.y) / 2.0
	# Walk along the wall one unit at a time, from the left edge of the arena.
	var x: float = arena_rect.position.x
	for home: int in home_count():
		var units: int = CONFIG.home_window_counts[home]
		_home_rects.append(Rect2(x, top, units * UNIT_WIDTH, wall_px))
		for i: int in units:
			# Each window is centred in its own unit.
			var left: float = x + i * UNIT_WIDTH + (UNIT_WIDTH - WINDOW_SIZE.x) / 2.0
			_window_rects.append(Rect2(Vector2(left, window_top), WINDOW_SIZE))
			_window_home.append(home)
		x += units * UNIT_WIDTH

	# The lighting queue. Homes take turns from the two ends inward:
	# leftmost, rightmost, second from left, second from right, ...
	# and each home's windows light left to right before the next home starts.
	var home_turn: PackedInt32Array = PackedInt32Array()
	home_turn.resize(home_count())
	for home: int in home_count():
		var from_right: int = home_count() - 1 - home
		home_turn[home] = home * 2 if home <= from_right else from_right * 2 + 1
	_window_order.resize(window_count())
	var place: int = 0
	for turn: int in home_count():
		for i: int in window_count():
			if home_turn[_window_home[i]] == turn:
				_window_order[i] = place
				place += 1

	_brightness.resize(window_count())
	_flicker_left.resize(window_count())
	# One pool of light per window, sitting at the window's top edge so it falls
	# on the floor just inside the wall. It starts invisible.
	for rect: Rect2 in _window_rects:
		var spill: Sprite2D = Glow.make_sprite(CONFIG.window_spill_radius_cells * wall_px, Color(LIT_COLOR, 0.0))
		spill.position = Vector2(rect.get_center().x, top)
		add_child(spill)
		_spills.append(spill)


## How many windows the block has in all.
func window_count() -> int:
	var total: int = 0
	for windows_in_home: int in CONFIG.home_window_counts:
		total += windows_in_home
	return total



## How many homes the block has.
func home_count() -> int:
	return CONFIG.home_window_counts.size()


## How many homes have at least one lit window.
func homes_lit() -> int:
	var lit_homes: Dictionary[int, bool] = {}
	for i: int in window_count():
		if _window_order[i] < lit_count:
			lit_homes[_window_home[i]] = true
	return lit_homes.size()


## Sets how many windows are lit and how strongly they shine (0.0 to 1.0).
func set_light(count: int, new_strength: float) -> void:
	lit_count = clampi(count, 0, window_count())
	strength = clampf(new_strength, 0.0, 1.0)


## One lit window drops dark for a moment. Called when a tree is cut down.
## Returns the window's index, or -1 if no window is lit (used by the tests).
func flicker() -> int:
	if lit_count <= 0:
		return -1
	_flicker_turn = (_flicker_turn + 1) % lit_count
	for i: int in window_count():
		if _window_order[i] == _flicker_turn:
			_flicker_left[i] = FLICKER_SECONDS
			return i
	return -1


## True while window `index` is held dark by a flicker. Used by the tests.
func is_flickering(index: int) -> bool:
	return _flicker_left[index] > 0.0


## Starts the next block's windows coming on. Called when the run is won.
func light_next_block() -> void:
	next_block_lit = true


## _process runs every drawn frame: glide each window toward its target, and
## redraw only if something actually changed.
func _process(delta: float) -> void:
	var changed: bool = false
	var step: float = FADE_SPEED * delta
	for i: int in _brightness.size():
		var target: float = strength if _window_order[i] < lit_count else 0.0
		if _flicker_left[i] > 0.0:
			_flicker_left[i] -= delta
			target = 0.0
		if _brightness[i] != target:
			_brightness[i] = move_toward(_brightness[i], target, step)
			# The pool of light in front of the window follows its brightness.
			changed = true
	# Every pool of light follows its window's brightness, times the light boost
	# (colour values above 1 let it shine through the night tint).
	for i: int in _spills.size():
		_spills[i].modulate = Color(LIT_COLOR * light_boost, _brightness[i] * CONFIG.window_spill_strength)
	if next_block_lit:
		_next_block_time += delta
		# How many distant windows have been switched on by now.
		var on: int = int(float(FAR_WINDOW_COUNT) * _next_block_time / NEXT_BLOCK_SECONDS)
		for i: int in _far_brightness.size():
			# A fixed scramble of the order, so they do not light left to right.
			var far_place: int = (i * 23) % FAR_WINDOW_COUNT
			if far_place < on and _far_brightness[i] < 1.0:
				_far_brightness[i] = move_toward(_far_brightness[i], 1.0, step)
				changed = true
	if changed:
		queue_redraw()


## _draw paints the homes, their windows, and the next block's row.
func _draw() -> void:
	var unit: int = 0  # counts units along the whole row, left to right
	for home: int in _home_rects.size():
		var rect: Rect2 = _home_rects[home]
		for i: int in CONFIG.home_window_counts[home]:
			var roof_rect := Rect2(rect.position.x + i * UNIT_WIDTH, rect.position.y, UNIT_WIDTH, ROOF_HEIGHT)
			if CONFIG.home_roofs != null:
				# The roof picture holds six designs side by side. Stepping by 5
				# (not 1) through them keeps two neighbours from repeating a pattern.
				var design: int = (unit * 5) % ROOF_DESIGNS
				var source := Rect2(design * UNIT_WIDTH, 0.0, UNIT_WIDTH, ROOF_HEIGHT)
				draw_texture_rect_region(CONFIG.home_roofs, roof_rect, source)
			else:
				draw_rect(roof_rect, HOME_COLOR)
			unit += 1
		# The front wall: everything below the roofs.
		draw_rect(Rect2(rect.position.x, rect.position.y + ROOF_HEIGHT, rect.size.x, rect.size.y - ROOF_HEIGHT), FRONT_COLOR)
		# A dark seam on the home's left edge marks where it starts (none before the first).
		if home > 0:
			draw_rect(Rect2(rect.position.x - SEAM_WIDTH / 2.0, rect.position.y, SEAM_WIDTH, rect.size.y), FRAME_COLOR)
	for i: int in _window_rects.size():
		# A 1-pixel frame first (grow(1) makes the rectangle 1 pixel bigger on
		# every side), then the glass on top of it.
		draw_rect(_window_rects[i].grow(1.0), FRAME_COLOR)
		# lerp blends two colours: 0.0 gives the first, 1.0 gives the second.
		draw_rect(_window_rects[i], DARK_COLOR.lerp(LIT_COLOR, _brightness[i]))
		# A 1-pixel bar down the middle splits the glass into two panes.
		var bar_x: float = floorf(_window_rects[i].get_center().x)
		draw_rect(Rect2(bar_x, _window_rects[i].position.y, 1.0, _window_rects[i].size.y), FRAME_COLOR)

	# The next block: small, along the very top edge. Dark ones are not drawn at
	# all, so nothing shows there until the run is won.
	var far_pitch: float = _arena_rect.size.x / float(FAR_WINDOW_COUNT)
	for i: int in FAR_WINDOW_COUNT:
		if _far_brightness[i] <= 0.0:
			continue
		var far_left: float = _arena_rect.position.x + far_pitch * float(i) + (far_pitch - FAR_WINDOW_SIZE.x) / 2.0
		var far_color := Color(FAR_LIT_COLOR, _far_brightness[i])  # same colour, fading in
		draw_rect(Rect2(Vector2(far_left, _arena_rect.position.y + 3.0), FAR_WINDOW_SIZE), far_color)
