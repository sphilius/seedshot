# capture_machines.gd - saves one picture of every machine kind standing on the real
# arena floor, at night and at day, to judge whether the art reads against the floor.
#
# Run WITHOUT --headless (a headless run draws nothing):
#   <Godot_v4.7.2-stable_win64_console.exe> --path . res://tests/capture_machines.tscn
extends Node

const ARENA_SCENE: PackedScene = preload("res://scenes/arena.tscn")
const OUT_DIR: String = "res://docs/s21/"


## Runs once: build an arena, line the machines up, save two pictures (dark, then lit).
func _ready() -> void:
	Sfx.effects_on = false
	CanopyFM.set_music_on(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var arena: Arena = ARENA_SCENE.instantiate()
	arena.autostart_waves = false
	add_child(arena)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# One of each kind in a row across the middle of the floor. Cells are (column, row).
	arena.spawn_scrapper_at(Vector2i(4, 5))
	arena.spawn_scrapper_at(Vector2i(7, 5), true)  # a Linebreaker
	arena.spawn_sawbot_at(Vector2i(11, 5), false)
	arena.spawn_sawbot_at(Vector2i(14, 5), true)   # a Ripsaw
	arena.spawn_spitter_at(Vector2i(18, 5), false)
	arena.spawn_spitter_at(Vector2i(21, 5), true)  # an Arc Spitter
	# Freeze them where they stand (a disabled node is still drawn, but does not move).
	for machine: Node in get_tree().get_nodes_in_group("enemies"):
		machine.process_mode = Node.PROCESS_MODE_DISABLED
	for child: Node in arena.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
	for step: int in 2:
		# Step 0: the arena's first-wave darkness. Step 1: most of the block lit.
		if step == 1:
			arena.waves.wave = 9
			arena.waves_cleared = 8
			arena._update_light()
		await get_tree().create_timer(1.6).timeout
		await RenderingServer.frame_post_draw
		var shot: Image = get_viewport().get_texture().get_image()
		var strip: Image = shot  # the whole frame
		var path: String = ProjectSettings.globalize_path(OUT_DIR + ("machines_night.png" if step == 0 else "machines_lit.png"))
		strip.save_png(path)
		print("saved ", path)
	get_tree().quit()
