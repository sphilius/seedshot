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
## the HUD text that sits over it. A lit window is a small scene (s20): glass that
## brightens toward the sill, curtains pulled to each side, a silhouette (a potted
## sprout or a hanging lamp, taking turns), a sill and a faint pool of light on the
## wall below. A lit door gets a porch lamp above it. The front where Lucky's shop stands is left
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
## The lit-window scene. Like GLASS_LIT_COLOR these run above 1 so they keep glowing
## under the night tint. The glass is dimmer at the top and brighter at the bottom.
const GLASS_LIT_TOP_COLOR: Color = Color(1.05, 0.70, 0.28)
const GLASS_LIT_BOTTOM_COLOR: Color = Color(1.45, 1.00, 0.45)
const CURTAIN_COLOR: Color = Color(0.62, 0.34, 0.16)
const SILHOUETTE_COLOR: Color = Color(0.07, 0.10, 0.06)
const SILL_COLOR: Color = Color(0.60, 0.62, 0.68)
## The pool of light on the wall under a lit window, and the porch lamp's halo.
const SPILL_COLOR: Color = Color(1.35, 0.90, 0.40)
const BULB_COLOR: Color = Color(1.8, 1.4, 0.7)

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


## The first cell of every front along a wall `cols` cells wide where Lucky's
## shop can hide: the SHUTTER fronts, so it is always one shutter among others.
## The very first front is left out (it sits in the corner of the lot, where a
## seed pod can hardly reach it). `static`: it needs no wall to exist yet, so the
## arena can ask before it builds one.
static func shop_cells(cols: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for index: int in range(1, cols / FRONT_CELLS):  # whole-number division
		if PATTERN[index % PATTERN.size()] == Kind.SHUTTER:
			cells.append(Vector2i(index * FRONT_CELLS, 0))  # row 0 is the top wall
	return cells


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
	_draw_pane(Rect2(front.position + Vector2(56.0, 16.0), Vector2(24.0, 14.0)), is_lit_door(index), lit_style(index))
	if is_lit_door(index):
		# A porch lamp above the door: a bright dot in a soft halo.
		var lamp: Vector2 = front.position + Vector2(29.0, 9.0)
		draw_circle(lamp, 8.0, Color(SPILL_COLOR, 0.10))
		draw_circle(lamp, 4.5, Color(SPILL_COLOR, 0.18))
		draw_circle(lamp, 2.0, GLASS_LIT_BOTTOM_COLOR)


## Two windows side by side; every third such front has one lit.
func _draw_windows(front: Rect2, index: int) -> void:
	_draw_pane(Rect2(front.position + Vector2(14.0, 16.0), Vector2(26.0, 16.0)), is_lit_windows(index), lit_style(index))
	_draw_pane(Rect2(front.position + Vector2(56.0, 16.0), Vector2(26.0, 16.0)), false, 0)


## Which DOOR fronts have their window lit (every second door). Public for the tests.
static func is_lit_door(index: int) -> bool:
	return index % 2 == 0


## Which WINDOWS fronts have their first window lit (every third one).
static func is_lit_windows(index: int) -> bool:
	return index % 3 == 0


## What stands in a lit window of front `index`: 0 = a potted sprout, 1 = a hanging lamp.
## `%` is the remainder after division, so the two take turns along the wall.
static func lit_style(index: int) -> int:
	return index % 2


## One window: a dark frame and glass. Dark glass gets a cross bar; lit glass becomes
## the little scene described at the top of this file (`style` picks its silhouette).
func _draw_pane(glass: Rect2, lit: bool, style: int) -> void:
	if lit:
		_draw_lit_pane(glass, style)
		return
	draw_rect(glass.grow(2.0), FRAME_COLOR)
	draw_rect(glass, GLASS_DARK_COLOR)
	var mid_x: float = glass.position.x + glass.size.x / 2.0
	draw_line(Vector2(mid_x, glass.position.y), Vector2(mid_x, glass.end.y), FRAME_COLOR, 2.0)


## A lit window, painted back to front: the pool of light on the wall below (so the
## window sits on top of it), the frame, the glass in three bands from dim to bright,
## the silhouette, the curtains, and the sill.
func _draw_lit_pane(glass: Rect2, style: int) -> void:
	for step: int in 3:
		var spill := Rect2(glass.position.x - 2.0 - step, glass.end.y + 3.0, glass.size.x + 4.0 + step * 2.0, 4.0 + step * 3.0)
		draw_rect(spill, Color(SPILL_COLOR, 0.07 - 0.02 * step))
	draw_rect(glass.grow(2.0), FRAME_COLOR)
	var band: float = glass.size.y / 3.0
	draw_rect(Rect2(glass.position, Vector2(glass.size.x, band + 1.0)), GLASS_LIT_TOP_COLOR)
	draw_rect(Rect2(glass.position + Vector2(0.0, band), Vector2(glass.size.x, band + 1.0)), GLASS_LIT_TOP_COLOR.lerp(GLASS_LIT_BOTTOM_COLOR, 0.5))
	draw_rect(Rect2(glass.position + Vector2(0.0, band * 2.0), Vector2(glass.size.x, band)), GLASS_LIT_BOTTOM_COLOR)
	var mid_x: float = glass.position.x + glass.size.x / 2.0
	if style == 0:
		# A potted sprout: a pot, a stem and two leaves, as black cut-outs on the glow.
		draw_rect(Rect2(mid_x - 3.0, glass.end.y - 4.0, 6.0, 4.0), SILHOUETTE_COLOR)
		draw_line(Vector2(mid_x, glass.end.y - 4.0), Vector2(mid_x, glass.end.y - 9.0), SILHOUETTE_COLOR, 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(mid_x, glass.end.y - 8.0), Vector2(mid_x - 5.0, glass.end.y - 11.0), Vector2(mid_x - 1.5, glass.end.y - 6.5)]), SILHOUETTE_COLOR)
		draw_colored_polygon(PackedVector2Array([Vector2(mid_x, glass.end.y - 9.0), Vector2(mid_x + 5.0, glass.end.y - 12.0), Vector2(mid_x + 1.5, glass.end.y - 7.0)]), SILHOUETTE_COLOR)
	else:
		# A hanging lamp: a cord, a dark shade and a bright bulb under it.
		draw_line(Vector2(mid_x, glass.position.y), Vector2(mid_x, glass.position.y + 5.0), SILHOUETTE_COLOR, 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(mid_x - 4.0, glass.position.y + 9.0), Vector2(mid_x, glass.position.y + 4.0), Vector2(mid_x + 4.0, glass.position.y + 9.0)]), SILHOUETTE_COLOR)
		draw_circle(Vector2(mid_x, glass.position.y + 10.0), 1.6, BULB_COLOR)
	# Curtains pulled to each side (a slim quadrilateral each), then the sill.
	draw_colored_polygon(PackedVector2Array([glass.position, glass.position + Vector2(5.0, 0.0), glass.position + Vector2(2.0, glass.size.y), glass.position + Vector2(0.0, glass.size.y)]), CURTAIN_COLOR)
	draw_colored_polygon(PackedVector2Array([glass.position + Vector2(glass.size.x, 0.0), glass.position + Vector2(glass.size.x - 5.0, 0.0), glass.position + Vector2(glass.size.x - 2.0, glass.size.y), glass.position + glass.size]), CURTAIN_COLOR)
	draw_rect(Rect2(glass.position.x - 3.0, glass.end.y + 1.0, glass.size.x + 6.0, 2.0), SILL_COLOR)
