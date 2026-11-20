# capture_reload.gd - saves close-ups of the s22 reload as the real game draws it:
# the row of pod pips under Seven (full, then part used), the reload ring halfway,
# and the upgrade cards with Quick Reload dealt.
#
# Run WITHOUT --headless (a headless run draws nothing):
#   <Godot_v4.7.2-stable_win64_console.exe> --path . res://tests/capture_reload.tscn
# The pictures land in docs/s22/.
extends Node

const ARENA_SCENE: PackedScene = preload("res://scenes/arena.tscn")
const OUT_DIR: String = "res://docs/s22/"


## Runs once: build the arena, stage each moment, take its picture, quit.
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
	await get_tree().create_timer(1.0).timeout
	var player: Player = arena.player

	# 1. A full load: ten bright pips.
	await _save(_around(player), 3, "reload_1_full.png")
	# 2. Six pods fired: four bright, six dim.
	player.seeds_in_clip = 4
	await get_tree().process_frame
	await _save(_around(player), 3, "reload_2_four_left.png")
	# 3. Halfway through a reload: the ring half filled. The tick is stopped
	# (process off) so the picture catches exactly half.
	player.seeds_in_clip = 0
	player.start_reload()
	player.reload_left = player.reload_seconds / 2.0
	player.set_physics_process(false)
	await get_tree().process_frame
	await _save(_around(player), 3, "reload_3_ring_half.png")
	player.set_physics_process(true)

	# 4. The upgrade cards, with Quick Reload dealt first.
	arena.waves.hold_break = true
	arena._end_wave_end_beat()  # deals the cards and parks Seven by the Heart Tree
	var deal: Array[StringName] = [&"quick_reload", &"seed_pouch", &"hardwood"]
	arena.upgrade_picker.offered = deal
	arena.upgrade_picker.queue_redraw()
	await get_tree().create_timer(0.8).timeout
	await _save(Rect2i(Vector2i.ZERO, get_viewport().get_visible_rect().size), 1, "reload_4_cards.png")
	get_tree().quit()


## The part of the screen around Seven: 160 x 120 pixels with Seven in the middle.
func _around(player: Player) -> Rect2i:
	var at: Vector2 = player.get_global_transform_with_canvas().origin
	return Rect2i(int(at.x) - 80, int(at.y) - 60, 160, 120)


## Saves `region` of the screen, enlarged `zoom` times, as docs/s22/<file_name>.
func _save(region: Rect2i, zoom: int, file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var crop: Image = get_viewport().get_texture().get_image().get_region(region)
	crop.resize(region.size.x * zoom, region.size.y * zoom, Image.INTERPOLATE_NEAREST)
	crop.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
	print("saved ", file_name)
