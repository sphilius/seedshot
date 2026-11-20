# capture_hd.gd - s26 HD display test: stages the arena at ONE fixed moment (lit block, grown trees,
# all six machines, Seven aiming) and saves the frame, so the 64 px art and the 128 px art can be
# compared at the same moment and the same window size.
#
# Run WITHOUT --headless (a headless run draws nothing). Everything after "--" goes to the script:
#   <Godot_v4.7.2-stable_win64_console.exe> --path . --resolution 1920x1080 res://tests/capture_hd.tscn -- after
# Saves docs/s26/arena_<label>_<width>x<height>.png (the whole window) and
#       docs/s26/arena_<label>_<width>x<height>_seven.png (a 3x close-up around Seven).
extends Node

const ARENA_SCENE: PackedScene = preload("res://scenes/arena.tscn")
const OUT_DIR: String = "res://docs/s26/"
## The close-up: a square this many WINDOW pixels wide around Seven, then enlarged ZOOM times.
const CROP_LAYOUT_PX: float = 120.0
const ZOOM: int = 3


## Runs once: build the arena, stage the moment, save two pictures, quit.
func _ready() -> void:
	Sfx.effects_on = false  # no noise while the window is up
	CanopyFM.set_music_on(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	# OS.get_cmdline_user_args() = the words after "--" on the command line.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var label: String = args[0] if args.size() > 0 else "shot"
	var arena: Arena = ARENA_SCENE.instantiate()
	arena.autostart_waves = false
	arena.wave_end_beat_seconds = 0.0
	add_child(arena)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Grown trees in two clumps, a sapling, and the six machines. Cells are (column, row).
	for cell: Vector2i in [Vector2i(6, 4), Vector2i(7, 4), Vector2i(6, 5), Vector2i(17, 9), Vector2i(18, 9), Vector2i(12, 3)]:
		arena.spawn_tree(cell, true)
	arena.spawn_tree(Vector2i(9, 10), false)  # false = a sapling
	arena.spawn_scrapper_at(Vector2i(10, 6))
	arena.spawn_scrapper_at(Vector2i(14, 4), true)  # a Linebreaker
	arena.spawn_sawbot_at(Vector2i(16, 7), false)
	arena.spawn_sawbot_at(Vector2i(20, 5), true)   # a Ripsaw
	arena.spawn_spitter_at(Vector2i(4, 9), false)
	arena.spawn_spitter_at(Vector2i(21, 10), true)  # an Arc Spitter
	# Freeze the machines where they stand (a disabled node is still drawn, but does not move).
	for machine: Node in get_tree().get_nodes_in_group("enemies"):
		machine.process_mode = Node.PROCESS_MODE_DISABLED
	# Most of the block lit, so the colours are close to how they were drawn.
	arena.waves.wave = 9
	arena.waves_cleared = 8
	arena._update_light()
	arena.player.touch_mode = true  # stops the real mouse overriding the aim we set
	arena.player.aim_direction = Vector2(1, -0.4).normalized()
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	var shot: Image = get_viewport().get_texture().get_image()
	var size_text: String = "%dx%d" % [shot.get_width(), shot.get_height()]
	var base: String = OUT_DIR + "arena_%s_%s" % [label, size_text]
	shot.save_png(ProjectSettings.globalize_path(base + ".png"))
	# The close-up. The picture is in WINDOW pixels; the game's layout is 1280 x 720, so layout
	# positions are multiplied by the window's scale to find Seven in the picture.
	var scale: float = float(shot.get_width()) / 1280.0
	var centre: Vector2 = arena.player.get_global_transform_with_canvas().origin * scale
	var crop: int = int(CROP_LAYOUT_PX * scale)
	var corner: Vector2i = Vector2i(centre) - Vector2i(crop / 2, crop / 2)
	var piece: Image = shot.get_region(Rect2i(corner, Vector2i(crop, crop)))
	piece.resize(int(CROP_LAYOUT_PX) * ZOOM, int(CROP_LAYOUT_PX) * ZOOM, Image.INTERPOLATE_NEAREST)
	piece.save_png(ProjectSettings.globalize_path(base + "_seven.png"))
	print("saved ", base, " (+ _seven)")
	get_tree().quit()
