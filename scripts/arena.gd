# arena.gd - the one-screen arena: owns the grid, walls, trees, enemies and pods.
# This is the root script of scenes/arena.tscn, the game's main scene.
class_name Arena
extends Node2D
## The scrapyard arena.
##
## The arena is the "parent that decides": children announce things with signals
## (the player fired, a Scrapper died, a sapling wants to turn solid) and the
## arena reacts by spawning nodes and updating the pathfinding grid.
##
## GRAY-BOX SCOPE: three hand-placed test trees, one Scrapper at a time (a new one
## walks in a moment after the last one dies), no waves, no player damage yet.

const CONFIG: GameConfig = preload("res://config/game_config.tres")
## preload() loads a scene file once, when the script itself loads. instantiate()
## then stamps out a fresh copy of that scene each time it is called.
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const TREE_SCENE: PackedScene = preload("res://scenes/forest_tree.tscn")
const SCRAPPER_SCENE: PackedScene = preload("res://scenes/scrapper.tscn")
const SEED_POD_SCENE: PackedScene = preload("res://scenes/seed_pod.tscn")

## Level layout for the gray box (grid cells, not tunables).
const TEST_TREE_CELLS: Array[Vector2i] = [Vector2i(9, 4), Vector2i(13, 10), Vector2i(17, 5)]
const PLAYER_START_CELL: Vector2i = Vector2i(6, 7)
## Physics layers 2 + 3 ("player" + "enemies") as a bit mask: 2 + 4 = 6.
const BODIES_MASK: int = 6

const BACKDROP_COLOR: Color = Color(0.09, 0.09, 0.10)
const WALL_COLOR: Color = Color(0.20, 0.19, 0.18)
const FLOOR_COLOR: Color = Color(0.33, 0.30, 0.27)
const GRID_LINE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.10)

## The pathfinding grid. Public so tests can inspect it.
var grid: ArenaGrid
var player: Player

## Which tree (sapling or grown) stands on which cell.
var _trees_by_cell: Dictionary[Vector2i, ForestTree] = {}
## Random numbers for picking where the next Scrapper walks in.
var _rng := RandomNumberGenerator.new()

## Child nodes that exist in arena.tscn. They are just folders that keep the
## scene tree tidy and control what draws on top of what.
@onready var _walls: StaticBody2D = $Walls
@onready var _trees: Node2D = $Trees
@onready var _enemies: Node2D = $Enemies
@onready var _pods: Node2D = $Pods
## Phone and tablet controls. Optional: the arena works without this node.
@onready var _touch: TouchControls = get_node_or_null("Hud/TouchControls")


## _ready runs once when the scene starts: build the grid and walls, then place
## the player, the test trees and the first Scrapper.
func _ready() -> void:
	# Centre the grid in the window.
	var arena_px: Vector2 = Vector2(CONFIG.grid_cols, CONFIG.grid_rows) * float(CONFIG.cell_size)
	var origin: Vector2 = ((get_viewport_rect().size - arena_px) / 2.0).floor()
	grid = ArenaGrid.new(CONFIG.grid_cols, CONFIG.grid_rows, CONFIG.cell_size, origin)
	_build_walls()

	player = PLAYER_SCENE.instantiate()
	player.position = grid.cell_to_world(PLAYER_START_CELL)
	player.seed_fired.connect(_on_player_seed_fired)
	add_child(player)
	# Hand the player to the touch controls, if the scene has them.
	if _touch != null:
		_touch.setup(player)

	for cell: Vector2i in TEST_TREE_CELLS:
		spawn_tree(cell, true)

	# The first Scrapper walks in from the middle of the right-hand side.
	spawn_scrapper_at(Vector2i(CONFIG.grid_cols - 2, CONFIG.grid_rows / 2))


## _draw paints the gray-box floor: backdrop, wall ring, floor, faint grid lines.
func _draw() -> void:
	var cell_px: float = float(CONFIG.cell_size)
	var arena_rect := Rect2(grid.origin, Vector2(grid.cols, grid.rows) * cell_px)
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), BACKDROP_COLOR)
	draw_rect(arena_rect, WALL_COLOR)
	draw_rect(arena_rect.grow(-cell_px), FLOOR_COLOR)  # grow(-n) shrinks each side by n
	for x: int in range(1, grid.cols):
		var line_x: float = grid.origin.x + x * cell_px
		draw_line(Vector2(line_x, arena_rect.position.y), Vector2(line_x, arena_rect.end.y), GRID_LINE_COLOR)
	for y: int in range(1, grid.rows):
		var line_y: float = grid.origin.y + y * cell_px
		draw_line(Vector2(arena_rect.position.x, line_y), Vector2(arena_rect.end.x, line_y), GRID_LINE_COLOR)


## Plants a tree on a cell. `grown` = true skips the sapling stage.
## Returns the new tree, or null if the cell is outside the grid or already taken.
func spawn_tree(cell: Vector2i, grown: bool) -> ForestTree:
	if not grid.in_bounds(cell) or grid.is_solid(cell) or _trees_by_cell.has(cell):
		return null
	var tree: ForestTree = TREE_SCENE.instantiate()
	tree.cell = cell
	tree.starts_grown = grown
	tree.position = grid.cell_to_world(cell)
	tree.ready_to_solidify.connect(_on_tree_ready_to_solidify)
	tree.felled.connect(_on_tree_felled)
	_trees.add_child(tree)
	_trees_by_cell[cell] = tree
	if grown:
		grid.set_solid(cell, true)
	return tree


## The tree (sapling or grown) on a cell, or null if there is none.
func tree_at(cell: Vector2i) -> ForestTree:
	return _trees_by_cell.get(cell)


## Creates a Scrapper on a cell and points it at the player.
func spawn_scrapper_at(cell: Vector2i) -> Scrapper:
	var scrapper: Scrapper = SCRAPPER_SCENE.instantiate()
	scrapper.position = grid.cell_to_world(cell)
	scrapper.setup(grid, player)
	scrapper.died.connect(_on_scrapper_died)
	_enemies.add_child(scrapper)
	return scrapper


## Builds the four invisible wall blocks that match the grid's solid outer ring.
func _build_walls() -> void:
	var cell_px: float = float(CONFIG.cell_size)
	var size: Vector2 = Vector2(grid.cols, grid.rows) * cell_px
	var top_left: Vector2 = grid.origin
	# Each Rect2 is (top-left corner, size) of one wall block, in pixels.
	var blocks: Array[Rect2] = [
		Rect2(top_left, Vector2(size.x, cell_px)),                              # top
		Rect2(top_left + Vector2(0.0, size.y - cell_px), Vector2(size.x, cell_px)),  # bottom
		Rect2(top_left, Vector2(cell_px, size.y)),                              # left
		Rect2(top_left + Vector2(size.x - cell_px, 0.0), Vector2(cell_px, size.y)),  # right
	]
	for block: Rect2 in blocks:
		var shape := RectangleShape2D.new()
		shape.size = block.size
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = block.get_center()
		_walls.add_child(collision)


## True if the player or an enemy is overlapping this cell right now.
func _is_cell_occupied(cell: Vector2i) -> bool:
	# Ask the physics engine: "does a cell-sized square here touch any body on the
	# player or enemy layers?" The square is slightly smaller than a cell so a body
	# merely brushing the edge does not count.
	var shape := RectangleShape2D.new()
	shape.size = Vector2.ONE * (float(CONFIG.cell_size) - 2.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, grid.cell_to_world(cell))
	query.collision_mask = BODIES_MASK
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## The cell itself if it is free; otherwise the nearest free neighbour; otherwise
## ArenaGrid.NO_CELL. Used so two machines falling on one spot still give two trees.
func _nearest_free_cell(cell: Vector2i) -> Vector2i:
	var offsets: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
	]
	for offset: Vector2i in offsets:
		var candidate: Vector2i = cell + offset
		if not grid.is_solid(candidate) and not _trees_by_cell.has(candidate):
			return candidate
	return ArenaGrid.NO_CELL


## Gray-box respawn: a new Scrapper walks in from a random spot on the edge of the
## floor that is far from the player.
func _spawn_replacement_scrapper() -> void:
	var player_cell: Vector2i = grid.world_to_cell(player.global_position)
	var candidates: Array[Vector2i] = []
	for x: int in range(1, grid.cols - 1):
		for y: int in range(1, grid.rows - 1):
			var is_edge: bool = x == 1 or y == 1 or x == grid.cols - 2 or y == grid.rows - 2
			var cell := Vector2i(x, y)
			var far_enough: bool = (cell - player_cell).length() >= 8.0
			if is_edge and far_enough and not grid.is_solid(cell):
				candidates.append(cell)
	if candidates.is_empty():
		return
	spawn_scrapper_at(candidates[_rng.randi_range(0, candidates.size() - 1)])


## Signal handler: the player fired. Spawn the pod where the signal says.
func _on_player_seed_fired(origin: Vector2, direction: Vector2) -> void:
	var pod: SeedPod = SEED_POD_SCENE.instantiate()
	pod.position = origin
	pod.direction = direction
	_pods.add_child(pod)


## Signal handler: a Scrapper died. Plant a sapling where it fell.
func _on_scrapper_died(scrapper: Scrapper) -> void:
	Sfx.play(&"enemy_down")
	var cell: Vector2i = _nearest_free_cell(grid.world_to_cell(scrapper.global_position))
	if cell != ArenaGrid.NO_CELL:
		# This handler runs in the middle of a physics step (the pod's overlap
		# callback caused the death), and Godot forbids adding physics bodies at
		# that moment. call_deferred queues the call for the end of the frame.
		spawn_tree.call_deferred(cell, false)
	if CONFIG.debug_respawn_delay > 0.0:
		get_tree().create_timer(CONFIG.debug_respawn_delay).timeout.connect(_spawn_replacement_scrapper)


## Signal handler: a sapling's timer ran out and it asks to become solid.
func _on_tree_ready_to_solidify(tree: ForestTree) -> void:
	# Never trap someone inside a tree: if the cell is occupied, ask again shortly.
	if _is_cell_occupied(tree.cell):
		tree.retry_later()
		return
	# SEAL GUARD (from the design doc): if this tree would cut the player off from
	# the arena centre, it stays a walk-through sapling for good.
	var player_cell: Vector2i = grid.world_to_cell(player.global_position)
	if grid.would_seal(tree.cell, player_cell, grid.center_cell()):
		return
	grid.set_solid(tree.cell, true)
	tree.solidify()
	Sfx.play(&"grow")


## Signal handler: a grown tree was destroyed. Open its cell up again.
func _on_tree_felled(tree: ForestTree) -> void:
	grid.set_solid(tree.cell, false)
	_trees_by_cell.erase(tree.cell)
