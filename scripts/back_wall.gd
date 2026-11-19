# back_wall.gd - the row of home and shop fronts along the arena's back (top) wall.
# Created by the arena in code (see arena.gd _ready). It has no input and no
# physics: it only draws.
class_name BackWall
extends Node2D
## Makes the back wall read as a street of homes instead of a blank bar (s18).
##
## The wall is cut into "fronts", each two cells wide: the same width as Lucky's
## hidden shop. Three kinds take turns along the wall:
##
##   SHUTTER   a rolled-down shutter with a ledge. Drawn EXACTLY like Lucky's
##             closed shop (same colours, same slats, same ledge), so the real
##             shop is one shutter among several. That is the camouflage.
##   DOOR      a front door with a small window beside it.
##   WINDOWS   two windows side by side.
##
## A few windows glow faintly, so the wall feels lived in without competing with
## the HUD text that sits over it. The front where Lucky's shop stands is left
## empty: the shop draws itself there (cat_shop.gd).

const CONFIG: GameConfig = preload("res://config/game_config.tres")

enum Kind { SHUTTER, DOOR, WINDOWS }
## The kinds in the order they repeat along the wall. Two shutters in every
## five fronts, so Lucky's shutter never stands alone.
const PATTERN: Array[Kind] = [Kind.SHUTTER, Kind.DOOR, Kind.WINDOWS, Kind.SHUTTER, Kind.DOOR]
## How wide one front is, in cells (must match CatShop.WIDTH_CELLS).
const FRONT_CELLS: int = 2
## Wall colours the fronts take in turn: three close shades of dark plaster.
const FRONT_COLORS: Array[Color] = [
	Color(0.33, 0.29, 0.34), Color(0.28, 0.31, 0.38), Color(0.36, 0.30, 0.29),
]
const EAVE_COLOR: Color = Color(0.11, 0.11, 0.14)
const EAVE_EDGE_COLOR: Color = Color(0.48, 0.48, 0.56)
const SEAM_COLOR: Color = Color(0.09, 0.09, 0.11)
const DOOR_COLOR: Color = Color(0.13, 0.10, 0.09)
const FRAME_COLOR: Color = Color(0.09, 0.09, 0.11)
const GLASS_DARK_COLOR: Color = Color(0.08, 0.09, 0.12)
## A faintly lit window: dim amber, far weaker than the bright homes on the
## bottom wall, so the HUD text over this wall stays easy to read.
## (Values above 1 keep it glowing under the night tint, like the other lights.)
const GLASS_LIT_COLOR: Color = Color(1.25, 0.85, 0.35)
const KNOB_COLOR: Color = Color(0.55, 0.45, 0.25)

## The arena's outer rectangle (walls included), in pixels. Set by setup().
var _arena_rect: Rect2
## Wall thickness in pixels: one grid cell.
var _wall_px: float = 48.0
## The first cell of the front that is left empty for Lucky's shop.
var _shop_cell_x: int = -1


## Called once by the arena: where the walls are, and which front is Lucky's.
func setup(arena_rect: Rect2, wall_px: float, shop_cell_x: int) -> void:
	_arena_rect = arena_rect
	_wall_px = wall_px
	_shop_cell_x = shop_cell_x
	queue_redraw()


## How many fronts fit along the wall. Public for the tests.
func front_count() -> int:
	return int(_arena_rect.size.x / (_wall_px * FRONT_CELLS))


## The kind of front number `index` (0 = leftmost). Public for the tests.
func kind_of(index: int) -> Kind:
	return PATTERN[index % PATTERN.size()]


## True if front `index` is the one Lucky's shop stands in (drawn by the shop).
func is_shop_front(index: int) -> bool:
	return index * FRONT_CELLS == _shop_cell_x


## The rectangle of front `index`, in this node's coordinates.
func front_rect(index: int) -> Rect2:
	var width: float = _wall_px * FRONT_CELLS
	return Rect2(_arena_rect.position + Vector2(index * width, 0.0), Vector2(width, _wall_px))


## _draw paints every front except Lucky's.
func _draw() -> void:
	for i: int in front_count():
		if is_shop_front(i):
			continue
		var front: Rect2 = front_rect(i)
		match kind_of(i):
			Kind.SHUTTER:
				_draw_shutter(front)
			Kind.DOOR:
				draw_rect(front, FRONT_COLORS[i % FRONT_COLORS.size()])
				_draw_door(front, i)
			Kind.WINDOWS:
				draw_rect(front, FRONT_COLORS[i % FRONT_COLORS.size()])
				_draw_windows(front, i)
		# The eave: a dark strip under the roof with a paler lower edge.
		draw_rect(Rect2(front.position, Vector2(front.size.x, 6.0)), EAVE_COLOR)
		draw_line(front.position + Vector2(0.0, 6.0), front.position + Vector2(front.size.x, 6.0), EAVE_EDGE_COLOR, 1.0)
		# The seam between this front and the one to its left.
		draw_line(front.position, front.position + Vector2(0.0, front.size.y), SEAM_COLOR, 2.0)


## A rolled-down shutter, copied from the closed shop in cat_shop.gd on purpose:
## same panel, same four slat lines, same ledge sticking out into the lot.
func _draw_shutter(front: Rect2) -> void:
	# The same wall colour and brickwork as the shop front (see CatShop._draw).
	draw_rect(front, CatShop.FRONT_COLOR)
	Props.draw_bricks(self, front, global_position)
	draw_rect(Rect2(front.position.x, front.end.y, front.size.x, CatShop.STICK_OUT), CatShop.LEDGE_COLOR)
	var window: Rect2 = front.grow(-6.0)  # grow(-n) shrinks each side by n
	draw_rect(window, CatShop.SHUTTER_COLOR)
	for i: int in range(1, 5):
		var y: float = window.position.y + window.size.y * i / 5.0
		draw_line(Vector2(window.position.x, y), Vector2(window.end.x, y), CatShop.SLAT_COLOR, 2.0)


## A front door on the left with a small window on the right.
func _draw_door(front: Rect2, index: int) -> void:
	var door := Rect2(front.position + Vector2(18.0, 12.0), Vector2(22.0, front.size.y - 12.0))
	draw_rect(door.grow(2.0), FRAME_COLOR)
	draw_rect(door, DOOR_COLOR)
	draw_circle(door.position + Vector2(17.0, 20.0), 1.5, KNOB_COLOR)
	_draw_pane(Rect2(front.position + Vector2(56.0, 16.0), Vector2(24.0, 14.0)), index % 2 == 0)


## Two windows side by side; every third such front has one lit.
func _draw_windows(front: Rect2, index: int) -> void:
	_draw_pane(Rect2(front.position + Vector2(14.0, 16.0), Vector2(26.0, 16.0)), index % 3 == 0)
	_draw_pane(Rect2(front.position + Vector2(56.0, 16.0), Vector2(26.0, 16.0)), false)


## One window: a dark frame, the glass (dim amber if lit), and a cross bar.
func _draw_pane(glass: Rect2, lit: bool) -> void:
	draw_rect(glass.grow(2.0), FRAME_COLOR)
	draw_rect(glass, GLASS_LIT_COLOR if lit else GLASS_DARK_COLOR)
	var mid_x: float = glass.position.x + glass.size.x / 2.0
	draw_line(Vector2(mid_x, glass.position.y), Vector2(mid_x, glass.end.y), FRAME_COLOR, 2.0)
