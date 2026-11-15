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

	# Layer 2: the real arena scene, driven through its public methods. (Headless
	# Godot drops simulated mouse/keyboard input, so we call fire() and try_vine()
	# directly instead of faking clicks.)
	# Turn off Scrapper respawning so no surprise enemy walks into a test. GDScript
	# will not assign through a `const` name, so we go through a normal variable
	# that points at the same shared config object. This only changes the copy in
	# memory for this test run; nothing is saved to the .tres file.
	var config: GameConfig = CONFIG
	config.debug_respawn_delay = 0.0
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
	add_child(_arena)
	# Remove the Scrapper the arena starts with, so each test controls its own.
	for enemy: Node in get_tree().get_nodes_in_group(Scrapper.GROUP):
		enemy.queue_free()
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


## Every action name the scripts rely on must exist in Project Settings > Input Map.
func _test_input_actions_exist() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"fire", &"vine", &"pause"]:
		_check(InputMap.has_action(action), "input action '%s' exists" % action)


## Kickoff steps 1-3: the arena starts with a player, three solid trees, one Scrapper.
func _test_arena_boots() -> void:
	_arena = ARENA_SCENE.instantiate()
	add_child(_arena)
	await get_tree().physics_frame
	_check(_arena.player != null, "arena has a player")
	_check(get_tree().get_nodes_in_group(Scrapper.GROUP).size() == 1, "arena starts with one Scrapper")
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
