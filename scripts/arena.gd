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
## SCOPE SO FAR: three hand-placed starter trees and five waves of Scrappers and
## Sawbots, timed by the WaveDirector child node. A Scrapper's melee hit costs a
## hit point; at zero the current wave starts again with the forest as it stood
## when that wave began.

## Emitted when the player goes down. (Tests listen for this; the game itself
## reacts in _on_player_died.)
signal player_defeated

const CONFIG: GameConfig = preload("res://config/game_config.tres")
## preload() loads a scene file once, when the script itself loads. instantiate()
## then stamps out a fresh copy of that scene each time it is called.
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const TREE_SCENE: PackedScene = preload("res://scenes/forest_tree.tscn")
const SCRAPPER_SCENE: PackedScene = preload("res://scenes/scrapper.tscn")
const SAWBOT_SCENE: PackedScene = preload("res://scenes/sawbot.tscn")
const SPITTER_SCENE: PackedScene = preload("res://scenes/spitter.tscn")
const SPIT_SHOT_SCENE: PackedScene = preload("res://scenes/spit_shot.tscn")
const SEED_POD_SCENE: PackedScene = preload("res://scenes/seed_pod.tscn")

## Level layout for the gray box (grid cells, not tunables).
const TEST_TREE_CELLS: Array[Vector2i] = [Vector2i(9, 4), Vector2i(13, 10), Vector2i(17, 5)]
const PLAYER_START_CELL: Vector2i = Vector2i(6, 7)
## The hidden shop fills this wall cell and the one to its right: top wall, well
## to the right, away from where the fight naturally happens.
const CAT_SHOP_CELL: Vector2i = Vector2i(20, 0)
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
## Random numbers for picking where the next machine walks in.
var _rng := RandomNumberGenerator.new()
## The forest as it stood when the current wave began: cell -> was it grown?
## If the player goes down, the arena is put back to exactly this.
var _forest_at_wave_start: Dictionary[Vector2i, bool] = {}
## Seconds the banner stays up. 0 or less means "until replaced".
var _banner_time_left: float = 0.0
## The cell of the most recent sapling planted by a downed machine.
var _last_planted_cell: Vector2i = ArenaGrid.NO_CELL
## True once the player has zipped (or the hint is otherwise no longer needed).
var _vine_hint_done: bool = false

## The hidden lucky cat's shop, in the top wall. Public so tests can reach it.
var cat_shop: CatShop
## True after the last wave is cleared. Public so tests can read it.
var is_run_finished: bool = false

## Start wave 1 as soon as the arena loads. The headless tests switch this off
## (before adding the arena to the scene) so no surprise enemy walks into a test.
@export var autostart_waves: bool = true

## Child nodes that exist in arena.tscn. They are just folders that keep the
## scene tree tidy and control what draws on top of what.
@onready var _walls: StaticBody2D = $Walls
@onready var _trees: Node2D = $Trees
@onready var _enemies: Node2D = $Enemies
@onready var _pods: Node2D = $Pods
## Enemy shots get their own folder, so "how many seed pods exist" stays simple.
@onready var _shots: Node2D = $Shots
## Phone and tablet controls. Optional: the arena works without this node.
@onready var _touch: TouchControls = get_node_or_null("Hud/TouchControls")
@onready var _health_pips: HealthPips = $Hud/HealthPips
@onready var _wave_label: Label = $Hud/WaveLabel
@onready var _banner: Label = $Hud/Banner
## The wave timetable. Public (no underscore) so tests can start a wave directly.
@onready var waves: WaveDirector = $WaveDirector


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
	# The pips redraw themselves every time the player's health changes.
	player.health_changed.connect(_health_pips.show_health)
	player.died.connect(_on_player_died)
	add_child(player)
	_health_pips.show_health(player.hp, CONFIG.player_max_hp)
	# Hand the player to the touch controls, if the scene has them.
	if _touch != null:
		_touch.setup(player)

	for cell: Vector2i in TEST_TREE_CELLS:
		spawn_tree(cell, true)

	# The hidden lucky cat's shop. It is two cells wide, so its centre sits on
	# the line between its two cells: half a cell right of the first one's centre.
	cat_shop = CatShop.new()
	cat_shop.position = grid.cell_to_world(CAT_SHOP_CELL) + Vector2(CONFIG.cell_size / 2.0, 0.0)
	cat_shop.opened.connect(_on_cat_shop_opened)
	add_child(cat_shop)
	player.zip_finished.connect(_on_player_zip_finished)

	# Listen to the wave director: it says when, the arena does the spawning.
	waves.wave_started.connect(_on_wave_started)
	waves.spawn_requested.connect(_on_spawn_requested)
	waves.wave_cleared.connect(_on_wave_cleared)
	waves.all_waves_cleared.connect(_on_all_waves_cleared)
	_banner.visible = false
	_wave_label.text = ""
	if autostart_waves:
		waves.start_wave(1)


## _process runs every drawn frame: hide the banner when its time is up.
func _process(delta: float) -> void:
	# The corner label doubles as the "bloom meter": how many trees are standing.
	if waves.wave > 0:
		_wave_label.text = "Wave %d / %d     Trees %d" % [waves.wave, waves.total_waves(), count_grown_trees()]
	if _banner_time_left > 0.0:
		_banner_time_left -= delta
		if _banner_time_left <= 0.0:
			_banner.visible = false


## _draw paints the gray-box floor: backdrop, wall ring, floor, faint grid lines.
func _draw() -> void:
	var cell_px: float = float(CONFIG.cell_size)
	var arena_rect := Rect2(grid.origin, Vector2(grid.cols, grid.rows) * cell_px)
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), BACKDROP_COLOR)
	draw_rect(arena_rect, WALL_COLOR)
	var floor_rect: Rect2 = arena_rect.grow(-cell_px)  # grow(-n) shrinks each side by n
	draw_rect(floor_rect, FLOOR_COLOR)
	if CONFIG.floor_texture != null:
		# The slab is one cell big, so repeating it lines up with the grid. The
		# third argument (true) means "repeat the texture", not "stretch it".
		# The last argument is a tint: white with low alpha = a faint overlay.
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		draw_texture_rect(CONFIG.floor_texture, floor_rect, true, Color(1.0, 1.0, 1.0, CONFIG.floor_texture_strength))
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
	scrapper.setup(grid)
	scrapper.chase(player)
	scrapper.died.connect(_on_enemy_died)
	# A landed swing goes straight to the player's take_damage. The Scrapper only
	# announces the hit; it never reaches into the player itself.
	scrapper.struck.connect(player.take_damage)
	_enemies.add_child(scrapper)
	return scrapper


## Creates a Sawbot on a cell. It finds its own trees, so it needs only the grid.
func spawn_sawbot_at(cell: Vector2i) -> Sawbot:
	var sawbot: Sawbot = SAWBOT_SCENE.instantiate()
	sawbot.position = grid.cell_to_world(cell)
	sawbot.setup(grid)
	sawbot.died.connect(_on_enemy_died)
	_enemies.add_child(sawbot)
	return sawbot


## Creates a Spitter on a cell and points it at the player.
func spawn_spitter_at(cell: Vector2i) -> Spitter:
	var spitter: Spitter = SPITTER_SCENE.instantiate()
	spitter.position = grid.cell_to_world(cell)
	spitter.setup(grid)
	spitter.aim_at(player)
	spitter.died.connect(_on_enemy_died)
	# The Spitter only announces "I fired"; the arena makes the shot appear.
	spitter.spat.connect(spawn_spit_shot)
	_enemies.add_child(spitter)
	return spitter


## Creates one enemy shot at `origin`, flying along `direction` (a unit vector).
## Connected to every Spitter's `spat` signal; public so tests can fire one too.
func spawn_spit_shot(origin: Vector2, direction: Vector2) -> SpitShot:
	var shot: SpitShot = SPIT_SHOT_SCENE.instantiate()
	shot.position = origin
	shot.direction = direction
	_shots.add_child(shot)
	return shot


## How many grown trees are standing right now (the "bloom" count on the HUD).
func count_grown_trees() -> int:
	var count: int = 0
	for tree: ForestTree in _trees_by_cell.values():
		if tree.stage == ForestTree.Stage.GROWN:
			count += 1
	return count


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


## Where the next machine walks in: a random open cell on the edge of the floor
## that is far from the player. Returns ArenaGrid.NO_CELL if there is none.
func _pick_spawn_cell() -> Vector2i:
	var candidates: Array[Vector2i] = _spawn_candidates()
	if candidates.is_empty():
		return ArenaGrid.NO_CELL
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


## Staged wave 1 only: picks the spawn cell that puts `cover` (a tree's position)
## most nearly on the straight line between the newcomer and the player. So the
## first Spitter's first shot is aimed at a tree, and the player sees it stop.
func _pick_spawn_cell_behind(cover: Vector2) -> Vector2i:
	var best: Vector2i = ArenaGrid.NO_CELL
	var best_miss: float = INF  # how far the line passes from the tree (smaller is better)
	for cell: Vector2i in _spawn_candidates():
		var from: Vector2 = grid.cell_to_world(cell)
		# The point on the line (newcomer -> player) that is nearest to the tree.
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(cover, from, player.global_position)
		var miss: float = nearest.distance_to(cover)
		if miss < best_miss:
			best = cell
			best_miss = miss
	return best


## Every open cell on the edge of the floor that is far from the player.
func _spawn_candidates() -> Array[Vector2i]:
	var player_cell: Vector2i = grid.world_to_cell(player.global_position)
	var candidates: Array[Vector2i] = []
	for x: int in range(1, grid.cols - 1):
		for y: int in range(1, grid.rows - 1):
			var is_edge: bool = x == 1 or y == 1 or x == grid.cols - 2 or y == grid.rows - 2
			var cell := Vector2i(x, y)
			var far_enough: bool = (cell - player_cell).length() >= 8.0
			if is_edge and far_enough and not grid.is_solid(cell):
				candidates.append(cell)
	return candidates


## Shows a line of big text in the middle of the screen. `seconds` is how long it
## stays; 0 means "until the next banner replaces it".
func _show_banner(text: String, seconds: float) -> void:
	_banner.text = text
	_banner.visible = true
	_banner_time_left = seconds


## Puts the arena back to how it was when the current wave began, revives the
## player, and starts that wave again. (From the design: "Death restarts the
## current wave with the forest as it stood at wave start.")
func _restart_current_wave() -> void:
	# Remove every machine, pod and tree. remove_child takes a node out of the
	# scene right now (so it stops counting as "in the arena" this very frame);
	# queue_free then deletes it at the end of the frame.
	for folder: Node in [_enemies, _pods, _shots, _trees]:
		for child: Node in folder.get_children():
			folder.remove_child(child)
			child.queue_free()
	for cell: Vector2i in _trees_by_cell.keys():
		grid.set_solid(cell, false)
	_trees_by_cell.clear()

	# Replant the forest from the snapshot taken at wave start.
	for cell: Vector2i in _forest_at_wave_start.keys():
		spawn_tree(cell, _forest_at_wave_start[cell])

	var start_cell: Vector2i = _nearest_free_cell(PLAYER_START_CELL)
	if start_cell == ArenaGrid.NO_CELL:
		start_cell = PLAYER_START_CELL
	player.revive(grid.cell_to_world(start_cell))
	waves.restart_wave()


## Signal handler: a wave began. Remember the forest, update the HUD.
func _on_wave_started(number: int, total: int) -> void:
	_forest_at_wave_start.clear()
	for cell: Vector2i in _trees_by_cell.keys():
		_forest_at_wave_start[cell] = _trees_by_cell[cell].stage == ForestTree.Stage.GROWN
	_show_banner("Wave %d" % number, 1.5)


## Signal handler: the director wants one machine sent in.
func _on_spawn_requested(kind: StringName, wave_number: int) -> void:
	var cell: Vector2i = _pick_spawn_cell()
	# STAGED WAVE 1: the Spitter arrives after the Scrapper has become a tree, and
	# walks in from behind that tree, so its first shot visibly stops on it.
	var is_staged: bool = wave_number <= CONFIG.wave_staged_waves
	if is_staged and kind == WaveDirector.SPITTER and tree_at(_last_planted_cell) != null:
		cell = _pick_spawn_cell_behind(grid.cell_to_world(_last_planted_cell))
	if cell == ArenaGrid.NO_CELL:
		waves.enemy_gone()  # nowhere to put it: tell the director not to wait for it
		return
	if kind == WaveDirector.SAWBOT:
		spawn_sawbot_at(cell)
	elif kind == WaveDirector.SPITTER:
		spawn_spitter_at(cell)
	else:
		var scrapper: Scrapper = spawn_scrapper_at(cell)
		# Faster every wave: wave 1 is 1.0, wave 2 is 1.12, wave 3 is 1.24, ...
		scrapper.speed_scale = 1.0 + CONFIG.scrapper_speed_gain_per_wave * (wave_number - 1)


## Signal handler: every machine of a wave is down.
func _on_wave_cleared(number: int) -> void:
	Sfx.play(&"wave_clear")
	_show_banner("Wave %d cleared" % number, CONFIG.wave_break_time)


## Signal handler: the last wave is cleared. Show the forest you ended with.
func _on_all_waves_cleared() -> void:
	is_run_finished = true
	Sfx.play(&"cat")
	# The arena is left exactly as it is: the end screen IS your forest.
	_show_banner("Forest complete: %d trees standing\nPress R or tap here to plant again" % count_grown_trees(), 0.0)


## Signal handler: the third pod landed on the hidden shop and the cat is out.
func _on_cat_shop_opened() -> void:
	player.double_shot = true
	_show_banner("Lucky cat! Seed pods now fire in pairs", 3.0)


## Signal handler: the player finished a vine zip. The "you can vine to this"
## ring has done its job, so switch it off on every tree.
func _on_player_zip_finished() -> void:
	for tree: ForestTree in _trees_by_cell.values():
		tree.show_vine_hint = false
	_vine_hint_done = true


## _unhandled_input receives input that nothing else used. After the last wave,
## R / Enter, or a tap or click on the banner, starts a fresh run.
func _unhandled_input(event: InputEvent) -> void:
	if not is_run_finished:
		return
	var wants_restart: bool = event.is_action_pressed(&"restart")
	if event is InputEventScreenTouch and event.pressed:
		wants_restart = _banner.get_global_rect().has_point((event as InputEventScreenTouch).position)
	elif event is InputEventMouseButton and event.pressed:
		wants_restart = _banner.get_global_rect().has_point((event as InputEventMouseButton).position)
	# Only reload when the arena IS the running scene. In the headless tests it
	# is a child of the test scene, and reloading would restart the tests.
	if wants_restart and get_tree().current_scene == self:
		get_tree().reload_current_scene()


## Signal handler: the player fired. Spawn the pod where the signal says.
func _on_player_seed_fired(origin: Vector2, direction: Vector2) -> void:
	var pod: SeedPod = SEED_POD_SCENE.instantiate()
	pod.position = origin
	pod.direction = direction
	_pods.add_child(pod)


## Signal handler: the player went down. Wait a moment, then restart the wave.
func _on_player_died() -> void:
	player_defeated.emit()
	if waves.wave == 0:
		return  # no wave is running (the tests do this): nothing to restart
	_show_banner("Down! Wave %d starts again" % waves.wave, CONFIG.death_restart_delay)
	# `await` pauses this function here until the timer's `timeout` signal fires.
	# The `false` means "this timer stops while the game is paused".
	await get_tree().create_timer(CONFIG.death_restart_delay, false).timeout
	# After an `await`, anything may have changed: this arena may already be gone.
	if not is_inside_tree():
		return
	_restart_current_wave()


## Signal handler: a Scrapper died. Plant a sapling where it fell.
func _on_enemy_died(enemy: Enemy) -> void:
	Sfx.play(&"enemy_down")
	var cell: Vector2i = _nearest_free_cell(grid.world_to_cell(enemy.global_position))
	if cell != ArenaGrid.NO_CELL:
		# This handler runs in the middle of a physics step (the pod's overlap
		# callback caused the death), and Godot forbids adding physics bodies at
		# that moment. call_deferred queues the call for the end of the frame.
		spawn_tree.call_deferred(cell, false)
		_last_planted_cell = cell
	waves.enemy_gone()  # the wave director keeps count of who is still standing


## Signal handler: a sapling's timer ran out and it asks to become solid.
func _on_tree_ready_to_solidify(tree: ForestTree) -> void:
	# Never trap someone inside a tree: if the cell is occupied, ask again shortly.
	if _is_cell_occupied(tree.cell):
		tree.retry_later()
		return
	# SPLIT GUARD: if this tree would cut the open floor in two, it stays a
	# walk-through sapling for good. That way nobody is ever walled in, and no
	# enemy is ever walled out. (The design doc only asked for "the player can
	# reach the centre", but the first phone playtest sealed the player into a
	# pocket that CONTAINED the centre, where the Scrapper could never follow.)
	if grid.would_split(tree.cell):
		return
	grid.set_solid(tree.cell, true)
	tree.solidify()
	Sfx.play(&"grow")
	# Teach the vine once: the first tree the player grows pulses until they zip.
	if not _vine_hint_done and tree.cell == _last_planted_cell:
		tree.show_vine_hint = true


## Signal handler: a grown tree was destroyed. Open its cell up again.
func _on_tree_felled(tree: ForestTree) -> void:
	grid.set_solid(tree.cell, false)
	_trees_by_cell.erase(tree.cell)
