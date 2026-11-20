# capture_skills.gd - saves pictures of the s24 skill unlocks as the real game
# draws them: the HUD before (no Brambles counter), the card screen after wave 3
# (both unlock cards plus one random card), the Bramble Seed clip right after its
# card, the HUD after, and the pause menu's CONTROLS list after the unlock.
#
# Run WITHOUT --headless (a headless run draws nothing):
#   <Godot_v4.7.2-stable_win64_console.exe> --path . res://tests/capture_skills.tscn
# The pictures land in docs/s24/.
extends Node

const ARENA_SCENE: PackedScene = preload("res://scenes/arena.tscn")
const OUT_DIR: String = "res://docs/s24/"


## Runs once: build the arena, stage each moment, take its picture, quit.
## (`await` pauses this function until the thing after it happens, such as the
## next physics step or a timer running out, without freezing the game.)
func _ready() -> void:
	Sfx.effects_on = false
	CanopyFM.set_music_on(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var arena: Arena = ARENA_SCENE.instantiate()
	arena.autostart_waves = false
	arena.random_cat_shop = false
	arena.wave_end_beat_seconds = 0.0
	add_child(arena)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var full := Rect2i(Vector2i.ZERO, Vector2i(get_viewport().get_visible_rect().size))
	var hud := Rect2i(0, 0, 900, 40)  # the corner label along the top

	# 1. Wave 1: the HUD has no Brambles counter (the seeds are still locked).
	arena.waves.time_scale = 0.0  # no machines walk in: only the screens matter
	arena.waves.start_wave(1)
	await get_tree().create_timer(1.0).timeout
	await _save(hud, 2, "skills_1_hud_locked.png")

	# 2. Wave 3 cleared: the card screen deals both unlocks plus one random card.
	arena.waves.wave = 3
	arena.waves.hold_break = true
	arena._end_wave_end_beat()  # deals the cards and parks Seven by the Heart Tree
	await get_tree().create_timer(0.8).timeout
	await _save(full, 1, "skills_2_wave3_cards.png")

	# 3. Bramble Seed picked: its clip plays straight away.
	arena.upgrade_picker.choose(0)
	await get_tree().create_timer(0.6, true, false, true).timeout  # real seconds (the clip slows the game)
	await _save(full, 1, "skills_3_bramble_clip.png")
	arena.clip_left = 0.0
	Engine.time_scale = 1.0

	# 4. The HUD now shows the Brambles counter.
	await get_tree().create_timer(0.5).timeout
	await _save(hud, 2, "skills_4_hud_unlocked.png")

	# 5. The pause menu lists Q or Space now.
	arena._pause.set_paused(true)
	await get_tree().create_timer(0.5).timeout
	await _save(full, 1, "skills_5_pause_controls.png")
	arena._pause.set_paused(false)

	# 6. The longest card title, "Seed Loader Pouch", fits on its card now.
	arena.waves.hold_break = true
	arena._end_wave_end_beat()
	# Swap in a chosen row (not a random deal) so the picture always holds the
	# longest title; queue_redraw asks the picker to run its _draw again.
	var deal: Array[StringName] = [&"seed_pouch", &"long_trellis", &"quick_reload"]
	arena.upgrade_picker.offered = deal
	arena.upgrade_picker.queue_redraw()
	await get_tree().create_timer(0.8).timeout
	await _save(Rect2i(40, 390, 1200, 140), 1, "skills_6_card_titles.png")
	get_tree().quit()


## Saves `region` of the screen, enlarged `zoom` times, as docs/s24/<file_name>.
func _save(region: Rect2i, zoom: int, file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var crop: Image = get_viewport().get_texture().get_image().get_region(region)
	crop.resize(region.size.x * zoom, region.size.y * zoom, Image.INTERPOLATE_NEAREST)
	crop.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
	print("saved ", file_name)
