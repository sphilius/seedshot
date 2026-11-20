# graffiti.gd - the Block's voice: spray-painted tags on the roofs of the homes
# along the arena's bottom wall.
# Created by the arena in code (see arena.gd _ready). It has no input and no
# physics: it only draws text.
class_name Graffiti
extends Node2D
## The Block answers Helios in paint.
##
## Each time a wave is cleared the arena calls reveal_up_to(wave), and one more
## tag appears. Tags never disappear, so by the last wave every roof has one.
## The words themselves live in the config (`graffiti_lines`).
##
## WHERE THE TAGS GO (s18, third try): ONE TAG PER HOME, painted on that home's
## own roof. Line 1 goes on the first home from the left, line 2 on the second,
## and so on (ten lines, ten homes).
##   - First they ran sideways up the side walls: haphazard and hard to read.
##   - Then all ten sat in two long rows across the whole wall, each with a black
##     outline. Sasha: "looks pasted on top of the buildings instead of being
##     graffiti", and barely readable, because neighbouring lines ran together.
##
## WHAT MAKES IT READ AS PAINT now (see _draw_tag):
##   - no black outline: the roof shows between and through the letters;
##   - each tag is a little see-through and has a faint wide halo of its own
##     colour, like the overspray a can leaves;
##   - each tag is tilted a few degrees, a different way on each home;
##   - a short tag is painted big on one row, a long one is broken onto two rows,
##     so every tag stays inside its own roof and none touches its neighbour.

const CONFIG: GameConfig = preload("res://config/game_config.tres")

## The biggest and smallest letter heights a tag may use, in pixels.
const MAX_FONT_SIZE: int = 22
const MIN_FONT_SIZE: int = 11
## Kept as the size the old tests measured with; a tag now picks its own size.
const FONT_SIZE: int = 17
## Empty space kept between a tag and the edges of its roof, in pixels.
const TAG_MARGIN: float = 5.0
## How far a tag may be tilted either way, in degrees.
const MAX_TILT_DEGREES: float = 4.0
## How see-through the paint is (1 = solid). A little under 1 lets the roof
## tiles show through, which is what makes it look sprayed on.
const PAINT_ALPHA: float = 0.88
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
## The roof of each home, left to right, in pixels. Set by setup().
var _roofs: Array[Rect2] = []


## Called once by the arena: tells this node where the walls are and where each
## home's roof is (`roofs`, from BlockWindows.roof_rects()).
func setup(arena_rect: Rect2, wall_px: float, roofs: Array[Rect2] = []) -> void:
	_arena_rect = arena_rect
	_wall_px = wall_px
	_roofs = roofs
	if _roofs.is_empty():
		# No homes handed in (a test, perhaps): treat the whole wall as one roof.
		_roofs = [Rect2(arena_rect.position.x, arena_rect.end.y - wall_px, arena_rect.size.x, wall_px)]


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


## The font the tags are painted in: the marker font from the config, or Godot's
## plain font if none is set.
func _font() -> Font:
	return CONFIG.graffiti_font if CONFIG.graffiti_font != null else ThemeDB.fallback_font


## The roof that line `index` is painted on. With more lines than homes the
## count wraps round (% is "remainder after dividing").
func roof_for(index: int) -> Rect2:
	return _roofs[index % _roofs.size()]


## Breaks `text` into two rows at the space nearest its middle. A text with no
## space stays on one row.
static func split_in_two(text: String) -> Array[String]:
	var best: int = -1
	var middle: float = float(text.length()) / 2.0
	for i: int in text.length():
		# absf is the distance from the middle, whichever side the space is on.
		if text[i] == " " and (best < 0 or absf(float(i) - middle) < absf(float(best) - middle)):
			best = i
	if best < 0:
		return [text]
	return [text.substr(0, best), text.substr(best + 1)]


## How line `index` is laid out on its roof, as a Dictionary:
##   rows  the text, as one or two rows
##   size  the letter height that makes every row fit, in pixels
##   roof  the roof rectangle it is painted on
## It tries one big row first; if that cannot fit at a readable size, two rows.
## Public so the tests can check that every tag fits.
func tag_layout(index: int) -> Dictionary:
	var roof: Rect2 = roof_for(index)
	var text: String = CONFIG.graffiti_lines[index]
	var one_row: Array[String] = [text]
	var one_size: int = _largest_size(one_row, roof)
	var two_rows: Array[String] = split_in_two(text)
	var two_size: int = _largest_size(two_rows, roof)
	# Bigger letters win. A tie goes to one row, which is easier to read.
	if two_rows.size() > 1 and two_size > one_size:
		return {rows = two_rows, size = two_size, roof = roof}
	return {rows = one_row, size = one_size, roof = roof}


## The largest letter height (between MIN and MAX) at which every row is no
## wider than the roof and the rows together are no taller than it.
func _largest_size(rows: Array[String], roof: Rect2) -> int:
	var font: Font = _font()
	var room := Vector2(roof.size.x - TAG_MARGIN * 2.0, roof.size.y - 2.0)
	for size: int in range(MAX_FONT_SIZE, MIN_FONT_SIZE - 1, -1):  # counts down from MAX
		var fits: bool = float(size) * 1.02 * float(rows.size()) <= room.y
		for row: String in rows:
			# get_string_size measures the text without drawing it.
			if font.get_string_size(row, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x > room.x:
				fits = false
		if fits:
			return size
	return MIN_FONT_SIZE


## How far tag `index` is tilted, in radians: a fixed "random-looking" amount
## per tag, so it is the same every time the roofs are redrawn.
static func tilt_for(index: int) -> float:
	# The remainder after dividing by 9 runs 0..8; that becomes -1..1.
	var spread: float = float((index * 7 + 3) % 9) / 4.0 - 1.0
	return deg_to_rad(MAX_TILT_DEGREES) * spread


## _draw paints every revealed tag on its own roof.
func _draw() -> void:
	for i: int in revealed_count:
		_draw_tag(i)


## Paints tag `index`: its rows centred on the middle of the roof, tilted, in
## its spray colour.
func _draw_tag(index: int) -> void:
	var layout: Dictionary = tag_layout(index)
	var roof: Rect2 = layout.roof
	var rows: Array[String] = layout.rows
	var size: int = layout.size
	var font: Font = _font()
	var color: Color = PAINT_COLORS[index % PAINT_COLORS.size()]
	# draw_set_transform moves and turns everything drawn after it: here the
	# origin (0, 0) becomes the roof's centre and the "paper" is tilted.
	draw_set_transform(roof.get_center(), tilt_for(index))
	var row_height: float = float(size) * 1.02
	for r: int in rows.size():
		var width: float = font.get_string_size(rows[r], HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
		# The baseline (the line letters stand on) of this row. The rows are
		# stacked around the centre; 0.36 of the size puts the letters' middle on it.
		var y: float = (float(r) - float(rows.size() - 1) / 2.0) * row_height + float(size) * 0.36
		var at := Vector2(-width / 2.0, y)
		# 1. Overspray: a wide, very faint outline in the paint's own colour.
		draw_string_outline(font, at, rows[r], HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, 6, Color(color, 0.10))
		# 2. A thin darker edge of the same paint, where the spray is thickest.
		draw_string_outline(font, at, rows[r], HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, 2, Color(color.darkened(0.55), 0.55))
		# 3. The letters themselves, a little see-through.
		draw_string(font, at, rows[r], HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, Color(color, PAINT_ALPHA))
	# A drip or two running down from the tag, as wet paint does.
	for d: int in 2:
		var drip_x: float = (float((index * 13 + d * 29) % 17) / 16.0 - 0.5) * roof.size.x * 0.5
		var drip_len: float = 4.0 + float((index * 5 + d * 3) % 6)
		var drip_top: float = float(rows.size()) * row_height / 2.0 - 2.0
		draw_line(Vector2(drip_x, drip_top), Vector2(drip_x, drip_top + drip_len), Color(color, 0.5), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0)  # back to normal for anything drawn later
