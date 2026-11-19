# check.gd - Seedshot's headless test runner (attached to tests/check.tscn).
# Run it from the project folder with the NON-mono Godot console build:
#   <Godot_v4.7.2-stable_win64_console.exe> --headless --path . res://tests/check.tscn
# It prints one line per failure, then "N passed, M failed", and exits with code 1
# if anything failed (so a script or CI job can tell).
extends Node
## Zero-dependency checks. No test addon: each _test_* function is a group of
## related assertions, and _check() counts passes and failures.

const CONFIG: GameConfig = preload("res://config/game_config.tres")
const ARENA_SCENE: PackedScene = preload("res://scenes/arena.tscn")

var _passed: int = 0
var _failed: int = 0
## The arena under test. Rebuilt fresh for each scene-level test.
var _arena: Arena


## _ready runs once when the test scene starts: run every group, report, quit.
## Functions that use `await` pause until something happens (a physics step, a
## signal), so the scene tests can let the game run for a moment between checks.
func _ready() -> void:
	# Layer 1: pure logic, no scene needed.
	_test_grid_coordinates()
	_test_grid_walls_and_paths()
	_test_seal_guard()
	_test_split_guard()
	_test_input_actions_exist()
	_test_art_is_the_right_size()
	_test_every_sound_is_a_real_file()

	# Layer 2: the real arena scene, driven through its public methods. (Headless
	# Godot drops simulated mouse/keyboard input, so we call fire() and try_vine()
	# directly instead of faking clicks.)
	# NOTE: tests cannot change config numbers. Writing to the shared config from
	# here was tried and had no effect (CONFIG is a preloaded constant). Where a
	# test needs things to happen sooner, it uses a knob on the node instead,
	# such as WaveDirector.time_scale.
	# `await` on a function call means: start it, and continue here only once it
	# has completely finished (including all of its own awaits).
	await _test_arena_boots()
	await _test_player_walks_and_stops_at_walls()
	await _test_pod_stops_on_tree()
	await _test_vine_on_empty_space_does_nothing()
	await _test_vine_zips_one_cell_short()
	await _test_scrapper_walks_to_player()
	await _test_kill_becomes_sapling_then_tree()
	await _test_felled_tree_clears_its_cell()

	# Layer 2b: touch controls. Headless Godot has no touchscreen, so these call
	# the touch layer's public touch_down / touch_moved / touch_up directly, which
	# is exactly what its _input does with real finger events.
	await _test_touch_move_stick_walks()
	await _test_touch_aim_stick_fires()
	await _test_touch_tap_on_tree_zips()
	await _test_touch_tap_rules()

	# Layer 2c: player health and the Scrapper's melee swing.
	await _test_player_health_and_blink()
	await _test_scrapper_swing_lands_after_windup()
	await _test_scrapper_swing_misses_if_you_leave()
	await _test_player_goes_down()

	# Layer 2d: fixes from the first phone playtest (2026-11-14).
	await _test_sapling_never_walls_the_floor_in_two()
	await _test_pause_freezes_the_game()
	await _test_mute_and_rate_marker()

	# Layer 2e: the Sawbot and the waves.
	await _test_sawbot_fells_a_tree_and_ignores_the_player()
	await _test_sawbot_takes_three_pods_and_becomes_a_tree()
	await _test_wave_director_counts_and_advances()
	await _test_wave_three_sends_faster_scrappers_and_a_sawbot()
	await _test_going_down_restarts_the_wave_with_its_forest()

	# Layer 2f: the Spitter and its shots.
	await _test_spitter_warns_then_hits_the_player()
	await _test_tree_stops_a_spit_shot()
	await _test_spitter_keeps_its_distance()
	await _test_spitter_closes_in_when_it_cannot_see_you()

	# Layer 2g: the vine's second use, yank and bind.
	await _test_vine_yanks_and_binds_a_machine()
	await _test_vine_bind_needs_a_clear_line()
	await _test_touch_tap_on_a_machine_binds_it()

	# Layer 2h: the hidden lucky cat, the staged first wave, the end of a run.
	await _test_three_pods_open_the_cat_shop()
	await _test_staged_wave_one_teaches_cover_and_the_vine()
	await _test_clearing_the_last_wave_ends_the_run()

	# Layer 2i: the story words (STORY.md step 1).
	await _test_story_words()
	# Layer 2j: the night look and the windows (STORY.md step 2).
	await _test_windows_and_night()
	await _test_tree_pictures()
	await _test_spare_fuse()
	await _test_talking_to_lucky()
	await _test_canopy_fm()

	print("%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


## Records one assertion. Prints only when it fails.
func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: " + message)


## Throws away the old arena (if any) and starts a fresh one with no enemies.
func _fresh_arena() -> void:
	if _arena != null:
		_arena.queue_free()
		await get_tree().physics_frame
	_arena = ARENA_SCENE.instantiate()
	# Switch the waves off BEFORE the arena enters the scene (its _ready reads
	# this), so each test controls exactly which enemies exist.
	_arena.autostart_waves = false
	add_child(_arena)
	# Give the physics engine two steps to register the new bodies.
	await get_tree().physics_frame
	await get_tree().physics_frame


## Lets the game run until `condition` returns true or `max_seconds` pass.
## Returns true if the condition was met. (A Callable is a function passed as a value.)
func _wait_until(condition: Callable, max_seconds: float) -> bool:
	var frames_left: int = int(max_seconds * 60.0)
	while frames_left > 0:
		if condition.call():
			return true
		await get_tree().physics_frame
		frames_left -= 1
	return condition.call()


## Layer 3a: the Klad art. Every sprite must be 64 x 64 and the floor slab one
## cell big, or the game would stretch pixels and the slab would not line up
## with the grid. Reading the config here is fine; only WRITING to it is ignored.
func _test_art_is_the_right_size() -> void:
	var sprites: Dictionary[String, Texture2D] = {
		"player": CONFIG.player_texture,
		"scrapper": CONFIG.scrapper_texture,
		"sawbot": CONFIG.sawbot_texture,
		"spitter": CONFIG.spitter_texture,
		"cat": CONFIG.cat_texture,
	}
	for sprite_name: String in sprites:
		var texture: Texture2D = sprites[sprite_name]
		_check(texture != null and texture.get_size() == Vector2(64.0, 64.0), "the %s sprite is 64 x 64" % sprite_name)
	# The floor tiles are one row of cell-sized squares: one cell tall, a whole
	# number of cells wide, with at least one detail tile after the plain ones.
	var tiles: Texture2D = CONFIG.floor_tiles
	_check(tiles != null and tiles.get_height() == CONFIG.cell_size, "the floor tiles are one cell tall")
	if tiles != null:
		var tile_count: int = tiles.get_width() / CONFIG.cell_size
		_check(tiles.get_width() % CONFIG.cell_size == 0, "the floor row is a whole number of tiles")
		_check(CONFIG.floor_plain_count > 0 and CONFIG.floor_plain_count < tile_count, "there are plain and detail floor tiles")
		# Every cell of the arena picks a tile that exists, and the same cell
		# always picks the same tile (so the floor does not shuffle each frame).
		var all_in_range: bool = true
		var details: int = 0
		var cells: int = 0
		for y: int in 15:
			for x: int in 26:
				var pick: int = Arena.floor_tile_for(Vector2i(x, y), tile_count, CONFIG.floor_plain_count, CONFIG.floor_detail_chance)
				all_in_range = all_in_range and pick >= 0 and pick < tile_count
				if pick >= CONFIG.floor_plain_count:
					details += 1
				cells += 1
		_check(all_in_range, "every floor cell picks a real tile")
		_check(Arena.floor_tile_for(Vector2i(5, 7), tile_count, 4, 0.1) == Arena.floor_tile_for(Vector2i(5, 7), tile_count, 4, 0.1),
			"a cell always picks the same floor tile")
		# The floor has 24 x 13 = 312 open cells; at about 1 in 14, roughly 22 details.
		# Allow a wide margin: this only catches "none" or "nearly all".
		var share: float = float(details) / float(cells)
		_check(share > CONFIG.floor_detail_chance * 0.4 and share < CONFIG.floor_detail_chance * 2.0,
			"detail tiles are rare but present (%d of %d cells)" % [details, cells])
	# 1.3333 x 48 is 63.998, not exactly 64, so allow a tenth of a pixel of slack.
	# absf() gives the size of a number without its sign.
	_check(absf(CONFIG.sprite_size_cells * CONFIG.cell_size - 64.0) < 0.1, "sprites are drawn at their real size")


## Layer 3b: the ElevenLabs sounds. Every sound name the game plays must come
## from a real file in audio/sfx, not from a generated beep. AudioStreamMP3 is
## the type Godot gives an imported .mp3; the beeps are AudioStreamWAV.
func _test_every_sound_is_a_real_file() -> void:
	var names: Array[StringName] = [&"unlock", &"fire", &"thunk", &"enemy_down", &"zip", &"grow",
		&"windup", &"hurt", &"player_down", &"saw", &"cat", &"bind", &"spit", &"wave_clear"]
	for sound_name: StringName in names:
		_check(Sfx.stream_for(sound_name) is AudioStreamMP3, "the '%s' sound is a real file" % sound_name)


## s11: the mute switch (M key and the speaker button) and the halfway
## "stop and rate" line on the wave-cleared banner.
func _test_mute_and_rate_marker() -> void:
	_check(InputMap.has_action(&"mute"), "the 'mute' action exists")

	# The switch itself: bus 0 is the Master bus every sound goes through.
	Sfx.set_muted(true)
	_check(AudioServer.is_bus_mute(0), "set_muted(true) silences the Master bus")
	Sfx.set_muted(false)
	_check(not AudioServer.is_bus_mute(0), "set_muted(false) brings the sound back")

	# The M key: send a pretend key press through the game's normal input path.
	var press := InputEventAction.new()
	press.action = &"mute"
	press.pressed = true
	Sfx._unhandled_key_input(press)
	_check(Sfx.is_muted, "pressing the mute key switches sound off")
	Sfx._unhandled_key_input(press)
	_check(not Sfx.is_muted, "pressing it again switches sound back on")

	# The speaker button: a click inside its area mutes; it does not pause.
	await _fresh_arena()
	var pause: PauseOverlay = _arena.get_node("Hud/PauseOverlay") as PauseOverlay
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = pause.mute_button_rect().get_center()
	pause._input(click)
	_check(Sfx.is_muted, "clicking the speaker button mutes")
	_check(not get_tree().paused, "clicking the speaker button does not pause")
	pause._input(click)
	_check(not Sfx.is_muted, "clicking it again un-mutes")

	# The halfway marker: only the marker wave gets the extra line.
	var marker: int = CONFIG.rate_marker_wave
	_check(_arena.wave_cleared_text(marker).contains("rate"), "the marker wave's banner says to stop and rate")
	_check(not _arena.wave_cleared_text(marker - 1).contains("rate"), "other waves' banners do not")


## Every action name the scripts rely on must exist in Project Settings > Input Map.
func _test_input_actions_exist() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"fire", &"vine", &"pause"]:
		_check(InputMap.has_action(action), "input action '%s' exists" % action)


## Kickoff steps 1-3: the arena starts with a player and three solid trees, and
## wave 1 begins by itself with its single "teaching" Scrapper.
func _test_arena_boots() -> void:
	_arena = ARENA_SCENE.instantiate()
	add_child(_arena)
	_arena.waves.time_scale = 20.0  # run the wave timetable 20x faster for the test
	await get_tree().physics_frame
	_check(_arena.player != null, "arena has a player")
	_check(_arena.waves.wave == 1, "wave 1 starts by itself")
	var one_enemy: Callable = func() -> bool: return get_tree().get_nodes_in_group(Enemy.GROUP).size() == 1
	_check(await _wait_until(one_enemy, 1.0), "wave 1 sends one machine in")
	await _wait_frames(20)
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enemy.GROUP)
	_check(enemies.size() == 1 and enemies[0] is Scrapper, "and it is a single Scrapper, nothing more")
	for cell: Vector2i in Arena.TEST_TREE_CELLS:
		var tree: ForestTree = _arena.tree_at(cell)
		_check(tree != null and tree.stage == ForestTree.Stage.GROWN, "test tree at %s is grown" % cell)
		_check(_arena.grid.is_solid(cell), "test tree cell %s is solid in the grid" % cell)


## Kickoff step 2: holding a move action walks the player; walls stop it.
## Input.action_press() switches an action on from code, as if the key were held.
## That works headless, unlike simulated key events.
func _test_player_walks_and_stops_at_walls() -> void:
	await _fresh_arena()
	var start: Vector2 = _arena.player.global_position
	Input.action_press(&"move_right")
	for i: int in 30:  # half a second of physics steps
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	var walked: float = _arena.player.global_position.x - start.x
	var expected: float = CONFIG.player_speed * 0.5
	_check(absf(walked - expected) < 20.0, "half a second of 'move_right' walks about %d px (got %.0f)" % [expected, walked])

	# Now walk left for long enough to cross the whole arena: the wall must stop us.
	Input.action_press(&"move_left")
	var hit_wall: Callable = func() -> bool: return _arena.player.get_slide_collision_count() > 0
	_check(await _wait_until(hit_wall, 6.0), "walking left eventually touches the wall")
	Input.action_release(&"move_left")
	var cell: Vector2i = _arena.grid.world_to_cell(_arena.player.global_position)
	_check(cell.x == 1, "the wall stops the player in the first floor column (cell x = %d)" % cell.x)


## Kickoff step 3: a seed pod fired at a tree stops on it and does not pass through.
func _test_pod_stops_on_tree() -> void:
	await _fresh_arena()
	var tree_cell: Vector2i = Arena.TEST_TREE_CELLS[0]
	var tree_x: float = _arena.grid.cell_to_world(tree_cell).x
	_arena.player.global_position = _arena.grid.cell_to_world(tree_cell + Vector2i(-4, 0))
	_check(_arena.player.fire(Vector2.RIGHT), "player fires a pod")
	await get_tree().physics_frame

	var pods: Node = _arena.get_node("Pods")
	_check(pods.get_child_count() == 1, "one pod exists after firing")
	# Track how far right the pod ever gets while it is alive. The array is a
	# one-item box so the lambda below can update the number it holds.
	var furthest_x: Array[float] = [0.0]
	var pod_gone: Callable = func() -> bool:
		if pods.get_child_count() == 0:
			return true
		furthest_x[0] = maxf(furthest_x[0], (pods.get_child(0) as Node2D).global_position.x)
		return false
	_check(await _wait_until(pod_gone, 1.0), "pod is removed after hitting the tree")
	_check(furthest_x[0] < tree_x, "pod never got past the tree's centre")
	_check(_arena.tree_at(tree_cell) != null, "tree is still standing")


## Kickoff step 4: right click on empty space does nothing.
func _test_vine_on_empty_space_does_nothing() -> void:
	await _fresh_arena()
	var before: Vector2 = _arena.player.global_position
	var empty_point: Vector2 = _arena.grid.cell_to_world(Vector2i(3, 12))
	_check(not _arena.player.try_vine(empty_point), "vine on empty floor is refused")
	await get_tree().physics_frame
	_check(_arena.player.global_position == before, "player did not move")
	_check(not _arena.player.is_zipping, "player is not zipping")


## Kickoff step 4: right click on a tree zips in a straight line, one cell short.
func _test_vine_zips_one_cell_short() -> void:
	await _fresh_arena()
	var tree_cell: Vector2i = Arena.TEST_TREE_CELLS[0]
	var tree_position: Vector2 = _arena.grid.cell_to_world(tree_cell)
	var start: Vector2 = _arena.grid.cell_to_world(tree_cell + Vector2i(-6, 0))
	_arena.player.global_position = start
	await get_tree().physics_frame

	_check(_arena.player.try_vine(tree_position), "vine latches onto the tree")
	_check(_arena.player.is_zipping, "player is zipping")
	_check(await _wait_until(func() -> bool: return not _arena.player.is_zipping, 2.0), "zip finishes")
	var end: Vector2 = _arena.player.global_position
	var gap: float = end.distance_to(tree_position)
	_check(absf(gap - float(CONFIG.cell_size)) < 2.0, "zip stops one cell from the tree (gap %.1f px)" % gap)
	_check(absf(end.y - start.y) < 0.5, "zip travelled in a straight line")
	_check(not _arena.player.try_vine(tree_position), "a second vine right away is refused (cooldown / already there)")


## Kickoff step 5: the Scrapper paths around trees and closes in on the player.
func _test_scrapper_walks_to_player() -> void:
	await _fresh_arena()
	# Player on the far side of a test tree, so a straight line would be blocked.
	var tree_cell: Vector2i = Arena.TEST_TREE_CELLS[0]
	_arena.player.global_position = _arena.grid.cell_to_world(tree_cell + Vector2i(-2, 0))
	var scrapper: Scrapper = _arena.spawn_scrapper_at(tree_cell + Vector2i(3, 0))
	var distance_before: float = scrapper.global_position.distance_to(_arena.player.global_position)
	var stop_distance: float = CONFIG.scrapper_stop_distance_cells * CONFIG.cell_size
	var arrived: Callable = func() -> bool:
		return scrapper.global_position.distance_to(_arena.player.global_position) <= stop_distance + 1.0
	_check(await _wait_until(arrived, 6.0), "Scrapper reaches the player around the tree")
	var distance_after: float = scrapper.global_position.distance_to(_arena.player.global_position)
	_check(distance_after < distance_before, "Scrapper got closer")
	_check(not _arena.grid.is_solid(_arena.grid.world_to_cell(scrapper.global_position)), "Scrapper is not inside a solid cell")


## Kickoff step 5: one pod kills the Scrapper; it becomes a sapling (not solid),
## then about a second later a solid tree whose grid cell is marked solid.
func _test_kill_becomes_sapling_then_tree() -> void:
	await _fresh_arena()
	var player_cell := Vector2i(5, 11)
	_arena.player.global_position = _arena.grid.cell_to_world(player_cell)
	var scrapper: Scrapper = _arena.spawn_scrapper_at(player_cell + Vector2i(6, 0))
	await get_tree().physics_frame
	_check(_arena.player.fire(Vector2.RIGHT), "player fires at the Scrapper")

	# Listen for the Scrapper's own `died` signal and note where it fell. connect()
	# with a lambda (an unnamed inline function) is handy for one-off listeners.
	# The array is a one-item box the lambda can write into.
	var fell_at: Array[Vector2] = []
	scrapper.died.connect(func(dead: Scrapper) -> void: fell_at.append(dead.global_position))
	_check(await _wait_until(func() -> bool: return not fell_at.is_empty(), 2.0), "Scrapper dies to one pod")
	if fell_at.is_empty():
		return
	# The sapling is planted at the end of the frame (deferred), so wait one step.
	await get_tree().physics_frame

	var fall_cell: Vector2i = _arena.grid.world_to_cell(fell_at[0])
	var sapling: ForestTree = _arena.tree_at(fall_cell)
	_check(sapling != null, "a tree node appears where the Scrapper fell")
	if sapling == null:
		return
	_check(sapling.stage == ForestTree.Stage.SAPLING, "it starts as a sapling")
	_check(not _arena.grid.is_solid(fall_cell), "a sapling's cell is not solid yet")

	var grown: Callable = func() -> bool: return sapling.stage == ForestTree.Stage.GROWN
	_check(await _wait_until(grown, CONFIG.sapling_time + 1.0), "the sapling grows into a tree")
	_check(_arena.grid.is_solid(fall_cell), "the grown tree's cell is solid in the grid")

	# And the new tree is real cover: a pod fired at it stops.
	await _wait_until(func() -> bool: return _arena.player.fire(Vector2.RIGHT), 1.0)
	var pods: Node = _arena.get_node("Pods")
	var pod_gone: Callable = func() -> bool: return pods.get_child_count() == 0
	_check(await _wait_until(pod_gone, 1.0), "a pod stops on the newly grown tree")


## Trees have HP; a felled tree opens its grid cell again.
func _test_felled_tree_clears_its_cell() -> void:
	await _fresh_arena()
	var cell: Vector2i = Arena.TEST_TREE_CELLS[1]
	var tree: ForestTree = _arena.tree_at(cell)
	tree.take_damage(CONFIG.tree_hp - 1)
	_check(_arena.tree_at(cell) != null, "tree survives damage below its HP")
	tree.take_damage(1)
	_check(_arena.tree_at(cell) == null, "tree is removed at 0 HP")
	_check(not _arena.grid.is_solid(cell), "its grid cell is clear again")


## Fetches the touch layer of the current arena.
func _touch_controls() -> TouchControls:
	return _arena.get_node("Hud/TouchControls") as TouchControls


## Lets the game run for a number of physics steps (60 steps = one second).
func _wait_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


## Touch: a thumb sliding on the left half walks the bot, at full speed, and
## lifting the thumb stops it.
func _test_touch_move_stick_walks() -> void:
	await _fresh_arena()
	var touch: TouchControls = _touch_controls()
	var start: Vector2 = _arena.player.global_position
	var thumb := Vector2(200.0, 500.0)  # left half of the 1280 px wide screen

	touch.touch_down(0, thumb)
	_check(touch.touch_mode and _arena.player.touch_mode, "first touch switches touch mode on")
	touch.touch_moved(0, thumb + Vector2(60.0, 0.0))
	await _wait_frames(30)
	var walked: float = _arena.player.global_position.x - start.x
	var expected: float = CONFIG.player_speed * 0.5
	_check(absf(walked - expected) < 20.0, "move stick pushed right walks about %d px (got %.0f)" % [expected, walked])
	_check(absf(_arena.player.global_position.y - start.y) < 1.0, "and does not drift up or down")

	touch.touch_up(0)
	_check(not Input.is_action_pressed(&"move_right"), "lifting the thumb releases the move action")
	var stopped_at: Vector2 = _arena.player.global_position
	await _wait_frames(10)
	_check(_arena.player.global_position == stopped_at, "the bot stops when the thumb lifts")

	# A thumb that slides only a little (finger wobble) must not move the bot.
	touch.touch_down(0, thumb)
	touch.touch_moved(0, thumb + Vector2(CONFIG.touch_drag_threshold * 0.5, 0.0))
	await _wait_frames(10)
	_check(_arena.player.global_position == stopped_at, "a tiny slide is ignored")
	touch.touch_up(0)


## Touch: a thumb sliding on the right half aims the bot and fires while held.
func _test_touch_aim_stick_fires() -> void:
	await _fresh_arena()
	var touch: TouchControls = _touch_controls()
	var pods: Node = _arena.get_node("Pods")
	var thumb := Vector2(1100.0, 500.0)  # right half

	touch.touch_down(1, thumb)
	await _wait_frames(5)
	_check(pods.get_child_count() == 0, "just resting a thumb on the right half does not fire")

	touch.touch_moved(1, thumb + Vector2(0.0, -60.0))  # slide up
	_check(_arena.player.aim_direction.is_equal_approx(Vector2.UP), "aim stick pushed up aims up")
	await _wait_frames(3)
	_check(pods.get_child_count() >= 1, "holding the aim stick fires a pod")
	if pods.get_child_count() >= 1:
		_check((pods.get_child(0) as SeedPod).direction.is_equal_approx(Vector2.UP), "the pod flies the way the stick points")

	touch.touch_up(1)
	_check(not _arena.player.touch_fire_held, "lifting the thumb stops firing")
	_check(_arena.player.aim_direction.is_equal_approx(Vector2.UP), "the bot keeps facing where it last aimed")
	# Wait for the pods in flight to hit the wall, then make sure no new ones appear.
	await _wait_until(func() -> bool: return pods.get_child_count() == 0, 2.0)
	await _wait_frames(20)
	_check(pods.get_child_count() == 0, "no more pods after the thumb lifts")


## Touch: a quick tap on a tree is the vine, and it obeys the same rules as right
## click (straight line, one cell short).
func _test_touch_tap_on_tree_zips() -> void:
	await _fresh_arena()
	var touch: TouchControls = _touch_controls()
	var tree_cell: Vector2i = Arena.TEST_TREE_CELLS[0]
	var tree_position: Vector2 = _arena.grid.cell_to_world(tree_cell)
	_arena.player.global_position = _arena.grid.cell_to_world(tree_cell + Vector2i(-6, 0))
	await get_tree().physics_frame

	# Tap a full cell off-centre: a miss for the mouse (0.9 cells), a hit for a finger.
	var sloppy_tap: Vector2 = tree_position + Vector2(0.0, float(CONFIG.cell_size))
	touch.touch_down(0, sloppy_tap)
	await _wait_frames(3)
	touch.touch_up(0)
	_check(_arena.player.is_zipping, "a tap near a tree starts a vine zip")
	_check(await _wait_until(func() -> bool: return not _arena.player.is_zipping, 2.0), "the zip finishes")
	var gap: float = _arena.player.global_position.distance_to(tree_position)
	_check(absf(gap - float(CONFIG.cell_size)) < 2.0, "the tap zip also stops one cell short (gap %.1f px)" % gap)
	_check(_arena.get_node("Pods").get_child_count() == 0, "a tap does not fire a pod")


## Touch: what must NOT trigger the vine - a tap on empty floor, a long press on a
## tree, and a thumb that is already being used as a stick.
func _test_touch_tap_rules() -> void:
	await _fresh_arena()
	var touch: TouchControls = _touch_controls()
	var tree_cell: Vector2i = Arena.TEST_TREE_CELLS[0]
	var tree_position: Vector2 = _arena.grid.cell_to_world(tree_cell)
	_arena.player.global_position = _arena.grid.cell_to_world(tree_cell + Vector2i(-6, 0))
	await get_tree().physics_frame
	var before: Vector2 = _arena.player.global_position

	touch.touch_down(0, _arena.grid.cell_to_world(Vector2i(3, 12)))
	await _wait_frames(3)
	touch.touch_up(0)
	_check(not _arena.player.is_zipping, "a tap on empty floor does nothing")

	touch.touch_down(0, tree_position)
	await _wait_frames(int(CONFIG.touch_tap_max_time * 60.0) + 12)
	touch.touch_up(0)
	_check(not _arena.player.is_zipping, "a long press on a tree is not a tap")

	# Start on the tree, slide away (it becomes the aim stick: the tree is on the
	# right half), then lift quickly. That was aiming, not a tap.
	touch.touch_down(0, tree_position)
	touch.touch_moved(0, tree_position + Vector2(50.0, 0.0))
	touch.touch_up(0)
	_check(not _arena.player.is_zipping, "a slide that starts on a tree is not a tap")
	_check(_arena.player.global_position == before, "the bot never moved")


## Health: a hit costs a hit point, the HUD pips follow, and the bot cannot be
## hurt again while it is still blinking from the last hit.
func _test_player_health_and_blink() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	var pips: HealthPips = _arena.get_node("Hud/HealthPips") as HealthPips
	var full: int = CONFIG.player_max_hp
	_check(player.hp == full, "the bot starts with full health (%d)" % full)
	_check(pips.current == full and pips.maximum == full, "the HUD pips start full")

	# take_damage returns true when the hit counted, false when it was ignored.
	# The pips are never told directly: the arena connected the player's
	# health_changed signal to them with connect(), so they update by themselves.
	_check(player.take_damage(1), "a hit counts")
	_check(player.hp == full - 1, "a hit costs one hit point")
	_check(pips.current == full - 1, "the HUD pips follow the health")
	_check(not player.take_damage(1), "a second hit straight away is ignored (still blinking)")
	_check(player.hp == full - 1, "and costs nothing")

	await _wait_frames(int(CONFIG.player_hit_invulnerable_time * 60.0) + 3)
	_check(player.modulate == Color.WHITE, "the blink ends and the bot is fully visible again")
	_check(player.take_damage(1), "after the blink, hits count again")


## Melee: a Scrapper next to the bot glows first (the warning), and only then does
## the hit land.
func _test_scrapper_swing_lands_after_windup() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	player.global_position = _arena.grid.cell_to_world(Vector2i(5, 11))
	var scrapper: Scrapper = _arena.spawn_scrapper_at(Vector2i(8, 11))
	# Put it just inside swing range (the range is a config number, in cells).
	var reach: float = CONFIG.scrapper_melee_range_cells * CONFIG.cell_size
	scrapper.global_position = player.global_position + Vector2(reach * 0.9, 0.0)

	await _wait_frames(3)
	_check(scrapper.is_winding_up, "a Scrapper in range starts its windup")
	_check(player.hp == CONFIG.player_max_hp, "the windup itself does no damage")

	var was_hit: Callable = func() -> bool: return player.hp < CONFIG.player_max_hp
	_check(await _wait_until(was_hit, CONFIG.scrapper_melee_windup + 0.5), "the swing lands when the windup ends")
	_check(player.hp == CONFIG.player_max_hp - CONFIG.scrapper_melee_damage, "it costs exactly the melee damage")
	_check(not scrapper.is_winding_up, "the Scrapper rests after the swing (cooldown)")


## Melee: leave the Scrapper's reach during the warning and the swing misses.
func _test_scrapper_swing_misses_if_you_leave() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	player.global_position = _arena.grid.cell_to_world(Vector2i(5, 11))
	var scrapper: Scrapper = _arena.spawn_scrapper_at(Vector2i(8, 11))
	var reach: float = CONFIG.scrapper_melee_range_cells * CONFIG.cell_size
	scrapper.global_position = player.global_position + Vector2(reach * 0.9, 0.0)
	await _wait_frames(3)
	_check(scrapper.is_winding_up, "the windup has started")

	# Step well out of reach (as a vine zip would) while it is still glowing.
	player.global_position = _arena.grid.cell_to_world(Vector2i(5, 3))
	await _wait_frames(int(CONFIG.scrapper_melee_windup * 60.0) + 15)
	_check(not scrapper.is_winding_up, "the windup is over")
	_check(player.hp == CONFIG.player_max_hp, "the swing missed: no damage")


## Death: at zero health the bot is down, can do nothing, and the arena is told.
func _test_player_goes_down() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	# One-item-box trick again: the lambda appends, so the test can count calls.
	var defeats: Array[bool] = []
	_arena.player_defeated.connect(func() -> void: defeats.append(true))

	_check(player.take_damage(CONFIG.player_max_hp), "a hit for all remaining health counts")
	# The arena waits death_restart_delay and then reloads the scene, but only when
	# it IS the running scene. Here it is a child of this test scene, so no reload.
	_check(player.hp == 0 and player.is_dead, "the bot is down at zero health")
	_check(defeats.size() == 1, "the arena announces the defeat exactly once")
	_check(not player.take_damage(1), "a downed bot cannot be hit again")
	_check(not player.fire(Vector2.RIGHT), "a downed bot cannot fire")
	_check(not player.try_vine(_arena.grid.cell_to_world(Arena.TEST_TREE_CELLS[0])), "or use the vine")

	var fell_at: Vector2 = player.global_position
	Input.action_press(&"move_right")
	await _wait_frames(10)
	Input.action_release(&"move_right")
	_check(player.global_position == fell_at, "or walk")


## Playtest fix: a sapling that would cut the floor in two never turns solid, so
## an enemy on the far side can always still walk to the player.
func _test_sapling_never_walls_the_floor_in_two() -> void:
	await _fresh_arena()
	# Build a wall of grown trees down one column, top to bottom, with one gap.
	var wall_x: int = 20
	var gap := Vector2i(wall_x, 7)
	for y: int in range(1, CONFIG.grid_rows - 1):  # every floor row (not the wall ring)
		if y != gap.y:
			_arena.spawn_tree(Vector2i(wall_x, y), true)
	# Now a machine "dies" in the gap: plant a sapling there and let its timer run.
	var sapling: ForestTree = _arena.spawn_tree(gap, false)
	_check(sapling != null, "a sapling is planted in the last gap")
	if sapling == null:
		return
	await _wait_frames(int((CONFIG.sapling_time + 0.5) * 60.0))
	_check(sapling.stage == ForestTree.Stage.SAPLING, "it stays a sapling: growing would cut the arena in two")
	_check(not _arena.grid.is_solid(gap), "so the gap stays open")
	var player_cell: Vector2i = _arena.grid.world_to_cell(_arena.player.global_position)
	_check(_arena.grid.has_path(Vector2i(wall_x + 2, 7), player_cell), "an enemy on the far side can still reach the player")

	# A sapling somewhere harmless still grows as normal.
	var harmless: ForestTree = _arena.spawn_tree(Vector2i(3, 3), false)
	var grown: Callable = func() -> bool: return harmless.stage == ForestTree.Stage.GROWN
	_check(await _wait_until(grown, CONFIG.sapling_time + 1.0), "a sapling in open floor still becomes a tree")


## Playtest fix: pausing freezes the bot, un-pausing lets it move again.
func _test_pause_freezes_the_game() -> void:
	await _fresh_arena()
	var pause: PauseOverlay = _arena.get_node("Hud/PauseOverlay") as PauseOverlay
	var player: Player = _arena.player
	var start: Vector2 = player.global_position

	pause.set_paused(true)
	_check(get_tree().paused, "set_paused(true) pauses the game")
	Input.action_press(&"move_right")
	# This test keeps running while paused because `await` on a SceneTree signal
	# is not something the pause can freeze; only node callbacks are frozen.
	await _wait_frames(15)
	_check(player.global_position == start, "the bot does not move while paused")

	pause.set_paused(false)
	_check(not get_tree().paused, "set_paused(false) carries on")
	await _wait_frames(15)
	Input.action_release(&"move_right")
	_check(player.global_position.x > start.x + 10.0, "the bot moves again after un-pausing")


## Sawbot: it walks to the nearest tree, saws it down bite by bite, and never
## touches the player.
func _test_sawbot_fells_a_tree_and_ignores_the_player() -> void:
	await _fresh_arena()
	var tree_cell: Vector2i = Arena.TEST_TREE_CELLS[1]
	var tree: ForestTree = _arena.tree_at(tree_cell)
	# Park the player right beside where the Sawbot starts: it must not care.
	_arena.player.global_position = _arena.grid.cell_to_world(tree_cell + Vector2i(4, 1))
	var sawbot: Sawbot = _arena.spawn_sawbot_at(tree_cell + Vector2i(3, 0))

	_check(await _wait_until(func() -> bool: return sawbot.is_sawing, 4.0), "the Sawbot walks to the nearest tree and starts sawing")
	_check(sawbot.global_position.distance_to(tree.global_position) <= CONFIG.sawbot_reach_cells * CONFIG.cell_size + 1.0, "it saws from within its reach")
	# One bite lands every sawbot_saw_interval seconds, so the tree's HP steps down.
	_check(await _wait_until(func() -> bool: return tree.hp < CONFIG.tree_hp, 1.5), "the tree loses hit points while being sawn")

	var seconds_to_fell: float = CONFIG.tree_hp * CONFIG.sawbot_saw_interval / float(CONFIG.sawbot_saw_damage)
	var felled: Callable = func() -> bool: return _arena.tree_at(tree_cell) == null
	_check(await _wait_until(felled, seconds_to_fell + 1.5), "the tree falls")
	_check(not _arena.grid.is_solid(tree_cell), "and its grid cell opens up again")
	_check(_arena.player.hp == CONFIG.player_max_hp, "the player was never hurt: a Sawbot ignores you")
	await _wait_frames(40)
	_check(not sawbot.is_sawing, "with that tree gone it stops sawing and moves on")


## Sawbot: tougher than a Scrapper, and like every machine it roots when downed.
func _test_sawbot_takes_three_pods_and_becomes_a_tree() -> void:
	await _fresh_arena()
	var player_cell := Vector2i(5, 12)
	_arena.player.global_position = _arena.grid.cell_to_world(player_cell)
	var sawbot: Sawbot = _arena.spawn_sawbot_at(player_cell + Vector2i(5, 0))
	await get_tree().physics_frame
	_check(sawbot.hp == CONFIG.sawbot_hp, "a Sawbot starts with %d hit points" % CONFIG.sawbot_hp)

	# The seed pod only knows it hit "an Enemy". That it works on a Sawbot too is
	# the point of the shared Enemy base class.
	_check(_arena.player.fire(sawbot.global_position - _arena.player.global_position), "the player fires at it")
	_check(await _wait_until(func() -> bool: return sawbot.hp == CONFIG.sawbot_hp - 1, 1.5), "one pod takes one hit point off")

	var fell_at: Array[Vector2] = []
	sawbot.died.connect(func(dead: Enemy) -> void: fell_at.append(dead.global_position))
	sawbot.take_damage(CONFIG.sawbot_hp)
	_check(fell_at.size() == 1, "at zero hit points it goes down")
	if fell_at.is_empty():
		return
	await get_tree().physics_frame  # the sapling is planted at the end of the frame
	_check(_arena.tree_at(_arena.grid.world_to_cell(fell_at[0])) != null, "and a sapling is planted where it fell")


## Waves: the director on its own, with no arena. It must send the right number
## of machines, notice when they are all down, rest, and move to the next wave.
func _test_wave_director_counts_and_advances() -> void:
	var director := WaveDirector.new()
	director.time_scale = 20.0  # 20x faster, so the test does not sit through real waits
	add_child(director)
	# Write down everything the director announces. Each lambda appends to a list
	# the test can read afterwards (connect() + a lambda = a one-off listener).
	var spawned: Array[StringName] = []
	var started: Array[int] = []
	var cleared: Array[int] = []
	var finished: Array[bool] = []
	director.spawn_requested.connect(func(kind: StringName, _wave: int) -> void: spawned.append(kind))
	director.wave_started.connect(func(number: int, _total: int) -> void: started.append(number))
	director.wave_cleared.connect(func(number: int) -> void: cleared.append(number))
	director.all_waves_cleared.connect(func() -> void: finished.append(true))

	_check(director.total_waves() == CONFIG.wave_scrappers.size(), "there is one wave per entry in the config list")
	director.start_wave(1)
	# (Comparing size and first item, rather than `started == [1]`, keeps the
	# types simple: a typed Array[int] and a plain [1] are different types.)
	_check(started.size() == 1 and started[0] == 1, "starting wave 1 announces wave 1")
	var wave_one_size: int = CONFIG.wave_scrappers[0] + CONFIG.wave_spitters[0] + CONFIG.wave_sawbots[0]
	var all_sent: Callable = func() -> bool: return director.state == WaveDirector.State.FIGHTING
	# Wave 1 is STAGED: one machine at a time, the next only after the last is down.
	for i: int in wave_one_size:
		var next_sent: Callable = func() -> bool: return spawned.size() == i + 1
		_check(await _wait_until(next_sent, 2.0), "staged wave 1 sends machine %d" % (i + 1))
		await _wait_frames(20)
		_check(spawned.size() == i + 1, "and holds the next one back while that one stands")
		_check(cleared.is_empty(), "the wave is not over while a machine still stands")
		director.enemy_gone()
	_check(spawned.size() == wave_one_size, "wave 1 asked for %d machine(s) (got %d)" % [wave_one_size, spawned.size()])
	_check(spawned[0] == WaveDirector.SCRAPPER and spawned[-1] == WaveDirector.SPITTER, "wave 1 is a Scrapper first, then a Spitter")
	# enemy_gone() is what the arena calls each time a machine is shot down.
	_check(cleared.size() == 1 and cleared[0] == 1, "when the last machine falls, wave 1 is cleared")
	_check(director.state == WaveDirector.State.BREAK, "then comes a rest")
	_check(await _wait_until(func() -> bool: return director.wave == 2, CONFIG.wave_break_time + 1.0), "after the rest, wave 2 starts by itself")

	# Jump to the last wave and clear it: the director must announce the end.
	var last: int = director.total_waves()
	spawned.clear()
	director.start_wave(last)
	await _wait_until(all_sent, 3.0)
	var sawbots_sent: int = spawned.count(WaveDirector.SAWBOT)
	_check(sawbots_sent == CONFIG.wave_sawbots[last - 1], "the last wave sends %d Sawbot(s) (got %d)" % [CONFIG.wave_sawbots[last - 1], sawbots_sent])
	var spitters_sent: int = spawned.count(WaveDirector.SPITTER)
	_check(spitters_sent == CONFIG.wave_spitters[last - 1], "and %d Spitter(s) (got %d)" % [CONFIG.wave_spitters[last - 1], spitters_sent])
	_check(spawned[0] == WaveDirector.SCRAPPER, "a wave opens with a Scrapper, with Sawbots spread through it")
	for i: int in spawned.size():
		director.enemy_gone()
	_check(finished.size() == 1, "clearing the last wave announces that all waves are done")
	_check(director.state == WaveDirector.State.DONE, "and the director stops")
	director.queue_free()


## Waves in the real arena: wave 3 brings a Sawbot and faster Scrappers.
func _test_wave_three_sends_faster_scrappers_and_a_sawbot() -> void:
	await _fresh_arena()
	_arena.waves.time_scale = 20.0
	# Wave 4 is the first wave with all three kinds of machine in it.
	var wave: int = 4
	_arena.waves.start_wave(wave)
	var expected: int = CONFIG.wave_scrappers[wave - 1] + CONFIG.wave_spitters[wave - 1] + CONFIG.wave_sawbots[wave - 1]
	var all_in: Callable = func() -> bool: return get_tree().get_nodes_in_group(Enemy.GROUP).size() == expected
	_check(await _wait_until(all_in, 3.0), "wave %d puts %d machines in the arena" % [wave, expected])

	# Count what actually walked in. Every machine joins the "enemies" group in
	# its _ready (see Enemy._configure_body), so one loop over the group sees
	# them all, whatever kind they are.
	var sawbots: int = 0
	var spitters: int = 0
	var scrapper_scale: float = 0.0
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		if node is Sawbot:  # `is` asks "is this node of that type?"
			sawbots += 1
		elif node is Spitter:
			spitters += 1
		elif node is Scrapper:
			scrapper_scale = (node as Scrapper).speed_scale
	_check(sawbots == CONFIG.wave_sawbots[wave - 1], "wave %d includes %d Sawbot(s)" % [wave, CONFIG.wave_sawbots[wave - 1]])
	_check(spitters == CONFIG.wave_spitters[wave - 1], "and %d Spitter(s)" % CONFIG.wave_spitters[wave - 1])
	var expected_scale: float = 1.0 + CONFIG.scrapper_speed_gain_per_wave * (wave - 1)
	_check(is_equal_approx(scrapper_scale, expected_scale), "wave %d Scrappers walk at %.2fx speed (got %.2f)" % [wave, expected_scale, scrapper_scale])
	# The arena rewrites the corner label in its _process, which runs once per
	# DRAWN frame (not per physics step), so wait for one drawn frame first.
	await get_tree().process_frame
	var label: String = (_arena.get_node("Hud/WaveLabel") as Label).text
	_check(label.begins_with("Wave %d / %d" % [wave, _arena.waves.total_waves()]), "the HUD shows the wave number")
	_check(label.contains("Homes lit"), "and how many homes are lit")
	_check(label.ends_with("Trees %d" % _arena.count_grown_trees()), "and how many trees are standing")


## Waves: going down restarts the same wave, with the forest put back to how it
## stood when that wave began.
func _test_going_down_restarts_the_wave_with_its_forest() -> void:
	await _fresh_arena()
	_arena.waves.time_scale = 20.0
	_arena.waves.start_wave(2)  # the forest snapshot is taken right here
	var late_tree_cell := Vector2i(3, 3)
	_check(_arena.spawn_tree(late_tree_cell, true) != null, "a tree grows during the wave")
	var enemy_in: Callable = func() -> bool: return get_tree().get_nodes_in_group(Enemy.GROUP).size() >= 1
	await _wait_until(enemy_in, 1.0)

	# Move the player away from the start, then knock out all its health at once.
	# The arena hears the player's `died` signal, waits death_restart_delay, and
	# rebuilds the wave from its snapshot.
	_arena.player.global_position = _arena.grid.cell_to_world(Vector2i(20, 12))
	_arena.player.take_damage(CONFIG.player_max_hp)
	_check(_arena.player.is_dead, "the player goes down")
	var back_up: Callable = func() -> bool: return not _arena.player.is_dead
	_check(await _wait_until(back_up, CONFIG.death_restart_delay + 1.0), "after a moment the player is back up")
	_check(_arena.player.hp == CONFIG.player_max_hp, "with full health")
	var start: Vector2 = _arena.grid.cell_to_world(Arena.PLAYER_START_CELL)
	_check(_arena.player.global_position.distance_to(start) < 1.0, "back at the starting spot")
	_check(_arena.waves.wave == 2, "still on wave 2")
	_check(get_tree().get_nodes_in_group(Enemy.GROUP).is_empty(), "the old machines are gone")
	_check(_arena.tree_at(late_tree_cell) == null, "the tree that grew during the wave is gone")
	_check(not _arena.grid.is_solid(late_tree_cell), "and its cell is open again")
	for cell: Vector2i in Arena.TEST_TREE_CELLS:
		_check(_arena.tree_at(cell) != null and _arena.grid.is_solid(cell), "the tree at %s from wave start is back" % cell)
	_check(await _wait_until(enemy_in, 1.0), "and the wave sends its machines in again")


## Spitter: with a clear line to the player it glows first (the warning), then
## its shot flies at the player and costs a hit point.
func _test_spitter_warns_then_hits_the_player() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	var shots: Node = _arena.get_node("Shots")
	# Row 12 has no trees in it, so the Spitter can see the player straight away.
	player.global_position = _arena.grid.cell_to_world(Vector2i(5, 12))
	var spitter: Spitter = _arena.spawn_spitter_at(Vector2i(10, 12))  # 5 cells away: in range
	await get_tree().physics_frame
	_check(spitter.hp == CONFIG.spitter_hp, "a Spitter starts with %d hit points" % CONFIG.spitter_hp)

	var glowing: Callable = func() -> bool: return spitter.is_winding_up
	_check(await _wait_until(glowing, CONFIG.spitter_cooldown), "a Spitter that can see the player starts its windup")
	_check(shots.get_child_count() == 0, "nothing is fired during the warning")
	_check(player.hp == CONFIG.player_max_hp, "and the warning does no damage")

	var fired: Callable = func() -> bool: return shots.get_child_count() == 1
	_check(await _wait_until(fired, CONFIG.spitter_windup + 0.5), "when the windup ends it fires one shot")
	if shots.get_child_count() == 1:
		var shot := shots.get_child(0) as SpitShot
		_check(shot.direction.is_equal_approx(Vector2.LEFT), "the shot flies straight at the player")

	var was_hit: Callable = func() -> bool: return player.hp < CONFIG.player_max_hp
	_check(await _wait_until(was_hit, 2.0), "the shot reaches the player")
	_check(player.hp == CONFIG.player_max_hp - CONFIG.spit_damage, "and costs exactly the spit damage")
	# queue_free() removes a node at the END of the current frame, so give it one
	# more physics step before looking.
	await get_tree().physics_frame
	_check(shots.get_child_count() == 0, "the shot is used up by the hit")


## Cover: a grown tree between the shot and the player stops the shot.
func _test_tree_stops_a_spit_shot() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	var shots: Node = _arena.get_node("Shots")
	var tree_cell: Vector2i = Arena.TEST_TREE_CELLS[0]
	var tree_x: float = _arena.grid.cell_to_world(tree_cell).x
	# Player two cells left of the tree; the shot starts three cells right of it.
	player.global_position = _arena.grid.cell_to_world(tree_cell + Vector2i(-2, 0))
	_arena.spawn_spit_shot(_arena.grid.cell_to_world(tree_cell + Vector2i(3, 0)), Vector2.LEFT)
	await get_tree().physics_frame

	# Track how far left the shot ever gets (same one-item-box trick as the pod test).
	var furthest_left: Array[float] = [INF]
	var shot_gone: Callable = func() -> bool:
		if shots.get_child_count() == 0:
			return true
		furthest_left[0] = minf(furthest_left[0], (shots.get_child(0) as Node2D).global_position.x)
		return false
	_check(await _wait_until(shot_gone, 2.0), "the shot is removed when it reaches the tree")
	_check(furthest_left[0] > tree_x, "it never got past the tree's centre")
	_check(player.hp == CONFIG.player_max_hp, "the player behind the tree is unhurt")
	_check(_arena.tree_at(tree_cell).hp == CONFIG.tree_hp, "and the tree is not damaged by it")


## Spitter: it backs away when the player gets too close.
func _test_spitter_keeps_its_distance() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	player.global_position = _arena.grid.cell_to_world(Vector2i(5, 12))
	var spitter: Spitter = _arena.spawn_spitter_at(Vector2i(7, 12))  # 2 cells: too close
	await get_tree().physics_frame
	var distance_before: float = spitter.global_position.distance_to(player.global_position)
	# It waits half a cooldown before its first shot; use that time to watch it move.
	await _wait_frames(int(CONFIG.spitter_cooldown * 0.5 * 60.0) - 6)
	var distance_after: float = spitter.global_position.distance_to(player.global_position)
	_check(distance_after > distance_before + 20.0, "a crowded Spitter backs away (%.0f px to %.0f px)" % [distance_before, distance_after])


## Spitter: with a tree in the way it cannot shoot, so it walks round for a clear line.
func _test_spitter_closes_in_when_it_cannot_see_you() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	var shots: Node = _arena.get_node("Shots")
	var tree_cell: Vector2i = Arena.TEST_TREE_CELLS[0]
	# Player hard against the left of the tree, Spitter four cells to its right:
	# the tree hides the player completely.
	player.global_position = _arena.grid.cell_to_world(tree_cell + Vector2i(-1, 0))
	var spitter: Spitter = _arena.spawn_spitter_at(tree_cell + Vector2i(4, 0))
	var start: Vector2 = spitter.global_position
	await _wait_frames(40)
	_check(not spitter.is_winding_up and shots.get_child_count() == 0, "a Spitter that cannot see the player does not fire")
	_check(spitter.global_position.distance_to(start) > 20.0, "it walks to find a clear line instead")
	var glowing: Callable = func() -> bool: return spitter.is_winding_up
	_check(await _wait_until(glowing, 6.0), "once it has walked round the tree, it starts a shot")


## Vine on a machine: it is dragged towards the bot, held still for the bind
## time, and then carries on as before.
func _test_vine_yanks_and_binds_a_machine() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	player.global_position = _arena.grid.cell_to_world(Vector2i(5, 12))
	var scrapper: Scrapper = _arena.spawn_scrapper_at(Vector2i(11, 12))  # 6 cells away
	await get_tree().physics_frame

	# Before Lucky's clamp, the vine cannot bind a machine.
	_check(not player.try_vine(scrapper.global_position) and not scrapper.is_bound, "no binding before the cat's gift")
	player.receive_cat_gift()
	_check(player.try_vine(scrapper.global_position), "the vine lands on a machine in clear view")
	_check(scrapper.is_bound, "the machine is bound")
	_check(not player.is_zipping, "the bot itself does not move")
	_check(not player.try_vine(scrapper.global_position), "the vine needs its cooldown before the next use")

	# The drag stops vine_yank_stop_cells from the bot.
	var stop: float = CONFIG.vine_yank_stop_cells * CONFIG.cell_size
	var arrived: Callable = func() -> bool: return absf(scrapper.global_position.distance_to(player.global_position) - stop) < 3.0
	_check(await _wait_until(arrived, 1.0), "it is dragged to %.1f cells from the bot" % CONFIG.vine_yank_stop_cells)

	# While bound it must not creep closer or start a swing.
	var held_at: Vector2 = scrapper.global_position
	await _wait_frames(30)
	_check(scrapper.is_bound and scrapper.global_position.distance_to(held_at) < 1.0, "it stays put while bound")
	_check(not scrapper.is_winding_up and player.hp == CONFIG.player_max_hp, "and cannot attack")

	var released: Callable = func() -> bool: return not scrapper.is_bound
	_check(await _wait_until(released, CONFIG.vine_bind_time + 0.5), "the binding wears off after %.1f s" % CONFIG.vine_bind_time)
	_check(scrapper.modulate == Color.WHITE, "and the green tint goes with it")
	var swinging: Callable = func() -> bool: return scrapper.is_winding_up
	_check(await _wait_until(swinging, 2.0), "then it comes at the bot again")


## Vine on a machine: a tree in the way blocks it, and a bound Sawbot stops sawing.
func _test_vine_bind_needs_a_clear_line() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	player.receive_cat_gift()  # binding needs Lucky's clamp
	var tree_cell: Vector2i = Arena.TEST_TREE_CELLS[0]
	# The tree sits exactly between the bot and the Sawbot.
	player.global_position = _arena.grid.cell_to_world(tree_cell + Vector2i(-3, 0))
	var sawbot: Sawbot = _arena.spawn_sawbot_at(tree_cell + Vector2i(3, 0))
	await get_tree().physics_frame
	_check(not player.try_vine(sawbot.global_position), "a machine behind a tree cannot be lashed")
	_check(not sawbot.is_bound, "so it is not bound")

	# Let it reach the tree and start cutting, then lash it from the open side.
	_check(await _wait_until(func() -> bool: return sawbot.is_sawing, 4.0), "the Sawbot starts sawing the tree")
	player.global_position = sawbot.global_position + Vector2(0.0, 4.0 * CONFIG.cell_size)
	await get_tree().physics_frame
	var tree_hp: int = _arena.tree_at(tree_cell).hp
	_check(player.try_vine(sawbot.global_position), "from the open side the vine lands")
	_check(sawbot.is_bound and not sawbot.is_sawing, "a bound Sawbot stops sawing")
	await _wait_frames(40)
	_check(_arena.tree_at(tree_cell).hp == tree_hp, "and the tree takes no more damage while it is bound")


## Touch: a quick tap on a machine is the same vine bind.
func _test_touch_tap_on_a_machine_binds_it() -> void:
	await _fresh_arena()
	var touch: TouchControls = _touch_controls()
	_arena.player.receive_cat_gift()  # binding needs Lucky's clamp
	_arena.player.global_position = _arena.grid.cell_to_world(Vector2i(5, 12))
	var spitter: Spitter = _arena.spawn_spitter_at(Vector2i(10, 12))
	await get_tree().physics_frame
	# Tap a little off-centre, as a fingertip would.
	touch.touch_down(0, spitter.global_position + Vector2(20.0, 15.0))
	await _wait_frames(3)
	touch.touch_up(0)
	_check(spitter.is_bound, "a tap on a machine binds it")
	_check(_arena.get_node("Shots").get_child_count() == 0 and not spitter.is_winding_up, "a bound Spitter is not shooting")


## The hidden lucky cat: three pods on the shop open it, and from then on every
## shot is a pair of pods. Pods on the plain wall do not count.
func _test_three_pods_open_the_cat_shop() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	var shop: CatShop = _arena.cat_shop
	var pods: Node = _arena.get_node("Pods")
	_check(shop != null and not shop.is_open and shop.hits == 0, "the arena has a closed shop")
	_check(not player.can_bind and not player.has_fuse, "no clamp and no fuse to begin with")

	# A pod on the ordinary wall, well left of the shop, must not count.
	player.global_position = _arena.grid.cell_to_world(Vector2i(4, 3))
	player.fire(Vector2.UP)
	await _wait_until(func() -> bool: return pods.get_child_count() == 0, 1.5)
	_check(shop.hits == 0, "a pod on the plain wall does not count")

	# Stand three cells below the shop and fire straight up at it.
	player.global_position = Vector2(shop.global_position.x, _arena.grid.cell_to_world(Vector2i(0, 4)).y)
	for shot: int in CONFIG.cat_hits_needed:
		# fire() refuses while the cooldown runs, so keep asking until it agrees.
		await _wait_until(func() -> bool: return player.fire(Vector2.UP), 1.0)
		var landed: Callable = func() -> bool: return shop.hits == shot + 1
		_check(await _wait_until(landed, 1.5), "pod %d lands on the shop" % (shot + 1))
		if shot < CONFIG.cat_hits_needed - 1:
			_check(not shop.is_open, "the shop stays shut after %d pod(s)" % (shot + 1))
	_check(shop.is_open, "the third pod opens the shop")
	_check(player.can_bind and player.has_fuse, "the cat's gift: the clamp and a spare fuse")
	await _wait_until(func() -> bool: return pods.get_child_count() == 0, 1.5)

	# Paired pods are gone (Sasha's story redesign): one shot is still one pod.
	await _wait_until(func() -> bool: return player.fire(Vector2.LEFT), 1.0)
	await get_tree().physics_frame
	_check(pods.get_child_count() == 1, "one shot is still one pod")
	shop.hit_by_seed()
	_check(shop.hits == CONFIG.cat_hits_needed, "an open shop ignores further pods")


## Staged wave 1: the lone Scrapper, then (only once it is a tree) a Spitter that
## walks in from behind that tree. The first tree pulses until the player zips.
func _test_staged_wave_one_teaches_cover_and_the_vine() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	_arena.waves.time_scale = 20.0
	_arena.waves.start_wave(1)
	var one_in: Callable = func() -> bool: return get_tree().get_nodes_in_group(Enemy.GROUP).size() == 1
	_check(await _wait_until(one_in, 1.0), "wave 1 opens with one machine")
	var scrapper := get_tree().get_first_node_in_group(Enemy.GROUP) as Scrapper
	_check(scrapper != null, "and it is a Scrapper")
	if scrapper == null:
		return
	await _wait_frames(30)
	_check(get_tree().get_nodes_in_group(Enemy.GROUP).size() == 1, "the Spitter waits while the Scrapper stands")

	# Down the Scrapper somewhere open, between the player and the right-hand wall.
	_arena.waves.time_scale = 1.0  # real timing now, so the tree is grown before the Spitter
	scrapper.global_position = _arena.grid.cell_to_world(Vector2i(12, 7))
	var tree_cell: Vector2i = _arena.grid.world_to_cell(scrapper.global_position)
	scrapper.take_damage(CONFIG.scrapper_hp)
	var grown: Callable = func() -> bool:
		var tree: ForestTree = _arena.tree_at(tree_cell)
		return tree != null and tree.stage == ForestTree.Stage.GROWN
	_check(await _wait_until(grown, CONFIG.sapling_time + 1.0), "the downed Scrapper becomes a tree")
	var tree: ForestTree = _arena.tree_at(tree_cell)
	_check(tree.show_vine_hint, "the first tree you grow pulses: you can vine to this")

	var spitter_in: Callable = func() -> bool: return get_tree().get_first_node_in_group(Enemy.GROUP) is Spitter
	_check(await _wait_until(spitter_in, CONFIG.wave_spawn_interval + 1.0), "then the Spitter walks in")
	var spitter := get_tree().get_first_node_in_group(Enemy.GROUP) as Spitter
	if spitter != null:
		# The tree should sit close to the straight line from Spitter to player.
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(tree.global_position, spitter.global_position, player.global_position)
		_check(nearest.distance_to(tree.global_position) < CONFIG.cell_size, "it comes in from behind the new tree (line misses the tree by %.0f px)" % nearest.distance_to(tree.global_position))

	# One zip to that tree and the hint has done its job.
	_check(player.try_vine(tree.global_position), "the player zips to the pulsing tree")
	_check(await _wait_until(func() -> bool: return not player.is_zipping, 2.0), "the zip finishes")
	_check(not tree.show_vine_hint, "and the pulse stops")


## Story step 1: Helios speaks as a wave starts, the Block paints an answer when
## it is cleared, and the opening line shows once only.
func _test_story_words() -> void:
	var total: int = CONFIG.wave_scrappers.size()
	_check(CONFIG.helios_lines.size() == total, "there is one Helios line per wave (%d)" % total)
	_check(CONFIG.graffiti_lines.size() == total, "there is one graffiti line per wave (%d)" % total)

	await _fresh_arena()
	var story := _arena.get_node("Hud/StoryLine") as Label
	_check(not story.visible, "no story line shows before a wave starts")
	_check(_arena.graffiti.revealed_count == 0, "the walls start clean")
	_check(_arena.helios_line_for(1).contains(CONFIG.helios_lines[0]), "wave 1 has Helios's first line")
	_check(_arena.helios_line_for(99) == "", "a wave with no line gets none")

	# Start wave 2 directly. The very first wave start of a run shows the hook.
	_arena.waves.time_scale = 20.0
	_arena.waves.start_wave(2)
	_check(story.visible and story.text == CONFIG.story_hook, "the first wave start shows the opening line")
	# Let the opening line run out; Helios's notice follows it.
	var helios_showing: Callable = func() -> bool: return story.text == _arena.helios_line_for(2)
	_check(await _wait_until(helios_showing, CONFIG.story_line_seconds + 1.0), "then Helios's line for that wave")

	# Clear the wave: one painted line per wave cleared so far, and Helios goes quiet.
	var all_sent: Callable = func() -> bool: return _arena.waves.state == WaveDirector.State.FIGHTING
	await _wait_until(all_sent, 4.0)
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		(node as Enemy).take_damage(99)
	_check(_arena.graffiti.revealed_count == 2, "clearing wave 2 puts two lines on the walls")
	_check(_arena.graffiti.line_text(1) == CONFIG.graffiti_lines[1], "the second is wave 2's line")
	_check(not story.visible, "Helios's line is cleared with the wave")

	# Painted lines never come off, and the opening line never repeats.
	_arena.graffiti.reveal_up_to(1)
	_check(_arena.graffiti.revealed_count == 2, "revealing an earlier wave removes nothing")
	_arena.waves.start_wave(1)
	_check(story.text == _arena.helios_line_for(1), "a later wave start skips the opening line")


## Story step 2: homes with several windows, lit by waves cleared and shining
## stronger each wave; the whole lot's tint follows the light; trees glow.
func _test_windows_and_night() -> void:
	await _fresh_arena()
	var windows: BlockWindows = _arena.windows
	var total: int = windows.window_count()
	var last: int = _arena.waves.total_waves()
	_check(total >= 20 and total <= 25, "the block has a fixed 20 to 25 windows (%d)" % total)
	_check(windows.home_count() < total, "homes have more than one window (%d homes)" % windows.home_count())
	# The roof picture holds six units side by side, each exactly one unit wide,
	# and the units packed edge to edge exactly fill the bottom wall.
	var roofs: Texture2D = CONFIG.home_roofs
	_check(roofs != null and is_equal_approx(roofs.get_width(), BlockWindows.UNIT_WIDTH * BlockWindows.ROOF_DESIGNS)
		and is_equal_approx(roofs.get_height(), BlockWindows.ROOF_HEIGHT), "the roof picture holds six whole roof units")
	_check(is_equal_approx(BlockWindows.UNIT_WIDTH * total, CONFIG.grid_cols * CONFIG.cell_size),
		"one roof unit per window exactly fills the bottom wall")

	# Before any wave: the first lamps only, shining faintly.
	_check(windows.lit_count == CONFIG.windows_lit_at_start, "the block starts with %d windows lit" % CONFIG.windows_lit_at_start)
	_check(is_equal_approx(windows.strength, CONFIG.window_strength_at_start), "shining at the starting strength")
	var dark_level: float = _arena.light_level()

	# The schedule: more windows and more strength with every wave cleared.
	var partly: int = _arena.lit_windows_after(last - 2)
	_check(partly > total / 2 and partly < total, "two waves from the end the block is mostly but not fully lit (%d of %d)" % [partly, total])
	_check(_arena.lit_windows_after(last) == total, "the last wave lights every window")
	_check(is_equal_approx(_arena.window_strength_after(last), 1.0), "at full strength")
	var climbing: bool = true
	for cleared: int in range(1, last + 1):
		if _arena.lit_windows_after(cleared) < _arena.lit_windows_after(cleared - 1):
			climbing = false
		if _arena.window_strength_after(cleared) <= _arena.window_strength_after(cleared - 1):
			climbing = false
	_check(climbing, "each wave cleared never dims the block and always strengthens the light")
	_check(_arena.wave_cleared_text(last).contains("lit"), "the last wave's banner says the block is lit")
	_check(not _arena.wave_cleared_text(last - 2).contains("lit"), "an earlier wave's banner does not")

	# Clearing a wave (here: pretending wave 4 was cleared) updates the windows.
	_arena.waves_cleared = 4
	_arena._update_light()
	_check(windows.lit_count == _arena.lit_windows_after(4), "clearing waves lights more windows")
	_check(windows.homes_lit() >= 2 and windows.homes_lit() <= windows.home_count(), "spread over several homes (%d)" % windows.homes_lit())
	_check(_arena.light_level() > dark_level, "and the lot's light level rises")

	# The whole lot is tinted to match: it moves from the dark tint toward the lit one.
	var ambient: CanvasModulate = _arena._ambient
	_check(ambient.color.is_equal_approx(CONFIG.ambient_dark) or ambient.color.r >= CONFIG.ambient_dark.r, "the lot starts at the dark tint")
	var tint_before: float = ambient.color.r
	await _wait_frames(40)
	_check(ambient.color.r > tint_before, "more light warms and brightens every sprite's tint")
	# Fewer lights, not a darker tint: halfway through the run the overall tint
	# is still much closer to dark than to lit; only the full block is fully lit.
	var middle: Color = _arena.ambient_tint_for(0.5)
	_check(middle.r - CONFIG.ambient_dark.r < (CONFIG.ambient_lit.r - CONFIG.ambient_dark.r) * 0.3,
		"halfway, the lot is still mostly dark (light comes from separate pools)")
	_check(_arena.ambient_tint_for(1.0).is_equal_approx(CONFIG.ambient_lit), "the fully lit block gets the full warm tint")
	_check(_arena.light_boost_for(0.0) > 1.0 and is_equal_approx(_arena.light_boost_for(1.0), 1.0),
		"lights shine through the dark, and are not boosted once the lot is lit")
	# Lantern strings go up after the listed waves, one at a time, and never come down.
	_check(Lanterns.strings_after(0) == 0, "no lantern strings at the start")
	var first_string_wave: int = CONFIG.lantern_string_waves[0]
	_check(Lanterns.strings_after(first_string_wave - 1) == 0 and Lanterns.strings_after(first_string_wave) == 1,
		"the first lantern string goes up after wave %d" % first_string_wave)
	_check(Lanterns.strings_after(last) == CONFIG.lantern_string_waves.size(), "every string is up at the end")
	_arena.waves_cleared = first_string_wave
	_arena._update_light()
	_check(_arena.lanterns.strings_up == 1, "clearing that wave hangs the string in the lot")
	_arena.waves_cleared = 0
	_arena._update_light()
	_check(_arena.lanterns.strings_up == 1, "and a restarted wave never takes it down")

	# Trees glow; saplings do not; Seven carries a lamp.
	var tree: ForestTree = _arena.spawn_tree(Vector2i(4, 3), true)
	_check(tree.has_node(Glow.NODE_NAME), "a grown tree glows")
	var sapling: ForestTree = _arena.spawn_tree(Vector2i(4, 11), false)
	_check(not sapling.has_node(Glow.NODE_NAME), "a sapling does not glow yet")
	_check(_arena.player.has_node(Glow.NODE_NAME), "Seven carries a lamp")

	# Blackout: felling a tree makes one lit window flicker, without changing the count.
	var lit_before: int = windows.lit_count
	tree.take_damage(99)
	var flickering: int = 0
	for i: int in total:
		if windows.is_flickering(i):
			flickering += 1
	_check(flickering == 1, "a felled tree makes one window flicker dark")
	_check(windows.lit_count == lit_before, "but the number of lit windows is unchanged")
	_check(not windows.next_block_lit, "the next block stays dark until the run is won")

	# The controls line makes way for the windows.
	var hint := _arena.get_node("Hud/Hint") as Label
	_arena.waves.start_wave(CONFIG.hint_hide_wave - 1)
	_check(hint.visible, "the controls line shows before wave %d" % CONFIG.hint_hide_wave)
	_arena.waves.start_wave(CONFIG.hint_hide_wave)
	_check(not hint.visible, "and hides from wave %d on" % CONFIG.hint_hide_wave)

## The end of a run: clearing the last wave leaves the arena as it is and says so.
func _test_clearing_the_last_wave_ends_the_run() -> void:
	await _fresh_arena()
	_arena.waves.time_scale = 20.0
	var last: int = _arena.waves.total_waves()
	_arena.waves.start_wave(last)
	_check(not _arena.is_run_finished, "the run is not over while the last wave is on")
	var all_sent: Callable = func() -> bool: return _arena.waves.state == WaveDirector.State.FIGHTING
	_check(await _wait_until(all_sent, 4.0), "the last wave sends everything in")
	# Down every machine. Each one roots where it stands.
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		(node as Enemy).take_damage(99)
	_check(_arena.waves.state == WaveDirector.State.DONE, "with the last machine down, the waves are done")
	_check(_arena.is_run_finished, "and the arena marks the run finished")
	await _wait_frames(int(CONFIG.sapling_time * 60.0) + 30)
	var banner := _arena.get_node("Hud/Banner") as Label
	_check(banner.visible and banner.text.begins_with(CONFIG.end_headline), "the end banner is up with the end headline")
	_check(banner.text.contains("Trees standing: %d" % _arena.count_grown_trees()), "it counts the trees left standing")
	_check(_arena.windows.lit_count == _arena.windows.window_count(), "every window of the block is lit")
	_check(is_equal_approx(_arena.windows.strength, 1.0), "at full strength")
	var last_word := _arena.get_node("Hud/StoryLine") as Label
	_check(last_word.visible and last_word.text.contains(CONFIG.helios_end_line), "Helios's last line stays under it")
	_check(_arena.graffiti.revealed_count == CONFIG.graffiti_lines.size(), "every graffiti line is on the walls")
	_check(_arena.windows.next_block_lit, "and the next block's windows start coming on")
	_check(_arena.count_grown_trees() > Arena.TEST_TREE_CELLS.size(), "and the forest is left standing (%d trees)" % _arena.count_grown_trees())


## The split guard must spot any cell whose tree would cut the open floor in two,
## including the two cases the older seal guard missed.
func _test_split_guard() -> void:
	# Case 1: a straight wall with one gap.
	var grid := ArenaGrid.new(10, 8, 48)
	for y: int in range(1, 7):
		if y != 3:
			grid.set_solid(Vector2i(4, y), true)
	_check(grid.would_split(Vector2i(4, 3)), "filling the last gap in a wall splits the floor")
	_check(not grid.would_split(Vector2i(6, 5)), "a tree in open floor splits nothing")
	_check(not grid.would_split(Vector2i(1, 1)), "a tree in a corner splits nothing")
	_check(not grid.is_solid(Vector2i(4, 3)), "would_split leaves the grid unchanged")

	# Case 2 (the phone playtest): a pocket that holds BOTH the player and the
	# centre cell. The old guard only asked "can the player reach the centre?",
	# and here the answer stays yes, so it let the last tree grow.
	var pocket := ArenaGrid.new(10, 8, 48)
	var centre: Vector2i = pocket.center_cell()  # (5, 4)
	var beside: Vector2i = centre + Vector2i(1, 0)
	for cell: Vector2i in [centre + Vector2i(-1, 0), centre + Vector2i(0, -1), centre + Vector2i(0, 1), beside + Vector2i(0, -1), beside + Vector2i(0, 1)]:
		pocket.set_solid(cell, true)
	var last_gap: Vector2i = beside + Vector2i(1, 0)
	_check(not pocket.would_seal(last_gap, beside, centre), "the old seal guard misses a pocket around the centre")
	_check(pocket.would_split(last_gap), "the split guard catches it")

	# Case 3: trees touching only at their corners still make a wall (nobody can
	# squeeze diagonally between them), so the last cell of a diagonal line counts.
	var diagonal := ArenaGrid.new(10, 8, 48)
	for i: int in 5:
		diagonal.set_solid(Vector2i(2 + i, 1 + i), true)  # (2,1) (3,2) (4,3) (5,4) (6,5)
	_check(diagonal.would_split(Vector2i(7, 6)), "finishing a corner-to-corner diagonal wall splits the floor")


## Cell <-> pixel conversion must agree in both directions.
func _test_grid_coordinates() -> void:
	var grid := ArenaGrid.new(10, 8, 48, Vector2(16.0, 0.0))
	_check(grid.cell_to_world(Vector2i(2, 3)) == Vector2(16.0 + 120.0, 168.0), "cell centre in pixels")
	_check(grid.world_to_cell(Vector2(16.0 + 120.0, 168.0)) == Vector2i(2, 3), "pixel back to cell")
	_check(grid.world_to_cell(Vector2(15.0, 10.0)) == Vector2i(-1, 0), "left of the grid is column -1")
	_check(not grid.in_bounds(Vector2i(-1, 0)), "column -1 is out of bounds")
	_check(grid.center_cell() == Vector2i(5, 4), "centre cell")


## The outer ring is wall, and paths bend around solid cells.
func _test_grid_walls_and_paths() -> void:
	var grid := ArenaGrid.new(10, 8, 48)
	_check(grid.is_solid(Vector2i(0, 3)), "border cell is solid")
	_check(not grid.is_solid(Vector2i(1, 1)), "interior cell is clear")

	var straight: Array[Vector2i] = grid.find_path(Vector2i(1, 4), Vector2i(8, 4))
	_check(straight.size() == 8, "straight path visits 8 cells")

	# Put a tree in the way: the path must still arrive, without using that cell.
	grid.set_solid(Vector2i(4, 4), true)
	var around: Array[Vector2i] = grid.find_path(Vector2i(1, 4), Vector2i(8, 4))
	_check(not around.is_empty() and around[-1] == Vector2i(8, 4), "path still reaches the goal")
	_check(not around.has(Vector2i(4, 4)), "path avoids the solid cell")


## The seal guard must spot the one cell that would cut the arena in two.
func _test_seal_guard() -> void:
	var grid := ArenaGrid.new(10, 8, 48)
	# Build a wall of trees down column 4, leaving a single gap at row 3.
	for y: int in range(1, 7):
		if y != 3:
			grid.set_solid(Vector2i(4, y), true)
	var left := Vector2i(2, 3)
	var right := Vector2i(7, 3)
	_check(grid.has_path(left, right), "the gap keeps both sides connected")
	_check(grid.would_seal(Vector2i(4, 3), left, right), "filling the gap would seal")
	_check(not grid.would_seal(Vector2i(6, 5), left, right), "an unrelated cell would not seal")
	_check(not grid.is_solid(Vector2i(4, 3)), "would_seal leaves the grid unchanged")
	_check(grid.has_path(left, right), "still connected after asking")


## The sunroot pictures: all 64 x 64, and a tree shows the right one for its
## state (sapling, grown, then cut once it has been damaged).
func _test_tree_pictures() -> void:
	var pictures: Array[Texture2D] = [CONFIG.tree_sapling_texture, CONFIG.tree_grown_texture, CONFIG.tree_cut_texture]
	var all_sized: bool = true
	for picture: Texture2D in pictures:
		all_sized = all_sized and picture != null and picture.get_size() == Vector2(64.0, 64.0)
	_check(all_sized, "the three tree pictures are 64 x 64")
	_check(CONFIG.graffiti_font != null, "the graffiti has its marker font")
	await _fresh_arena()
	var tree: ForestTree = _arena.spawn_tree(Vector2i(5, 5), false)
	_check(tree != null and tree.current_texture() == CONFIG.tree_sapling_texture, "a new tree shows the sapling picture")
	if tree == null:
		return
	tree.solidify()
	_check(tree.current_texture() == CONFIG.tree_grown_texture, "a grown tree shows the grown picture")
	tree.take_damage(1)
	if is_instance_valid(tree) and tree.hp > 0:
		_check(tree.current_texture() == CONFIG.tree_cut_texture, "a bitten tree shows the cut picture")


## Lucky's spare fuse: it saves Seven once, is NOT refitted by clearing a wave,
## and IS refitted when Seven is really defeated and the wave restarts.
func _test_spare_fuse() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	player.take_damage(CONFIG.player_max_hp)
	_check(player.is_dead, "without the cat's gift, a deadly hit downs Seven")
	player.revive(player.global_position)

	player.receive_cat_gift()
	await _wait_frames(70)  # let the revive blink run out
	player.take_damage(CONFIG.player_max_hp)
	_check(not player.is_dead and player.hp == CONFIG.fuse_revive_hp, "with a fuse, Seven gets back up (%d HP)" % CONFIG.fuse_revive_hp)
	_check(not player.has_fuse, "and the fuse is used up")

	# Clearing a wave does not refit it.
	_arena.waves_cleared += 1
	_arena._update_light()
	_check(not player.has_fuse, "clearing a wave does not refit the fuse")
	await _wait_frames(150)  # let the long fuse blink run out
	player.take_damage(CONFIG.player_max_hp)
	_check(player.is_dead, "without a fuse the next deadly hit downs Seven")

	# A real defeat restarts the wave and refits it.
	player.revive(player.global_position)
	_check(player.has_fuse, "a real defeat (the wave restart) refits the fuse")


## Talking to Lucky: words only. The greeting depends on the wave the cat was
## found in; small talk depends on the wave being played and cycles.
func _test_talking_to_lucky() -> void:
	_check(LuckyLines.greeting_for(2) == CONFIG.lucky_greeting_early, "found in wave 2: the early greeting")
	_check(LuckyLines.greeting_for(5) == CONFIG.lucky_greeting_middle, "found in wave 5: the middle greeting")
	_check(LuckyLines.greeting_for(9) == CONFIG.lucky_greeting_late, "found in wave 9: the late greeting")
	_check(LuckyLines.small_talk_for(8, 0) == CONFIG.lucky_talk_wave_8[0], "wave 8 has its own small talk")
	var set_size: int = CONFIG.lucky_talk_waves_1_to_3.size()
	_check(LuckyLines.small_talk_for(1, set_size) == LuckyLines.small_talk_for(1, 0), "small talk cycles round its set")

	await _fresh_arena()
	_check(_arena.talk_to_lucky() == "", "Lucky says nothing while the shop is shut")
	var shop: CatShop = _arena.cat_shop
	# The KNOCK x3 hint: hidden early, shown from its wave while the shop is shut.
	_arena.waves.start_wave(CONFIG.knock_hint_wave - 1)
	_check(not _arena.graffiti.show_knock, "no KNOCK hint before wave %d" % CONFIG.knock_hint_wave)
	_arena.waves.start_wave(CONFIG.knock_hint_wave)
	_check(_arena.graffiti.show_knock, "from wave %d a shut shop gets the KNOCK x3 hint" % CONFIG.knock_hint_wave)
	for i: int in CONFIG.cat_hits_needed:
		shop.hit_by_seed()
	_check(_arena.lucky_found_wave >= 1, "the arena remembers the wave Lucky was found in")
	_check(not _arena.graffiti.show_knock, "the KNOCK hint goes once the shop is open")
	var first: String = _arena.talk_to_lucky()
	var second: String = _arena.talk_to_lucky()
	_check(first != "" and second != "" and first != second, "talking again gives the next line")
	var hp_before: int = _arena.player.hp
	_check(_arena.player.hp == hp_before and _arena.player.can_bind, "talking changes nothing in the game")
	_arena.player.global_position = shop.global_position + Vector2(0.0, 2.0 * CONFIG.cell_size)
	_check(_arena.is_near_lucky(), "standing just below the shop is close enough to talk")
	_arena.player.global_position = _arena.grid.cell_to_world(Vector2i(3, 12))
	_check(not _arena.is_near_lucky(), "across the lot is too far")


## Canopy FM: three stations with real song files; the muffle filter opens as the
## block lights; a felled tree dulls the radio for a moment.
func _test_canopy_fm() -> void:
	for id: StringName in CanopyFM.STATIONS:
		_check(ResourceLoader.exists(CanopyFM.STATIONS[id]), "the %s station has its song" % id)
	_check(CanopyFM.STATIONS.size() == 3, "three stations")
	_check(CanopyFM.cutoff_for(0.0) < CanopyFM.cutoff_for(0.5) and CanopyFM.cutoff_for(0.5) < CanopyFM.cutoff_for(1.0),
		"the radio sounds clearer as the block lights")
	_check(is_equal_approx(CanopyFM.cutoff_for(0.0), CONFIG.music_cutoff_dark_hz), "dark block: muffled")
	_check(is_equal_approx(CanopyFM.cutoff_for(1.0), CONFIG.music_cutoff_lit_hz), "lit block: clear")
	await _fresh_arena()
	var tree: ForestTree = _arena.spawn_tree(Vector2i(6, 6), true)
	tree.take_damage(99)
	_check(CanopyFM.is_dulled(), "cutting a tree down dulls the radio")
	var start: StringName = CanopyFM.station
	CanopyFM.set_station(&"dub")
	_check(CanopyFM.station == &"dub", "the station can be changed")
	CanopyFM.set_station(start)
