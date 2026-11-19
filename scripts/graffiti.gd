# graffiti.gd - the Block's voice: spray-painted lines across the roofs of the
# homes on the arena's bottom wall.
# Created by the arena in code (see arena.gd _ready). It has no input and no
# physics: it only draws text.
class_name Graffiti
extends Node2D
## The Block answers Helios in paint.
##
## Each time a wave is cleared the arena calls reveal_up_to(wave), and one more
## line appears. Lines never disappear, so by the late waves the roofs are
## covered. The words themselves live in the config (`graffiti_lines`).
##
## WHERE THE LINES GO (s18): level, across the roofs on the bottom wall, the way
## the concept art shows it. (They used to run sideways up the left and right
## walls, which Sasha found haphazard and hard to read.) The wall is one cell
## tall, which fits two rows of text. Each row is cut into equal "slots", one
## per line, and the lower row is shifted half a slot so the lines sit like
## bricks instead of in columns:
##
##   row 0 (upper)   line 1      line 3      line 5      line 7      line 9
##   row 1 (lower)         line 2      line 4      line 6      line 8      line 10

const CONFIG: GameConfig = preload("res://config/game_config.tres")

const ROW_COUNT: int = 2
const FONT_SIZE: int = 17
## Where each row's text sits, measured down from the top of the bottom wall to
## the text's baseline (the line the letters stand on), in pixels.
const ROW_BASELINES: Array[float] = [17.0, 35.0]
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


## How many slots one row is cut into: half the lines each, rounded up.
func slots_per_row() -> int:
	# ceili rounds up to a whole number.
	return ceili(float(CONFIG.graffiti_lines.size()) / float(ROW_COUNT))


## Where line `index` is painted: the left end of its baseline and the width of
## its slot, as [position, width]. Public so the tests can check the layout.
func line_place(index: int) -> Array:
	var row: int = index % ROW_COUNT
	var slot: int = index / ROW_COUNT  # whole-number division: lines 0 and 1 share slot 0
	# The lower row is half a slot narrower overall, so its shift fits on the wall.
	var slot_width: float = _arena_rect.size.x / (float(slots_per_row()) + 0.5)
	var x: float = _arena_rect.position.x + (float(slot) + 0.5 * float(row)) * slot_width
	var y: float = _arena_rect.end.y - _wall_px + ROW_BASELINES[row]
	return [Vector2(x, y), slot_width]


## _draw paints every revealed line, level, centred in its slot on the roofs.
func _draw() -> void:
	# The marker font from the config, or Godot's plain font if none is set.
	var font: Font = CONFIG.graffiti_font if CONFIG.graffiti_font != null else ThemeDB.fallback_font
	for i: int in revealed_count:
		var place: Array = line_place(i)
		var color: Color = PAINT_COLORS[i % PAINT_COLORS.size()]
		_draw_painted(font, place[0], CONFIG.graffiti_lines[i], color, place[1])


## Draws `text` like spray paint, centred in a slot `width` pixels wide: first
## a dark backing and a soft see-through halo (the overspray a can leaves), so
## it reads over roof tiles and lit windows, then the letters themselves.
## draw_string_outline draws only the outline of each letter, `size` pixels wide.
func _draw_painted(font: Font, at: Vector2, text: String, color: Color, width: float) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, FONT_SIZE, 7, Color(0.0, 0.0, 0.0, 0.55))
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, FONT_SIZE, 3, Color(color, 0.25))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, FONT_SIZE, color)
