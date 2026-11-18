# lanterns.gd - strings of paper lanterns the block hangs across the lot as it wins its light back.
# Created by the arena in code (see arena.gd _ready). It has no input and no physics.
class_name Lanterns
extends Node2D
## Lantern strings across the lot.
##
## WHY: in Sasha's chosen light concept (06_light_progression_h) the lot is lit by
## SOURCES (windows, lanterns, trees) while the rest stays dark, and more sources
## appear as the block wins. Each string is one of those sources: one goes up
## after each wave named in the config's `lantern_string_waves`.
##
## WHAT IT DRAWS: each string is a wire from the left wall to the right wall that
## droops in the middle, with a lantern every `lantern_spacing_px`. Every lantern
## also throws a small pool of light (a glow sprite, see glow.gd). A new string
## fades in, so it never pops.
##
## Strings hang LOW in the scene order (under trees, machines and Seven), so they
## never hide the action.

const CONFIG: GameConfig = preload("res://config/game_config.tres")

## Wire colour (dark, so it reads as a thin line against the floor).
const WIRE_COLOR: Color = Color(0.10, 0.10, 0.10, 0.8)
## Lantern body colour when fully lit.
const LANTERN_COLOR: Color = Color(1.0, 0.80, 0.45)
## Lantern size, in pixels.
const LANTERN_SIZE: Vector2 = Vector2(6.0, 8.0)
## How much a string's brightness rises per second while it fades in (2 = half a second).
const FADE_SPEED: float = 2.0

## How many strings are up right now. Public so the tests can read it.
var strings_up: int = 0

## The floor's rectangle (inside the walls), in pixels. Set by setup().
var _floor_rect: Rect2
## Brightness of each string, 0.0 (not up yet) to 1.0, one entry per string.
var _brightness: PackedFloat32Array = PackedFloat32Array()
## The lantern positions of each string: one Array of points per string.
var _lantern_points: Array[PackedVector2Array] = []
## The glow sprites of each string, so they can fade with it.
var _glows: Array[Array] = []


## Called once by the arena: works out where every string and lantern hangs, and
## makes their (still invisible) pools of light.
func setup(floor_rect: Rect2) -> void:
	_floor_rect = floor_rect
	var count: int = CONFIG.lantern_string_waves.size()
	_brightness.resize(count)  # resize fills new entries with 0.0
	for s: int in count:
		var points := PackedVector2Array()
		var string_glows: Array[Sprite2D] = []
		# How many lanterns fit along the string (at least two).
		var lanterns: int = maxi(2, int(floor_rect.size.x / CONFIG.lantern_spacing_px))
		for i: int in lanterns:
			# t runs evenly from just inside the left end to just inside the right end.
			var t: float = (float(i) + 0.5) / float(lanterns)
			var point: Vector2 = point_on_string(s, t)
			points.append(point)
			var glow: Sprite2D = Glow.make_sprite(CONFIG.lantern_glow_radius_cells * float(CONFIG.cell_size), Color(CONFIG.lantern_glow_color, 0.0))
			glow.position = point
			# A glow normally draws behind its parent; here the parent is this
			# whole node, so draw it in front instead (it still only adds light).
			glow.show_behind_parent = false
			add_child(glow)
			string_glows.append(glow)
		_lantern_points.append(points)
		_glows.append(string_glows)


## The point a fraction `t` (0 = left wall, 1 = right wall) along string `s`.
## The droop is a parabola: 4 * t * (1 - t) is 0 at both ends and 1 in the middle.
func point_on_string(s: int, t: float) -> Vector2:
	var height: float = CONFIG.lantern_string_heights[mini(s, CONFIG.lantern_string_heights.size() - 1)]
	var y: float = _floor_rect.end.y - height * _floor_rect.size.y
	return Vector2(_floor_rect.position.x + t * _floor_rect.size.x, y + CONFIG.lantern_sag_px * 4.0 * t * (1.0 - t))


## How many strings are up after `cleared` waves: one for each wave in the
## config's list that has been cleared. `static` so the tests can ask directly.
static func strings_after(cleared: int) -> int:
	var count: int = 0
	for wave: int in CONFIG.lantern_string_waves:
		if cleared >= wave:
			count += 1
	return count


## Called by the arena whenever waves are cleared. Never takes strings down.
func set_strings(count: int) -> void:
	strings_up = maxi(strings_up, clampi(count, 0, _brightness.size()))


## Fade each string toward its target, and redraw only while something changes.
func _process(delta: float) -> void:
	var changed: bool = false
	for s: int in _brightness.size():
		var target: float = 1.0 if s < strings_up else 0.0
		if _brightness[s] != target:
			_brightness[s] = move_toward(_brightness[s], target, FADE_SPEED * delta)
			for glow: Sprite2D in _glows[s]:
				glow.modulate.a = _brightness[s] * CONFIG.lantern_glow_color.a
			changed = true
	if changed:
		queue_redraw()


## Draws each string that is up (or fading in): the drooping wire, then its lanterns.
func _draw() -> void:
	for s: int in _brightness.size():
		var shown: float = _brightness[s]
		if shown <= 0.0:
			continue
		# The wire, as 24 short straight pieces following the droop.
		var wire := PackedVector2Array()
		for i: int in 25:
			wire.append(point_on_string(s, float(i) / 24.0))
		draw_polyline(wire, Color(WIRE_COLOR, WIRE_COLOR.a * shown), 1.0)
		# The lanterns hang just under the wire, centred on their points.
		for point: Vector2 in _lantern_points[s]:
			var body := Rect2(point - Vector2(LANTERN_SIZE.x / 2.0, 1.0), LANTERN_SIZE)
			draw_rect(body.grow(1.0), Color(WIRE_COLOR, shown))
			draw_rect(body, Color(LANTERN_COLOR, shown))
