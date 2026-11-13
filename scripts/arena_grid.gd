# arena_grid.gd - the arena as a grid of cells, plus pathfinding over that grid.
# This is a plain RefCounted class (not a Node), so it holds no visuals and can be
# tested headlessly: tests just call ArenaGrid.new(...) and ask it questions.
class_name ArenaGrid
extends RefCounted
## The arena as a grid of square cells, with A* pathfinding.
##
## VOCABULARY
##   cell   a grid coordinate, Vector2i(column, row). (0, 0) is the top-left cell.
##   world  a pixel position on screen, Vector2(x, y).
##   solid  a cell nothing can walk through: a wall or a grown tree.
##
## WHY AStarGrid2D: it is Godot's built-in grid pathfinder. When a tree grows or is
## cut down we flip ONE cell between solid and clear, which is instant. The
## alternative (re-baking a navigation mesh) is slow on web builds.

## Returned by helpers that look for a cell and find none.
const NO_CELL: Vector2i = Vector2i(-1, -1)

## Grid size in cells, and the size of one cell in pixels.
var cols: int
var rows: int
var cell_size: int
## World position of the top-left corner of cell (0, 0).
var origin: Vector2

## Godot's grid pathfinder. The leading underscore marks it as private: other
## scripts should use the methods below instead of touching it directly.
var _astar: AStarGrid2D = AStarGrid2D.new()


## Builds an empty grid whose outer ring of cells is solid wall.
## (`_init` is the constructor: it runs when you call ArenaGrid.new(...).)
func _init(p_cols: int, p_rows: int, p_cell_size: int, p_origin: Vector2 = Vector2.ZERO) -> void:
	cols = p_cols
	rows = p_rows
	cell_size = p_cell_size
	origin = p_origin

	_astar.region = Rect2i(0, 0, cols, rows)
	_astar.cell_size = Vector2(cell_size, cell_size)
	# Allow a diagonal step only when both cells beside it are clear, so enemies
	# never try to squeeze diagonally between two trees that touch at a corner.
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()  # must be called once after changing region/cell_size

	# The outer ring is the arena wall.
	for x: int in cols:
		_astar.set_point_solid(Vector2i(x, 0), true)
		_astar.set_point_solid(Vector2i(x, rows - 1), true)
	for y: int in rows:
		_astar.set_point_solid(Vector2i(0, y), true)
		_astar.set_point_solid(Vector2i(cols - 1, y), true)


## Which cell contains this pixel position? (May be out of bounds: check in_bounds.)
func world_to_cell(world_position: Vector2) -> Vector2i:
	var local: Vector2 = (world_position - origin) / float(cell_size)
	return Vector2i(floori(local.x), floori(local.y))


## Pixel position of the CENTRE of a cell.
func cell_to_world(cell: Vector2i) -> Vector2:
	return origin + (Vector2(cell) + Vector2(0.5, 0.5)) * float(cell_size)


## The cell in the middle of the arena. The seal guard keeps a route open to it.
func center_cell() -> Vector2i:
	return Vector2i(cols / 2, rows / 2)  # integer division on purpose


## True if the cell is inside the grid at all.
func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows


## True for walls and grown trees. Cells outside the grid count as solid.
func is_solid(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return true
	return _astar.is_point_solid(cell)


## Marks a cell as blocked (a tree grew) or clear (a tree was cut down).
func set_solid(cell: Vector2i, solid: bool) -> void:
	if in_bounds(cell):
		_astar.set_point_solid(cell, solid)


## The list of cells to walk through to get from one cell to another, including
## both ends. If the goal cannot be reached, the path leads as close as possible
## (that is what `true` = "allow partial path" means). Empty if either cell is
## outside the grid.
func find_path(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	if not in_bounds(from_cell) or not in_bounds(to_cell):
		return []
	return _astar.get_id_path(from_cell, to_cell, true)


## True if a complete walkable route exists between the two cells.
func has_path(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if not in_bounds(from_cell) or not in_bounds(to_cell):
		return false
	if is_solid(to_cell):
		return false
	return not _astar.get_id_path(from_cell, to_cell).is_empty()


## SEAL GUARD: would turning `cell` solid cut the route between the two cells?
## We temporarily block the cell, ask the pathfinder, then put it back, so the
## grid is unchanged when this returns.
func would_seal(cell: Vector2i, from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if not in_bounds(cell) or is_solid(cell):
		return false  # nothing would change, so nothing new gets sealed
	_astar.set_point_solid(cell, true)
	var sealed: bool = not has_path(from_cell, to_cell)
	_astar.set_point_solid(cell, false)
	return sealed
