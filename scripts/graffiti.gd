# graffiti.gd - the Block's voice: spray-painted lines on the arena's side walls.
# Created by the arena in code (see arena.gd _ready). It has no input and no
# physics: it only draws text.
class_name Graffiti
extends Node2D
## The Block answers Helios in paint.
##
## Each time a wave is cleared the arena calls reveal_up_to(wave), and one more
## line appears on a wall. Lines never disappear, so by the late waves the walls
## are covered. The words themselves live in the config (`graffiti_lines`).
##
## WHERE THE LINES GO: only the left and right walls are free (the top wall holds
## the HUD, the bottom wall holds the controls line). A wall is one cell wide,
## which fits two rows of text side by side. That gives four rows in all:
##
##   row 0  left wall, outer half      row 1  right wall, outer half
##   row 2  left wall, inner half      row 3  right wall, inner half
##
## Line 1 goes in row 0, line 2 in row 1, and so on round and round, each one
## starting where the last line in its row ended.

const CONFIG: GameConfig = preload("res://config/game_config.tres")

const ROW_COUNT: int = 4
const FONT_SIZE: int = 20
## Empty wall left between two lines in the same row, in pixels.
const GAP: float = 30.0
## Empty wall before the first line of a row, in pixels.
const START_MARGIN: float = 14.0
## Spray-can colours, used in turn: teal, amber, pink, pale green.
const PAINT_COLORS: Array[Color] = [
	Color(0.35, 0.90, 0.85), Color(1.00, 0.75, 0.25), Color(1.00, 0.45, 0.65), Color(0.70, 0.95, 0.45),
]

## How many lines are on the walls right now. Public so tests can read it.
var revealed_count: int = 0

## The arena's outer rectangle (walls included), in pixels. Set by setup().
var _arena_rect: Rect2
## Wall thickness in pixels: one grid cell.
var _wall_px: float = 48.0


## Called once by the arena: tells this node where the walls are.
func setup(arena_rect: Rect2, wall_px: float) -> void:
	_arena_rect = arena_rect
	_wall_px = wall_px


## Shows every line up to and including wave `wave`'s. Never hides a line, so
## calling it with a smaller number (a restarted wave) changes nothing.
func reveal_up_to(wave: int) -> void:
	var wanted: int = mini(wave, CONFIG.graffiti_lines.size())
	if wanted > revealed_count:
		revealed_count = wanted
		queue_redraw()  # ask Godot to call _draw again


## The text of line `index` (0 = the first wave's line). Used by the tests.
func line_text(index: int) -> String:
	return CONFIG.graffiti_lines[index]


## _draw paints every revealed line, turned sideways to run along its wall.
func _draw() -> void:
	# The marker font from the config, or Godot's plain font if none is set.
	var font: Font = CONFIG.graffiti_font if CONFIG.graffiti_font != null else ThemeDB.fallback_font
	# How far along each of the four rows the next line starts.
	var used: Array[float] = [START_MARGIN, START_MARGIN, START_MARGIN, START_MARGIN]
	for i: int in revealed_count:
		var text: String = CONFIG.graffiti_lines[i]
		var row: int = i % ROW_COUNT
		var is_left_wall: bool = row % 2 == 0
		var is_inner_half: bool = row >= 2
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE).x
		var along: float = used[row]
		used[row] += width + GAP

		# draw_set_transform moves and turns the "paper" that later draw calls
		# write on. Left wall: text reads bottom-to-top (a quarter turn
		# anticlockwise). Right wall: top-to-bottom (a quarter turn clockwise).
		var half: float = _wall_px / 2.0
		if is_left_wall:
			var x: float = _arena_rect.position.x + (half if is_inner_half else 0.0) + half - 4.0
			var y: float = _arena_rect.end.y - _wall_px - along
			draw_set_transform(Vector2(x, y), -PI / 2.0)
		else:
			var x: float = _arena_rect.end.x - (half if is_inner_half else 0.0) - half + 4.0
			var y: float = _arena_rect.position.y + _wall_px + along
			draw_set_transform(Vector2(x, y), PI / 2.0)
		var color: Color = PAINT_COLORS[i % PAINT_COLORS.size()]
		_draw_painted(font, Vector2.ZERO, text, color)
	# Put the "paper" back, so nothing drawn later is turned by accident.
	draw_set_transform(Vector2.ZERO, 0.0)


## Draws `text` like spray paint: first a soft, see-through halo around the
## letters (the overspray a can leaves), then the letters themselves.
## draw_string_outline draws only the outline of each letter, `size` pixels wide.
func _draw_painted(font: Font, at: Vector2, text: String, color: Color) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, 6, Color(color, 0.18))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, color)
