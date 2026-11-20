# capture_logbook.gd - saves pictures of the s25 Logbook as the real game draws
# it: the pause menu on its usual THIS RUN page (now with seven buttons), then the
# Logbook's newest page and, if there is one, its second page.
#
# Run WITHOUT --headless (a headless run draws nothing):
#   <Godot_v4.7.2-stable_win64_console.exe> --path . res://tests/capture_logbook.tscn
# The pictures land in docs/s25/.
extends Node

const ARENA_SCENE: PackedScene = preload("res://scenes/arena.tscn")
const OUT_DIR: String = "res://docs/s25/"


## Runs once: build the arena, have Canopy FM and Lucky say a run's worth of
## lines, open the pause menu, take its pictures, quit. (`await` pauses this
## function until the thing after it happens, without freezing the game.)
func _ready() -> void:
	Sfx.effects_on = false
	CanopyFM.set_music_on(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var arena: Arena = ARENA_SCENE.instantiate()
	arena.autostart_waves = false
	arena.random_cat_shop = false
	arena.wave_end_beat_seconds = 0.0
	arena.intro_clips_on = false  # no slow-motion clips: only the menu matters here
	add_child(arena)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var full := Rect2i(Vector2i.ZERO, Vector2i(get_viewport().get_visible_rect().size))

	# A run so far: wave 1's tutorial, the Bramble Seed card and its tip at wave 4,
	# and a word from Lucky. Draining the queue puts each line on the air in turn,
	# which is the moment the Logbook writes it down.
	arena.waves.time_scale = 0.0  # no machines walk in
	arena.waves.start_wave(1)
	_drain(arena)
	arena.apply_upgrade(&"bramble_seed")
	arena.waves.start_wave(4)
	_drain(arena)
	arena._radio_interrupt(arena._lucky_says(_lucky_line()))
	_drain(arena)
	await get_tree().create_timer(0.5).timeout

	# 1. The pause menu as it opens: seven buttons, THIS RUN on the right.
	arena._pause.set_paused(true)
	await get_tree().create_timer(0.3, true).timeout
	await _save(full, "logbook_1_pause_menu.png")

	# 2. Button 6: the Logbook's newest page.
	arena._pause.choose(PauseOverlay.Item.LOGBOOK)
	await get_tree().create_timer(0.3, true).timeout
	await _save(full, "logbook_2_page_1.png")

	# 3. Pressed again: the next, older page (only if the book has one).
	if arena.logbook.pages().size() > 1:
		arena._pause.choose(PauseOverlay.Item.LOGBOOK)
		await get_tree().create_timer(0.3, true).timeout
		await _save(full, "logbook_3_page_2.png")
	print("logbook holds ", arena.logbook.size(), " lines on ", arena.logbook.pages().size(), " pages")
	arena._pause.set_paused(false)
	get_tree().quit()


## Lucky's early greeting, the line said when the shop is found in waves 1 to 3.
func _lucky_line() -> String:
	return Arena.CONFIG.lucky_greeting_early


## Puts every waiting radio line on the air at once (see tests/check.gd).
func _drain(arena: Arena) -> void:
	while not arena._story_queue.is_empty():
		arena._show_next_story_line()


## Saves `region` of the screen as docs/s25/<file_name>.
func _save(region: Rect2i, file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var crop: Image = get_viewport().get_texture().get_image().get_region(region)
	crop.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
	print("saved ", file_name)
