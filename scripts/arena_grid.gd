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
## How much dearer a step along the outer border is than an ordinary step.
const BORDER_WEIGHT: float = 2.5

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
	# The floor cells right beside a wall "cost" more to walk through, so routes
	# keep off the outer border when there is another way. (s18 round 4: a
	# Linebreaker wedged itself between a tree and Lucky's shop up there.)
	# A weight of 1 is normal; a higher weight makes a cell less attractive.
	for x: int in range(1, cols - 1):
		for y: int in range(1, rows - 1):
			if x == 1 or y == 1 or x == cols - 2 or y == rows - 2:
				_astar.set_point_weight_scale(Vector2i(x, y), BORDER_WEIGHT)


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


## SPLIT GUARD: would turning `cell` solid cut the open floor into two or more
## separate areas? The arena uses this before a sapling becomes a tree, so the
## forest can never wall anyone in OR out: every open cell stays reachable from
## every other, which means an enemy can always walk to the player.
##
## HOW: a new tree can only cut the floor where it stands. So look at the open
## cells directly beside it (up, down, left, right). If you can still walk from
## the first of them to all the others WITHOUT stepping on `cell`, nothing was
## cut. That walk is a "flood fill": start somewhere, keep spreading to open
## neighbours until there is nowhere new to go.
## (Only straight steps are counted. Diagonal steps between two trees that touch
## at a corner are not allowed by the pathfinder either, so the two agree.)
func would_split(cell: Vector2i) -> bool:
	if not in_bounds(cell) or is_solid(cell):
		return false  # nothing would change
	var steps: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var open_neighbours: Array[Vector2i] = []
	for step: Vector2i in steps:
		if not is_solid(cell + step):
			open_neighbours.append(cell + step)
	if open_neighbours.size() <= 1:
		return false  # a dead end (or fully enclosed): filling it cuts nothing

	# Flood fill from the first open neighbour. `reached` is used as a set: only
	# its keys matter. `frontier` is the to-do list of cells still to spread from.
	var reached: Dictionary[Vector2i, bool] = {cell: true, open_neighbours[0]: true}
	var frontier: Array[Vector2i] = [open_neighbours[0]]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_back()  # take one cell off the list
		for step: Vector2i in steps:
			var next: Vector2i = current + step
			if not reached.has(next) and not is_solid(next):
				reached[next] = true
				frontier.append(next)

	# Any open neighbour the fill never reached is now on the far side of a wall.
	for neighbour: Vector2i in open_neighbours:
		if not reached.has(neighbour):
			return true
	return false


## SEAL GUARD: would turning `cell` solid cut the route between the two cells?
## (Narrower than would_split: it only protects one route. The arena used this
## first, but a player could still be sealed into a pocket TOGETHER with the
## other cell, so the arena now calls would_split instead.)
## We temporarily block the cell, ask the pathfinder, then put it back, so the
## grid is unchanged when this returns.
func would_seal(cell: Vector2i, from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if not in_bounds(cell) or is_solid(cell):
		return false  # nothing would change, so nothing new gets sealed
	_astar.set_point_solid(cell, true)
	var sealed: bool = not has_path(from_cell, to_cell)
	_astar.set_point_solid(cell, false)
	return sealed
