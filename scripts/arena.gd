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
## Emitted when the Heart Tree is felled (the wave then starts again).
signal heart_tree_felled

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
## The Heart Tree's cell: the middle of the lot (see forest_tree.gd is_heart).
const HEART_TREE_CELL: Vector2i = Vector2i(13, 7)
## The hidden shop fills this wall cell and the one to its right: top wall, well
## to the right, away from where the fight naturally happens.
const CAT_SHOP_CELL: Vector2i = Vector2i(20, 0)
## Physics layers 2 + 3 ("player" + "enemies") as a bit mask: 2 + 4 = 6.
const BODIES_MASK: int = 6

## Night colours: dark and cool, so the warm windows and glowing trees stand out.
const BACKDROP_COLOR: Color = Color(0.05, 0.05, 0.07)
## These are the colours under FULL light. A CanvasModulate node (see _ready)
## tints them, and everything else in the lot, darker and cooler while the block
## is still mostly dark.
const WALL_COLOR: Color = Color(0.19, 0.19, 0.22)
const FLOOR_COLOR: Color = Color(0.29, 0.29, 0.31)
const GRID_LINE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.10)
## The title screen, where a finished run returns to (and New Game + is picked).
const TITLE_SCENE: String = "res://scenes/title.tscn"
## The ring round a tap point's soil patch (brighter than white on purpose).
const TAP_RING_COLOR: Color = Color(2.2, 1.7, 0.6, 0.85)

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
## The cells holding a great sunroot at wave start (New Game +), for restarts.
var _great_trees_at_wave_start: Array[Vector2i] = []
## True for a New Game + run: harder waves, and trees mature into great sunroots.
var ng_plus: bool = false
## The cells holding a tap tree at wave start, so a restart replants them as tap trees.
var _tap_trees_at_wave_start: Array[Vector2i] = []
## This wave's tap points: soil patches where a downed machine grows a tap tree.
## Public so the tests can read it.
var tap_points: Array[Vector2i] = []
## Seconds the banner stays up. 0 or less means "until replaced".
var _banner_time_left: float = 0.0
## Small story lines still waiting to be shown under the banner, in order.
## Lines waiting for the radio, oldest first: each is {speaker = Radio.HELIOS /
## CANOPY / LUCKY, text = the words}.
var _story_queue: Array[Dictionary] = []
## Canopy FM tutorial moments already played this run (so each plays once).
var _dj_said: Dictionary[StringName, bool] = {}
## Seconds the story line on screen has left. 0 or less means "until replaced".
var _story_time_left: float = 0.0
## True once the opening line has been shown, so a restarted wave 1 skips it.
var _hook_shown: bool = false
## The cell of the most recent sapling planted by a downed machine.
var _last_planted_cell: Vector2i = ArenaGrid.NO_CELL
## True once the player has zipped (or the hint is otherwise no longer needed).
var _vine_hint_done: bool = false

## The block's windows along the bottom wall. Public so tests can reach it.
var windows: BlockWindows
## The highest wave cleared so far this run. It drives the windows and the
## light: a restarted wave never takes light away. Public so tests can read it.
var waves_cleared: int = 0
## The node that tints the whole lot to match the light (see _ready).
var _ambient: CanvasModulate
## The wave the lucky cat was found in (0 = not found yet). Picks Lucky's greeting.
var lucky_found_wave: int = 0
## How many times Seven has talked to Lucky: picks the next small-talk line.
var _lucky_talks: int = 0
## The lantern strings (see lanterns.gd). Public so tests can read it.
var lanterns: Lanterns
## The great sunroots' Canopy lines and Sunburst (see great_powers.gd). Public for tests.
var great_powers: GreatPowers
## Brick walls and street props (see props.gd). Public so tests can read it.
var props: Props
## Holds the bramble patches (see bramble.gd), so a restart can clear them.
var _brambles: Node2D
## The Heart Tree, or null if there is none (felled and not yet replanted, or a
## test arena without one). Public so tests can read it.
var heart_tree: ForestTree
## How many times Canopy FM has raised the Heart Tree alarm. Public for the tests.
var heart_alarms: int = 0
## Seconds until Canopy FM may raise the Heart Tree alarm again.
var _heart_alarm_left: float = 0.0
## Knob: plant the Heart Tree at the start. The tests switch it off for the
## older checks that count trees, since writes to the shared config are ignored.
@export var plant_heart_tree: bool = true
## The between-wave upgrade cards (see upgrade_picker.gd). Public for tests.
var upgrade_picker: UpgradePicker
## Run-long upgrade effects the arena hands out (see apply_upgrade). Public for tests.
var seed_damage_bonus: int = 0
var tree_hp_bonus: int = 0
var sapling_time_scale: float = 1.0
## Every upgrade picked this run, in order. Public for tests.
var upgrades_taken: Array[StringName] = []
## The Block's painted lines on the side walls. Public so tests can reach it.
var graffiti: Graffiti
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
## The smaller line under the banner: Helios's notices and the opening line.
## The radio panel (see radio.gd): Helios, Canopy FM and Lucky speak here.
## Public so the tests can read who is on the air.
var radio: Radio
## The controls line along the bottom wall.
@onready var _hint: Label = $Hud/Hint
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

	# The Block's graffiti. Added first, so everything else draws on top of it.
	graffiti = Graffiti.new()
	graffiti.setup(Rect2(origin, arena_px), float(CONFIG.cell_size))
	add_child(graffiti)
	windows = BlockWindows.new()
	windows.setup(Rect2(origin, arena_px), float(CONFIG.cell_size))
	add_child(windows)
	# Lantern strings across the lot. Added before the trees and machines, so
	# they hang underneath them and never hide the action.
	# The art pass: brick walls and street props (see props.gd). Added first among
	# the arena's drawn children, so it sits on the floor under everything else.
	props = Props.new()
	add_child(props)
	move_child(props, 0)  # draw right after the floor
	props.setup(grid, Rect2(grid.origin, Vector2(grid.cols, grid.rows) * float(CONFIG.cell_size)))
	_brambles = Node2D.new()
	_brambles.name = "Brambles"
	add_child(_brambles)
	move_child(_brambles, 1)  # on the floor, just above the props, under everything else
	lanterns = Lanterns.new()
	lanterns.setup(Rect2(origin, arena_px).grow(-float(CONFIG.cell_size)))
	add_child(lanterns)
	# The great sunroots' cables and Sunburst ring. z_index 1 draws them over the
	# trees and machines (which use 0), so a cable is never hidden by a canopy.
	great_powers = GreatPowers.new()
	great_powers.z_index = 1
	add_child(great_powers)
	# CanvasModulate multiplies the colour of everything drawn in this scene
	# (floor, walls, sprites, trees) by one colour. The HUD is on its own
	# CanvasLayer, so it is not tinted and stays readable. This is how the
	# sprites are "recoloured" to match the light: one tint, updated in _process.
	_ambient = CanvasModulate.new()
	_ambient.color = CONFIG.ambient_dark
	add_child(_ambient)
	_update_light()

	player = PLAYER_SCENE.instantiate()
	# Seven's lamp: a warm pool of light that moves with the bot.
	player.add_child(Glow.make_sprite(CONFIG.player_glow_radius_cells * float(CONFIG.cell_size), CONFIG.player_glow_color))
	player.position = grid.cell_to_world(PLAYER_START_CELL)
	player.seed_fired.connect(_on_player_seed_fired)
	# The pips redraw themselves every time the player's health changes.
	player.health_changed.connect(_health_pips.show_health)
	player.died.connect(_on_player_died)
	player.fuse_used.connect(_on_player_fuse_used)
	add_child(player)
	_health_pips.show_health(player.hp, player.max_hp)
	# Hand the player to the touch controls, if the scene has them.
	if _touch != null:
		_touch.setup(player)

	for cell: Vector2i in TEST_TREE_CELLS:
		spawn_tree(cell, true)
	if plant_heart_tree:
		heart_tree = spawn_tree(HEART_TREE_CELL, true)

	# The hidden lucky cat's shop. It is two cells wide, so its centre sits on
	# the line between its two cells: half a cell right of the first one's centre.
	cat_shop = CatShop.new()
	cat_shop.position = grid.cell_to_world(CAT_SHOP_CELL) + Vector2(CONFIG.cell_size / 2.0, 0.0)
	cat_shop.opened.connect(_on_cat_shop_opened)
	add_child(cat_shop)

	player.zip_finished.connect(_on_player_zip_finished)
	player.bramble_thrown.connect(spawn_bramble)

	# Listen to the wave director: it says when, the arena does the spawning.
	waves.wave_started.connect(_on_wave_started)
	waves.spawn_requested.connect(_on_spawn_requested)
	waves.wave_cleared.connect(_on_wave_cleared)
	waves.all_waves_cleared.connect(_on_all_waves_cleared)
	_banner.visible = false
	radio = Radio.new()
	$Hud.add_child(radio)
	upgrade_picker = UpgradePicker.new()
	upgrade_picker.picked.connect(apply_upgrade)
	$Hud.add_child(upgrade_picker)
	_wave_label.text = ""
	if RunState.ng_plus:
		apply_ng_plus()
	if autostart_waves:
		waves.start_wave(1)


## _process runs every drawn frame: hide the banner when its time is up.
func _process(delta: float) -> void:
	# The corner label doubles as the score: every standing tree powers one home.
	if waves.wave > 0:
		# Bramble Seeds in hand, out of the most Seven can hold.
		_wave_label.text = "Wave %d / %d    Homes lit %d / %d    Trees %d    Brambles %d / %d" % [
			waves.wave, waves.total_waves(), windows.homes_lit(), windows.home_count(), count_grown_trees(),
			player.bramble_charges, CONFIG.bramble_max_charges]
	# Glide the lot's tint toward what the current light calls for.
	var wanted_tint: Color = ambient_tint_for(light_level())
	if cat_shop != null:
		cat_shop.show_talk_hint = is_near_lucky()
	# Lights shine brighter than white while the lot is dark, and normally once
	# it is fully lit; otherwise the end of the run turns into a yellow glare.
	var boost: float = light_boost_for(light_level())
	# Canopy FM opens up as the block lights (see canopy_fm.gd).
	CanopyFM.set_light(light_level())
	radio.signal_strength = light_level()  # Canopy FM's signal grows with the light
	windows.light_boost = boost
	lanterns.light_boost = boost
	great_powers.light_boost = boost
	# One shared value for every tree's markers (a static var, see forest_tree.gd).
	ForestTree.light_boost = boost
	_heart_alarm_left = maxf(_heart_alarm_left - delta, 0.0)
	# The bright cables showed through the upgrade cards: hide them while it is open.
	great_powers.cables_hidden = upgrade_picker.is_open()
	_ambient.color = _ambient.color.lerp(wanted_tint, minf(1.0, CONFIG.ambient_change_speed * delta))
	# The last machines are still growing into trees when the end screen comes
	# up, so keep its score current instead of freezing it at the first count.
	if is_run_finished:
		_banner.text = end_banner_text()
	# The small story line: when its time is up, show the next one or hide.
	if _story_time_left > 0.0:
		_story_time_left -= delta
		if _story_time_left <= 0.0:
			_show_next_story_line()
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
	if CONFIG.floor_tiles != null:
		# One slab per floor cell. The tiles sit side by side in one picture, so
		# tile number n is the 48 x 48 square starting n cells from its left edge.
		var tile_count: int = CONFIG.floor_tiles.get_width() / CONFIG.cell_size
		for y: int in range(1, grid.rows - 1):        # skip row 0 and the last row: they are wall
			for x: int in range(1, grid.cols - 1):
				var pick: int = floor_tile_for(Vector2i(x, y), tile_count, CONFIG.floor_plain_count, CONFIG.floor_detail_chance)
				var source := Rect2(pick * cell_px, 0.0, cell_px, cell_px)
				var target := Rect2(grid.origin + Vector2(x, y) * cell_px, Vector2.ONE * cell_px)
				# draw_texture_rect_region copies one square of a picture onto the screen.
				draw_texture_rect_region(CONFIG.floor_tiles, target, source, CONFIG.floor_tint)
		# This wave's tap points: a soil patch on each.
		if CONFIG.tap_point_texture != null:
			for cell: Vector2i in tap_points:
				draw_texture_rect(CONFIG.tap_point_texture, Rect2(grid.origin + Vector2(cell) * cell_px, Vector2.ONE * cell_px), false)
				# A gold ring, so the patch reads at night. Colour values above 1
				# keep it bright under the night tint (like the lights, see light_boost).
				draw_arc(grid.cell_to_world(cell), cell_px * 0.48, 0.0, TAU, 32, TAP_RING_COLOR, 2.0)
		# Each slab already has its own dark edge, so the grid lines below would
		# only double them up.
		return
	for x: int in range(1, grid.cols):
		var line_x: float = grid.origin.x + x * cell_px
		draw_line(Vector2(line_x, arena_rect.position.y), Vector2(line_x, arena_rect.end.y), GRID_LINE_COLOR)
	for y: int in range(1, grid.rows):
		var line_y: float = grid.origin.y + y * cell_px
		draw_line(Vector2(arena_rect.position.x, line_y), Vector2(arena_rect.end.x, line_y), GRID_LINE_COLOR)


## Which floor tile cell `cell` shows: a number from 0 to tile_count - 1.
## Most cells get one of the first `plain_count` tiles (plain slabs); about
## `detail_chance` of them get one of the rest (moss, puddle, grate...).
##
## WHY NOT randi(): the floor is redrawn whenever Godot asks, and a random pick
## would reshuffle it every time. Instead the cell's own x and y are mixed into
## a big scrambled number (a "hash"), so the same cell always gets the same
## tile, but neighbouring cells look unrelated. `static` means it needs no
## arena to run, so the tests can call it directly.
static func floor_tile_for(cell: Vector2i, tile_count: int, plain_count: int, detail_chance: float) -> int:
	# Multiplying by large odd numbers and XOR-ing (^) scrambles the bits well.
	# `& 0x7fffffff` keeps the result positive.
	var h: int = ((cell.x * 73856093) ^ (cell.y * 19349663) ^ 0x5bd1e995) & 0x7fffffff
	var detail_count: int = tile_count - plain_count
	# The lowest three digits of h decide "detail or plain"...
	if detail_count > 0 and float(h % 1000) / 1000.0 < detail_chance:
		# ...and the digits above them decide which one.
		return plain_count + (h / 1000) % detail_count
	return (h / 1000) % maxi(plain_count, 1)


## Plants a tree on a cell. `grown` = true skips the sapling stage.
## Returns the new tree, or null if the cell is outside the grid or already taken.
func spawn_tree(cell: Vector2i, grown: bool) -> ForestTree:
	if not grid.in_bounds(cell) or grid.is_solid(cell) or _trees_by_cell.has(cell):
		return null
	var tree: ForestTree = TREE_SCENE.instantiate()
	tree.cell = cell
	tree.starts_grown = grown
	# A tree on a tap point is a tap tree; the patch is used up.
	if tap_points.has(cell):
		tree.is_tap = true
		tap_points.erase(cell)
		queue_redraw()  # the soil patch disappears from the floor
	# The Heart Tree's cell always grows the Heart Tree (also when a restarted
	# wave replants the forest from its snapshot).
	tree.is_heart = grown and cell == HEART_TREE_CELL and plant_heart_tree
	if tree.is_heart:
		heart_tree = tree
	tree.bonus_hp = tree_hp_bonus             # Hardwood upgrades
	tree.sapling_time_scale = sapling_time_scale  # Quick Roots upgrades
	tree.position = grid.cell_to_world(cell)
	tree.ready_to_solidify.connect(_on_tree_ready_to_solidify)
	tree.felled.connect(_on_tree_felled)
	tree.hurt.connect(_on_tree_hurt)
	_trees.add_child(tree)
	_trees_by_cell[cell] = tree
	if grown:
		grid.set_solid(cell, true)
	return tree


## Grows a bramble patch where a Bramble Seed lands. The landing point is kept
## on the floor (one cell in from the walls), so a throw at a wall lands at its
## foot. Connected to the player's bramble_thrown signal; public for the tests.
func spawn_bramble(at: Vector2) -> Bramble:
	var floor_rect := Rect2(grid.origin, Vector2(grid.cols, grid.rows) * float(CONFIG.cell_size)).grow(-float(CONFIG.cell_size))
	var bramble := Bramble.new()
	bramble.position = at.clamp(floor_rect.position, floor_rect.end)
	_brambles.add_child(bramble)
	return bramble


## The grown tree nearest to `point` within `reach` pixels, or null.
func _grown_tree_near(point: Vector2, reach: float) -> ForestTree:
	var best: ForestTree = null
	var best_distance: float = reach
	for tree: ForestTree in _trees_by_cell.values():
		if not is_instance_valid(tree) or tree.stage != ForestTree.Stage.GROWN:
			continue
		var distance: float = tree.global_position.distance_to(point)
		if distance <= best_distance:
			best = tree
			best_distance = distance
	return best


## The tree (sapling or grown) on a cell, or null if there is none.
func tree_at(cell: Vector2i) -> ForestTree:
	return _trees_by_cell.get(cell)


## Creates a Scrapper on a cell and points it at the player.
func spawn_scrapper_at(cell: Vector2i, heavy: bool = false) -> Scrapper:
	var scrapper: Scrapper = SCRAPPER_SCENE.instantiate()
	scrapper.heavy = heavy  # true = a Linebreaker
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
func spawn_spitter_at(cell: Vector2i, arc: bool = false) -> Spitter:
	var spitter: Spitter = SPITTER_SCENE.instantiate()
	spitter.arc = arc  # true = an Arc Spitter
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
	for folder: Node in [_enemies, _pods, _shots, _trees, _brambles]:
		for child: Node in folder.get_children():
			folder.remove_child(child)
			child.queue_free()
	for cell: Vector2i in _trees_by_cell.keys():
		grid.set_solid(cell, false)
	_trees_by_cell.clear()

	# Replant the forest from the snapshot taken at wave start.
	tap_points.clear()
	for cell: Vector2i in _forest_at_wave_start.keys():
		if _tap_trees_at_wave_start.has(cell):
			tap_points.append(cell)  # spawn_tree turns this back into a tap tree
		var replanted: ForestTree = spawn_tree(cell, _forest_at_wave_start[cell])
		if replanted != null and _great_trees_at_wave_start.has(cell):
			replanted.mature()

	var start_cell: Vector2i = _nearest_free_cell(PLAYER_START_CELL)
	if start_cell == ArenaGrid.NO_CELL:
		start_cell = PLAYER_START_CELL
	player.revive(grid.cell_to_world(start_cell))
	waves.restart_wave()


## How many windows are lit once `cleared` waves have been cleared. It climbs
## evenly from `windows_lit_at_start` to every window after the last wave, so
## after wave 8 of 10 the block is most of the way there, and wave 10 finishes it.
func lit_windows_after(cleared: int) -> int:
	var total: int = windows.window_count()
	var share: float = float(cleared) / float(maxi(1, waves.total_waves()))  # 0.0 to 1.0
	# roundi rounds to the nearest whole number and returns an int.
	return clampi(CONFIG.windows_lit_at_start + roundi(float(total - CONFIG.windows_lit_at_start) * share), 0, total)


## How strongly lit windows shine once `cleared` waves have been cleared.
func window_strength_after(cleared: int) -> float:
	var share: float = float(cleared) / float(maxi(1, waves.total_waves()))
	return lerpf(CONFIG.window_strength_at_start, 1.0, clampf(share, 0.0, 1.0))


## How bright the lot is overall, 0.0 (dark block) to 1.0 (every window on at
## full strength): the share of windows lit, times how strongly they shine.
func light_level() -> float:
	return float(windows.lit_count) / float(maxi(1, windows.window_count())) * windows.strength


## The tint the whole lot should have at light level `level` (0 to 1). The
## curve keeps it near the dark tint until late in the run, so the middle
## waves are lit by separate pools (windows, lanterns, trees), not by
## brightening everything at once.
func ambient_tint_for(level: float) -> Color:
	return CONFIG.ambient_dark.lerp(CONFIG.ambient_lit, pow(clampf(level, 0.0, 1.0), CONFIG.ambient_curve))


## How much the lights are boosted at light level `level`: the config's
## light_boost while the lot is dark, falling to 1.0 as the tint reaches lit.
func light_boost_for(level: float) -> float:
	var lit_share: float = pow(clampf(level, 0.0, 1.0), CONFIG.ambient_curve)
	return lerpf(CONFIG.light_boost, 1.0, lit_share)


## Tells the windows and lanterns what the waves cleared so far have earned.
func _update_light() -> void:
	windows.set_light(lit_windows_after(waves_cleared) + tap_bonus_windows(), window_strength_after(waves_cleared))
	lanterns.set_strings(Lanterns.strings_after(waves_cleared))


## Queues radio lines to play one after another, replacing whatever was on the
## air. Each line is {speaker, text}; see _radio_line.
func _show_story_lines(lines: Array[Dictionary]) -> void:
	_story_queue = lines.duplicate()
	_show_next_story_line()


## Adds lines to the END of the radio queue, without cutting off what is playing.
## Used for Canopy FM's tips, which react to things happening in the fight.
func _radio_later(lines: Array[Dictionary]) -> void:
	_story_queue.append_array(lines)
	if not radio.is_on():
		_show_next_story_line()


## Puts one line at the FRONT of the radio queue: it plays next (at once if the
## radio is quiet). For news that cannot wait, like the Heart Tree being cut.
func _radio_urgent(line: Dictionary) -> void:
	_story_queue.push_front(line)  # push_front adds at the start of an Array
	if not radio.is_on():
		_show_next_story_line()


## Signal handler: a grown tree was hurt but still stands. If it is the Heart
## Tree, Canopy FM raises the alarm (not more often than heart_alarm_cooldown).
func _on_tree_hurt(tree: ForestTree) -> void:
	if not tree.is_heart or _heart_alarm_left > 0.0:
		return
	_heart_alarm_left = CONFIG.heart_alarm_cooldown
	heart_alarms += 1
	_radio_urgent(_radio_line(Radio.CANOPY, CONFIG.heart_alarm_line))


## One radio line, as the queue wants it.
static func _radio_line(speaker: StringName, text: String) -> Dictionary:
	return {speaker = speaker, text = text}


## Canopy FM lines from the config, as radio lines.
static func _dj(texts: Array[String]) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for text: String in texts:
		lines.append(_radio_line(Radio.CANOPY, text))
	return lines


## Plays a Canopy FM tutorial moment once per run (and never in New Game +,
## where the player already knows the controls).
func _dj_once(moment: StringName, texts: Array[String]) -> void:
	if ng_plus or _dj_said.has(moment):
		return
	_dj_said[moment] = true
	_radio_later(_dj(texts))


## True when the player is on a touch screen (phone or tablet), so the tips name
## thumbs and taps instead of keys and clicks.
static func _is_touch() -> bool:
	return DisplayServer.is_touchscreen_available()


## Puts the next queued line on the radio, or takes the radio off the air when
## none are left. A line stays up for story_line_seconds after it finishes typing.
func _show_next_story_line() -> void:
	if _story_queue.is_empty():
		radio.clear()
		_story_time_left = 0.0
		return
	var line: Dictionary = _story_queue.pop_front()  # pop_front removes and returns the first entry
	radio.say(line.speaker, line.text)
	_story_time_left = CONFIG.story_line_seconds + float(line.text.length()) / CONFIG.radio_chars_per_second


## What Helios says as wave `number` starts, ready to show. Empty if the config
## has no line for that wave. Public so the tests can read it.
func helios_line_for(number: int) -> String:
	if number < 1 or number > CONFIG.helios_lines.size():
		return ""
	return CONFIG.helios_lines[number - 1]


## What Canopy FM says after Helios as wave `number` starts:
##   wave 1          how to move and shoot (or, in New Game +, what great
##                   sunroots can do);
##   cat-hint waves  a hint about the lucky cat, only while the shop is shut.
func dj_lines_for_wave(number: int) -> Array[String]:
	var lines: Array[String] = []
	if number == 2 and not ng_plus:
		lines.append_array(CONFIG.dj_bramble_touch if _is_touch() else CONFIG.dj_bramble)
	if number == 1:
		if ng_plus:
			lines.append_array(CONFIG.dj_ng_plus_intro)
		else:
			lines.append_array(CONFIG.dj_intro_touch if _is_touch() else CONFIG.dj_intro)
	var hint: int = CONFIG.dj_cat_hint_waves.find(number)
	if hint >= 0 and hint < CONFIG.dj_cat_hints.size() and cat_shop != null and not cat_shop.is_open:
		lines.append(CONFIG.dj_cat_hints[hint])
	return lines


## Signal handler: a wave began. Remember the forest, update the HUD.
func _on_wave_started(number: int, total: int) -> void:
	_forest_at_wave_start.clear()
	_tap_trees_at_wave_start.clear()
	_great_trees_at_wave_start.clear()
	for cell: Vector2i in _trees_by_cell.keys():
		_forest_at_wave_start[cell] = _trees_by_cell[cell].stage == ForestTree.Stage.GROWN
		if _trees_by_cell[cell].is_tap:
			_tap_trees_at_wave_start.append(cell)
		if _trees_by_cell[cell].is_great:
			_great_trees_at_wave_start.append(cell)
	_choose_tap_points(number)
	_show_banner("Wave %d" % number, 1.5)
	# By now the controls are learned; the bottom wall belongs to the windows.
	_hint.visible = number < CONFIG.hint_hide_wave
	# On the radio: Canopy FM's opening line (once only), then Helios's notice,
	# then whatever Canopy FM has to say about this wave (tips, cat hints).
	var lines: Array[Dictionary] = []
	if not _hook_shown:
		_hook_shown = true
		lines.append(_radio_line(Radio.CANOPY, CONFIG.story_hook))
	if helios_line_for(number) != "":
		lines.append(_radio_line(Radio.HELIOS, helios_line_for(number)))
	# Wave 1: point the Heart Tree out, in every run (Sasha forgot it existed).
	if number == 1 and is_instance_valid(heart_tree):
		lines.append(_radio_line(Radio.CANOPY, CONFIG.heart_intro_line))
	lines.append_array(_dj(dj_lines_for_wave(number)))
	_show_story_lines(lines)


## Signal handler: the director wants one machine sent in.
func _on_spawn_requested(kind: StringName, wave_number: int) -> void:
	var cell: Vector2i = _pick_spawn_cell()
	# STAGED WAVE 1: the Spitter arrives after the Scrapper has become a tree, and
	# walks in from behind that tree, so its first shot visibly stops on it.
	var is_staged: bool = wave_number <= waves.staged_wave_count()
	if is_staged and kind == WaveDirector.SPITTER and tree_at(_last_planted_cell) != null:
		cell = _pick_spawn_cell_behind(grid.cell_to_world(_last_planted_cell))
	if cell == ArenaGrid.NO_CELL:
		waves.enemy_gone()  # nowhere to put it: tell the director not to wait for it
		return
	if kind == WaveDirector.SAWBOT:
		spawn_sawbot_at(cell)
		_dj_once(&"sawbot", CONFIG.dj_first_sawbot)
	elif kind == WaveDirector.SPITTER or kind == WaveDirector.ARC_SPITTER:
		spawn_spitter_at(cell, kind == WaveDirector.ARC_SPITTER)
		if kind == WaveDirector.ARC_SPITTER:
			_dj_once(&"arc_spitter", CONFIG.dj_first_arc_spitter)
	else:
		var scrapper: Scrapper = spawn_scrapper_at(cell, kind == WaveDirector.LINEBREAKER)
		if kind == WaveDirector.LINEBREAKER:
			_dj_once(&"linebreaker", CONFIG.dj_first_linebreaker)
		# Faster every wave: wave 1 is 1.0, wave 2 is 1.12, wave 3 is 1.24, ...
		scrapper.speed_scale = 1.0 + CONFIG.scrapper_speed_gain_per_wave * (wave_number - 1)


## Signal handler: every machine of a wave is down.
func _on_wave_cleared(number: int) -> void:
	Sfx.play(&"wave_clear")
	_show_banner(wave_cleared_text(number), CONFIG.wave_break_time)
	# Between waves (not after the last one): deal the upgrade cards. The next
	# wave waits until one is picked.
	if number < waves.total_waves() and number >= CONFIG.upgrade_from_wave:
		waves.hold_break = true
		upgrade_picker.offer(CONFIG.upgrade_choices)
	# The Heart Tree heals between waves.
	if is_instance_valid(heart_tree):
		heart_tree.hp = heart_tree.max_hp()
		heart_tree.queue_redraw()
	# More of the block comes on, and every lit window shines a little stronger.
	waves_cleared = maxi(waves_cleared, number)
	_update_light()
	if ng_plus:
		mature_trees()
	# The Block answers Helios: one more painted line on the walls.
	graffiti.reveal_up_to(number)
	_show_story_lines([])  # clear any Helios line still showing


## The banner text for clearing wave `number`. The marker wave (halfway) adds
## a second line telling the player they can stop and rate now.
func wave_cleared_text(number: int) -> String:
	var text: String = "Wave %d cleared" % number
	if number == CONFIG.rate_marker_wave:
		text += "\nHalfway! Stop and rate here, or play on"
	if number == waves.total_waves():
		text += "\nThe whole block is lit"
	return text


## The end screen's banner text: the headline and the final score.
func end_banner_text() -> String:
	var unlocked: String = "\nNew Game + unlocked! " if RunState.just_unlocked else "\n"
	return "%s\nTrees standing: %d%sPress R or tap here for the title screen" % [CONFIG.end_headline, count_grown_trees(), unlocked]


## Signal handler: the last wave is cleared. Show the end screen over the forest.
func _on_all_waves_cleared() -> void:
	is_run_finished = true
	RunState.record_win()  # winning once unlocks New Game + (saved)
	Sfx.play(&"cat")
	# The arena is left exactly as it is: the end screen IS your forest.
	_show_banner(end_banner_text(), 0.0)
	windows.light_next_block()  # the light jumps the wall
	# Helios gets the last word, and it stays up with the banner.
	_story_queue.clear()
	radio.say(Radio.HELIOS, CONFIG.helios_end_line)
	_story_time_left = 0.0


## Signal handler: the third pod landed on the hidden shop and the cat is out.
func _on_cat_shop_opened() -> void:
	player.receive_cat_gift()
	lucky_found_wave = maxi(waves.wave, 1)

	_show_banner("Lucky's gift: right-click a machine to bind it. Spare fuse fitted.", 4.0)
	_show_story_lines([_lucky_says(LuckyLines.greeting_for(lucky_found_wave))])


## Seven talks to Lucky: the next small-talk line for the wave being played.
## Returns the line shown, or "" if the shop is still shut. Words only.
func talk_to_lucky() -> String:
	if cat_shop == null or not cat_shop.is_open:
		return ""
	var line: String = LuckyLines.small_talk_for(maxi(waves.wave, 1), _lucky_talks)
	_lucky_talks += 1
	_show_story_lines([_lucky_says(line)])
	Sfx.play(&"cat")
	return line


## True while Seven stands close enough to the open shop to talk with the E key.
func is_near_lucky() -> bool:
	if cat_shop == null or not cat_shop.is_open:
		return false
	return player.global_position.distance_to(cat_shop.global_position) <= CONFIG.lucky_talk_range_cells * CONFIG.cell_size


## How a line of Lucky's is shown under the banner.
func _lucky_says(line: String) -> Dictionary:
	return _radio_line(Radio.LUCKY, line)


## Signal handler: the spare fuse saved Seven from going down.
func _on_player_fuse_used() -> void:
	_show_banner("Fuse blown! Seven is back up", 2.0)


## Signal handler: the player finished a vine zip. The "you can vine to this"
## ring has done its job, so switch it off on every tree.
func _on_player_zip_finished() -> void:
	for tree: ForestTree in _trees_by_cell.values():
		tree.show_vine_hint = false
	_vine_hint_done = true
	var tree: ForestTree = player.zip_tree
	# TRELLIS: a zip that started beside another tree strings a vine between them.
	var from_tree: ForestTree = _grown_tree_near(player.zip_from, CONFIG.trellis_start_reach_cells * CONFIG.cell_size)
	if is_instance_valid(tree) and from_tree != null and from_tree != tree:
		great_powers.add_trellis(from_tree.global_position, tree.global_position)
	# A zip that ends at a great sunroot sets off its Sunburst.
	if is_instance_valid(tree) and tree.is_great and tree.stage == ForestTree.Stage.GROWN:
		if great_powers.sunburst(tree.global_position) > 0:
			_show_banner("Sunburst!", 1.0)


## _unhandled_input receives input that nothing else used. After the last wave,
## R / Enter, or a tap or click on the banner, starts a fresh run.
func _unhandled_input(event: InputEvent) -> void:
	# Talking to Lucky: the E key near the open shop, or a tap / click on it.
	if not is_run_finished and cat_shop != null and cat_shop.is_open:
		var wants_talk: bool = event.is_action_pressed(&"talk") and is_near_lucky()
		if event is InputEventScreenTouch and event.pressed:
			wants_talk = wants_talk or _is_on_shop((event as InputEventScreenTouch).position)
		if wants_talk:
			talk_to_lucky()
			get_viewport().set_input_as_handled()  # this press is used up
			return
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
		RunState.just_unlocked = false
		get_tree().change_scene_to_file(TITLE_SCENE)  # back to the title screen


## Signal handler: the player fired. Spawn the pod where the signal says.
func _on_player_seed_fired(origin: Vector2, direction: Vector2) -> void:
	var pod: SeedPod = SEED_POD_SCENE.instantiate()
	pod.position = origin
	pod.direction = direction
	pod.damage = CONFIG.seed_damage + seed_damage_bonus  # Heavy Seeds upgrades add to it
	_pods.add_child(pod)


## Applies upgrade `id` for the rest of the run, then lets the next wave come.
## Connected to the upgrade picker's `picked` signal; public so tests can call it.
func apply_upgrade(id: StringName) -> void:
	upgrades_taken.append(id)
	match id:
		&"seed_pouch":
			player.fire_cooldown_scale *= CONFIG.upgrade_fire_cooldown_factor
		&"heavy_seeds":
			seed_damage_bonus += CONFIG.upgrade_seed_damage
		&"thick_plating":
			player.max_hp += CONFIG.upgrade_max_hp
			player.heal(player.max_hp)  # a full repair (heal never goes over max_hp)
		&"hardwood":
			tree_hp_bonus += CONFIG.upgrade_tree_hp
			# Trees already standing get it too.
			for tree: ForestTree in _trees_by_cell.values():
				if is_instance_valid(tree):
					tree.bonus_hp = tree_hp_bonus
					tree.hp += CONFIG.upgrade_tree_hp
					tree.queue_redraw()
		&"quick_roots":
			sapling_time_scale *= CONFIG.upgrade_sapling_time_factor
		&"long_trellis":
			great_powers.trellis_bonus_seconds += CONFIG.upgrade_trellis_seconds
	_show_banner(UpgradePicker.CATALOG[id][0] + "!", 1.2)
	Sfx.play(&"grow")
	waves.hold_break = false


## The Heart Tree fell: the block's roots are cut, so the wave starts again (like
## Seven going down). The restart replants it from the wave-start snapshot.
func _on_heart_tree_felled() -> void:
	heart_tree = null
	if waves.wave == 0 or is_run_finished:
		return
	heart_tree_felled.emit()
	_show_banner("The Heart Tree fell! Wave %d starts again" % waves.wave, CONFIG.death_restart_delay)
	await get_tree().create_timer(CONFIG.death_restart_delay, false).timeout
	if not is_inside_tree():
		return
	_restart_current_wave()


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
		# The first machine to go down: Canopy FM explains cover and the vine.
		_dj_once(&"first_tree", CONFIG.dj_first_tree_touch if _is_touch() else CONFIG.dj_first_tree)
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
	if tree.is_tap:
		# A tap tree: Seven gets a pip back, and the block gets extra windows.
		player.heal(CONFIG.tap_tree_heal)
		_update_light()
	# Teach the vine once: the first tree the player grows pulses until they zip.
	if not _vine_hint_done and tree.cell == _last_planted_cell:
		tree.show_vine_hint = true


## Signal handler: a grown tree was destroyed. Open its cell up again.
func _on_tree_felled(tree: ForestTree) -> void:
	grid.set_solid(tree.cell, false)
	_trees_by_cell.erase(tree.cell)
	windows.flicker()  # the block feels it: one lit window drops dark for a moment
	CanopyFM.dull()    # and the radio dulls for a moment
	if tree.is_heart:
		_on_heart_tree_felled()
	if tree.is_tap:
		_update_light.call_deferred()  # its extra windows go out (once it is gone)


## True if screen point `screen_point` (as a touch reports it) lands on the cat
## shop. get_global_transform_with_canvas turns the shop's position into screen
## pixels, the same space touches use.
func _is_on_shop(screen_point: Vector2) -> bool:
	var centre: Vector2 = cat_shop.get_global_transform_with_canvas().origin
	var half := Vector2(CatShop.WIDTH_CELLS, 1.5) * float(CONFIG.cell_size) / 2.0
	return Rect2(centre - half, half * 2.0).has_point(screen_point)


## Extra windows lit by the tap trees standing right now (grown ones only).
func tap_bonus_windows() -> int:
	var count: int = 0
	for tree: ForestTree in _trees_by_cell.values():
		if is_instance_valid(tree) and tree.is_tap and tree.stage == ForestTree.Stage.GROWN and not tree.is_queued_for_deletion():
			count += 1
	return count * CONFIG.tap_tree_bonus_windows


## Picks this wave's tap points: random open floor cells, not hugging a wall,
## not under Seven, not on a tree. None before `tap_points_from_wave`.
func _choose_tap_points(wave_number: int) -> void:
	tap_points.clear()
	if wave_number >= CONFIG.tap_points_from_wave:
		var candidates: Array[Vector2i] = []
		var seven_cell: Vector2i = grid.world_to_cell(player.global_position)
		# Two cells in from every wall, so a patch is never tucked into a corner.
		for y: int in range(3, grid.rows - 3):
			for x: int in range(3, grid.cols - 3):
				var cell := Vector2i(x, y)
				if grid.is_solid(cell) or _trees_by_cell.has(cell) or cell == seven_cell:
					continue
				candidates.append(cell)
		candidates.shuffle()  # shuffle puts the list in a random order
		for i: int in mini(CONFIG.tap_points_per_wave, candidates.size()):
			tap_points.append(candidates[i])
	queue_redraw()  # redraw the floor with the new patches


## Switches this run to NEW GAME +: more machines, sent faster, no tutorial
## staging; and trees can mature into great sunroots (see mature_trees).
func apply_ng_plus() -> void:
	ng_plus = true
	waves.count_multiplier = CONFIG.ng_plus_count_multiplier
	waves.pace_multiplier = CONFIG.ng_plus_pace_multiplier
	waves.staged_waves = 0


## New Game +: every tree that was already grown when this wave started and is
## still standing now matures into a great sunroot (tree stage 4).
func mature_trees() -> void:
	for cell: Vector2i in _trees_by_cell.keys():
		var tree: ForestTree = _trees_by_cell[cell]
		if _forest_at_wave_start.get(cell, false) and tree.stage == ForestTree.Stage.GROWN and not tree.is_great:
			tree.mature()
