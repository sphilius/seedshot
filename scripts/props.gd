# props.gd - the walls' brickwork and the street props (art pass, from concept 05_props_b).
# Created by the arena in code and drawn just above the floor, under trees and machines.
class_name Props
extends Node2D
## WHAT IT DRAWS
##   Bricks     faint mortar lines over the top, left and right walls, so they read
##              as brick instead of flat grey. (The bottom wall is the homes.)
##   Wall props Helios meters and notices (some crossed out by the block) fixed to
##              the walls. Graffiti is painted over them, as it would be.
##   Flat props a broken solar panel lying on the floor. You walk and shoot over it.
##   Corner props a planter box, a barrel planter, a bike and a chair with a card
##              table, one in each corner of the floor. These are SOLID, like a
##              tree that can't be cut: they block walking, pods and shots.
##
## The pictures are frames of art/sprites/props.png (tools/prop_sprites.py), one
## 64 x 64 frame each, in the order of FRAMES.

const CONFIG: GameConfig = preload("res://config/game_config.tres")
## Frame order in props.png. Must match PROPS in tools/prop_sprites.py.
const FRAMES: Array[StringName] = [&"meter", &"notice", &"notice_x", &"planter", &"barrel", &"cable", &"panel", &"bike", &"chair"]
const FRAME_PX: float = 64.0

## Brick size in pixels, and the mortar colour (darker than the wall, see-through).
const BRICK: Vector2 = Vector2(24.0, 12.0)
const MORTAR_COLOR: Color = Color(0.0, 0.0, 0.0, 0.22)
const BRICK_HIGHLIGHT: Color = Color(1.0, 1.0, 1.0, 0.035)

## The cells of the solid corner props. Public so the tests (and the arena, for
## keeping spawns off them) can read them. Filled in by setup().
var solid_cells: Array[Vector2i] = []

## [frame name, cell] for each wall prop, flat prop and corner prop. Set by setup().
var _placements: Array[Array] = []
var _grid: ArenaGrid
var _arena_rect: Rect2


## Called once by the arena: lays the props out on this grid and makes the
## corner props solid (a collision box each, and a solid cell for pathfinding).
func setup(grid: ArenaGrid, arena_rect: Rect2) -> void:
	_grid = grid
	_arena_rect = arena_rect
	var last_col: int = grid.cols - 1
	var last_row: int = grid.rows - 1
	# Wall props: x = 0 is the left wall, x = last_col the right wall, y = 0 the top wall.
	_placements = [
		[&"meter", Vector2i(0, 3)], [&"notice", Vector2i(0, 9)],
		[&"notice_x", Vector2i(last_col, 4)], [&"meter", Vector2i(last_col, 10)],
		[&"meter", Vector2i(9, 0)], [&"notice_x", Vector2i(17, 0)],
		# Flat on the floor (walkable).
		[&"panel", Vector2i(19, 11)],
	]
	# One solid prop in each corner of the floor (the floor starts one cell in from the walls).
	var corners: Array[Array] = [
		[&"barrel", Vector2i(1, 1)], [&"planter", Vector2i(last_col - 1, 1)],
		[&"bike", Vector2i(1, last_row - 1)], [&"chair", Vector2i(last_col - 1, last_row - 1)],
	]
	for corner: Array in corners:
		_placements.append(corner)
		var cell: Vector2i = corner[1]
		solid_cells.append(cell)
		grid.set_solid(cell, true)  # machines path around it
		# A StaticBody2D on layer 1 ("world") stops the player, pods and shots, like a tree.
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = grid.cell_to_world(cell)
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2.ONE * float(CONFIG.cell_size)
		shape.shape = box
		body.add_child(shape)
		add_child(body)
	queue_redraw()


## Mortar lines over `rect` (pixels, in the coordinates of `canvas`), in a
## running-bond pattern (each row shifted half a brick). `world_offset` is the
## canvas's position in the world, so bricks line up across different nodes:
## the cat shop uses this too, so its front matches the wall around it.
static func draw_bricks(canvas: CanvasItem, rect: Rect2, world_offset: Vector2) -> void:
	var world_top: float = rect.position.y + world_offset.y
	# The first mortar row at or above the rect's top, on the world's brick grid.
	var first_row: int = floori(world_top / BRICK.y)
	var row: int = first_row
	while row * BRICK.y - world_offset.y < rect.end.y:
		var y: float = row * BRICK.y - world_offset.y
		if y >= rect.position.y:
			canvas.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), MORTAR_COLOR, 1.0)
			canvas.draw_line(Vector2(rect.position.x, y + 1.0), Vector2(rect.end.x, y + 1.0), BRICK_HIGHLIGHT, 1.0)
		# The upright joints in this row, shifted half a brick on odd rows.
		var shift: float = (BRICK.x / 2.0) if posmod(row, 2) == 1 else 0.0
		var x_world: float = floorf((rect.position.x + world_offset.x - shift) / BRICK.x) * BRICK.x + shift
		while x_world - world_offset.x < rect.end.x:
			var x: float = x_world - world_offset.x
			if x >= rect.position.x:
				var top: float = maxf(y, rect.position.y)
				var bottom: float = minf(y + BRICK.y, rect.end.y)
				if bottom > top:
					canvas.draw_line(Vector2(x, top), Vector2(x, bottom), MORTAR_COLOR, 1.0)
			x_world += BRICK.x
		row += 1


## _draw paints the brickwork, then every prop.
func _draw() -> void:
	if _grid == null:
		return
	var wall: float = float(CONFIG.cell_size)
	# The three brick walls: top, left, right (this node sits at the world origin).
	draw_bricks(self, Rect2(_arena_rect.position, Vector2(_arena_rect.size.x, wall)), Vector2.ZERO)
	draw_bricks(self, Rect2(_arena_rect.position + Vector2(0.0, wall), Vector2(wall, _arena_rect.size.y - wall * 2.0)), Vector2.ZERO)
	draw_bricks(self, Rect2(Vector2(_arena_rect.end.x - wall, _arena_rect.position.y + wall), Vector2(wall, _arena_rect.size.y - wall * 2.0)), Vector2.ZERO)
	if CONFIG.props_texture == null:
		return
	for placement: Array in _placements:
		var frame: int = FRAMES.find(placement[0])
		var centre: Vector2 = _grid.cell_to_world(placement[1])
		var source := Rect2(frame * FRAME_PX, 0.0, FRAME_PX, FRAME_PX)
		# Drawn at the same size as other sprites (64 px picture -> sprite size).
		var size: float = CONFIG.sprite_size_cells * float(CONFIG.cell_size)
		draw_texture_rect_region(CONFIG.props_texture, Rect2(centre - Vector2.ONE * size / 2.0, Vector2.ONE * size), source)
