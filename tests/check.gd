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
	# The radio's pace is a matter of taste and was slowed twice in s18; the
	# checks below were timed for the original pace, so they run at that pace.
	# (CONFIG is one shared object, so this reaches the arena too. Only this
	# test run is changed: nothing is saved.)
	# (.set() is used because GDScript will not assign to a field of a constant.)
	CONFIG.set(&"radio_chars_per_second", 40.0)
	CONFIG.set(&"story_line_seconds", 3.0)
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
	await _test_radio_voices()
	# Layer 2j: the night look and the windows (STORY.md step 2).
	await _test_windows_and_night()
	await _test_tree_pictures()
	await _test_spare_fuse()
	await _test_talking_to_lucky()
	await _test_canopy_fm()
	await _test_tap_points()
	await _test_new_game_plus()
	await _test_great_powers()
	await _test_trellis()
	await _test_heart_tree()
	await _test_new_machines()
	await _test_upgrades()
	await _test_props_and_lucky_art()
	await _test_bramble_seed()
	# s18: fixes from the phone playtest of 2026-11-19.
	await _test_web_build_has_no_extra_audio_bus()
	await _test_canopy_line_caps()
	await _test_readable_trees()
	await _test_ng_plus_opening()
	await _test_plating_and_grove_rest()
	await _test_s18_machines_heart_cards_light()
	await _test_knockout_and_fuse_animations()
	await _test_banner_radio_and_wave_beat()
	await _test_pause_menu()
	await _test_back_wall_and_roof_graffiti()
	await _test_harder_waves_aim_line_sunburst()
	await _test_hit_feedback()
	await _test_s18_shields_and_bolts()
	await _test_s18_machine_roles()
	await _test_s18_sunburst_chain()
	await _test_s18_wear_and_big_moments()
	await _test_s18_entrances()
	await _test_s18_lucky_moves()
	await _test_s18_round_4()
	# s19: phase 1 of the post-jam backlog.
	await _test_s19_phase1()
	await _test_s19_contact()
	await _test_s19_snare()
	await _test_s19_canopy_line_line()
	await _test_s19_bramble_preview()
	await _test_s19_bramble_intro()
	await _test_s19_lucky()
	await _test_s19_bigger_trees()
	await _test_s19_fuse_saves_once()
	# s22: phase 3, the seed shooter's reload.
	await _test_s22_reload()
	# s23: a Full screen button in the pause menu (for phones in a browser).
	await _test_s23_fullscreen()
	# s24: Bramble Seeds and the Vine Trip Line are cards, from wave 3 on.
	await _test_s24_skill_unlocks()
	# s25: the Logbook in the pause menu keeps every Canopy FM and Lucky line.
	await _test_s25_logbook()

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
## `with_heart`: plant the Heart Tree. Off by default, because the older checks
## were written before it existed and expect only the three hand-placed trees.
## `locked_skills` (s24): start without Bramble Seeds and the Trip Line, as the
## real game does. Off by default: the older checks throw brambles from the start.
func _fresh_arena(with_heart: bool = false, locked_skills: bool = false) -> void:
	if _arena != null:
		_arena.queue_free()
		await get_tree().physics_frame
	_arena = ARENA_SCENE.instantiate()
	# Switch the waves off BEFORE the arena enters the scene (its _ready reads
	# this), so each test controls exactly which enemies exist.
	_arena.autostart_waves = false
	_arena.plant_heart_tree = with_heart
	# No slow-motion beat at the end of a wave: the checks deal the cards at once.
	_arena.wave_end_beat_seconds = 0.0
	# The heavy machines' intro clips slow the whole game down; only the test
	# written for them switches them back on.
	_arena.intro_clips_on = false
	# Lucky's shop moves each run; the tests keep it where they know to shoot.
	_arena.random_cat_shop = false
	# Saplings wait between waves in the real game; the older checks grow trees
	# in the breaks, so only the test written for the rule switches it on.
	_arena.pause_growth_between_waves = false
	# Canopy FM's "[static]" breaks change the words; the checks compare them exactly.
	_arena.radio_static_on = false
	_arena.skills_locked = locked_skills
	add_child(_arena)
	# Give the physics engine two steps to register the new bodies.
	await get_tree().physics_frame
	await get_tree().physics_frame


## Puts every waiting radio line on the air at once, the way they would come up
## one by one over the next half minute. Each line passes _show_next_story_line,
## which is where the Logbook writes them down.
func _drain_radio() -> void:
	while not _arena._story_queue.is_empty():
		_arena._show_next_story_line()


## s25 LOGBOOK: every Canopy FM and Lucky line said this run is kept, once each,
## newest first, for a page in the pause menu. Helios is left out.
func _test_s25_logbook() -> void:
	# --- The book on its own (no arena). ---
	var book := Logbook.new()
	_check(book.add(Radio.CANOPY, "Plant a seed in it.", 1), "a Canopy FM line is kept")
	_check(not book.add(Radio.CANOPY, "Plant a seed in it.", 2), "the same words are not kept twice")
	_check(not book.add(Radio.HELIOS, "Unauthorised growth detected.", 1), "Helios is left out")
	_check(not book.add(Radio.CANOPY, "   ", 1), "an empty line is left out")
	_check(book.add(Radio.LUCKY, "Mrrp. Hello, little gardener.", 3), "a Lucky line is kept")
	_check(book.size() == 2, "the book holds the two kept lines")
	var first_page: Array = book.pages()[0]
	_check(first_page[0].speaker == Radio.LUCKY and first_page[0].text.begins_with("W3 Lucky: "), "the newest line comes first, tagged with its wave and speaker")
	_check(first_page[0].first and first_page[1].text.begins_with("W1 Canopy FM: "), "each line starts with a row marked first")
	# Wrapping: whole words only, and no row over the limit.
	var long_text: String = "one two three four five six seven eight nine ten eleven twelve"
	var rows: Array[String] = Logbook.wrap_words(long_text, 20)
	var fits: bool = true
	for row: String in rows:
		fits = fits and row.length() <= 20
	_check(rows.size() > 1 and fits and " ".join(rows) == long_text, "a long line wraps between words, and no words are lost")
	_check(Logbook.wrap_words("supercalifragilistic", 5) == ["supercalifragilistic"], "a word longer than a row gets a row of its own")
	# Paging: a line is never split across two pages.
	var made_up: Array[Dictionary] = []
	for i: int in 5:
		made_up.append({speaker = Radio.CANOPY, text = "aaa bbb ccc ddd eee fff", wave = 1})
	# "W1 Canopy FM: aaa bbb ccc ddd" is 29 letters, so at 30 letters a row each
	# made-up line takes 2 rows, and a 5-row page holds 2 lines.
	var pages: Array = Logbook.pages_from(made_up, 5, 30)
	_check(pages.size() == 3 and pages[0].size() == 4 and pages[2].size() == 2, "rows pack onto pages, two lines of two rows per five-row page")
	_check(pages[1][0].first, "and every page starts on the first row of a line")
	# The cap: the oldest line goes.
	var full := Logbook.new()
	for i: int in CONFIG.logbook_max_entries + 5:
		full.add(Radio.CANOPY, "tip %d" % i, 1)
	_check(full.size() == CONFIG.logbook_max_entries and full.entries[0].text == "tip 5", "past logbook_max_entries the oldest lines are dropped")

	# --- In the arena: wave 1's lines go in as they are said. ---
	await _fresh_arena(true)  # with the Heart Tree, so its wave 1 line is said too
	_check(_arena.logbook.size() == 0 and _arena._pause.logbook == _arena.logbook, "a run starts with an empty book, shared with the pause menu")
	_arena.waves.time_scale = 0.0
	_arena.waves.start_wave(1)
	_check(not _arena.logbook.has_text(CONFIG.heart_intro_line), "a line still waiting for the radio is not in the book yet")
	_drain_radio()
	_check(_arena.logbook.has_text(CONFIG.heart_intro_line), "the Heart Tree line is in the book once said")
	var intro: Array[String] = CONFIG.dj_intro_touch if Arena._is_touch() else CONFIG.dj_intro
	_check(_arena.logbook.has_text(intro[0]) and _arena.logbook.has_text(intro[-1]), "and so is the controls tutorial")
	_check(not _arena.logbook.has_text(_arena.helios_line_for(1)), "Helios's wave 1 notice is not")
	# A restart says wave 1's lines again (and may add a fresh one, like the
	# repair tip when Seven comes back dented). No words are in the book twice.
	_arena._restart_current_wave()
	_drain_radio()
	var seen: Dictionary = {}
	var repeats: int = 0
	for entry: Dictionary in _arena.logbook.entries:
		if seen.has(entry.text):
			repeats += 1
		seen[entry.text] = true
	_check(repeats == 0 and _arena.logbook.has_text(CONFIG.heart_intro_line), "a restarted wave puts nothing in the book twice")

	# --- Static never gets into the book. ---
	_arena.radio_static_on = true
	var tip: String = "Lob it at a crowd or into a gateway they all have to squeeze through tonight."
	_arena._radio_urgent(Arena._radio_line(Radio.CANOPY, tip))
	_drain_radio()
	var clean: bool = true
	for entry: Dictionary in _arena.logbook.entries:
		clean = clean and not entry.text.contains("[static]")
	_check(_arena.logbook.has_text(tip) and clean, "the book keeps the clean words, never '[static]'")
	_arena.radio_static_on = false

	# --- Skill tips and Lucky. ---
	_arena.apply_upgrade(&"bramble_seed")
	_arena.waves.start_wave(2)
	_drain_radio()
	var bramble: Array[String] = CONFIG.dj_bramble_touch if Arena._is_touch() else CONFIG.dj_bramble
	_check(_arena.logbook.has_text(bramble[0]), "the Bramble Seed tip goes in at the wave after its card")
	_arena._radio_interrupt(_arena._lucky_says(CONFIG.lucky_greeting_early))
	_drain_radio()
	var newest: Dictionary = _arena.logbook.entries[-1]
	_check(newest.speaker == Radio.LUCKY and newest.text == CONFIG.lucky_greeting_early and newest.wave == 2, "Lucky's line goes in too, tagged with the wave")

	# --- The pause menu's Logbook button. ---
	var pause: PauseOverlay = _arena._pause
	_check(PauseOverlay.Item.LOGBOOK == PauseOverlay.ITEM_COUNT - 2 and pause.menu_label(PauseOverlay.Item.LOGBOOK).begins_with("6   Logbook"), "Logbook is button 6, just above Quit")
	pause.set_paused(true)
	_check(pause.logbook_page == -1, "a pause opens on this run's numbers")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_6
	key.pressed = true
	pause._input(key)
	_check(pause.logbook_page == 0 and get_tree().paused, "key 6 opens the Logbook's newest page, and the game stays paused")
	var page_count: int = _arena.logbook.pages().size()
	for i: int in page_count:
		pause.choose(PauseOverlay.Item.LOGBOOK)
	_check(pause.logbook_page == -1, "pressing it once per page steps through and back to this run's numbers")
	pause.choose(PauseOverlay.Item.LOGBOOK)
	pause.choose(PauseOverlay.Item.RESUME)
	pause.set_paused(true)
	_check(pause.logbook_page == -1, "the next pause opens on this run's numbers again")
	pause.choose(PauseOverlay.Item.RESUME)
	# An empty book still opens (on a "nothing yet" page) and closes again.
	var empty := PauseOverlay.new()
	empty.next_logbook_page()
	var opened: bool = empty.logbook_page == 0
	empty.next_logbook_page()
	_check(opened and empty.logbook_page == -1, "with no book yet, Logbook opens one empty page, then closes")
	empty.free()


## s23 FULL SCREEN: the pause menu gains a sixth button, above Quit, that switches
## full screen. Headless Godot has no real window, so these check the button, its
## words, where it sits and that pressing it keeps the menu up; whether a phone's
## browser really goes full screen needs a person with a phone.
func _test_s23_fullscreen() -> void:
	await _fresh_arena()
	var pause: PauseOverlay = _arena.get_node("Hud/PauseOverlay") as PauseOverlay
	# (s25 added Logbook as button 6, so Quit moved down to 7.)
	_check(PauseOverlay.Item.FULLSCREEN == 4 and PauseOverlay.Item.QUIT == PauseOverlay.ITEM_COUNT - 1, "Full screen is button 5, and Quit stays last")
	_check(PauseOverlay.fullscreen_available(), "outside a browser, full screen is always offered")
	_check(pause.menu_label(PauseOverlay.Item.FULLSCREEN).begins_with("5   Full screen: "), "its label reads '5   Full screen: On / Off'")
	_check(pause.menu_label(PauseOverlay.Item.QUIT).begins_with("%d   " % PauseOverlay.ITEM_COUNT), "Quit's key is the last number")
	# All the buttons, and the hint line under them, fit on the 720 px tall screen.
	var last: Rect2 = pause.menu_button_rect(PauseOverlay.ITEM_COUNT - 1)
	_check(last.end.y + 34.0 < 720.0, "all the buttons and the hint below them fit on screen")
	_check(CONFIG.fullscreen_lock_landscape, "a full-screen phone is asked to hold landscape")

	pause.set_paused(true)
	# A pretend click on the Full screen button, the way a player would press it.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = pause.menu_button_rect(PauseOverlay.Item.FULLSCREEN).get_center()
	pause._input(click)
	_check(get_tree().paused, "pressing Full screen keeps the menu up")
	# Key 5 presses it too (and puts the window back as it was).
	var key := InputEventKey.new()
	key.physical_keycode = KEY_5
	key.pressed = true
	pause._input(key)
	_check(get_tree().paused, "and so does key 5")
	_check(not PauseOverlay.is_fullscreen(), "after two presses the window is back as it was")
	pause.choose(PauseOverlay.Item.RESUME)
	_check(not get_tree().paused, "Resume still carries on")


## s22 RELOAD: the shooter holds seed_clip_size pods, reloads by itself when empty
## (or on R), each Quick Reload card takes time off, and a new wave refills it.
func _test_s22_reload() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	_check(InputMap.has_action(&"reload"), "input action 'reload' exists (R)")
	_check(CONFIG.seed_clip_size == 10 and is_equal_approx(CONFIG.reload_seconds, 3.0), "a load is 10 pods and the first reload is 3 s")
	_check(player.seeds_in_clip == CONFIG.seed_clip_size, "Seven starts with a full load")
	_check(not player.start_reload(), "R with a full load does nothing")

	# Fire the whole load. Clearing the private cooldown between shots skips the
	# 0.22 s wait, so the check does not have to sit through it.
	var fired: int = 0
	for i: int in CONFIG.seed_clip_size:
		player._fire_cooldown_left = 0.0
		if player.fire(Vector2.RIGHT):
			fired += 1
	_check(fired == CONFIG.seed_clip_size, "all %d pods of a load fire" % CONFIG.seed_clip_size)
	_check(player.is_reloading() and is_equal_approx(player.reload_left, CONFIG.reload_seconds), "the last pod starts a %.1f s reload by itself" % CONFIG.reload_seconds)
	player._fire_cooldown_left = 0.0
	_check(not player.fire(Vector2.RIGHT), "the 11th pod does not fire while reloading")

	# Let the reload run in game time. 170 physics frames is 2.83 s: not done yet.
	await _wait_frames_physics(170)
	_check(player.is_reloading() and player.seeds_in_clip == 0, "still reloading just before 3 s")
	var done: Callable = func() -> bool: return not player.is_reloading()
	_check(await _wait_until(done, 0.5), "the reload finishes at 3 s")
	_check(player.seeds_in_clip == CONFIG.seed_clip_size, "and the load is full again")
	player._fire_cooldown_left = 0.0
	_check(player.fire(Vector2.RIGHT), "and Seven can fire again")

	# R reloads early once a pod has gone.
	_check(player.start_reload(), "R with pods missing starts a reload")
	_check(not player.start_reload(), "a second R while reloading does nothing")

	# A new wave refills the load at once.
	_arena.waves.start_wave(2)
	_check(not player.is_reloading() and player.seeds_in_clip == CONFIG.seed_clip_size, "a new wave starts with a full load")

	# The Quick Reload card: 0.6 s off per pick, four picks, ending at 0.6 s.
	var expected: Array[float] = [3.0, 2.4, 1.8, 1.2, 0.6]
	for picks: int in expected.size():
		_check(is_equal_approx(Arena.reload_seconds_after(picks), expected[picks]), "after %d Quick Reloads the reload takes %.1f s" % [picks, expected[picks]])
	for i: int in CONFIG.upgrade_reload_max_picks:
		_check(not _arena.upgrades_left_out().has(&"quick_reload"), "Quick Reload is still dealt after %d picks" % i)
		_arena.apply_upgrade(&"quick_reload")
		_check(is_equal_approx(player.reload_seconds, expected[i + 1]), "pick %d: Seven's reload is now %.1f s" % [i + 1, expected[i + 1]])
	_check(_arena.upgrades_left_out().has(&"quick_reload"), "after %d picks Quick Reload is no longer dealt" % CONFIG.upgrade_reload_max_picks)
	# The shorter reload is the one really used.
	player.seeds_in_clip = 1
	player._fire_cooldown_left = 0.0
	player.fire(Vector2.RIGHT)
	_check(is_equal_approx(player.reload_left, 0.6), "with four picks a reload really takes 0.6 s")
	_check(UpgradePicker._describe(&"quick_reload") == "Reloads 0.6 s faster. Stacks 4 times.", "the Quick Reload card reads right")


## Lets `count` physics frames go by (one frame is 1/60 s of game time).
func _wait_frames_physics(count: int) -> void:
	for i: int in count:
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


## The spoken radio lines (audio/voice, made by tools/gen_voices.py): every line the
## radio can say has a recording, the recording matches the words now in the config,
## and the radio plays and stops it.
func _test_radio_voices() -> void:
	# 1. Every spoken variable has a file for every entry, and the words the tool
	#    spoke (manifest.json) are the words in the config today.
	var manifest_file: FileAccess = FileAccess.open("res://audio/voice/manifest.json", FileAccess.READ)
	_check(manifest_file != null, "the voice manifest is there")
	var manifest: Dictionary = {}
	if manifest_file != null:
		manifest = JSON.parse_string(manifest_file.get_as_text())
	var missing: Array[String] = []
	var stale: Array[String] = []
	var spoken_count: int = 0
	for variable: StringName in Radio.VOICE_VARS:
		var value: Variant = CONFIG.get(variable)
		var texts: Array = value if value is Array else [value]
		for index: int in texts.size():
			var id: String = "%s_%d" % [variable, index]
			spoken_count += 1
			if not ResourceLoader.exists("res://audio/voice/%s.mp3" % id):
				missing.append(id)
			if not manifest.has(id) or manifest[id]["text"] != texts[index]:
				stale.append(id)
	_check(missing.is_empty(), "every spoken line has a recording (%d lines; missing: %s)" % [spoken_count, ", ".join(missing)])
	_check(stale.is_empty(), "the recordings were made from today's words (run tools/gen_voices.py speak --force if not; stale: %s)" % ", ".join(stale))
	# 2. A line is found by its words, with the Sunburst number filled in as the arena sends it.
	_check(Radio.voice_path_for(CONFIG.helios_lines[0]) == "res://audio/voice/helios_lines_0.mp3", "Helios's first line finds its recording")
	_check(Radio.voice_path_for(CONFIG.sunburst_intro_line % CONFIG.sunburst_charges_per_wave).ends_with("sunburst_intro_line_0.mp3"), "the Sunburst tip finds its recording with its number filled in")
	_check(Radio.voice_path_for("Lucky speaks.") == "", "an unspoken line has no recording")
	# 3. The radio plays it, cuts it when a new line comes, and stops it when taken off the air.
	await _fresh_arena()
	var was_unlocked: bool = Sfx.is_unlocked
	var was_effects: bool = Sfx.effects_on
	Sfx.is_unlocked = true
	Sfx.effects_on = true
	var radio: Radio = _arena.radio
	radio.say(Radio.HELIOS, CONFIG.helios_lines[0], CONFIG.helios_lines[0])
	_check(radio.is_voice_playing(), "Helios's line is spoken")
	radio.say(Radio.LUCKY, "Lucky speaks.", "Lucky speaks.")
	_check(not radio.is_voice_playing(), "a line with no recording cuts the voice that was speaking")
	radio.say(Radio.CANOPY, CONFIG.dj_intro[0], CONFIG.dj_intro[0])
	_check(radio.is_voice_playing(), "a Canopy FM line is spoken")
	radio.clear()
	_check(not radio.is_voice_playing(), "taking the radio off the air stops the voice")
	Sfx.effects_on = false
	radio.say(Radio.HELIOS, CONFIG.helios_lines[0], CONFIG.helios_lines[0])
	_check(not radio.is_voice_playing(), "with Sound effects off there is no voice")
	Sfx.is_unlocked = was_unlocked
	Sfx.effects_on = was_effects


## Layer 3b: the ElevenLabs sounds. Every sound name the game plays must come
## from a real file in audio/sfx, not from a generated beep. AudioStreamMP3 is
## the type Godot gives an imported .mp3; the beeps are AudioStreamWAV.
func _test_every_sound_is_a_real_file() -> void:
	var names: Array[StringName] = [&"unlock", &"fire", &"thunk", &"plink", &"enemy_down", &"zip", &"grow",
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
	# Keep firing while we wait (fire() itself refuses to shoot faster than the
	# cooldown allows): a Scrapper takes scrapper_hp pods since s18 round 2.
	var down: Callable = func() -> bool:
		_arena.player.fire(Vector2.RIGHT)
		return not fell_at.is_empty()
	_check(await _wait_until(down, 3.0), "a Scrapper dies to %d pods" % CONFIG.scrapper_hp)
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
## Waits for `count` DRAWN frames. _process (where the arena updates the HUD,
## the tints and the sheets) runs once per drawn frame, and on a busy computer
## several physics frames can pass between two of them, so a check that needs
## _process to have run must wait with this and not with _wait_frames.
func _wait_drawn_frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame  # `process_frame` fires once per drawn frame


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
	# Three cells away: close enough that the pod lands before the Sawbot (faster
	# since s18) has walked out of its path.
	var sawbot: Sawbot = _arena.spawn_sawbot_at(player_cell + Vector2i(3, 0))
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
	_check(label.contains("Trees %d " % _arena.count_grown_trees()), "and how many trees are standing")
	_check(label.contains("Brambles %d / %d" % [_arena.player.bramble_charges, CONFIG.bramble_max_charges]), "and how many Bramble Seeds Seven holds")


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
	# s18 round 5: a restart gives at most 80% of full health (restart_hp_cap_share).
	_check(_arena.player.hp == floori(float(CONFIG.player_max_hp) * CONFIG.restart_hp_cap_share), "with health capped at 80%")
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
		# dot() of two unit vectors is 1 when they point the same way. (The
		# Spitter may have stepped aside to hide first, so "left" is no longer exact.)
		var to_player: Vector2 = (player.global_position - spitter.global_position).normalized()
		_check(shot.direction.dot(to_player) > 0.97, "the shot flies straight at the player")

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
	_check(not shop.is_neon_showing(), "a closed shop shows no neon paw (it is not a clue)")
	# The flicker: steady at full brightness, and a stutter between dim and bright at
	# the start of every period.
	var period: float = CONFIG.neon_flicker_period
	var stutter: float = CONFIG.neon_flicker_seconds
	_check(is_equal_approx(CatShop.neon_level(stutter + 0.1, period, stutter), 1.0), "the neon burns steady between flickers")
	_check(is_equal_approx(CatShop.neon_level(0.0, period, stutter), 0.25) and is_equal_approx(CatShop.neon_level(CatShop.NEON_STUTTER_STEP * 1.5, period, stutter), 1.0), "the neon stutters dim, bright at the start of each period")
	_check(is_equal_approx(CatShop.neon_level(period + 0.0, period, stutter), 0.25), "and it flickers again every period")
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
	_check(shop.is_neon_showing(), "once open, the neon paw sign shows")
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
	var radio: Radio = _arena.radio
	_check(not radio.is_on(), "the radio is quiet before a wave starts")
	_check(_arena.graffiti.revealed_count == 0, "the walls start clean")
	_check(_arena.helios_line_for(1).contains(CONFIG.helios_lines[0]), "wave 1 has Helios's first line")
	_check(_arena.helios_line_for(99) == "", "a wave with no line gets none")

	# Start wave 2 directly. The very first wave start of a run shows the hook.
	# Seven stands still through this whole test while wave 2 walks in. Make it
	# unhittable, or a knock-out (and its slow motion) would upset the timing.
	_arena.player._invulnerable_left = 999.0
	_arena.waves.time_scale = 20.0
	_arena.waves.start_wave(2)
	_check(radio.speaker == Radio.CANOPY and radio.text == CONFIG.story_hook, "the first wave start: Canopy FM says the opening line")
	# Let the opening line run out; Helios's notice follows it.
	var helios_showing: Callable = func() -> bool: return radio.text == _arena.helios_line_for(2)
	var hook_seconds: float = CONFIG.story_line_seconds + CONFIG.story_hook.length() / CONFIG.radio_chars_per_second
	_check(await _wait_until(helios_showing, hook_seconds + 1.0), "then Helios's line for that wave")
	_check(radio.speaker == Radio.HELIOS, "spoken by Helios")

	# Clear the wave: one painted line per wave cleared so far, and Helios goes quiet.
	var all_sent: Callable = func() -> bool: return _arena.waves.state == WaveDirector.State.FIGHTING
	await _wait_until(all_sent, 4.0)
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		(node as Enemy).take_damage(99)
	_check(_arena.graffiti.revealed_count == 2, "clearing wave 2 puts two lines on the walls")
	_check(_arena.graffiti.line_text(1) == CONFIG.graffiti_lines[1], "the second is wave 2's line")
	_check(radio.is_on() and radio.text == _arena.helios_line_for(2), "clearing the wave does not cut off the line on the air (s18)")

	# Painted lines never come off, and the opening line never repeats.
	_arena.graffiti.reveal_up_to(1)
	_check(_arena.graffiti.revealed_count == 2, "revealing an earlier wave removes nothing")
	_arena.waves.start_wave(1)
	_check(_arena._is_radio_pending(_arena.helios_line_for(1)) and not _arena._is_radio_pending(CONFIG.story_hook), "a later wave start queues its notice and skips the opening line")

	# Canopy FM teaches: wave 1's tutorial follows Helios; the cat hints come on
	# their waves only while the shop is shut.
	var wave_1_dj: Array[String] = _arena.dj_lines_for_wave(1)
	_check(not wave_1_dj.is_empty() and wave_1_dj[0] == CONFIG.dj_intro[0], "on wave 1 Canopy FM explains the controls")
	var hint_wave: int = CONFIG.dj_cat_hint_waves[0]
	_check(_arena.dj_lines_for_wave(hint_wave).has(CONFIG.dj_cat_hints[0]), "on wave %d Canopy FM hints at the cat" % hint_wave)
	for i: int in CONFIG.cat_hits_needed:
		_arena.cat_shop.hit_by_seed()
	_check(not _arena.dj_lines_for_wave(hint_wave).has(CONFIG.dj_cat_hints[0]), "no cat hints once Lucky is found")
	_arena._dj_once(&"sawbot", CONFIG.dj_first_sawbot)
	var queued: int = _arena._story_queue.size()
	_arena._dj_once(&"sawbot", CONFIG.dj_first_sawbot)
	_check(_arena._story_queue.size() == queued, "each Canopy FM tip plays once per run")


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
	_check(windows.lit_count == _arena.lit_windows_now() + _arena.tap_bonus_windows(), "clearing waves lights more windows")
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
	_check(_arena.radio.speaker == Radio.HELIOS and _arena.radio.text == CONFIG.helios_end_line, "Helios's last line stays on the radio")
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
	# Seven in the locked design faces the viewer and mirrors to follow the aim.
	await _fresh_arena()
	var seven: Player = _arena.player
	var seven_sprite: Sprite2D = seven.get_node("Sprite2D")
	seven.touch_mode = true          # so the aim comes from aim_direction, not the mouse
	seven.aim_direction = Vector2.LEFT
	await _wait_frames(3)
	_check(not seven_sprite.flip_h and is_zero_approx(seven_sprite.rotation), "aiming left shows the West frame, not a mirror, and no lean")
	_check(seven_sprite.frame == 4, "aiming left picks the West frame (4), got %d" % seven_sprite.frame)
	seven.aim_direction = Vector2.RIGHT
	await _wait_frames(3)
	_check(seven_sprite.frame == 0, "aiming right picks the East frame (0), got %d" % seven_sprite.frame)
	# All eight compass points, then the angles in between rounding to the nearest frame.
	var compass: Array[Vector2] = [Vector2.RIGHT, Vector2(1, 1), Vector2.DOWN, Vector2(-1, 1), Vector2.LEFT, Vector2(-1, -1), Vector2.UP, Vector2(1, -1)]
	var every_frame_right: bool = true
	for i: int in compass.size():
		every_frame_right = every_frame_right and Player.facing_frame(compass[i], 8) == i
	_check(every_frame_right, "each of the eight compass aims picks its own facing frame")
	_check(Player.facing_frame(Vector2.from_angle(deg_to_rad(-10.0)), 8) == 0, "aiming a little above East still picks East")
	_check(Player.facing_frame(Vector2.from_angle(deg_to_rad(-30.0)), 8) == 7, "aiming 30 degrees above East picks North-East")
	_check(seven_sprite.hframes == CONFIG.player_facing_count, "Seven's sprite is cut into one frame per facing")
	var facings: Texture2D = CONFIG.player_facings_texture
	_check(facings != null and facings.get_size() == Vector2(64.0 * CONFIG.player_facing_count, 64.0), "the facings strip is one 64 x 64 frame per facing")
	var repair: Texture2D = CONFIG.repair_icon_texture
	_check(repair != null and repair.get_size() == Vector2(64.0, 64.0), "the repair icon is 64 x 64")
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
	# Let the fuse's "cannot be hurt" time run out (60 physics frames a second).
	await _wait_frames(int(CONFIG.fuse_invulnerable_time * 60.0) + 30)
	player.take_damage(CONFIG.player_max_hp)
	_check(player.is_dead, "without a fuse the next deadly hit downs Seven")

	# s18 round 4: a defeat does NOT refit it. One fuse, once per run.
	player.revive(player.global_position)
	_check(not player.has_fuse, "a defeat (the wave restart) does not refit the fuse: once per run")


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
	# No floor arrow or words ever point at the shop: finding it is the player's job.
	_arena.waves.start_wave(5)
	_check(not ("show_knock" in _arena.graffiti), "nothing is painted on the floor pointing at the shop")
	for i: int in CONFIG.cat_hits_needed:
		shop.hit_by_seed()
	_check(_arena.lucky_found_wave >= 1, "the arena remembers the wave Lucky was found in")

	var first: String = _arena.talk_to_lucky()
	var second: String = _arena.talk_to_lucky()
	_check(first != "" and second != "" and first != second, "talking again gives the next line")
	var hp_before: int = _arena.player.hp
	_check(_arena.player.hp == hp_before and _arena.player.can_bind, "talking changes nothing in the game")
	_arena.player.global_position = shop.global_position + Vector2(0.0, 2.0 * CONFIG.cell_size)
	_check(_arena.is_near_lucky(), "standing just below the shop is close enough to talk")
	_arena.player.global_position = _arena.grid.cell_to_world(Vector2i(3, 12))
	_check(not _arena.is_near_lucky(), "across the lot is too far")


## Canopy FM: four stations with real song files; the muffle filter opens as the
## block lights; a felled tree dulls the radio for a moment.
func _test_canopy_fm() -> void:
	for id: StringName in CanopyFM.STATIONS:
		_check(ResourceLoader.exists(CanopyFM.STATIONS[id]), "the %s station has its song" % id)
	_check(CanopyFM.STATIONS.size() == 4, "four stations")
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


## Tap points (story step 5): soil patches from wave 2; a tree grown on one is a
## tap tree that heals Seven, lights extra windows, has more HP, and survives a
## wave restart as a tap tree.
func _test_tap_points() -> void:
	await _fresh_arena()
	_arena.waves.start_wave(CONFIG.tap_points_from_wave - 1)
	_check(_arena.tap_points.is_empty(), "no tap points before wave %d" % CONFIG.tap_points_from_wave)
	_arena.waves.start_wave(CONFIG.tap_points_from_wave)
	_check(_arena.tap_points.size() == CONFIG.tap_points_per_wave, "wave %d has %d tap points" % [CONFIG.tap_points_from_wave, CONFIG.tap_points_per_wave])
	var cell: Vector2i = _arena.tap_points[0]
	_check(not _arena.grid.is_solid(cell) and _arena.tree_at(cell) == null, "a tap point is open floor")

	var player: Player = _arena.player
	player.take_damage(2)
	var hp_before: int = player.hp
	var lit_before: int = _arena.windows.lit_count
	var tree: ForestTree = _arena.spawn_tree(cell, false)
	_check(tree.is_tap and not _arena.tap_points.has(cell), "a tree on a tap point is a tap tree, and the patch is used up")
	_check(tree.max_hp() == CONFIG.tree_hp * CONFIG.tap_tree_hp_multiplier, "a tap tree is slow to saw (more HP)")
	player.global_position = _arena.grid.cell_to_world(Vector2i(2, 2))  # stand clear of the cell
	_arena._on_tree_ready_to_solidify(tree)
	_check(tree.stage == ForestTree.Stage.GROWN, "the tap tree grows")
	_check(player.hp == mini(hp_before + CONFIG.tap_tree_heal, CONFIG.player_max_hp), "it heals Seven by %d" % CONFIG.tap_tree_heal)
	_check(_arena.windows.lit_count == mini(lit_before + CONFIG.tap_tree_bonus_windows, _arena.windows.window_count()),
		"it lights %d more windows" % CONFIG.tap_tree_bonus_windows)

	# A restart of the wave replants it as a tap tree.
	_arena.waves.start_wave(_arena.waves.wave)   # snapshot the forest, as a new wave does
	_arena._restart_current_wave()
	await _wait_frames(2)
	var replanted: ForestTree = _arena.tree_at(cell)
	_check(replanted != null and replanted.is_tap, "a wave restart replants it as a tap tree")

	# Felling it puts its extra windows out again.
	replanted.take_damage(999)
	await _wait_frames(3)
	_check(_arena.tap_bonus_windows() == 0, "felling it takes its extra windows away")


## New Game +: locked until a win, then harder waves (50% more machines, rounded
## up, sent faster, no staged tutorial), great sunroots, and a station picker.
func _test_new_game_plus() -> void:
	var was_unlocked: bool = RunState.ng_plus_unlocked
	# The title screen: New Game + locked, no station picker.
	RunState.ng_plus_unlocked = false
	var title: Control = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await _wait_frames(2)
	_check(title.ng_plus_button.disabled and not title.station_button.visible, "before a win: New Game + locked, no station picker")
	RunState.ng_plus_unlocked = true
	title.refresh()
	_check(not title.ng_plus_button.disabled and title.station_button.visible, "after a win: New Game + and the station picker open")
	var station_before: StringName = CanopyFM.station
	title.station_button.pressed.emit()
	_check(CanopyFM.station != station_before, "the station button changes the station")
	CanopyFM.set_station(station_before)
	title.queue_free()

	# A New Game + arena.
	await _fresh_arena()
	var normal_wave_3: int = _arena.waves.machines_in_wave(3)
	_arena.apply_ng_plus()
	var hard_wave_3: int = _arena.waves.machines_in_wave(3)
	_check(hard_wave_3 >= ceili(normal_wave_3 * CONFIG.ng_plus_count_multiplier) - 2 and hard_wave_3 > normal_wave_3,
		"New Game + sends about 50%% more machines (wave 3: %d -> %d)" % [normal_wave_3, hard_wave_3])
	_check(_arena.waves.staged_wave_count() == 0, "no staged tutorial wave in New Game +")

	# Great sunroots: a tree grown at wave start and standing at wave clear matures.
	_arena.waves.start_wave(2)  # snapshots the forest: the three hand-placed trees are grown
	var tree: ForestTree = _arena.tree_at(Arena.TEST_TREE_CELLS[0])
	# It must stand through great_sunroot_waves_needed waves: one short is not enough.
	for i: int in CONFIG.great_sunroot_waves_needed - 1:
		_arena.mature_trees()
	_check(not tree.is_great, "one wave short, the tree is not a great sunroot yet")
	_arena._on_wave_cleared(2)
	_check(tree.is_great, "a tree that stood through %d waves matures into a great sunroot" % CONFIG.great_sunroot_waves_needed)
	_check(tree.hp == CONFIG.tree_hp * CONFIG.great_sunroot_hp_multiplier, "with %dx the hit points" % CONFIG.great_sunroot_hp_multiplier)
	_check(tree.current_texture() == CONFIG.tree_great_texture, "and the stage 4 picture")
	var fresh: ForestTree = _arena.spawn_tree(Vector2i(8, 8), true)
	_arena._on_wave_cleared(3)
	_check(not fresh.is_great, "a tree planted after the wave started does not mature yet")

	# Any win unlocks New Game +, even one where the lucky cat was never found.
	await _fresh_arena()
	RunState.ng_plus_unlocked = false
	_check(not _arena.cat_shop.is_open, "(this run never opened Lucky's shop)")
	_arena._on_all_waves_cleared()
	_check(RunState.ng_plus_unlocked, "a win without finding Lucky still unlocks New Game +")

	RunState.ng_plus_unlocked = was_unlocked
	RunState.just_unlocked = false
	RunState.save()  # put the save file back the way it was


## Great sunroots' powers (great_powers.gd): Canopy lines between pairs that can
## see each other, which bind machines crossing them, and the Sunburst on a zip.
func _test_great_powers() -> void:
	await _fresh_arena()
	var powers: GreatPowers = _arena.great_powers
	await _wait_frames(2)
	_check(powers.lines.is_empty(), "no great sunroots, no Canopy lines (a normal run)")

	# Two great trees 6 cells apart with a clear view: one cable.
	var a: ForestTree = _arena.spawn_tree(Vector2i(3, 12), true)
	var b: ForestTree = _arena.spawn_tree(Vector2i(9, 12), true)
	a.mature()
	b.mature()
	await _wait_frames(2)
	_check(powers.lines.size() == 1, "two great sunroots that see each other string a Canopy line")
	_check(powers.is_charged(powers.lines[0]), "a new line is charged")

	# A machine walking across the cable is caught, and the cable recharges.
	var scrapper: Scrapper = _arena.spawn_scrapper_at(Vector2i(6, 12))
	await _wait_frames(2)
	_check(scrapper.is_snared, "a machine on the Canopy line is snared")
	_check(not powers.is_charged(powers.lines[0]), "then the line recharges before it catches again")

	# A wall of wood between them: a third (ordinary) tree blocks the view.
	var c: ForestTree = _arena.spawn_tree(Vector2i(3, 2), true)
	var d: ForestTree = _arena.spawn_tree(Vector2i(9, 2), true)
	c.mature()
	d.mature()
	_arena.spawn_tree(Vector2i(6, 2), true)
	await _wait_frames(2)
	_check(powers.lines.size() == 1, "a tree in between blocks a Canopy line")

	# Too far apart: no line.
	var far: ForestTree = _arena.spawn_tree(Vector2i(9 + int(CONFIG.canopy_line_range_cells) + 2, 12), true)
	far.mature()
	await _wait_frames(2)
	_check(powers.lines.size() == 1, "great sunroots too far apart make no line")

	# Sunburst: zipping to a great sunroot stuns the machines around it.
	var near: Scrapper = _arena.spawn_scrapper_at(Vector2i(4, 10))
	_check(powers.sunburst(a.global_position) >= 1, "a Sunburst stuns the machines near the great tree")
	_check(not is_instance_valid(near) or near.is_dead or near.is_bound, "the machine in range is stunned (or downed)")
	_check(powers.sunburst(a.global_position) == -1, "a second Sunburst waits for the cooldown")
	powers.sunburst_cooldown_left = 0.0
	powers.sunburst_charges = 1  # a fresh charge (a wave now gives one, not two)
	_arena.player.zip_tree = b
	_arena._on_player_zip_finished()
	_check(powers.sunburst_cooldown_left > 0.0, "a zip that ends at a great sunroot sets off its Sunburst")
	powers.sunburst_cooldown_left = 0.0
	_arena.player.zip_tree = _arena.tree_at(Arena.TEST_TREE_CELLS[0])
	_arena._on_player_zip_finished()
	_check(powers.sunburst_cooldown_left == 0.0, "a zip to an ordinary tree does not")


## The Trellis: a zip from beside one tree to another leaves a vine between them
## for a few seconds, which snares each machine crossing it once.
func _test_trellis() -> void:
	await _fresh_arena()
	var powers: GreatPowers = _arena.great_powers
	var a: ForestTree = _arena.spawn_tree(Vector2i(3, 12), true)
	var b: ForestTree = _arena.spawn_tree(Vector2i(9, 12), true)
	# Pretend Seven zipped from right beside tree a to tree b.
	_arena.player.zip_from = a.global_position + Vector2(CONFIG.cell_size, 0.0)
	_arena.player.zip_tree = b
	_arena._on_player_zip_finished()
	_check(powers.trellises.size() == 1, "a zip from one tree to another strings a trellis")
	var scrapper: Scrapper = _arena.spawn_scrapper_at(Vector2i(6, 12))
	await _wait_frames(2)
	_check(scrapper.is_snared, "a machine crossing the trellis is snared")
	# A zip that did not start beside a tree strings nothing.
	_arena.player.zip_from = _arena.grid.cell_to_world(Vector2i(20, 7))
	_arena._on_player_zip_finished()
	_check(powers.trellises.size() == 1, "a zip from open ground strings no trellis")
	var gone: Callable = func() -> bool: return powers.trellises.is_empty()
	_check(await _wait_until(gone, CONFIG.trellis_seconds + 1.0), "the trellis withers after %d seconds" % CONFIG.trellis_seconds)


## The Heart Tree: a tough tree in the middle that Sawbots go for first; if it
## falls the wave starts again, and it heals between waves.
func _test_heart_tree() -> void:
	await _fresh_arena(true)
	var heart: ForestTree = _arena.heart_tree
	_check(heart != null and heart.is_heart and heart.cell == Arena.HEART_TREE_CELL, "the Heart Tree stands in the middle of the lot")
	_check(heart.hp == CONFIG.tree_hp * CONFIG.heart_tree_hp_multiplier, "with %dx a tree's hit points" % CONFIG.heart_tree_hp_multiplier)
	# A Sawbot a little nearer to an ordinary tree still heads for the Heart.
	var sawbot: Sawbot = _arena.spawn_sawbot_at(Vector2i(13, 9))  # 1 cell from (13, 10), 2 from the Heart
	_check(sawbot._nearest_tree(ForestTree.Stage.GROWN, INF) == heart, "a Sawbot goes for the Heart Tree first")
	sawbot.take_damage(99)
	# Hurt it, then clear a wave: it heals.
	heart.take_damage(3)
	_arena._on_wave_cleared(1)
	_check(heart.hp == heart.max_hp(), "the Heart Tree heals between waves")
	# Fell it during a wave: the wave starts again, with the Heart replanted.
	_arena.waves.start_wave(2)
	var felled: Array[bool] = [false]
	_arena.heart_tree_felled.connect(func() -> void: felled[0] = true)
	heart.take_damage(heart.hp)
	_check(felled[0], "felling the Heart Tree loses the wave")
	var replanted: Callable = func() -> bool: return is_instance_valid(_arena.heart_tree) and _arena.heart_tree.is_heart
	_check(await _wait_until(replanted, CONFIG.death_restart_delay + 1.0), "and the wave restarts with the Heart Tree replanted")


## The late-wave machines: Linebreakers (heavy Scrappers) and Arc Spitters
## (three-shot fans), and the waves that send them.
func _test_new_machines() -> void:
	await _fresh_arena()
	var heavy: Scrapper = _arena.spawn_scrapper_at(Vector2i(20, 12), true)
	await _wait_frames(1)
	_check(heavy.hp == CONFIG.linebreaker_hp, "a Linebreaker has %d hit points" % CONFIG.linebreaker_hp)
	_check(is_equal_approx(heavy.scale.x, CONFIG.linebreaker_scale), "and is bigger than a Scrapper")
	var arc: Spitter = _arena.spawn_spitter_at(Vector2i(20, 3), true)
	await _wait_frames(1)
	var shots: Array[Vector2] = []
	arc.spat.connect(func(_origin: Vector2, direction: Vector2, _electric: bool) -> void: shots.append(direction))
	arc._fire(Vector2.LEFT * 100.0)
	_check(shots.size() == 3, "an Arc Spitter fires a fan of three shots")
	# The waves: none of either early on; both by the last wave.
	var director: WaveDirector = _arena.waves
	var last: int = director.total_waves()
	_check(not director._build_queue(1).has(WaveDirector.LINEBREAKER), "no Linebreakers in wave 1")
	_check(director._build_queue(last).has(WaveDirector.LINEBREAKER), "Linebreakers in the last wave")
	_check(director._build_queue(last).has(WaveDirector.ARC_SPITTER), "Arc Spitters in the last wave")


## Between-wave upgrades: clearing a wave deals the cards and holds the next
## wave; picking one applies it and lets the next wave come.
func _test_upgrades() -> void:
	await _fresh_arena()
	var picker: UpgradePicker = _arena.upgrade_picker
	_check(not picker.is_open(), "no upgrade cards before a wave is cleared")
	for id: StringName in UpgradePicker.CATALOG.keys():
		_check(picker.has_icon(id), "the '%s' card has its picture" % id)
	_arena.waves.start_wave(2)  # wave 1 is the staged tutorial: one machine at a time
	var all_sent: Callable = func() -> bool: return _arena.waves.state == WaveDirector.State.FIGHTING
	_arena.waves.time_scale = 20.0
	await _wait_until(all_sent, 4.0)
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		(node as Enemy).take_damage(99)
	_check(picker.is_open() and picker.offered.size() == CONFIG.upgrade_choices, "clearing a wave deals %d upgrade cards" % CONFIG.upgrade_choices)
	_check(_arena.waves.hold_break, "and the next wave waits for a pick")
	picker.choose(0)
	_check(not picker.is_open() and not _arena.waves.hold_break, "picking one closes the cards and lets the next wave come")
	_check(_arena.upgrades_taken.size() == 1, "the pick is recorded")

	# Each upgrade does what its card says.
	var player: Player = _arena.player
	var hp_before: int = player.max_hp
	_arena.apply_upgrade(&"thick_plating")
	_check(player.max_hp == hp_before, "Patch Kit: no extra max health")
	_arena.apply_upgrade(&"seed_pouch")
	_check(player.fire_cooldown_scale < 1.0, "Seed Pouch: pods come faster")
	# Compare with the bonus before: an earlier step in this test may have picked a
	# random card, Heavy Seeds included, so the bonus does not always start at zero.
	var bonus_before: float = _arena.seed_damage_bonus
	_arena.apply_upgrade(&"heavy_seeds")
	_check(is_equal_approx(_arena.seed_damage_bonus - bonus_before, CONFIG.upgrade_seed_damage), "Heavy Seeds: pods hit harder, by %.1f" % CONFIG.upgrade_seed_damage)
	_arena.apply_upgrade(&"heavy_seeds")
	_check(is_equal_approx(_arena.seed_damage_bonus - bonus_before, 2.0 * CONFIG.upgrade_seed_damage), "Heavy Seeds stacks: two picks add twice")
	_check(is_equal_approx(CONFIG.upgrade_seed_damage, 0.5), "Heavy Seeds adds half a point of damage")
	# A fractional hit: the machine keeps the leftover half for its next hit.
	var target: Scrapper = _arena.spawn_scrapper_at(Vector2i(20, 3))
	var target_hp: int = target.hp
	target.take_damage(1.5)
	_check(target.hp == target_hp - 1, "a 1.5 hit takes 1 point and keeps the half")
	target.take_damage(1.5)
	_check(target.hp == target_hp - 3, "the next 1.5 hit takes 2: 3 points over two hits")
	var standing: ForestTree = _arena.tree_at(Arena.TEST_TREE_CELLS[0])
	var tree_hp_before: int = standing.hp
	_arena.apply_upgrade(&"hardwood")
	_check(standing.hp == tree_hp_before + CONFIG.upgrade_tree_hp, "Hardwood: trees already standing get more hit points")
	var planted: ForestTree = _arena.spawn_tree(Vector2i(4, 12), true)
	_check(planted.max_hp() == CONFIG.tree_hp + _arena.tree_hp_bonus, "and so do new trees")
	# (Measure the change: the random first pick above may already have been Long Trellis.)
	var trellis_before: float = _arena.great_powers.trellis_bonus_seconds
	_arena.apply_upgrade(&"long_trellis")
	_check(is_equal_approx(_arena.great_powers.trellis_bonus_seconds - trellis_before, CONFIG.upgrade_trellis_seconds), "Long Trellis: trellis vines last longer")
	# (Count from what is already taken: the random first pick may have been Quick Roots.)
	var roots_before: int = _arena.quick_roots_taken
	var gain: float = CONFIG.upgrade_sapling_rate_gain
	_arena.apply_upgrade(&"quick_roots")
	# Rooting RATE goes up 15% a pick, so the TIME is divided by 1.15, then 1.30...
	_check(is_equal_approx(_arena.sapling_time_scale, 1.0 / (1.0 + gain * float(roots_before + 1))), "Quick Roots: saplings root %d%% faster" % roundi(gain * 100.0))
	_arena.apply_upgrade(&"quick_roots")
	_check(is_equal_approx(_arena.sapling_time_scale, 1.0 / (1.0 + gain * float(roots_before + 2))), "a second Quick Roots stacks: the rates add up")
	# Seed Pouch multiplies the time between pods each pick, so it stacks as well.
	var pouch_before: float = player.fire_cooldown_scale
	_arena.apply_upgrade(&"seed_pouch")
	_check(is_equal_approx(player.fire_cooldown_scale, pouch_before * CONFIG.upgrade_fire_cooldown_factor), "a second Seed Pouch stacks too")
	for id: StringName in UpgradePicker.CATALOG.keys():
		_check(UpgradePicker._describe(id).find("%d") == -1, "the %s card's text is filled in" % id)


## The art pass: props from concept 05_props_b (corner props are solid), and
## Lucky's two-frame wave.
func _test_props_and_lucky_art() -> void:
	_check(CONFIG.props_texture != null and CONFIG.props_texture.get_width() == Props.FRAMES.size() * 64, "the props picture holds one 64 px frame per prop")
	_check(CONFIG.cat_wave_texture != null, "Lucky has a second, paw-down frame")
	await _fresh_arena()
	var props: Props = _arena.props
	_check(props.solid_cells.size() == 4, "four solid props, one per floor corner")
	for cell: Vector2i in props.solid_cells:
		_check(_arena.grid.is_solid(cell), "machines path around the prop at %s" % cell)
	_check(not _arena._spawn_candidates().has(props.solid_cells[0]), "and no machine spawns inside one")


## The third seed type: Bramble Seeds. Thrown toward the aim, they grow a thorn
## patch that slows and hurts machines; Seven holds a few and they grow back.
func _test_bramble_seed() -> void:
	_check(InputMap.has_action(&"bramble"), "the bramble action exists (Q / Space)")
	await _fresh_arena()
	var player: Player = _arena.player
	_check(player.bramble_charges == CONFIG.bramble_max_charges, "Seven starts with %d Bramble Seeds" % CONFIG.bramble_max_charges)
	player.aim_direction = Vector2.RIGHT
	_check(player.throw_bramble(), "a Bramble Seed can be thrown")
	_check(player.bramble_charges == CONFIG.bramble_max_charges - 1, "it uses one seed")
	var patches: Array[Node] = _arena.get_node("Brambles").get_children()
	_check(patches.size() == 1, "and a thorn patch grows")
	var patch: Bramble = patches[0]
	var expected: Vector2 = player.global_position + Vector2.RIGHT * CONFIG.bramble_range_cells * CONFIG.cell_size
	_check(patch.global_position.distance_to(expected) < 1.0, "%d cells out along the aim" % CONFIG.bramble_range_cells)

	# A machine in the thorns is slowed and hurt on each tick.
	var scrapper: Scrapper = _arena.spawn_scrapper_at(_arena.grid.world_to_cell(patch.global_position), true)  # a Linebreaker: enough hit points to survive
	await _wait_frames(3)
	_check(scrapper.is_slowed(), "a machine in the thorns is slowed")
	var hp_before: int = scrapper.hp
	await _wait_frames(int(CONFIG.bramble_tick_seconds * 60.0) + 5)
	_check(not is_instance_valid(scrapper) or scrapper.hp < hp_before, "and loses hit points")

	# Throws stop at zero seeds, then they grow back.
	while player.bramble_charges > 0:
		player.throw_bramble()
	_check(not player.throw_bramble(), "no seeds, no throw")
	var grown_back: Callable = func() -> bool: return player.bramble_charges >= 1
	_check(await _wait_until(grown_back, CONFIG.bramble_recharge_seconds + 1.0), "a seed grows back after %d s" % CONFIG.bramble_recharge_seconds)

	# A throw at a wall lands on the floor at its foot.
	var at_wall: Bramble = _arena.spawn_bramble(Vector2(-500.0, -500.0))
	_check(not _arena.grid.is_solid(_arena.grid.world_to_cell(at_wall.global_position)) or _arena.props.solid_cells.has(_arena.grid.world_to_cell(at_wall.global_position)), "a throw at a wall lands on the floor")
	# A weak reference does not keep the patch alive, and reads null once it is freed.
	var patch_ref: WeakRef = weakref(patch)
	var withered: Callable = func() -> bool: return patch_ref.get_ref() == null
	_check(await _wait_until(withered, CONFIG.bramble_seconds + 1.0), "the patch withers after %d s" % CONFIG.bramble_seconds)


## s18, the "no sound at all on the web build" bug. In a browser, Godot 4.7.2
## wires any second audio bus into a closed loop with Master, so nothing reaches
## the speakers (the full story is on CanopyFM.uses_music_bus). The fix: the web
## build makes no extra bus. Headless tests cannot hear a browser, so these guard
## the cause; the real proof is the web export measured in a browser.
func _test_web_build_has_no_extra_audio_bus() -> void:
	_check(not CanopyFM.uses_music_bus(true), "the web build makes no extra audio bus (one silences every sound there)")
	_check(CanopyFM.uses_music_bus(false), "desktop builds keep the Music bus and its filter")
	# These tests run on desktop, so here the bus does exist. Exactly one extra
	# bus: if another script ever adds one, the web build needs the same care.
	var music: int = AudioServer.get_bus_index(CanopyFM.BUS_NAME)
	_check(music == 1 and AudioServer.bus_count == 2, "Master and Music are the only audio buses")
	if music < 0:
		return  # the checks below would only print engine errors
	_check(AudioServer.get_bus_send(music) == &"Master", "the Music bus feeds Master, so mute covers the radio")
	_check(not AudioServer.is_bus_mute(0) and not AudioServer.is_bus_mute(music), "the game starts with sound on")
	var filter := AudioServer.get_bus_effect(music, 0) as AudioEffectLowPassFilter
	_check(filter != null, "the Music bus carries the low-pass filter")
	if filter == null:
		return
	# Canopy FM must be steering THIS filter (the one on the bus), not a spare copy:
	# light the block fully and the cutoff on the bus has to climb.
	# An arena reports its own light level every frame, which would overwrite ours,
	# so remove the one the previous test left behind first.
	if _arena != null:
		_arena.queue_free()
		_arena = null
		await get_tree().physics_frame
	# Start from a known state: a dark block, with any "tree was cut" dulling over.
	# (await pauses this function until _wait_until has finished its own waiting.)
	CanopyFM.set_light(0.0)
	var closed: Callable = func() -> bool: return not CanopyFM.is_dulled() and filter.cutoff_hz < CONFIG.music_cutoff_dark_hz * 1.2
	await _wait_until(closed, CONFIG.music_dull_seconds + 4.0)
	var before: float = filter.cutoff_hz
	CanopyFM.set_light(1.0)
	var opened: Callable = func() -> bool: return filter.cutoff_hz > before * 1.5
	_check(await _wait_until(opened, 3.0), "lighting the block opens the filter on the Music bus")
	CanopyFM.set_light(0.0)


## s18, the New Game + overload: 70+ great sunroots each linked to every other,
## which lagged the game, hid the machines and held one Sawbot for two minutes.
## Now cables are capped, are worked out only when the forest changes, and a
## machine that a cable lets go is left alone for a few seconds.
func _test_canopy_line_caps() -> void:
	await _fresh_arena()
	var powers: GreatPowers = _arena.great_powers

	# Fill the lot with 60 great sunroots, row by row. spawn_tree returns null
	# for a wall, a prop or a taken cell, so those are simply skipped.
	var planted: int = 0
	for y: int in CONFIG.grid_rows:
		for x: int in CONFIG.grid_cols:
			if planted >= 60:
				break
			var tree: ForestTree = _arena.spawn_tree(Vector2i(x, y), true)
			if tree != null:
				tree.mature()
				planted += 1
	_check(planted == 60, "the lot has room for the 60 great sunroots this check needs (got %d)" % planted)
	await _wait_frames(3)
	_check(not powers.lines.is_empty(), "60 great sunroots string some Canopy lines")
	_check(powers.lines.size() <= CONFIG.canopy_line_max, "60 great sunroots stay under the cap of %d lines (got %d)" % [CONFIG.canopy_line_max, powers.lines.size()])
	# Count the cables each tree holds: none may have more than its share.
	var links: Dictionary[int, int] = {}
	for line: Dictionary in powers.lines:
		for tree: ForestTree in [line.a, line.b]:
			links[tree.get_instance_id()] = links.get(tree.get_instance_id(), 0) + 1
	var most: int = 0
	for count: int in links.values():
		most = maxi(most, count)
	_check(most <= CONFIG.canopy_line_links_per_tree, "no great sunroot holds more than %d lines (most: %d)" % [CONFIG.canopy_line_links_per_tree, most])

	# A forest that is not changing must not be worked out again every step.
	var rebuilds: int = powers.rebuild_count
	await _wait_frames(30)
	_check(powers.rebuild_count == rebuilds, "the lines are not rebuilt while the forest stays the same")
	# Cutting one tree down changes the forest: exactly then they are rebuilt.
	(powers.lines[0].a as ForestTree).take_damage(9999)
	await _wait_frames(3)
	_check(powers.rebuild_count > rebuilds, "the lines are rebuilt when a great sunroot falls")
	_check(powers.lines.size() <= CONFIG.canopy_line_max, "still under the cap afterwards")

	# The cards: the arena hides the cables while the upgrade cards are up.
	_arena.upgrade_picker.offer(CONFIG.upgrade_choices)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(powers.cables_hidden, "the Canopy lines are hidden while the upgrade cards are up")
	_arena.upgrade_picker.offered.clear()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not powers.cables_hidden, "and shown again once a card is picked")

	# A snared machine can walk free afterwards. Two great sunroots, one cable,
	# and a Scrapper standing on it.
	await _fresh_arena()
	powers = _arena.great_powers
	var a: ForestTree = _arena.spawn_tree(Vector2i(3, 12), true)
	var b: ForestTree = _arena.spawn_tree(Vector2i(9, 12), true)
	a.mature()
	b.mature()
	var scrapper: Scrapper = _arena.spawn_scrapper_at(Vector2i(6, 12))
	await _wait_frames(3)
	_check(scrapper.is_snared and powers.is_immune(scrapper), "a machine on the Canopy line is snared")
	var released: Callable = func() -> bool: return not scrapper.is_snared
	_check(await _wait_until(released, CONFIG.canopy_line_bind_seconds + 1.0), "the line lets it go after %.1f s" % CONFIG.canopy_line_bind_seconds)
	# Put it straight back on the cable with the cable fully charged: before s18
	# it would be caught again at once, for ever.
	powers._recharge.clear()
	scrapper.global_position = _arena.grid.cell_to_world(Vector2i(6, 12))
	await _wait_frames(3)
	_check(powers.is_charged(powers.lines[0]) and not scrapper.is_snared, "a machine just let go is not snared again: it can walk free")
	# Once the immunity has run out, the cable can catch it again.
	powers._immune.clear()
	scrapper.global_position = _arena.grid.cell_to_world(Vector2i(6, 12))
	await _wait_frames(3)
	_check(scrapper.is_snared, "after %.0f s it can be caught again" % CONFIG.canopy_line_immunity_seconds)


## s18, "must fix before I submit": Sasha forgot the Heart Tree existed, could
## not find it, and could not tell when trees were growing. These check the
## state behind what is drawn (headless Godot has no screen to look at).
func _test_readable_trees() -> void:
	await _fresh_arena(true)
	var heart: ForestTree = _arena.heart_tree
	_check(CONFIG.heart_tree_label != "" and heart._overlay != null and heart._overlay.z_index > _arena.great_powers.z_index,
		"the Heart Tree's label and ring are drawn above the glow and the Canopy lines")
	_check(not heart.is_alarmed() and _arena.heart_alarms == 0, "an unhurt Heart Tree raises no alarm")

	# Hit it: it shows the alarm, and Canopy FM says so on the radio.
	heart.take_damage(1)
	_check(heart.hp < heart.max_hp(), "a hurt tree is below full health, so its health bar shows")
	_check(heart.is_alarmed(), "a hit Heart Tree shows its alarm colours")
	_check(_arena.heart_alarms == 1, "Canopy FM raises the alarm when the Heart Tree is hit")
	var on_air: bool = _arena.radio.text == CONFIG.heart_alarm_line
	var queued_next: bool = not _arena._story_queue.is_empty() and _arena._story_queue[0].text == CONFIG.heart_alarm_line
	_check(on_air or queued_next, "the alarm line is on the radio, or is the very next line")
	# A second hit straight away must not repeat the line.
	heart.take_damage(1)
	_check(_arena.heart_alarms == 1, "the alarm is not repeated for every hit")
	var calm: Callable = func() -> bool: return not heart.is_alarmed()
	_check(await _wait_until(calm, CONFIG.heart_alarm_show_seconds + 1.0), "the alarm colours fade after %.0f s" % CONFIG.heart_alarm_show_seconds)

	# Wave 1 points the Heart Tree out on the radio.
	_arena.waves.start_wave(1)
	var mentioned: bool = _arena.radio.text == CONFIG.heart_intro_line
	for line: Dictionary in _arena._story_queue:
		mentioned = mentioned or line.text == CONFIG.heart_intro_line
	_check(mentioned, "Canopy FM points out the Heart Tree as wave 1 starts")

	# Only the Heart Tree raises the alarm: an ordinary tree does not.
	await _fresh_arena(true)
	var plain: ForestTree = _arena.spawn_tree(Vector2i(3, 12), true)
	plain.take_damage(1)
	_check(_arena.heart_alarms == 0 and not plain.is_alarmed(), "an ordinary tree being cut raises no Heart Tree alarm")

	# Growth you can see: a sapling's ring fills, then the tree pops.
	var sapling: ForestTree = _arena.spawn_tree(Vector2i(5, 12), false)
	_check(sapling.growth() < 0.2 and not sapling.is_popping(), "a new sapling starts with an empty growth ring")
	var half: Callable = func() -> bool: return sapling.growth() > 0.4
	_check(await _wait_until(half, CONFIG.sapling_time + 1.0), "the ring fills as the sapling roots")
	var grown: Callable = func() -> bool: return sapling.stage == ForestTree.Stage.GROWN
	_check(await _wait_until(grown, CONFIG.sapling_time + 2.0), "the sapling becomes a tree")
	_check(sapling.is_popping() and sapling.pop_scale() >= 1.0, "becoming a tree plays the pop (a clear visual step)")
	var settled: Callable = func() -> bool: return not sapling.is_popping()
	_check(await _wait_until(settled, CONFIG.tree_pop_seconds + 1.0) and is_equal_approx(sapling.pop_scale(), 1.0), "then it settles back to normal size")
	sapling.mature()
	_check(sapling.is_popping(), "maturing into a great sunroot pops too")


## s18: New Game + opens with Canopy FM waking Seven up and offering a reminder
## of the controls, which can be skipped (and skips itself if left alone).
func _test_ng_plus_opening() -> void:
	# All the radio text waiting or showing, as one list, for the checks below.
	var radio_texts: Callable = func() -> Array[String]:
		var texts: Array[String] = [_arena.radio.text]
		for line: Dictionary in _arena._story_queue:
			texts.append(line.text)
		return texts

	# The question: the wake-up line is on the radio and wave 1 is waiting.
	await _fresh_arena()
	_arena.apply_ng_plus()
	_arena.offer_refresher()
	_check(_arena.tutorial_offer.is_open(), "New Game + opens with the 'do you remember?' buttons")
	_check(_arena.radio.text == CONFIG.ng_plus_wakeup_line, "Canopy FM says the wake-up line")
	_check(_arena.waves.wave == 0, "wave 1 waits for the answer")

	# "Remind me": the tutorial is back on, with the staged first wave and the tips.
	_arena.tutorial_offer.choose(true)
	_check(not _arena.tutorial_offer.is_open() and _arena.waves.wave == 1, "answering starts wave 1")
	_check(_arena.tutorial_on and _arena.waves.staged_wave_count() == CONFIG.wave_staged_waves, "'Remind me' brings back the staged tutorial wave")
	var said: Array[String] = radio_texts.call()
	_check(said.has(CONFIG.ng_plus_threat_line), "Canopy FM warns that Helios sent tougher, faster drones")
	var intro: Array[String] = CONFIG.dj_intro_touch if Arena._is_touch() else CONFIG.dj_intro
	_check(said.has(intro[0]), "and the controls are explained again")
	_check(not said.has(CONFIG.story_hook), "the usual opening hook is not repeated on top")

	# "I remember": no tutorial, but the warning is still given.
	await _fresh_arena()
	_arena.apply_ng_plus()
	_arena.offer_refresher()
	_arena.tutorial_offer.choose(false)
	said = radio_texts.call()
	_check(not _arena.tutorial_on and _arena.waves.staged_wave_count() == 0 and _arena.waves.wave == 1, "'I remember' skips the tutorial and starts wave 1")
	_check(said.has(CONFIG.ng_plus_threat_line) and not said.has(intro[0]), "skipping still gives the warning, without the controls")

	# Left alone, it skips by itself.
	await _fresh_arena()
	_arena.apply_ng_plus()
	_arena.offer_refresher()
	_arena.tutorial_offer.time_left = 0.05
	var started: Callable = func() -> bool: return _arena.waves.wave == 1
	_check(await _wait_until(started, 2.0) and not _arena.tutorial_on, "with no answer it skips the tutorial by itself")

	# A normal run never shows the question.
	await _fresh_arena()
	_check(not _arena.tutorial_offer.is_open() and _arena.tutorial_on, "a normal run has no question and always has the tutorial")


## s18 group 4: Thick Plating adds pips without repairing, health has a cap, the
## pips stay clear of the wave label, and Grove rest is how Seven repairs.
func _test_plating_and_grove_rest() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	var pips: HealthPips = _arena._health_pips

	# PATCH KIT (the card that was Thick Plating): a random 1 to 3 pip refill and
	# no extra max health, so it cannot stack.
	var max_before: int = player.max_hp
	player.hp = 1  # (set directly: take_damage would be ignored while Seven blinks)
	_arena.apply_upgrade(&"thick_plating")
	var gave: int = _arena.last_repair_pips
	_check(gave >= CONFIG.upgrade_repair_min_pips and gave <= CONFIG.upgrade_repair_max_pips, "a Patch Kit repairs between %d and %d pips" % [CONFIG.upgrade_repair_min_pips, CONFIG.upgrade_repair_max_pips])
	_check(player.hp == 1 + gave and player.max_hp == max_before, "the pips come back, and max health does not grow")
	for i: int in 10:
		_arena.apply_upgrade(&"thick_plating")
	_check(player.hp == player.max_hp and player.max_hp == max_before, "ten more never take Seven past full health")
	_check(_arena.upgrades_left_out().has(&"thick_plating"), "at full health the Patch Kit is not dealt")
	var dealt_it: bool = false
	for i: int in 20:
		_arena.upgrade_picker.offer(CONFIG.upgrade_choices, _arena.upgrades_left_out())
		dealt_it = dealt_it or _arena.upgrade_picker.offered.has(&"thick_plating")
	_arena.upgrade_picker.choose(0)  # close the cards again
	_check(not dealt_it, "20 deals at full health never show the Patch Kit")

	# The pips: add_plating still raises the maximum up to the cap (kept for the HUD check).
	player.add_plating(CONFIG.player_hp_cap)
	_check(player.max_hp == CONFIG.player_hp_cap, "max health stops at the cap of %d" % CONFIG.player_hp_cap)

	# The HUD: with the longest wave label and every pip, the row starts after
	# the label and ends before the right margin.
	_arena._wave_label.text = "Wave 10 / 10    Homes lit 40 / 40    Trees 100    Brambles 2 / 2"
	await _wait_drawn_frames(4)  # let the arena's _process hand the label's end to the pips
	var label_end: float = _arena._wave_label.position.x + _arena._wave_label.get_minimum_size().x
	var last: Rect2 = pips.pip_rect(pips.maximum - 1)
	_check(pips.maximum == CONFIG.player_hp_cap and pips.pip_rect(0).position.x >= label_end, "the full row of pips starts after the wave label")
	_check(last.end.x <= get_viewport().get_visible_rect().size.x - CONFIG.hud_pips_right_margin + 0.5, "and ends before the right margin")

	# Grove rest: no trees nearby, no repair.
	await _fresh_arena()
	player = _arena.player
	player.take_damage(2)
	var hurt_hp: int = player.hp
	_arena.tick_grove_rest(CONFIG.grove_rest_seconds_per_pip * 3.0)
	_check(player.hp == hurt_hp and not player.is_resting, "away from trees, a hurt Seven is not repaired")
	_check(_arena._dj_said.has(&"grove_rest"), "the first hit makes Canopy FM explain Grove rest")

	# Grow the trees it needs, right around Seven.
	var here: Vector2i = _arena.grid.world_to_cell(player.global_position)
	var planted: int = 0
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1)]:
		if planted < CONFIG.grove_rest_trees and _arena.spawn_tree(here + offset, true) != null:
			planted += 1
	await _wait_frames(2)
	_check(_arena.grown_trees_near(player.global_position, CONFIG.grove_rest_radius_cells) >= CONFIG.grove_rest_trees, "%d grown trees stand within reach" % CONFIG.grove_rest_trees)
	_arena.tick_grove_rest(CONFIG.grove_rest_seconds_per_pip * 0.5)
	_check(player.is_resting and player.hp == hurt_hp, "among them Seven glows, but half the time gives no pip yet")
	_arena.tick_grove_rest(CONFIG.grove_rest_seconds_per_pip * 0.6)
	_check(player.hp == hurt_hp + 1, "after grove_rest_seconds_per_pip, one pip is back")
	_arena.tick_grove_rest(CONFIG.grove_rest_seconds_per_pip)
	_arena.tick_grove_rest(CONFIG.grove_rest_seconds_per_pip)
	_check(player.hp == player.max_hp and not player.is_resting, "it stops at full health, and the glow goes out")

	# s18: no Grove rest between waves, or before a wave's first machine walks in.
	player.hp = 1
	_arena.waves.wave = 3
	_arena.waves.state = WaveDirector.State.BREAK
	_arena.tick_grove_rest(CONFIG.grove_rest_seconds_per_pip * 2.0)
	_check(player.hp == 1 and not player.is_resting, "between waves the grove does not repair Seven")
	_arena.waves.state = WaveDirector.State.SPAWNING
	_arena.tick_grove_rest(CONFIG.grove_rest_seconds_per_pip * 2.0)
	_check(player.hp == 1, "nor before the wave's first machine has walked in")
	_arena.waves.state = WaveDirector.State.FIGHTING
	_arena.spawn_sawbot_at(Vector2i(22, 12))
	_arena.tick_grove_rest(CONFIG.grove_rest_seconds_per_pip * 1.1)
	_check(player.hp == 2 and player.is_resting, "with a machine on the lot, it repairs again")
	_arena.waves.state = WaveDirector.State.IDLE
	_arena.waves.wave = 0

## s18 batch 2: tougher and faster machines, the Heart Tree's fading label, Seven
## parked while the upgrade cards are up, and windows that follow the forest.
func _test_s18_machines_heart_cards_light() -> void:
	# Machines: the two heavy kinds have their new hit points and their own speeds.
	await _fresh_arena(true)
	var heavy: Scrapper = _arena.spawn_scrapper_at(Vector2i(3, 3), true)
	var arc: Spitter = _arena.spawn_spitter_at(Vector2i(20, 3), true)
	await get_tree().physics_frame
	_check(heavy.hp == CONFIG.linebreaker_hp and heavy.max_hp == heavy.hp, "a Linebreaker starts with %d hit points" % CONFIG.linebreaker_hp)
	_check(arc.hp == CONFIG.arc_spitter_hp, "an Arc Spitter starts with %d hit points" % CONFIG.arc_spitter_hp)
	_check(heavy._speed() < CONFIG.scrapper_speed * 0.5, "a Linebreaker is slow: under half a Scrapper's speed (%.0f px/s)" % heavy._speed())
	_check(is_equal_approx(arc._speed(), CONFIG.spitter_speed * CONFIG.arc_spitter_speed_factor), "an Arc Spitter walks at its own speed")
	heavy.toughen(CONFIG.ng_plus_heavy_hp_multiplier, CONFIG.ng_plus_speed_multiplier)
	_check(heavy.hp == ceili(CONFIG.linebreaker_hp * CONFIG.ng_plus_heavy_hp_multiplier) and heavy.speed_scale > 1.0, "New Game + makes it tougher and faster still")
	heavy.queue_free()
	arc.queue_free()

	# Heart Tree: the ring and label fade once the first wave is cleared, but
	# come straight back while it is being hit.
	var heart: ForestTree = _arena.heart_tree
	_check(is_equal_approx(heart.heart_marker_strength(), 1.0), "the Heart Tree's label shows at the start")
	_arena.waves_cleared = CONFIG.heart_label_waves
	var faded: Callable = func() -> bool: return ForestTree.heart_marker_fade <= 0.01
	_check(await _wait_until(faded, CONFIG.heart_label_fade_seconds + 2.0), "after the first wave the ring and label fade away")
	heart.take_damage(1)
	_check(is_equal_approx(heart.heart_marker_strength(), 1.0), "a hit brings the (red) label back for a moment")

	# Upgrade cards: Seven is parked next to the Heart Tree and cannot act.
	var player: Player = _arena.player
	# s18 round 4: Seven is locked where it stands, not moved to the Heart Tree.
	var stood_at: Vector2 = player.global_position
	_arena._park_player_for_cards()
	_check(player.locked and player.global_position.is_equal_approx(stood_at), "the cards lock Seven where it stands")
	var parked: Vector2i = _arena.park_cell()
	_check(not _arena.grid.is_solid(parked) and _arena.tree_at(parked) == null, "park_cell still names an open cell by the Heart Tree")
	_check(not player.fire(Vector2.RIGHT) and not player.throw_bramble(), "and Seven cannot shoot or throw while they are up")
	_arena.apply_upgrade(&"seed_pouch")
	_check(not player.locked, "picking a card frees Seven again")

	# Light follows the forest: a thin forest carries only part of the earned light.
	await _fresh_arena()
	_arena.waves_cleared = 4
	var earned: int = _arena.lit_windows_after(4)
	var thin: int = _arena.lit_windows_now()
	_check(_arena.forest_share() < 1.0 and thin < earned, "with few trees, fewer windows are lit than the waves earned (%d of %d)" % [thin, earned])
	for x: int in range(3, 23):
		_arena.spawn_tree(Vector2i(x, 4), true)
	_check(is_equal_approx(_arena.forest_share(), 1.0) and _arena.lit_windows_now() == earned, "a big healthy forest lights everything the waves earned")
	var points_before: float = _arena.forest_points()
	_arena.tree_at(Vector2i(3, 4)).take_damage(3)
	_check(_arena.forest_points() < points_before, "a damaged tree counts for less light")
	_arena.waves_cleared = _arena.waves.total_waves()
	_check(is_equal_approx(_arena.forest_share(), 1.0), "winning lights the whole block whatever the forest")

## s18: Seven has a knock-out animation, and a different one when the spare fuse
## saves it.
func _test_knockout_and_fuse_animations() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	var sprite: Sprite2D = player._sprite
	var normal_scale: Vector2 = sprite.scale

	# Knock-out: tips over onto its side and greys out.
	player.take_damage(player.max_hp)
	_check(player.is_dead and player.is_knockout_playing() and not player.is_fuse_flash_playing(), "going down starts the knock-out animation")
	var settled: Callable = func() -> bool: return not player.is_knockout_playing()
	await _wait_until(settled, CONFIG.knockout_seconds + 1.0)
	await _wait_frames(3)
	_check(is_equal_approx(absf(sprite.rotation), PI / 2.0), "Seven ends up lying on its side")
	_check(player.modulate.r < 0.6, "and greyed out")
	player.revive(player.global_position)
	_check(is_zero_approx(sprite.rotation) and sprite.scale.is_equal_approx(normal_scale) and player.modulate.is_equal_approx(Color.WHITE), "a revive stands Seven back up, in full colour")

	# The spare fuse: a different animation, and Seven stays up.
	player.receive_cat_gift()
	player._invulnerable_left = 0.0  # skip the safe moment after the revive
	player.take_damage(player.max_hp)
	_check(not player.is_dead and player.is_fuse_flash_playing() and not player.is_knockout_playing(), "the fuse plays its own flash, not the knock-out")
	_check(sprite.scale.x > normal_scale.x and is_zero_approx(sprite.rotation), "the picture pops up big and stays upright")
	var flashed: Callable = func() -> bool: return not player.is_fuse_flash_playing()
	await _wait_until(flashed, CONFIG.fuse_flash_seconds + 1.0)
	await _wait_frames(3)
	_check(sprite.scale.is_equal_approx(normal_scale), "and settles back to its normal size")

## s18 group 7: the end banner fits the screen, "Final notice" is the last wave's
## line, radio lines are never cut off, and a wave ends on a slow-motion beat.
func _test_banner_radio_and_wave_beat() -> void:
	await _fresh_arena()
	# The banner: every line of the longest end screen fits inside the label.
	RunState.just_unlocked = true
	var banner: Label = _arena._banner
	var font: Font = banner.get_theme_font(&"font")
	var font_size: int = banner.get_theme_font_size(&"font_size")
	var widest: float = 0.0
	for line: String in _arena.end_banner_text().split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	RunState.just_unlocked = false
	_check(widest <= banner.size.x, "every line of the end banner fits the screen (%d of %d px)" % [roundi(widest), roundi(banner.size.x)])
	_check(banner.autowrap_mode != TextServer.AUTOWRAP_OFF and banner.size.x < get_viewport().get_visible_rect().size.x, "and any longer banner wraps inside a side margin")

	# Helios: "Final notice" belongs to the last wave now.
	var last: int = _arena.waves.total_waves()
	_check(_arena.helios_line_for(last) == "Final notice.", "Helios says 'Final notice' on the last wave")
	_check(_arena.helios_line_for(8) != "Final notice." and _arena.helios_line_for(8) != _arena.helios_line_for(9), "waves 8 and 9 have their own lines")

	# The radio: new lines wait their turn instead of replacing what is on the air.
	var first := Arena._radio_line(Radio.CANOPY, "First line.")
	var second := Arena._radio_line(Radio.CANOPY, "Second line.")
	_arena._show_story_lines([first])
	_arena._show_story_lines([second])
	_check(_arena.radio.text == "First line." and _arena._story_queue.size() == 1, "a new line waits behind the one on the air")
	_arena._show_story_lines([second])
	_check(_arena._story_queue.size() == 1, "and the same line is never queued twice")
	_arena._story_queue.append(Arena._radio_line(Radio.HELIOS, "Old notice."))
	_arena._drop_waiting_helios_lines()
	_check(_arena._story_queue.size() == 1 and _arena._story_queue[0].text == "Second line.", "a new wave drops stale Helios notices but keeps Canopy FM's tips")
	_arena._radio_interrupt(Arena._radio_line(Radio.CANOPY, "Lucky speaks."))
	_check(_arena.radio.text == "Lucky speaks." and _arena._story_queue[0].text == "First line.", "an interruption plays at once, and the cut-off line is said again after it")
	var typed_and_held: float = CONFIG.story_line_seconds + "Lucky speaks.".length() / CONFIG.radio_chars_per_second
	var back_to_first: Callable = func() -> bool: return _arena.radio.text == "First line."
	_check(not back_to_first.call() and await _wait_until(back_to_first, typed_and_held + 1.0), "each line stays up until it is typed and held")

	# The wave end beat: slow motion first, then the cards.
	await _fresh_arena()
	_arena.wave_end_beat_seconds = 0.3
	_arena.waves.start_wave(2)
	_arena.waves.time_scale = 20.0
	var all_sent: Callable = func() -> bool: return _arena.waves.state == WaveDirector.State.FIGHTING
	await _wait_until(all_sent, 4.0)
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		(node as Enemy).take_damage(99)
	_check(_arena.is_wave_end_beat_playing() and Engine.time_scale < 1.0, "the last kill of a wave slows the game down")
	_check(not _arena.upgrade_picker.is_open() and _arena.waves.hold_break, "the cards wait for the beat, and so does the next wave")
	var cards_up: Callable = func() -> bool: return _arena.upgrade_picker.is_open()
	_check(await _wait_until(cards_up, 3.0), "then the upgrade cards come up")
	_check(is_equal_approx(Engine.time_scale, 1.0) and _arena.player.locked, "at normal speed again, with Seven parked")
	_arena.upgrade_picker.choose(0)

## s18: the pause menu has real options: resume, restart the wave, sound effects,
## music, and quit; Restart and Quit ask first.
func _test_pause_menu() -> void:
	await _fresh_arena()
	var pause: PauseOverlay = _arena.get_node("Hud/PauseOverlay") as PauseOverlay
	# A pretend left click, reused for every button below.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true

	pause.set_paused(true)
	# A click on empty space no longer resumes (it used to): only the buttons do.
	click.position = Vector2(640.0, 700.0)
	pause._input(click)
	_check(get_tree().paused, "a click beside the buttons does not un-pause")
	_check(_arena.pause_stats().size() >= 5 and _arena.pause_stats()[-1].contains(CanopyFM.station_name()), "the menu has this run's numbers and the song playing")

	# Sound effects and music switch off and on separately.
	click.position = pause.menu_button_rect(PauseOverlay.Item.EFFECTS).get_center()
	pause._input(click)
	_check(not Sfx.effects_on and get_tree().paused and pause.menu_label(PauseOverlay.Item.EFFECTS).contains("Off"), "the Sound effects button switches them off, and the menu stays up")
	pause.choose(PauseOverlay.Item.EFFECTS)
	_check(Sfx.effects_on, "and on again")
	pause.choose(PauseOverlay.Item.MUSIC)
	_check(not CanopyFM.music_on and not Sfx.is_muted, "the Music button switches only the music off")
	pause.choose(PauseOverlay.Item.MUSIC)
	_check(CanopyFM.music_on, "and on again")

	# s19: while the game is muted, both sound rows say so; each keeps its own setting.
	Sfx.set_muted(true)
	_check(pause.menu_label(PauseOverlay.Item.EFFECTS).contains("muted") and pause.menu_label(PauseOverlay.Item.MUSIC).contains("muted"), "while muted, the Sound and Music rows say so")
	_check(pause.menu_label(PauseOverlay.Item.EFFECTS).contains("On") and pause.menu_label(PauseOverlay.Item.MUSIC).contains("On"), "and still show their own On / Off setting")
	pause.choose(PauseOverlay.Item.MUSIC)
	_check(not CanopyFM.music_on and Sfx.is_muted and pause.menu_label(PauseOverlay.Item.MUSIC).contains("Off"), "a switch still changes only itself while muted")
	pause.choose(PauseOverlay.Item.MUSIC)
	Sfx.set_muted(false)
	_check(not pause.menu_label(PauseOverlay.Item.EFFECTS).contains("muted") and not pause.menu_label(PauseOverlay.Item.MUSIC).contains("muted"), "unmuted, the note goes away")

	# Restart this wave: asks first, then puts the wave back.
	_arena.waves.start_wave(2)
	_arena.player.take_damage(1)
	pause.choose(PauseOverlay.Item.RESTART)
	_check(get_tree().paused and pause.menu_label(PauseOverlay.Item.RESTART).contains("Sure"), "Restart asks 'Sure?' on the first press")
	pause.choose(PauseOverlay.Item.RESTART)
	_check(not get_tree().paused and _arena.player.hp == floori(float(_arena.player.max_hp) * CONFIG.restart_hp_cap_share) and _arena.waves.wave == 2, "the second press restarts the wave with Seven at the 80% cap")

	# Quit: asks first; a different button in between disarms it.
	pause.set_paused(true)
	pause.choose(PauseOverlay.Item.QUIT)
	pause.choose(PauseOverlay.Item.EFFECTS)
	pause.choose(PauseOverlay.Item.EFFECTS)
	pause.choose(PauseOverlay.Item.QUIT)
	_check(_arena.quit_requests == 0 and get_tree().paused, "Quit needs two presses in a row")
	pause.choose(PauseOverlay.Item.QUIT)
	_check(_arena.quit_requests == 1 and not get_tree().paused, "the second press quits to the main menu")

	# The bind control is listed only after Lucky's gift (it would spoil the secret).
	_check(not " ".join(pause.controls_lines(false)).contains("bind") and not " ".join(pause.controls_lines(true)).contains("bind"), "before Lucky's gift the controls list does not mention binding")
	_arena._on_cat_shop_opened()
	_check(" ".join(pause.controls_lines(false)).contains("bind") and " ".join(pause.controls_lines(true)).contains("bind"), "after the gift it does")

	# Resume by its button.
	pause.set_paused(true)
	pause.choose(PauseOverlay.Item.RESUME)
	_check(not get_tree().paused, "Resume carries on")

## s18: the back wall is a row of home fronts that hides Lucky's shutter among
## others, and the graffiti is painted level across the roofs.
func _test_back_wall_and_roof_graffiti() -> void:
	await _fresh_arena()
	var wall: BackWall = _arena.back_wall
	var shop_front: int = Arena.CAT_SHOP_CELL.x / BackWall.FRONT_CELLS
	_check(wall.front_count() * BackWall.FRONT_CELLS == CONFIG.grid_cols, "the fronts fill the back wall exactly (%d of them)" % wall.front_count())
	_check(wall.is_shop_front(shop_front), "one front is left empty for Lucky's shop")
	# Lit windows are small scenes: they take turns between a sprout and a hanging lamp,
	# and only every second door / third windows front is lit (a few, not all).
	_check(BackWall.lit_style(0) != BackWall.lit_style(1) and BackWall.lit_style(2) == BackWall.lit_style(0), "lit windows alternate between a sprout and a lamp")
	var lit_doors: int = 0
	var lit_window_fronts: int = 0
	for i: int in wall.front_count():
		if wall.kind_of(i) == BackWall.Kind.DOOR and BackWall.is_lit_door(i):
			lit_doors += 1
		if wall.kind_of(i) == BackWall.Kind.WINDOWS and BackWall.is_lit_windows(i):
			lit_window_fronts += 1
	_check(lit_doors >= 1 and lit_window_fronts >= 1, "the back wall has some lit homes (%d doors, %d window fronts)" % [lit_doors, lit_window_fronts])
	_check(is_equal_approx(wall.front_rect(shop_front).get_center().x, _arena.cat_shop.global_position.x), "and the shop stands exactly in it")
	_check(wall.kind_of(shop_front) == BackWall.Kind.SHUTTER, "that front would be a shutter anyway, so the pattern is unbroken")
	var other_shutters: int = 0
	for i: int in wall.front_count():
		if not wall.is_shop_front(i) and wall.kind_of(i) == BackWall.Kind.SHUTTER:
			other_shutters += 1
	_check(other_shutters >= 3, "Lucky's shutter hides among %d others" % other_shutters)

	# Graffiti: every line sits level inside the bottom wall, and inside the arena.
	var graffiti: Graffiti = _arena.graffiti
	var arena_rect := Rect2(_arena.grid.origin, Vector2(CONFIG.grid_cols, CONFIG.grid_rows) * float(CONFIG.cell_size))
	var font: Font = CONFIG.graffiti_font
	var all_fit: bool = true
	var roofs_used: Dictionary[Rect2, bool] = {}  # which roofs carry a tag
	for i: int in CONFIG.graffiti_lines.size():
		# tag_layout says how the line is painted: its rows, letter height and roof.
		var layout: Dictionary = graffiti.tag_layout(i)
		var roof: Rect2 = layout.roof
		roofs_used[roof] = true  # a Dictionary used as a set: each roof is counted once
		# Its middle must lie on one of the four walls (the outer ring of cells),
		# and its room is never taller than a wall is thick.
		var middle: Vector2i = _arena.grid.world_to_cell(roof.get_center())
		var on_wall: bool = middle.x == 0 or middle.y == 0 or middle.x == CONFIG.grid_cols - 1 or middle.y == CONFIG.grid_rows - 1
		if not on_wall or roof.size.y > CONFIG.cell_size or layout.size < Graffiti.MIN_FONT_SIZE:
			all_fit = false
			print("  tag %d is off the walls or too small: %s" % [i, roof])
		# Measure each row at the tag's own letter height: none may be wider than its roof.
		for row: String in layout.rows:
			if font.get_string_size(row, HORIZONTAL_ALIGNMENT_LEFT, -1.0, layout.size).x > roof.size.x:
				all_fit = false
				print("  tag %d is too wide for its spot: %s" % [i, row])
	_check(all_fit, "every graffiti tag fits on its own stretch of wall")
	_check(roofs_used.size() == CONFIG.graffiti_lines.size(), "each tag has a spot of its own, so no two run together")
	# s18 round 4: the tags are spread over three walls, not crowded on the roofs.
	var on_roofs: int = 0
	var sideways: int = 0
	var on_back: int = 0
	for i: int in CONFIG.graffiti_lines.size():
		var middle: Vector2i = _arena.grid.world_to_cell(graffiti.roof_for(i).get_center())
		if not is_zero_approx(graffiti.turn_for(i)):
			sideways += 1
		elif middle.y == 0:
			on_back += 1
			_check(middle.x != _arena.cat_shop_cell.x and middle.x != _arena.cat_shop_cell.x + 1, "a back wall tag is not on Lucky's shutter")
		else:
			on_roofs += 1
	_check(on_roofs <= 4 and on_back == Graffiti.BACK_WALL_TAGS and sideways == 4, "tags: %d on roofs, %d on back wall shutters, %d sideways on the side walls" % [on_roofs, on_back, sideways])
	_check(Graffiti.split_in_two("WE ARE THE NEIGHBOURS") == ["WE ARE THE", "NEIGHBOURS"], "a long tag is broken at the space nearest its middle")
	_check(graffiti.get_index() > _arena.windows.get_index(), "and is painted over the roofs, not under them")

## s18 groups 6, 8 and 9: more machines per wave, a visible aim line, and
## Sunburst on visible charges instead of a hidden cooldown.
func _test_harder_waves_aim_line_sunburst() -> void:
	# Group 6: about a third more machines over a run; the tutorial wave untouched.
	var total: int = 0
	for list: Array[int] in [CONFIG.wave_scrappers, CONFIG.wave_spitters, CONFIG.wave_sawbots]:
		for count: int in list:
			total += count
	_check(total >= 116 and total <= 126, "a run sends about 40%% more machines than the old 85 (%d), escorts not counted" % total)
	_check(CONFIG.wave_scrappers[0] == 1 and CONFIG.wave_spitters[0] == 1 and CONFIG.wave_sawbots[0] == 0, "the tutorial wave is unchanged")

	# Group 8: the aim line runs along the aim and stops at the first tree.
	await _fresh_arena()
	var player: Player = _arena.player
	var here := Vector2i(6, 11)
	player.global_position = _arena.grid.cell_to_world(here)
	player.touch_mode = true  # so the (absent) mouse does not overwrite the aim
	player.aim_direction = Vector2.RIGHT
	await _wait_frames(4)
	var open_reach: float = player.aim_line_end.x - player.global_position.x
	_check(open_reach > CONFIG.cell_size * 3.0 and is_equal_approx(player.aim_line_end.y, player.global_position.y), "the aim line runs out along the aim")
	_arena.spawn_tree(here + Vector2i(3, 0), true)
	await _wait_frames(4)
	var blocked_reach: float = player.aim_line_end.x - player.global_position.x
	_check(blocked_reach < open_reach and blocked_reach <= CONFIG.cell_size * 3.0, "and stops at the first tree in the way")
	player.aim_direction = Vector2(0.6, 0.8)  # down and to the right
	await _wait_frames(3)
	# With the facings strip the turn is in the picture: no lean, the SE frame instead.
	_check(is_zero_approx(player._sprite.rotation) and player._sprite.frame == 1, "Seven turns to the South-East frame for a down-right aim, with no lean")
	_check(player.is_aim_shown(), "the aim line shows while Seven can act")
	player.locked = true
	_check(not player.is_aim_shown(), "and hides while the upgrade cards lock Seven")
	player.locked = false

	# Group 9: Sunburst runs on charges that the player can see.
	var powers: GreatPowers = _arena.great_powers
	var great: ForestTree = _arena.tree_at(here + Vector2i(3, 0))
	great.mature()
	await _wait_frames(3)
	_check(powers.sunburst_charges == CONFIG.sunburst_charges_per_wave and ForestTree.sunburst_ready, "a wave starts with %d Sunbursts, and great sunroots show the gold sheen" % CONFIG.sunburst_charges_per_wave)
	for i: int in CONFIG.sunburst_charges_per_wave:
		powers.sunburst_cooldown_left = 0.0
		powers.sunburst(great.global_position)
	powers.sunburst_cooldown_left = 0.0
	_check(powers.sunburst_charges == 0 and not powers.is_sunburst_ready(), "using them all leaves none, whatever the cooldown says")
	await _wait_frames(3)
	_check(not ForestTree.sunburst_ready, "and the gold sheen goes out")
	_arena.waves.start_wave(3)
	_check(powers.sunburst_charges == CONFIG.sunburst_charges_per_wave, "the next wave refills them")
	_check(_arena._is_radio_pending(CONFIG.sunburst_intro_line % CONFIG.sunburst_charges_per_wave), "and Canopy FM explains Sunburst the first time a great sunroot is standing")

## s18 "if time allows" (hit-read, impact): a machine flashes when a shot lands,
## the screen shakes for a kill and harder for a hit on Seven, and Seven shows
## which side the hit came from.
func _test_hit_feedback() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	var player_cell: Vector2i = _arena.grid.world_to_cell(player.global_position)

	# A Linebreaker has enough hit points to survive a pod, so it flashes.
	var heavy: Scrapper = _arena.spawn_scrapper_at(player_cell + Vector2i(6, 0), true)
	await _wait_frames(2)
	_check(heavy.hit_flash_left == 0.0, "a machine that has not been hit does not flash")
	heavy.take_damage(1)
	_check(is_equal_approx(heavy.hit_flash_left, CONFIG.hit_flash_seconds), "a hit it survives starts the flash")
	var flash_over: Callable = func() -> bool: return heavy.hit_flash_left == 0.0
	_check(await _wait_until(flash_over, CONFIG.hit_flash_seconds + 0.5), "and the flash ends by itself")

	# A machine going down gives a small shake of the playfield.
	_check(_arena.shake_offset == Vector2.ZERO, "the screen is still before anything goes down")
	heavy.take_damage(heavy.hp)
	await get_tree().process_frame
	await get_tree().process_frame
	# 1.5: the offset is random in x and y, so its length can pass the px number a little.
	var kill_shake: float = _arena.shake_offset.length()
	_check(kill_shake > 0.0 and kill_shake <= CONFIG.shake_kill_px * 1.5, "a machine going down shakes the screen a little (%.1f px)" % kill_shake)
	_check(get_viewport().canvas_transform.origin.is_equal_approx(_arena.shake_offset), "the shake moves the playfield, not the HUD")
	var shake_over: Callable = func() -> bool: return _arena.shake_offset == Vector2.ZERO
	_check(await _wait_until(shake_over, CONFIG.shake_seconds + 0.5), "the shake dies away")
	_check(get_viewport().canvas_transform == Transform2D.IDENTITY, "and the playfield is back in place")

	# A hit on Seven: a red arc toward the source, a red screen flash, a harder shake.
	var from: Vector2 = player.global_position + Vector2(120.0, 0.0)
	_check(_arena.hurt_flash.color.a == 0.0, "the red sheet is see-through until Seven is hurt")
	_check(player.take_damage(1, from), "a hit on Seven counts")
	_check(player.hurt_arc_left > 0.0 and player.hurt_from == from, "Seven shows where the hit came from")
	_check(is_equal_approx(_arena.hurt_flash_left, CONFIG.hurt_flash_seconds), "the screen starts its red flash")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_arena.hurt_flash.color.a > 0.0, "the red sheet shows")
	_check(_arena.shake_offset.length() > 0.0, "and the screen shakes")
	_check(_arena.hurt_flash.get_index() == 0, "the red sheet is under every HUD label and menu")
	var red_over: Callable = func() -> bool: return _arena.hurt_flash_left == 0.0 and _arena.shake_offset == Vector2.ZERO
	_check(await _wait_until(red_over, 1.5), "both end by themselves")
	_check(_arena.hurt_flash.color.a == 0.0, "the red sheet is see-through again")

	# A hit that is ignored (Seven is still blinking) does not flash again.
	_check(not player.take_damage(1, from) and _arena.hurt_flash_left == 0.0, "an ignored hit gives no flash")

	# A weaker shake never replaces a stronger one that is still running.
	_arena.shake(CONFIG.shake_hurt_px)
	_arena.shake(CONFIG.shake_kill_px)
	_check(is_equal_approx(_arena._shake_px, CONFIG.shake_hurt_px * CONFIG.shake_scale), "a small shake does not cut a big one short")


## s18 playtest round 2: the two heavy machines wear force fields instead of
## hard rings, the Arc Spitter fires bolts, and a ready Sunburst is a gold sheen.
func _test_s18_shields_and_bolts() -> void:
	await _fresh_arena()
	# One of each machine, far from Seven so nothing fights during the check.
	var heavy: Scrapper = _arena.spawn_scrapper_at(Vector2i(22, 3), true)
	var plain: Scrapper = _arena.spawn_scrapper_at(Vector2i(22, 5))
	var arc: Spitter = _arena.spawn_spitter_at(Vector2i(22, 11), true)
	var spitter: Spitter = _arena.spawn_spitter_at(Vector2i(20, 12))
	await get_tree().physics_frame
	# _shield_color() returns a see-through colour (alpha 0) for "no shield".
	_check(heavy._shield_color().a > 0.0 and not heavy._shield_sparks(), "a Linebreaker has a force field (no sparks)")
	_check(arc._shield_color().a > 0.0 and arc._shield_sparks(), "an Arc Spitter has one that crackles")
	_check(plain._shield_color().a == 0.0 and spitter._shield_color().a == 0.0, "plain Scrappers and Spitters have none")
	# The Arc Spitter's shots are electric; a plain Spitter's are not.
	# A "lambda" (the func in brackets) collects what each `spat` signal carries.
	var flags: Array[bool] = []
	arc.spat.connect(func(_origin: Vector2, _direction: Vector2, electric: bool) -> void: flags.append(electric))
	spitter.spat.connect(func(_origin: Vector2, _direction: Vector2, electric: bool) -> void: flags.append(electric))
	arc._fire(Vector2.LEFT)
	spitter._fire(Vector2.LEFT)
	_check(flags == [true, true, true, false], "an Arc Spitter fires three bolts; a plain Spitter one ordinary shot")
	var bolt: SpitShot = _arena.spawn_spit_shot(Vector2(300.0, 300.0), Vector2.RIGHT, true)
	_check(bolt.electric and not _arena.spawn_spit_shot(Vector2(300.0, 340.0), Vector2.RIGHT).electric, "the arena makes a bolt only when asked to")

	# A ready Sunburst turns great sunroots gold: no ring, a gold pool of light.
	var great: ForestTree = _arena.spawn_tree(Vector2i(5, 11), true)
	great.mature()
	# (The arena sets ForestTree.sunburst_ready itself every frame, from the charges.)
	await _wait_drawn_frames(4)
	var glow := great.get_node(Glow.NODE_NAME) as Sprite2D
	_check(glow.modulate.is_equal_approx(CONFIG.sunburst_glow_color), "a ready Sunburst turns a great sunroot's light gold")
	_arena.great_powers.sunburst_charges = 0
	await _wait_drawn_frames(4)
	_check(glow.modulate.is_equal_approx(CONFIG.tree_glow_color), "and it goes back to green when none is ready")


## s18 playtest round 2: double hit points, a Linebreaker's three escorts, Arc
## Spitters that guard Sawbots, and Spitters that hide behind trees to reload.
func _test_s18_machine_roles() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	_check(CONFIG.scrapper_hp == 2 and CONFIG.spitter_hp == 4 and CONFIG.sawbot_hp == 6 and CONFIG.linebreaker_hp == 30 and CONFIG.arc_spitter_hp == 12, "every machine has double its old hit points")

	# A Linebreaker sent in by the wave director brings its escorts.
	_arena.waves.wave = 6
	_arena.waves.state = WaveDirector.State.FIGHTING
	_arena._on_spawn_requested(WaveDirector.LINEBREAKER, 6)
	await get_tree().physics_frame
	var heavy: Scrapper = null
	var escorts: Array[Spitter] = []
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		if node is Scrapper:
			heavy = node as Scrapper
		elif node is Spitter:
			escorts.append(node as Spitter)
	_check(heavy != null and heavy.heavy and escorts.size() == CONFIG.linebreaker_escorts, "a Linebreaker arrives with %d Spitters" % CONFIG.linebreaker_escorts)
	# Let the escorts finish rolling out of their gates before moving them by hand.
	await _wait_frames(int(CONFIG.gate_walk_in_seconds * 60.0) + 10)
	var all_guard: bool = true
	for escort: Spitter in escorts:
		all_guard = all_guard and escort.ward == heavy
	_check(all_guard, "and every one of them guards it")
	_check(_arena.waves._alive == CONFIG.linebreaker_escorts, "the wave director counts the escorts, so the wave waits for them too")

	# An escort dragged far away walks back to its ward instead of hunting Seven.
	var escort: Spitter = escorts[0]
	var leash: float = CONFIG.escort_leash_cells * CONFIG.cell_size
	heavy.set_physics_process(false)  # hold the Linebreaker still for the check
	heavy.global_position = _arena.grid.cell_to_world(Vector2i(22, 3))
	escort.global_position = _arena.grid.cell_to_world(Vector2i(14, 3))
	var back: Callable = func() -> bool: return escort.global_position.distance_to(heavy.global_position) <= leash + 8.0
	_check(await _wait_until(back, 6.0), "an escort left behind walks back to within %.0f cells of its Linebreaker" % CONFIG.escort_leash_cells)
	# With its ward gone it is an ordinary Spitter again.
	heavy.take_damage(999)
	await get_tree().physics_frame
	_check(not is_instance_valid(escort.ward) or escort.ward.is_dead, "when the Linebreaker falls the escort has nothing left to guard")

	# An Arc Spitter picks the nearest Sawbot as its ward.
	await _fresh_arena()
	player = _arena.player
	var sawbot: Sawbot = _arena.spawn_sawbot_at(Vector2i(22, 12))
	var arc: Spitter = _arena.spawn_spitter_at(Vector2i(20, 12), true)
	var plain: Spitter = _arena.spawn_spitter_at(Vector2i(22, 2))
	_check(await _wait_until(func() -> bool: return arc.ward == sawbot, 1.5), "an Arc Spitter guards the nearest Sawbot")
	_check(plain.ward == null and not plain.guards_sawbots, "a plain Spitter guards nobody")

	# Cover: a reloading Spitter with a tree nearby hides behind it.
	await _fresh_arena()
	player = _arena.player
	var player_cell: Vector2i = _arena.grid.world_to_cell(player.global_position)
	# A tree six cells to Seven's right; the Spitter stands in the open, one row down.
	var tree_cell: Vector2i = player_cell + Vector2i(6, 0)
	_arena.spawn_tree(tree_cell, true)
	var spitter: Spitter = _arena.spawn_spitter_at(tree_cell + Vector2i(1, 1))
	spitter._cooldown_left = 30.0  # a long reload, so it has time to hide
	var world_mask: int = Spitter.WORLD_MASK
	# "Hidden" = a ray from the Spitter to Seven hits a wall or a tree.
	var hidden: Callable = func() -> bool:
		var ray := PhysicsRayQueryParameters2D.create(spitter.global_position, player.global_position, world_mask)
		# The test scene is a plain Node, so it borrows the arena's physics world.
		return not _arena.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
	_check(not hidden.call(), "the Spitter starts in the open, in Seven's sight")
	_check(await _wait_until(hidden, 3.0), "while reloading it walks behind a tree, out of Seven's sight")
	_check(spitter.cover_cell != ArenaGrid.NO_CELL, "and it remembers that hiding cell")
	# Ready to fire again: it comes back out for a clear line.
	spitter._cooldown_left = 0.0
	_check(await _wait_until(func() -> bool: return spitter.is_winding_up, 4.0), "with the shot ready it steps out and winds up")


## s18 playtest round 2: a Sunburst chains to great sunroots close by, great
## sunroots are capped, and a restarted wave keeps a tree's age.
func _test_s18_sunburst_chain() -> void:
	await _fresh_arena()
	var powers: GreatPowers = _arena.great_powers
	# Three great sunroots in a row, 4 cells apart (inside the chain range of
	# 4.5), and a fourth far away on its own.
	var cells: Array[Vector2i] = [Vector2i(4, 11), Vector2i(8, 11), Vector2i(12, 11), Vector2i(22, 3)]
	var trees: Array[ForestTree] = []
	for cell: Vector2i in cells:
		var tree: ForestTree = _arena.spawn_tree(cell, true)
		tree.mature()
		trees.append(tree)
	# A machine beside the THIRD tree: too far for the first flare, in reach of the chain.
	var far_bot: Sawbot = _arena.spawn_sawbot_at(Vector2i(13, 12))
	far_bot.set_physics_process(false)  # keep it from walking off during the check
	await get_tree().physics_frame
	powers.sunburst_charges = 1
	var hp_before: int = far_bot.hp
	var caught: int = powers.sunburst(trees[0].global_position)
	_check(caught == 0 and far_bot.hp == hp_before, "the first flare does not reach a machine three trees away")
	# The chain needs two steps of sunburst_chain_delay to reach the third tree.
	var settled: Callable = func() -> bool: return powers._chain.is_empty() and powers.chain_size >= 3
	_check(await _wait_until(settled, CONFIG.sunburst_chain_delay * 2.0 + 1.0), "the Sunburst runs down the row of great sunroots")
	_check(powers.chain_size == 3, "three trees flared: the far one on its own was out of reach (%d)" % powers.chain_size)
	_check(far_bot.hp == hp_before - CONFIG.sunburst_damage and far_bot.is_bound, "the chain stuns and hurts the machine by the third tree")
	_check(powers.sunburst_charges == 0, "and the whole chain cost one charge")

	# The cap: with great_sunroot_max standing, no more trees mature.
	await _fresh_arena()
	_arena.ng_plus = true
	var planted: Array[ForestTree] = []
	for x: int in range(2, 2 + CONFIG.great_sunroot_max + 3):
		planted.append(_arena.spawn_tree(Vector2i(x, 12), true))
	_arena.waves.start_wave(2)  # snapshots the forest, so these count as "grown at wave start"
	for i: int in CONFIG.great_sunroot_waves_needed:
		_arena.mature_trees()
	_check(_arena.count_great_trees() == CONFIG.great_sunroot_max, "the lot holds at most %d great sunroots (%d)" % [CONFIG.great_sunroot_max, _arena.count_great_trees()])
	# A restarted wave replants the forest; a tree keeps the waves it had stood through.
	var young: ForestTree = _arena.spawn_tree(Vector2i(20, 9), true)
	young.waves_stood = 2
	_arena.waves.start_wave(3)
	_arena._restart_current_wave()
	_check(_arena.tree_at(Vector2i(20, 9)).waves_stood == 2, "a restarted wave keeps how long each tree has stood")


## s18 playtest round 2: Seven shows wear in three steps, the fuse gives a gold
## shield that runs down, and a knock-out or a fuse revive slows and darkens the game.
func _test_s18_wear_and_big_moments() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	# Wear follows the share of health left. (hp is set directly: take_damage
	# would be ignored while Seven blinks after the hit before.)
	_check(player.wear_level() == 0, "an unhurt Seven shows no wear")
	player.hp = 3  # 3 of 5 = 60%: at or under the "dented" share
	_check(player.wear_level() == 1, "at 3 of 5 pips Seven is dented (level 1)")
	player.hp = 2
	# 2 of 5 = 40% is above the "battered" share of 34%, so still level 1.
	_check(player.wear_level() == 1, "at 2 of 5 it is still level 1")
	player.max_hp = 10
	player.hp = 3
	_check(player.wear_level() == 2, "at 3 of 10 pips Seven is battered (level 2)")
	player.hp = 1
	_check(player.wear_level() == 3, "on the last pip it is level 3, whatever the maximum")
	player.max_hp = CONFIG.player_max_hp

	# The fuse: Seven gets back up, the game slows and darkens, and a shield counts down.
	# (The big moments only play during a wave, so pretend wave 3 is being fought.)
	_arena.waves.wave = 3
	_arena.waves.state = WaveDirector.State.FIGHTING
	player.receive_cat_gift()
	player.hp = 1
	player._invulnerable_left = 0.0
	player.take_damage(1)
	_check(player.hp == CONFIG.fuse_revive_hp and not player.is_dead, "the fuse puts Seven back up")
	_check(is_equal_approx(player.fuse_shield_left, CONFIG.fuse_invulnerable_time), "with a shield for %.0f seconds" % CONFIG.fuse_invulnerable_time)
	_check(_arena.drama_left > 0.0 and is_equal_approx(Engine.time_scale, CONFIG.drama_slow_scale), "the game drops into slow motion for the moment")
	await _wait_drawn_frames(4)
	_check(_arena.dim_sheet.color.a > 0.0, "and the screen darkens")
	_check(not player.take_damage(1), "nothing can hurt Seven while the shield is up")
	# The slow motion ends by itself after fuse_drama_seconds of REAL time.
	var normal_again: Callable = func() -> bool: return _arena.drama_left <= 0.0
	_check(await _wait_until(normal_again, CONFIG.fuse_drama_seconds + 1.0), "the slow motion ends")
	_check(is_equal_approx(Engine.time_scale, 1.0) and is_zero_approx(_arena.dim_sheet.color.a), "at normal speed, with the screen clear again")

	# A knock-out does the same, and the arena leaves normal speed behind it.
	player.has_fuse = false
	player._invulnerable_left = 0.0
	player.fuse_shield_left = 0.0
	player.hp = 1
	player.take_damage(1)
	_check(player.is_dead and _arena.drama_left > 0.0, "a knock-out also slows and darkens the game")
	_check(await _wait_until(normal_again, CONFIG.knockout_drama_seconds + 1.0) and is_equal_approx(Engine.time_scale, 1.0), "and then lets go of it")


## s18 round 3: ordinary machines roll out of gates in the side walls, the two
## heavy kinds drop in from above, and the first of each heavy kind gets a clip.
func _test_s18_entrances() -> void:
	await _fresh_arena()
	var gates: Gates = _arena.gates
	_check(gates.gate_cells().size() == CONFIG.gate_rows.size() * 2, "each side wall has a gate on every gate row (%d gates)" % gates.gate_cells().size())
	var all_in_walls: bool = true
	for gate: Vector2i in gates.gate_cells():
		# A gate is a wall cell (solid); the cell in front of it is open floor.
		all_in_walls = all_in_walls and _arena.grid.is_solid(gate) and not _arena.grid.is_solid(gates.floor_cell_of(gate))
	_check(all_in_walls, "every gate is in a wall with open floor in front of it")

	# A Scrapper sent in by the wave director starts inside a gate and rolls out.
	_arena.waves.wave = 2
	_arena.waves.state = WaveDirector.State.FIGHTING
	_arena._on_spawn_requested(WaveDirector.SCRAPPER, 2)
	var scrapper := get_tree().get_first_node_in_group(Enemy.GROUP) as Scrapper
	var start_cell: Vector2i = _arena.grid.world_to_cell(scrapper.global_position)
	_check(gates.gate_cells().has(start_cell) and scrapper.is_entering, "a Scrapper starts inside a gate, still arriving")
	_check(gates.is_lit(start_cell), "and that gate's warning lamp lights")
	var is_out: Callable = func() -> bool: return not scrapper.is_entering
	_check(await _wait_until(is_out, CONFIG.gate_walk_in_seconds + 1.0), "it rolls out onto the floor")
	_check(_arena.grid.world_to_cell(scrapper.global_position) == gates.floor_cell_of(start_cell), "and ends on the cell in front of that gate")

	# A tree never grows in a gateway: a machine downed there roots one cell over.
	scrapper.take_damage(999)
	await _wait_frames(3)
	_check(_arena.tree_at(gates.floor_cell_of(start_cell)) == null, "a machine downed in a gateway does not plant its tree there")
	_check(_arena.trees_planted == 1, "its tree is planted beside the gateway instead")

	# A Linebreaker drops in: no gate, a fall, then a landing with a hard shake.
	await _fresh_arena()
	gates = _arena.gates
	_arena.intro_clips_on = true
	_arena.waves.wave = 6
	_arena.waves.state = WaveDirector.State.FIGHTING
	# A one-item box the lambda can write into: how many landings were announced.
	var landings: Array[int] = [0]
	_arena._on_spawn_requested(WaveDirector.LINEBREAKER, 6)
	var heavy: Scrapper = null
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		if node is Scrapper:
			heavy = node as Scrapper
	heavy.landed.connect(func(_machine: Enemy) -> void: landings[0] += 1)
	var heavy_cell: Vector2i = _arena.grid.world_to_cell(heavy.global_position)
	_check(heavy.is_entering and gates.gate_for(heavy_cell) == ArenaGrid.NO_CELL, "a Linebreaker does not use a gate: it is falling")
	_check(heavy._sprite.position.y < -100.0, "its picture starts high above its landing spot")
	_check(_arena.clip_left > 0.0 and is_equal_approx(Engine.time_scale, CONFIG.heavy_intro_slow_scale), "the first Linebreaker gets an intro clip in slow motion")
	_check(_arena.clip_label.visible and _arena.clip_label.text == CONFIG.intro_titles[WaveDirector.LINEBREAKER], "with its name on screen")
	var has_landed: Callable = func() -> bool: return landings[0] == 1
	_check(await _wait_until(has_landed, CONFIG.drop_seconds + 2.0), "it lands")
	_check(not heavy.is_entering and heavy._sprite.position.is_zero_approx() and heavy.land_fx_left > 0.0, "on its landing spot, awake, in a ring of dust")
	_check(_arena._shake_px >= CONFIG.shake_land_px * CONFIG.shake_scale, "and the landing shakes the screen hard")
	# The clip ends by itself and gives the game its speed back.
	var clip_over: Callable = func() -> bool: return _arena.clip_left <= 0.0
	_check(await _wait_until(clip_over, CONFIG.heavy_intro_seconds + 2.0), "the clip ends")
	await _wait_drawn_frames(3)
	_check(is_equal_approx(Engine.time_scale, 1.0) and is_zero_approx(_arena._bar_top.size.y) and not _arena.clip_label.visible, "at normal speed, with the black bars and the name gone")
	# The second Linebreaker of the run still drops, but gets no clip.
	_arena._on_spawn_requested(WaveDirector.LINEBREAKER, 6)
	_check(_arena.clip_left <= 0.0, "a second Linebreaker drops in without a clip")
	_check(Sfx.stream_for(&"crash") != null and Sfx.stream_for(&"drop") != null and Sfx.stream_for(&"gate") != null, "the crash, the falling whistle and the gate each have a sound")


## s18 round 3: Lucky's shop hides behind a random shutter each run, and the
## heavy landing has a real recorded sound.
func _test_s18_lucky_moves() -> void:
	# The places it may hide: shutter fronts of the back wall, never the corner one.
	var places: Array[Vector2i] = BackWall.shop_cells(CONFIG.grid_cols)
	_check(places.size() >= 3 and places.has(Arena.CAT_SHOP_CELL), "the shop has %d shutters to hide behind, the old spot among them" % places.size())
	var all_shutters: bool = true
	for place: Vector2i in places:
		var index: int = place.x / BackWall.FRONT_CELLS
		all_shutters = all_shutters and index > 0 and place.y == 0 and BackWall.PATTERN[index % BackWall.PATTERN.size()] == BackWall.Kind.SHUTTER
	_check(all_shutters, "every hiding place is a shutter front in the top wall, away from the corner")

	# Build a dozen arenas with the knob ON and note where the shop went.
	# (_fresh_arena switches the knob off, so these are built by hand here.)
	var seen: Dictionary[Vector2i, bool] = {}
	var always_lined_up: bool = true
	for i: int in 12:
		if _arena != null:
			_arena.queue_free()
			await get_tree().physics_frame
		_arena = ARENA_SCENE.instantiate()
		_arena.autostart_waves = false
		_arena.intro_clips_on = false
		add_child(_arena)
		await get_tree().physics_frame
		seen[_arena.cat_shop_cell] = true
		# The shop node, the gap left in the back wall and the chosen cell must agree.
		var front: int = _arena.cat_shop_cell.x / BackWall.FRONT_CELLS
		var lined_up: bool = places.has(_arena.cat_shop_cell) and _arena.back_wall.is_shop_front(front)
		lined_up = lined_up and is_equal_approx(_arena.back_wall.front_rect(front).get_center().x, _arena.cat_shop.global_position.x)
		always_lined_up = always_lined_up and lined_up
	_check(always_lined_up, "wherever it is, the shop stands exactly in the gap the back wall leaves for it")
	_check(seen.size() >= 2, "over 12 runs the shop turned up in %d different places" % seen.size())

	# It still opens to three pods in its new place.
	var shop: CatShop = _arena.cat_shop
	for i: int in CONFIG.cat_hits_needed:
		var pod: SeedPod = Arena.SEED_POD_SCENE.instantiate()
		# Start each pod two cells below the shop, flying straight up at it.
		pod.position = shop.global_position + Vector2(0.0, CONFIG.cell_size * 2.0)
		pod.direction = Vector2.UP
		_arena.get_node("Pods").add_child(pod)
		await _wait_frames(20)
	_check(shop.is_open, "three pods open the shop wherever it is hiding")

	# The landing crash is a real recording now, not the generated one.
	_check(Sfx.stream_for(&"crash") is AudioStreamMP3, "the heavy landing plays the recorded crash")


## s18 round 4, from Sasha's playtest of round 3: restarts that cannot loop or
## heal, a once-per-run fuse, a Sawbot that must stand next to what it cuts,
## escorts that land with their Linebreaker, saplings that wait between waves,
## a radio box that fits its words, and a dark panel under the end screen.
func _test_s18_round_4() -> void:
	await _fresh_arena(true)
	var player: Player = _arena.player

	# A RESTARTED WAVE gives back the health Seven had when the wave began.
	player.hp = 2
	_arena.waves.start_wave(3)  # the arena notes Seven's health as the wave starts
	player.receive_cat_gift()
	player.has_fuse = false  # the fuse was used earlier in the run
	player.hp = 1
	_arena._restart_pending = true
	_arena.waves.hold_break = true
	_arena.upgrade_picker.offer(CONFIG.upgrade_choices)
	_arena._restart_current_wave()
	_check(player.hp == 2 + CONFIG.restart_bonus_pips and not player.is_dead, "a restarted wave gives Seven the 2 pips it began the wave with plus %d, not full health" % CONFIG.restart_bonus_pips)
	_check(_arena._hp_at_wave_start == 2, "and a second restart would give the same again, not one more each time")
	_check(not player.has_fuse, "and no new fuse")
	_check(not _arena.upgrade_picker.is_open() and not _arena.waves.hold_break and not player.locked, "a restart takes the upgrade cards away and frees Seven")

	# A wave that "clears" while a restart is pending does not count.
	var cleared_before: int = _arena.waves_cleared
	_arena._restart_pending = true
	_arena._on_wave_cleared(3)
	_check(_arena.waves_cleared == cleared_before and not _arena.upgrade_picker.is_open(), "a wave cleared as Seven goes down does not count, and deals no cards")
	_arena._restart_pending = false
	_arena.waves.hold_break = false

	# SAWBOT REACH: two cells from the Heart Tree is too far to cut it.
	await _fresh_arena(true)
	var sawbot: Sawbot = _arena.spawn_sawbot_at(Arena.HEART_TREE_CELL + Vector2i(2, 0))
	await _wait_frames(2)
	var reach: float = CONFIG.sawbot_reach_cells * CONFIG.cell_size
	_check(sawbot._nearest_tree(ForestTree.Stage.GROWN, reach, false) == null, "a Sawbot two cells from the Heart Tree cannot reach it")
	_check(sawbot._nearest_tree(ForestTree.Stage.GROWN, INF) == _arena.heart_tree, "though the Heart Tree still lures it")
	await _wait_frames(20)
	_check(_arena.heart_tree.hp == _arena.heart_tree.max_hp(), "so it does not cut it from there")
	sawbot.queue_free()

	# ESCORTS land around their Linebreaker.
	_arena._on_spawn_requested(WaveDirector.LINEBREAKER, 6)
	var heavy: Scrapper = null
	var escorts: Array[Spitter] = []
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		if node is Scrapper and (node as Scrapper).heavy:
			heavy = node as Scrapper
		elif node is Spitter:
			escorts.append(node as Spitter)
	var all_close: bool = heavy != null and escorts.size() == CONFIG.linebreaker_escorts
	for escort: Spitter in escorts:
		var apart: Vector2i = (_arena.grid.world_to_cell(escort.global_position) - _arena.grid.world_to_cell(heavy.global_position)).abs()
		if maxi(apart.x, apart.y) > 2 or not escort.is_entering or escort.ward != heavy:
			all_close = false
	_check(all_close, "a Linebreaker's %d escorts drop in within 2 cells of it, guarding it" % CONFIG.linebreaker_escorts)

	# THE FIRST SCRAPPER gets an intro clip too (regular game only).
	await _fresh_arena()
	_arena.intro_clips_on = true
	_arena._on_spawn_requested(WaveDirector.SCRAPPER, 1)
	_check(_arena.clip_left > 0.0 and _arena.clip_label.text == CONFIG.intro_titles[WaveDirector.SCRAPPER], "the first Scrapper of a run gets an intro clip with its name")
	_check(CONFIG.intro_titles.has(WaveDirector.SPITTER) and CONFIG.intro_titles.has(WaveDirector.SAWBOT), "and the Spitter and the Sawbot have one waiting")
	_arena.clip_left = 0.0
	_arena.intro_clips_on = false
	Engine.time_scale = 1.0

	# A BIG MOMENT keeps its subject lit: the dark sheet has a pool of light.
	player = _arena.player  # a fresh arena has a fresh Seven
	_arena.waves.wave = 1
	_arena.start_drama(0.6, player)
	await _wait_drawn_frames(3)
	_check(_arena.dim_sheet.color.a > 0.0 and _arena.dim_sheet.focus != Vector2.INF, "a big moment darkens the screen but leaves a pool of light on Seven")
	_arena.drama_left = 0.0
	_arena.dim_sheet.color = Color(0.0, 0.0, 0.0, 0.0)
	_arena.waves.wave = 0
	Engine.time_scale = 1.0

	# SAPLINGS WAIT between waves.
	_arena.pause_growth_between_waves = true
	_arena.waves.hold_break = true  # or the director would end the break at once
	_arena.waves.state = WaveDirector.State.BREAK
	var sapling: ForestTree = _arena.spawn_tree(Vector2i(4, 4), false)
	await _wait_drawn_frames(8)
	_check(sapling.stage == ForestTree.Stage.SAPLING and is_zero_approx(sapling.growth()), "a sapling does not grow between waves")
	_arena.waves.state = WaveDirector.State.IDLE
	_arena.waves.hold_break = false
	await _wait_drawn_frames(8)
	_check(sapling.growth() > 0.0, "and grows again once the break is over")
	_arena.pause_growth_between_waves = false

	# THE RADIO BOX grows to fit a long line.
	var radio: Radio = _arena.radio
	radio.say(Radio.CANOPY, "Short.")
	_check(is_equal_approx(radio.panel_rect().size.y, Radio.PANEL_RECT.size.y), "a short radio line keeps the small box")
	radio.say(Radio.CANOPY, "Heads up: Helios has sent tougher, faster drones after you this time. And then some more words, so that it wraps onto a third row.")
	_check(radio.panel_rect().size.y > Radio.PANEL_RECT.size.y + 20.0, "a long line makes the box taller, so no words hang out of it")
	_check(CONFIG.story_line_seconds >= 3.0, "a line stays up at least 3 seconds after it has typed (%.1f)" % CONFIG.story_line_seconds)
	radio.clear()

	# THE MUSIC SWITCH really stops the song.
	CanopyFM.set_music_on(false)
	_check(not CanopyFM.music_on and not CanopyFM._player.playing, "Music off stops the song (not just pauses it)")
	CanopyFM.set_music_on(true)
	_check(CanopyFM.music_on, "and Music on brings it back")

	# THE END SCREEN has a dark panel behind its words.
	_check(not _arena.has_end_panel(), "no panel behind an ordinary banner")
	_arena._on_all_waves_cleared()
	_check(_arena.has_end_panel() and _arena._banner.size.x < get_viewport().get_visible_rect().size.x, "the end screen's words sit on a dark panel sized to them")

	# THE RIPSAW: the upgraded Sawbot.
	await _fresh_arena()
	var ripsaw: Sawbot = _arena.spawn_sawbot_at(Vector2i(4, 8), true)
	var plain: Sawbot = _arena.spawn_sawbot_at(Vector2i(4, 10))
	await _wait_frames(2)
	_check(ripsaw.big and ripsaw.hp == CONFIG.ripsaw_hp and ripsaw.hp > plain.hp, "a Ripsaw has more hit points than a Sawbot (%d to %d)" % [ripsaw.hp, plain.hp])
	_check(ripsaw._speed() > plain._speed() and is_equal_approx(ripsaw._saw_interval() * 2.0, plain._saw_interval()), "it walks faster and its blade bites twice as often")
	_check(ripsaw.scale.x > plain.scale.x, "and it is bigger")
	var waves: WaveDirector = _arena.waves
	var first_wave: int = 0
	var most: int = 0
	for number: int in range(1, waves.total_waves() + 1):
		var count: int = waves._build_queue(number).count(WaveDirector.RIPSAW)
		if count > 0 and first_wave == 0:
			first_wave = number
		most = maxi(most, count)
	_check(first_wave == 7 and most <= 3, "regular game: Ripsaws from wave 7, never more than 3 in a wave")
	_arena.apply_ng_plus()
	first_wave = 0
	most = 0
	for number: int in range(1, waves.total_waves() + 1):
		var count: int = waves._build_queue(number).count(WaveDirector.RIPSAW)
		if count > 0 and first_wave == 0:
			first_wave = number
		most = maxi(most, count)
	_check(first_wave == 4 and most <= 5, "New Game +: Ripsaws from wave 4, never more than 5 in a wave")

	# A WEDGED LINEBREAKER shoulders through; routes keep off the outer border.
	var heavy_one: Scrapper = _arena.spawn_scrapper_at(Vector2i(20, 8), true)
	await _wait_frames(2)
	_check(heavy_one.shoulders_through and not _arena.spawn_scrapper_at(Vector2i(20, 10)).shoulders_through, "a Linebreaker can shoulder through when wedged; a Scrapper cannot")
	heavy_one._stuck_time = CONFIG.stuck_seconds  # as if it had been pushing at something
	heavy_one.velocity = Vector2.ZERO
	var along_border: Array[Vector2i] = _arena.grid.find_path(Vector2i(3, 1), Vector2i(22, 1))
	var leaves_border: bool = false
	for cell: Vector2i in along_border:
		if cell.y > 1:
			leaves_border = true
	_check(leaves_border, "a route between two border cells swings in off the border")

	# THE RADIO: a tap on the panel moves it along; Canopy FM hisses in the dark.
	await _fresh_arena()
	_arena._radio_later([Arena._radio_line(Radio.CANOPY, "First line, long enough to still be typing."), Arena._radio_line(Radio.HELIOS, "Second line.")])
	_check(_arena.radio.is_on() and not _arena.radio.is_fully_typed(), "a radio line starts typing")
	_arena.skip_radio_line()
	_check(_arena.radio.is_fully_typed() and _arena.radio.speaker == Radio.CANOPY, "one tap on the panel finishes typing the line")
	_arena.skip_radio_line()
	_check(_arena.radio.speaker == Radio.HELIOS, "the next tap goes on to the next line")
	_check(Sfx.stream_for(&"static") != null, "a Helios notice has a burst of static to cut in and out with")
	_check(CanopyFM.hiss_for(0.0) > CanopyFM.hiss_for(1.0) + 20.0, "Canopy FM hisses in the dark (%.0f dB) and is clear once the block is lit (%.0f dB)" % [CanopyFM.hiss_for(0.0), CanopyFM.hiss_for(1.0)])

	# s18 round 5: weak-signal text, the restart cap, and clips that do not cut each other off.
	var plain_line: String = "Seven, this is Canopy FM, the only station still on the air tonight."
	_check(Arena.with_static(plain_line, 0.0).contains("[static]") and Arena.with_static(plain_line, 1.0) == plain_line, "Canopy FM's words break up with [static] in the dark and are whole once the block is lit")
	_check(Arena.with_static(plain_line, 0.0).replace(" [static]", "") == plain_line, "the [static] is only added between whole words")
	await _fresh_arena(true)
	_arena.waves.start_wave(3)
	_arena._restart_current_wave()
	var cap: int = floori(float(_arena.player.max_hp) * CONFIG.restart_hp_cap_share)
	_check(_arena.player.hp == cap and cap < _arena.player.max_hp, "a restart from full health comes back capped at %d of %d pips" % [cap, _arena.player.max_hp])
	_arena.intro_clips_on = true
	_arena._on_spawn_requested(WaveDirector.SAWBOT, 4)
	_arena._on_spawn_requested(WaveDirector.LINEBREAKER, 6)
	_check(_arena.clip_label.text == CONFIG.intro_titles[WaveDirector.SAWBOT] and not _arena._intro_done.has(WaveDirector.LINEBREAKER), "a Linebreaker landing during another clip keeps its own clip for the next one")
	_arena.clip_left = 0.0
	_arena._on_spawn_requested(WaveDirector.LINEBREAKER, 6)
	_check(_arena.clip_left > 0.0 and _arena.clip_label.text == CONFIG.intro_titles[WaveDirector.LINEBREAKER], "which then gets it")
	_arena.clip_left = 0.0
	_arena._heart_clip_wait = 0.0
	_arena.heart_tree.take_damage(1)
	_check(_arena.clip_left > 0.0 and _arena.clip_label.text == CONFIG.heart_clip_title and is_equal_approx(_arena._clip_zoom, CONFIG.heart_clip_zoom), "a cut into the Heart Tree plays a short, gentler clip on it")
	_arena.clip_left = 0.0
	_arena.heart_tree.take_damage(1)
	_check(_arena.clip_left <= 0.0, "and not again straight away")
	_arena.intro_clips_on = false
	Engine.time_scale = 1.0

## How many times `text` is on the radio or waiting in its queue (for the s19
## restart checks: a restart must never leave a line said twice).
func _radio_copies_of(text: String) -> int:
	var copies: int = 0
	if _arena.radio.is_on() and _arena._current_line.get("text", "") == text:
		copies += 1
	for line: Dictionary in _arena._story_queue:
		if line.text == text:
			copies += 1
	return copies


## s19 phase 1: the post-jam fixes, one group per item.
func _test_s19_phase1() -> void:
	# ITEM 1: a restarted wave says its one-time radio lines again.
	# In wave 1 the opening hook and a tutorial line (said through _dj_once) are
	# first said during the wave; after a restart both must come round again.
	await _fresh_arena()
	_arena.player._invulnerable_left = 999.0
	_arena.waves.time_scale = 20.0
	_arena.tutorial_on = true
	_arena.waves.start_wave(1)
	_check(_arena._hook_shown and _radio_copies_of(CONFIG.story_hook) == 1, "wave 1 start: the opening hook is on the air")
	_arena._dj_once(&"s19_test_moment", ["S19 one-time line."])
	_check(_arena._dj_said.has(&"s19_test_moment"), "a one-time line is marked as said")
	_arena._story_queue.append(Arena._radio_line(Radio.CANOPY, "S19 stale line from the failed attempt."))
	_arena._restart_current_wave()
	_check(not _arena._dj_said.has(&"s19_test_moment"), "a restart in wave 1 forgets the one-time line first said in that wave")
	_check(_radio_copies_of(CONFIG.story_hook) == 1 and _arena._hook_shown, "and the opening hook is said again, once")
	_check(_radio_copies_of("S19 stale line from the failed attempt.") == 0, "lines still waiting from the failed attempt are dropped")
	_check(_radio_copies_of(_arena.helios_line_for(1)) == 1, "Helios's notice is not doubled")
	_arena._dj_once(&"s19_test_moment", ["S19 one-time line."])
	_check(_radio_copies_of("S19 one-time line.") == 1, "the forgotten line can be said again, once")
	_arena._restart_current_wave()
	_arena._restart_current_wave()
	_check(_radio_copies_of(CONFIG.story_hook) == 1, "restarting twice still leaves the hook said once")

	# In a LATER wave: lines from earlier waves are not repeated, this wave's are.
	await _fresh_arena()
	_arena.player._invulnerable_left = 999.0
	_arena.waves.time_scale = 20.0
	_arena.tutorial_on = true
	_arena.waves.start_wave(1)
	_arena._dj_once(&"s19_early", ["S19 early line."])
	_arena.waves.start_wave(3)  # the snapshot is taken here: "s19_early" is from an earlier wave
	_arena._dj_once(&"s19_this_wave", ["S19 this-wave line."])
	_arena._restart_current_wave()
	_check(_arena._dj_said.has(&"s19_early"), "a restart in wave 3 keeps lines from earlier waves as said")
	_check(not _arena._dj_said.has(&"s19_this_wave"), "but forgets the ones first said in wave 3")
	_check(_radio_copies_of(CONFIG.story_hook) == 0, "the hook (said in wave 1) is not repeated in wave 3")
	_check(_radio_copies_of("S19 early line.") == 0, "an earlier wave's line is not repeated")
	_check(_radio_copies_of(_arena.helios_line_for(3)) == 1, "wave 3's own notice is queued once")
	_arena._dj_once(&"s19_this_wave", ["S19 this-wave line."])
	_check(_radio_copies_of("S19 this-wave line.") == 1, "wave 3's one-time line plays again after the restart")

	# ITEM 2: Helios's opening line.
	_check(CONFIG.helios_lines[0] == "Good evening, valued customer. Your sector's account is 90 minutes past due, and we hate to bring it up.", "Helios's opening line is the new text")
	for line: String in CONFIG.helios_lines:
		_check(not line.contains("90 days"), "no Helios line still says 90 days")


## s19 item 3: machines are solid to Seven and hurt on contact (not while they
## are arriving or tied up), and Seven can never be pinned by one.
func _test_s19_contact() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	player._invulnerable_left = 0.0
	player.global_position = _arena.grid.cell_to_world(Vector2i(5, 12))
	# A machine tied up by the vine stands still, so it makes a fixed obstacle.
	# (Binding with the puller at its own spot binds it without dragging it.)
	var wall_bot: Scrapper = _arena.spawn_scrapper_at(Vector2i(8, 12))
	await _wait_frames(2)
	wall_bot.yank_and_bind(wall_bot.global_position, 0.0, 999.0)
	var wall_x: float = wall_bot.global_position.x
	Input.action_press(&"move_right")
	await _wait_frames(120)  # two seconds: far more than enough to cross three cells
	Input.action_release(&"move_right")
	var gap: float = wall_x - player.global_position.x
	var radii: float = (CONFIG.player_radius_cells + CONFIG.scrapper_radius_cells) * float(CONFIG.cell_size)
	_check(player.global_position.x < wall_x and gap > radii - 3.0, "Seven cannot walk through a machine (stopped %.0f px short; the two bodies are %.0f px wide together)" % [gap, radii])
	_check(player.hp == CONFIG.player_max_hp, "pushing against a tied-up machine does not hurt")

	# A free machine that is touching Seven hurts her, once per cooldown.
	await _fresh_arena()
	player = _arena.player
	player._invulnerable_left = 0.0
	player.global_position = _arena.grid.cell_to_world(Vector2i(5, 12))
	var toucher: Sawbot = _arena.spawn_sawbot_at(Vector2i(8, 12))
	await _wait_frames(2)
	toucher.is_entering = false
	toucher.global_position = player.global_position + Vector2(radii + 2.0, 0.0)  # edges 2 px apart
	player.hp = player.max_hp
	player._invulnerable_left = 0.0
	toucher._contact_left = 0.0
	toucher._tick_bound(0.0)  # what the machine does at the top of every physics step
	_check(player.hp == player.max_hp - CONFIG.contact_damage, "touching a machine costs %d pip" % CONFIG.contact_damage)
	toucher._tick_bound(0.0)
	_check(player.hp == player.max_hp - CONFIG.contact_damage, "and not again straight away")
	# Even with the machine's cooldown over, Seven's own blink protects her.
	toucher._contact_left = 0.0
	toucher._tick_bound(0.0)
	_check(player.hp == player.max_hp - CONFIG.contact_damage, "Seven's blink after a hit blocks another touch")
	player._invulnerable_left = 0.0
	toucher._contact_left = 0.0
	toucher._tick_bound(0.0)
	_check(player.hp == player.max_hp - 2 * CONFIG.contact_damage, "once the blink and the cooldown are over, a touch hurts again")

	# Not while it is arriving, not while it is tied up, not when merely near.
	player.hp = player.max_hp
	player._invulnerable_left = 0.0
	toucher._contact_left = 0.0
	toucher.is_entering = true
	toucher._tick_bound(0.0)
	_check(player.hp == player.max_hp, "a machine still rolling out of a gate or dropping in does not hurt")
	toucher.is_entering = false
	toucher.is_bound = true
	toucher._bound_time_left = 5.0
	toucher._tick_bound(0.0)
	_check(player.hp == player.max_hp, "a bound machine does not hurt")
	toucher.is_bound = false
	toucher.global_position = player.global_position + Vector2(radii + CONFIG.contact_margin_px + 10.0, 0.0)
	toucher._tick_bound(0.0)
	_check(player.hp == player.max_hp, "standing close but not touching does not hurt")

	# Never pinned: Seven stands between a tree and a tied-up machine and can walk out.
	await _fresh_arena()
	player = _arena.player
	_arena.spawn_tree(Vector2i(10, 12), true)
	player.global_position = _arena.grid.cell_to_world(Vector2i(9, 12))
	var jammer: Scrapper = _arena.spawn_scrapper_at(Vector2i(7, 12))
	await _wait_frames(2)
	jammer.yank_and_bind(jammer.global_position, 0.0, 999.0)
	jammer.global_position = player.global_position + Vector2(-radii - 1.0, 0.0)  # pressed against her left side
	var start_y: float = player.global_position.y
	Input.action_press(&"move_up")
	await _wait_frames(30)
	Input.action_release(&"move_up")
	_check(start_y - player.global_position.y > 15.0, "pressed between a machine and a tree, Seven can still walk out sideways (%.0f px)" % (start_y - player.global_position.y))

	# The vine zip passes over machines.
	await _fresh_arena()
	player = _arena.player
	player.global_position = _arena.grid.cell_to_world(Vector2i(4, 12))
	var tree: ForestTree = _arena.spawn_tree(Vector2i(14, 12), true)
	var in_the_way: Scrapper = _arena.spawn_scrapper_at(Vector2i(8, 12))
	await _wait_frames(2)
	in_the_way.yank_and_bind(in_the_way.global_position, 0.0, 999.0)
	_check(player.try_vine(tree.global_position), "the vine still latches a tree with a machine in the line")
	var landed_past: Callable = func() -> bool: return not player.is_zipping
	await _wait_until(landed_past, 3.0)
	_check(player.global_position.x > in_the_way.global_position.x + 20.0, "and the zip carries Seven past the machine")


## s19 items 4 and 5: the forest's vines SNARE (slowed, can still act); only
## Seven's own vine BINDS (frozen, cannot act).
func _test_s19_snare() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	player._invulnerable_left = 999.0  # the shots are not what these checks are about
	player.global_position = _arena.grid.cell_to_world(Vector2i(5, 12))
	var snared: Spitter = _arena.spawn_spitter_at(Vector2i(10, 12))
	var bound: Spitter = _arena.spawn_spitter_at(Vector2i(10, 14))
	await _wait_frames(2)
	snared.snare_for(30.0)
	bound.yank_and_bind(bound.global_position, 0.0, 30.0)
	_check(snared.is_snared and not snared.is_bound, "a snared machine is snared, not bound")
	_check(bound.is_bound and not bound.is_snared, "a bound machine is bound, not snared")
	_check(is_equal_approx(snared.movement_factor(), CONFIG.snare_speed_factor) and is_equal_approx(bound.movement_factor(), 1.0), "snaring slows walking; a bind is handled separately")

	# The snared Spitter still winds up and fires; the bound one never does.
	var shots: Node = _arena.get_node("Shots")
	var winding: Callable = func() -> bool: return snared.is_winding_up
	_check(await _wait_until(winding, CONFIG.spitter_cooldown + 2.0), "a Spitter caught on a forest vine still winds up")
	var fired: Callable = func() -> bool: return shots.get_child_count() >= 1
	_check(await _wait_until(fired, CONFIG.spitter_windup + 1.0), "and still fires")
	_check(not bound.is_winding_up, "a Spitter bound by Seven's vine never winds up")
	_check(snared.is_snared, "and the snare was still holding when it fired")

	# A snare slows a walker; the same walk unsnared goes further.
	await _fresh_arena()
	player = _arena.player
	player._invulnerable_left = 999.0
	player.global_position = _arena.grid.cell_to_world(Vector2i(3, 12))
	var held: Scrapper = _arena.spawn_scrapper_at(Vector2i(20, 12))
	var free: Scrapper = _arena.spawn_scrapper_at(Vector2i(20, 8))
	await _wait_frames(2)
	held.snare_for(30.0)
	var held_start: Vector2 = held.global_position
	var free_start: Vector2 = free.global_position
	await _wait_frames(30)
	var held_walked: float = held.global_position.distance_to(held_start)
	var free_walked: float = free.global_position.distance_to(free_start)
	_check(free_walked > 20.0 and held_walked < free_walked * 0.5, "a snared Scrapper crawls (%.0f px against %.0f px)" % [held_walked, free_walked])

	# A snare wears off, and Seven's vine on a snared machine binds it outright.
	held._snared_time_left = 0.0
	held._tick_bound(0.016)
	_check(not held.is_snared, "a snare wears off")
	held.snare_for(30.0)
	held.yank_and_bind(held.global_position, 0.0, 5.0)
	_check(held.is_bound and not held.is_snared, "Seven's vine on a snared machine binds it and ends the snare")
	held.snare_for(30.0)
	_check(not held.is_snared, "a bound machine cannot also be snared")

	# Item 5 (numbers only): the forest's grip is shorter than it was.
	_check(CONFIG.canopy_line_bind_seconds < 2.5 and CONFIG.trellis_bind_seconds < 2.0, "the forest's snares are shorter than the old binds (%.1f s and %.1f s)" % [CONFIG.canopy_line_bind_seconds, CONFIG.trellis_bind_seconds])


## s19 item 6: Canopy FM explains the forest's vines the first time one forms.
func _test_s19_canopy_line_line() -> void:
	await _fresh_arena()
	_arena.ng_plus = true
	_arena.tutorial_on = false  # New Game +, no reminder: the line must still come
	var a: ForestTree = _arena.spawn_tree(Vector2i(3, 12), true)
	var b: ForestTree = _arena.spawn_tree(Vector2i(9, 12), true)
	_check(_radio_copies_of(CONFIG.canopy_line_intro_line) == 0, "nothing is said before a line forms")
	a.mature()
	b.mature()
	await _wait_frames(3)
	_check(_arena.great_powers.lines.size() == 1, "two great sunroots string a canopy line")
	_check(_radio_copies_of(CONFIG.canopy_line_intro_line) == 1, "the first canopy line makes Canopy FM explain the vines")
	_check(not CONFIG.canopy_line_intro_line.contains("\n") and CONFIG.canopy_line_intro_line.count(". ") == 0, "and it is one sentence")
	# Said once: clear the radio, then form another line between two more trees.
	_arena._story_queue.clear()
	_arena.radio.clear()
	_arena._current_line = {}
	var c: ForestTree = _arena.spawn_tree(Vector2i(3, 6), true)
	var d: ForestTree = _arena.spawn_tree(Vector2i(9, 6), true)
	c.mature()
	d.mature()
	await _wait_frames(3)
	_check(_arena.great_powers.lines.size() >= 2 and _radio_copies_of(CONFIG.canopy_line_intro_line) == 0, "a later line says nothing more")


## s19 item 7: a faint ring shows where the Bramble Seed will land.
func _test_s19_bramble_preview() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	var floor_rect: Rect2 = _arena.bramble_floor_rect()
	_check(player.bramble_bounds == floor_rect, "the player knows the floor a bramble can land on")
	# In the open: exactly bramble_range_cells along the aim.
	player.global_position = _arena.grid.cell_to_world(Vector2i(10, 7))
	player.aim_direction = Vector2.RIGHT
	var open_spot: Vector2 = player.global_position + Vector2.RIGHT * CONFIG.bramble_range_cells * CONFIG.cell_size
	_check(player.bramble_landing_point().is_equal_approx(open_spot), "in the open the ring sits bramble_range_cells away")
	# Aimed at a wall: the ring sits at the clamped spot, one cell in from the wall.
	player.global_position = _arena.grid.cell_to_world(Vector2i(22, 7))
	var wall_spot: Vector2 = player.bramble_landing_point()
	_check(floor_rect.has_point(wall_spot) or is_equal_approx(wall_spot.x, floor_rect.end.x), "aimed at a wall the ring is kept on the floor")
	_check(is_equal_approx(wall_spot.x, floor_rect.end.x), "at the foot of the wall (x = %.0f)" % wall_spot.x)
	# What is drawn is where the patch grows.
	var thrown_at: Array[Vector2] = []
	player.bramble_thrown.connect(func(at: Vector2) -> void: thrown_at.append(at))
	var patches_before: int = _arena._brambles.get_child_count()
	_check(player.throw_bramble() and thrown_at.size() == 1, "a throw is announced")
	_check(thrown_at[0].is_equal_approx(wall_spot), "the seed is announced at the spot the ring showed")
	_check(_arena._brambles.get_child_count() == patches_before + 1 and _arena._brambles.get_child(patches_before).position.is_equal_approx(wall_spot), "and the patch grows exactly there")
	# The ring shows only while there is a seed in hand, and Seven is up and free.
	player.bramble_charges = 2
	_check(player.is_bramble_preview_shown(), "the ring shows while Seven holds a seed")
	player.bramble_charges = 0
	_check(not player.is_bramble_preview_shown(), "and not when there is none to throw")
	player.bramble_charges = 1
	player.locked = true
	_check(not player.is_bramble_preview_shown(), "nor while the upgrade cards have Seven locked")
	player.locked = false
	_check(Bramble.radius_px() == CONFIG.bramble_radius_cells * CONFIG.cell_size, "the ring is the size of the patch")


## s19 item 8: the Bramble Seed is introduced clearly, once, with a clip.
func _test_s19_bramble_intro() -> void:
	# The words say what it does, when to use it, and name the key.
	var keys_text: String = " ".join(CONFIG.dj_bramble)
	_check(keys_text.contains("Q or Space") and keys_text.contains("slows down") and keys_text.contains("gateway"), "the wave 2 radio lines name the key, say what it does and when to use it")
	_check(" ".join(CONFIG.dj_bramble_touch).contains("bramble button") and not keys_text.to_lower().contains("trick."), "the touch lines name the button")
	_check(CONFIG.intro_titles.has(Arena.BRAMBLE_KIND) and CONFIG.intro_titles[Arena.BRAMBLE_KIND].contains("Q or Space"), "the clip's title is in intro_titles and names the key")

	await _fresh_arena()
	_arena.intro_clips_on = true
	_arena.waves.time_scale = 0.0  # no machines arrive: only the bramble clip is under test
	_arena.waves.start_wave(1)
	await _wait_drawn_frames(3)
	_check(_arena.clip_left <= 0.0, "no clip in wave 1")
	# Wave 2, but another clip is playing: the bramble clip waits its turn.
	_arena.clip_left = 5.0
	_arena.waves.start_wave(2)
	await _wait_drawn_frames(3)
	_check(not _arena._intro_done.has(Arena.BRAMBLE_KIND), "it waits while another clip is playing")
	_arena.clip_left = 0.0
	# No seed in hand yet: still waits ("the first time a charge is available").
	_arena.player.bramble_charges = 0
	_arena.player.bramble_recharge_left = 100.0  # or the next physics step would grow one back
	await _wait_drawn_frames(3)
	_check(_arena.clip_left <= 0.0, "and while Seven has no seed")
	_arena.player.bramble_charges = 1
	await _wait_drawn_frames(3)
	_check(_arena.clip_left > 0.0 and _arena.clip_label.text == CONFIG.intro_titles[Arena.BRAMBLE_KIND], "wave 2 with a seed in hand: the clip plays, with its title")
	# Once only, even after the wave restarts.
	_arena.clip_left = 0.0
	Engine.time_scale = 1.0
	_arena._restart_current_wave()
	await _wait_drawn_frames(3)
	_check(_arena.clip_left <= 0.0, "it does not play again after a restart")
	_arena.intro_clips_on = false
	Engine.time_scale = 1.0


## s19 item 9: Lucky's lines stay up longer, and on a phone the open shop shows
## a paw "Tap" button that counts as a tap on Lucky.
func _test_s19_lucky() -> void:
	# The shipped numbers (the checks shorten the shared config's holds, so ask a
	# fresh GameConfig for the defaults).
	var shipped := GameConfig.new()
	_check(shipped.lucky_line_seconds > shipped.story_line_seconds, "Lucky's lines are held longer than everyone else's (%.0f s against %.0f s)" % [shipped.lucky_line_seconds, shipped.story_line_seconds])

	await _fresh_arena()
	# (CONFIG.set() from the test scene does not reach the arena's config, so these
	# checks use the numbers as shipped.)
	_check(is_equal_approx(_arena._hold_seconds_for(Radio.LUCKY), shipped.lucky_line_seconds), "Lucky's hold is her own number")
	_check(is_equal_approx(_arena._hold_seconds_for(Radio.CANOPY), shipped.story_line_seconds) and is_equal_approx(_arena._hold_seconds_for(Radio.HELIOS), shipped.story_line_seconds), "Canopy FM and Helios keep the usual hold")
	var line: String = "Hello, kid."
	var typing: float = float(line.length()) / shipped.radio_chars_per_second
	_arena._radio_interrupt(_arena._lucky_says(line))
	_check(is_equal_approx(_arena._story_time_left, shipped.lucky_line_seconds + typing), "a Lucky line is on the air for her hold plus its typing time")
	_arena._radio_interrupt(Arena._radio_line(Radio.CANOPY, line))
	_check(is_equal_approx(_arena._story_time_left, shipped.story_line_seconds + typing), "a Canopy FM line is on the air for the usual hold")

	# The tap button: only when the shop is open and the player is on a phone.
	await _fresh_arena()
	var shop: CatShop = _arena.cat_shop
	_arena.player.touch_mode = true
	await _wait_drawn_frames(2)
	_check(not shop.show_tap_button, "a shut shop shows no button")
	for i: int in CONFIG.cat_hits_needed:
		shop.hit_by_seed()
	await _wait_drawn_frames(2)
	_check(shop.show_tap_button, "the open shop shows the paw button on a phone")
	var button_at: Vector2 = shop.get_global_transform_with_canvas().origin + CatShop.button_offset()
	_check(_arena._is_on_shop(button_at), "a tap on the button counts as a tap on Lucky")
	_check(_arena._is_on_shop(button_at + Vector2(CONFIG.lucky_button_radius_px - 2.0, 0.0)), "also near its edge")
	_check(not _arena._is_on_shop(button_at + Vector2(CONFIG.lucky_button_radius_px + 40.0, 0.0)), "but not well outside it")
	_check(CatShop.button_offset().y > float(CONFIG.cell_size) / 2.0 + CatShop.STICK_OUT, "the button sits below the shop's ledge")
	_arena.player.touch_mode = false
	await _wait_drawn_frames(2)
	_check(not shop.show_tap_button, "on a desktop the button is not shown (the shop says 'E: talk' instead)")


## s19 item 10: trees are DRAWN bigger, but what they block stays exactly one cell.
func _test_s19_bigger_trees() -> void:
	await _fresh_arena(true)
	_check(CONFIG.tree_draw_scale > 1.0, "a grown tree is drawn bigger than before (%.2f x)" % CONFIG.tree_draw_scale)
	var grown: ForestTree = _arena.spawn_tree(Vector2i(8, 12), true)
	var young: ForestTree = _arena.spawn_tree(Vector2i(12, 12), false)
	await _wait_frames(2)
	_check(is_equal_approx(grown.drawn_scale(), CONFIG.tree_draw_scale), "a grown tree is drawn at the new scale")
	_check(is_equal_approx(young.drawn_scale(), 1.0), "a sapling keeps its size")
	grown.mature()
	_check(is_equal_approx(grown.drawn_scale(), CONFIG.tree_draw_scale), "so does a great sunroot")
	# The collision square is exactly one cell for every kind of tree, whatever is drawn.
	var cell_px: float = float(CONFIG.cell_size)
	var trees: Array[ForestTree] = [grown, young, _arena.heart_tree]
	for tree: ForestTree in trees:
		var square: Vector2 = (tree.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect().size
		_check(square.is_equal_approx(Vector2(cell_px, cell_px)), "a tree's collision square is exactly one cell (%.0f x %.0f)" % [square.x, square.y])
	_check((grown.get_node("CollisionShape2D") as CollisionShape2D).scale.is_equal_approx(Vector2.ONE) and grown.scale.is_equal_approx(Vector2.ONE), "the tree itself is not scaled, only its picture")


## s19 open note: "the fuse saved Seven more than once". Not reproduced by reading
## the code (one fuse per shop opening, never refitted); this tries to make it
## happen by going down again and again, through restarts and extra pods on the shop.
func _test_s19_fuse_saves_once() -> void:
	await _fresh_arena()
	var player: Player = _arena.player
	var saves: Array[int] = [0]  # an Array so the lambda below can change it
	player.fuse_used.connect(func() -> void: saves[0] += 1)
	_arena.waves.wave = 3
	_arena.waves.state = WaveDirector.State.FIGHTING
	for i: int in CONFIG.cat_hits_needed:
		_arena.cat_shop.hit_by_seed()
	_check(player.has_fuse, "opening the shop fits one fuse")
	# Go down five times in a row, restarting the wave in between each time.
	for attempt: int in 5:
		player.hp = 1
		player._invulnerable_left = 0.0
		player.fuse_shield_left = 0.0
		player.take_damage(1)
		if player.is_dead:
			_arena._restart_current_wave()
	_check(saves[0] == 1, "five knock-outs in a row used the fuse exactly once (%d)" % saves[0])
	_check(not player.has_fuse, "and no fuse is fitted again after it blows")
	# More pods on an already-open shop, and a restart, give nothing back either.
	for i: int in 6:
		_arena.cat_shop.hit_by_seed()
	_arena._restart_current_wave()
	_check(not player.has_fuse and saves[0] == 1, "more pods on the open shop and another restart do not refit it")


## s24 SKILL UNLOCKS: Bramble Seeds and the Vine Trip Line are not there at the
## start of a run. They are upgrade cards, both on the screen after wave
## skill_unlock_after_wave (3), and ordinary random cards after that.
func _test_s24_skill_unlocks() -> void:
	_check(CONFIG.skill_unlock_after_wave == 3, "the skill cards first come after wave 3")
	await _fresh_arena(false, true)  # locked_skills: as the real game starts
	var player: Player = _arena.player
	var powers: GreatPowers = _arena.great_powers
	_check(_arena.skill_cards_on and not _arena.trip_line_unlocked, "a run starts with skill cards on and no trip line")

	# --- Locked: no seeds, no throw, none grow back, nothing on screen. ---
	_check(not player.bramble_unlocked and player.bramble_charges == 0, "and no Bramble Seeds in hand")
	_check(not player.throw_bramble(), "Q / Space throws nothing")
	_check(not player.is_bramble_preview_shown(), "and no landing ring shows")
	player._tick_brambles(100.0)  # far longer than a recharge
	_check(player.bramble_charges == 0, "no seed grows back while locked")
	player.revive(player.global_position)
	_check(player.bramble_charges == 0, "a revive does not hand back locked seeds")
	_arena.waves.time_scale = 0.0  # no machines arrive: only the HUD is under test
	_arena.waves.start_wave(1)
	await _wait_drawn_frames(2)  # the arena's _process rewrites the label once per drawn frame
	var label: String = (_arena.get_node("Hud/WaveLabel") as Label).text
	_check(label.begins_with("Wave 1") and not label.contains("Brambles"), "the HUD has no Brambles counter yet")
	_check(not " ".join(_arena._pause.controls_lines(false)).contains("Bramble") and not " ".join(_arena._pause.controls_lines(true)).contains("Bramble"), "the pause menu does not list the Bramble Seed yet")
	_check(" ".join(_arena._pause.controls_lines(false)).contains("R   reload"), "but it does list R for reload")
	var touch: TouchControls = _touch_controls()
	var button_spot: Vector2 = TouchControls.BRAMBLE_SPOT * touch.get_viewport_rect().size
	_check(not touch.is_bramble_button_shown() and not touch.bramble_button_hit(button_spot), "the touch bramble button is hidden and cannot be tapped")
	_check(not " ".join(_arena.dj_lines_for_wave(2)).contains(CONFIG.dj_bramble[0]), "wave 2 no longer explains the Bramble Seed")
	# A tree-to-tree zip leaves no trip line yet (same zip as _test_trellis).
	var a: ForestTree = _arena.spawn_tree(Vector2i(3, 12), true)
	var b: ForestTree = _arena.spawn_tree(Vector2i(9, 12), true)
	player.zip_from = a.global_position + Vector2(CONFIG.cell_size, 0.0)
	player.zip_tree = b
	_arena._on_player_zip_finished()
	_check(powers.trellises.is_empty(), "a tree-to-tree zip strings no trip line before its card")

	# --- Which cards are dealt, screen by screen. ---
	# The arena reads waves.wave to know which screen it is dealing, so setting it
	# by hand stands in for "wave N was just cleared" without fighting it.
	for wave: int in [1, 2]:
		_arena.waves.wave = wave
		var early: Array[StringName] = _arena.upgrades_left_out()
		_check(early.has(&"bramble_seed") and early.has(&"trip_line") and _arena.upgrades_always_shown().is_empty(), "after wave %d neither unlock card is dealt" % wave)
	_check(_arena.upgrades_left_out().has(&"long_trellis"), "and the 'lasts longer' card waits for the trip line")
	_arena.waves.wave = 3
	var must: Array[StringName] = _arena.upgrades_always_shown()
	_check(must.size() == 2 and must[0] == &"bramble_seed" and must[1] == &"trip_line", "after wave 3 both unlock cards must be shown")
	_arena.upgrade_picker.offer(CONFIG.upgrade_choices, _arena.upgrades_left_out(), must)
	var row: Array[StringName] = _arena.upgrade_picker.offered
	_check(row.size() == CONFIG.upgrade_choices and row[0] == &"bramble_seed" and row[1] == &"trip_line" and not row.slice(2).has(&"bramble_seed"), "the wave 3 screen shows both, plus a random card")
	_arena.upgrade_picker.cancel()
	_arena.waves.wave = 4
	var later: Array[StringName] = _arena.upgrades_left_out()
	_check(_arena.upgrades_always_shown().is_empty() and not later.has(&"bramble_seed") and not later.has(&"trip_line"), "after wave 4 a skipped unlock is an ordinary random card")
	_check(UpgradePicker._describe(&"bramble_seed").contains(str(CONFIG.bramble_max_charges)) and UpgradePicker._describe(&"trip_line").contains("%.0f" % CONFIG.trellis_seconds), "the unlock cards name their numbers")
	_check(_arena.upgrade_picker.has_icon(&"bramble_seed") and _arena.upgrade_picker.has_icon(&"trip_line"), "both unlock cards have a picture")
	# Every card title fits on its card (the space beside the picture), shrinking
	# its font if it has to. "Seed Loader Pouch" used to be cut off.
	var font: Font = ThemeDB.fallback_font
	var title_width: float = UpgradePicker.CARD_SIZE.x - UpgradePicker.ICON_MARGIN * 2.0 - UpgradePicker.ICON_SIZE - 14.0
	var all_fit: bool = true
	for id: StringName in UpgradePicker.CATALOG.keys():
		var title: String = "%d   %s" % [3, UpgradePicker.CATALOG[id][0]]
		var size: int = UpgradePicker.title_font_size(font, title, title_width)
		if font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x > title_width:
			all_fit = false
	_check(all_fit, "every card title fits on its card")

	# --- Picking Bramble Seed. ---
	# apply_upgrade is what the arena runs when the picker's `picked` signal fires,
	# so calling it straight is the same as clicking the card.
	_arena.apply_upgrade(&"bramble_seed")
	_check(player.bramble_unlocked and player.bramble_charges == CONFIG.bramble_max_charges, "the Bramble Seed card hands over a full hand of seeds")
	_check(_arena.upgrades_left_out().has(&"bramble_seed"), "and is not dealt again")
	_check(" ".join(_arena._pause.controls_lines(false)).contains("Q or Space   throw a Bramble Seed"), "the pause menu now lists Q or Space")
	_check(touch.is_bramble_button_shown() and touch.bramble_button_hit(button_spot), "the touch button shows and can be tapped")
	_check(_arena.skill_tip_lines() == CONFIG.dj_bramble, "Canopy FM will explain it when the next wave starts")
	# "await get_tree().process_frame" waits for one drawn frame, so the arena's
	# _process has rewritten the HUD label before it is read.
	await get_tree().process_frame
	label = (_arena.get_node("Hud/WaveLabel") as Label).text
	_check(label.contains("Brambles %d / %d" % [CONFIG.bramble_max_charges, CONFIG.bramble_max_charges]), "the HUD counter appears")
	_check(player.throw_bramble(), "and a seed can be thrown")

	# --- Picking Vine Trip Line, then its "lasts longer" card. ---
	_arena.apply_upgrade(&"trip_line")
	_check(_arena.trip_line_unlocked and _arena.upgrades_left_out().has(&"trip_line"), "the Trip Line card unlocks the trip line, once")
	_check(not _arena.upgrades_left_out().has(&"long_trellis"), "and the 'lasts longer' card can now be dealt")
	var tips: Array[String] = _arena.skill_tip_lines()
	_check(tips.size() == CONFIG.dj_bramble.size() + CONFIG.dj_trip_line.size() and tips[-1] == CONFIG.dj_trip_line[0], "both tips are waiting, in the order picked")
	_arena._on_player_zip_finished()
	_check(powers.trellises.size() == 1 and is_equal_approx(powers.trellises[0].time_left, CONFIG.trellis_seconds), "the same zip now strings a trip line for %.0f s" % CONFIG.trellis_seconds)

	# --- The next wave says the tips once; a restart does not say them again. ---
	_arena.waves.start_wave(4)
	_check(_arena.skill_tip_lines().is_empty(), "the tips are said when the next wave starts, then cleared")
	_arena._restart_current_wave()
	_check(_arena.skill_tip_lines().is_empty() and player.bramble_unlocked and _arena.trip_line_unlocked, "a restarted wave keeps the skills and does not repeat the tips")

	# --- The Bramble clip plays right after the card, never while the cards are up. ---
	await _fresh_arena(false, true)
	player = _arena.player
	_arena.intro_clips_on = true
	_arena.waves.time_scale = 0.0
	_arena.waves.start_wave(1)
	await _wait_drawn_frames(3)
	_check(_arena.clip_left <= 0.0, "no Bramble clip while the seeds are locked")
	_arena.waves.wave = 3
	_arena.upgrade_picker.offer(CONFIG.upgrade_choices, _arena.upgrades_left_out(), _arena.upgrades_always_shown())
	player.locked = true  # the cards park Seven
	player.unlock_brambles()  # seeds in hand, cards still up
	await _wait_drawn_frames(3)
	_check(_arena.clip_left <= 0.0, "nor while the cards are still up")
	_arena.upgrade_picker.choose(0)  # Bramble Seed
	await _wait_drawn_frames(3)
	_check(_arena.clip_left > 0.0 and _arena.clip_label.text == CONFIG.intro_titles[Arena.BRAMBLE_KIND], "the clip plays as soon as the card is picked")
	_arena.clip_left = 0.0
	_arena.intro_clips_on = false
	Engine.time_scale = 1.0

	# --- Set to 0 in the config, the skills are there from the start. ---
	# The rule is a static function (it needs no arena), so the 0 case can be
	# asked directly without changing the shared config.
	_check(not Arena.skill_cards_wanted(true, 0), "skill_unlock_after_wave = 0 means no skill cards")
	_check(Arena.skill_cards_wanted(true, 3) and not Arena.skill_cards_wanted(false, 3), "otherwise the cards are on unless the arena was told not to lock")
	# With the cards off (here: an older-check arena) both skills are there from
	# the start and their cards are never dealt.
	await _fresh_arena()
	_check(not _arena.skill_cards_on and _arena.player.bramble_unlocked and _arena.trip_line_unlocked, "without skill cards both skills are there from the start")
	_arena.waves.wave = 3
	_check(_arena.upgrades_left_out().has(&"bramble_seed") and _arena.upgrades_left_out().has(&"trip_line") and _arena.upgrades_always_shown().is_empty(), "and their cards are never dealt")
