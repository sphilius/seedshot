# capture_trees.gd - stages one picture of a forest and saves it to docs/s19/ so a
# change to how trees are DRAWN can be compared before and after (s19 item 10).
#
# Run it from the project folder with the NON-mono console build, WITHOUT --headless
# (a headless run draws nothing). Everything after the lone `--` is read by the
# script: the first word is the label put in the file name.
#   <Godot_v4.7.2-stable_win64_console.exe> --path . res://tests/capture_trees.tscn -- before
# It writes docs/s19/trees_before.png and quits. It never touches itch/.
extends Node

const ARENA_SCENE: PackedScene = preload("res://scenes/arena.tscn")
const OUT_DIR: String = "res://docs/s19/"

## A mid-run forest: clumps and a lone tree or two, clear of Seven's start cell.
const FOREST_CELLS: Array[Vector2i] = [
	Vector2i(4, 3), Vector2i(5, 3), Vector2i(4, 4), Vector2i(8, 5), Vector2i(9, 5),
	Vector2i(8, 10), Vector2i(9, 10), Vector2i(9, 11), Vector2i(11, 3), Vector2i(12, 4),
	Vector2i(15, 9), Vector2i(16, 9), Vector2i(16, 10), Vector2i(18, 4), Vector2i(19, 4),
	Vector2i(20, 8), Vector2i(21, 8), Vector2i(21, 11), Vector2i(4, 10), Vector2i(12, 11),
]


func _ready() -> void:
	# OS.get_cmdline_user_args() returns what followed `--` on the command line.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var label: String = args[0] if args.size() > 0 else "shot"
	Sfx.effects_on = false  # no noise while the window is up
	CanopyFM.set_music_on(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var arena: Arena = ARENA_SCENE.instantiate()
	arena.autostart_waves = false
	arena.wave_end_beat_seconds = 0.0
	add_child(arena)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for cell: Vector2i in FOREST_CELLS:
		if arena.tree_at(cell) == null:
			arena.spawn_tree(cell, true)
	# Two great sunroots (the biggest drawn tree) and one tree a Sawbot has bitten.
	arena.tree_at(Vector2i(9, 5)).mature()
	arena.tree_at(Vector2i(16, 9)).mature()
	arena.tree_at(Vector2i(21, 8)).take_damage(2)
	# Mid-run light, so the picture matches what a player sees.
	arena.waves.wave = 6
	arena.waves_cleared = 5
	arena.graffiti.reveal_up_to(5)
	arena._update_light()
	# A few machines among the trees, and Seven with a young sapling beside it.
	arena.spawn_scrapper_at(Vector2i(14, 7))
	arena.spawn_spitter_at(Vector2i(18, 12))
	arena.spawn_sawbot_at(Vector2i(10, 8))
	arena.spawn_tree(Vector2i(7, 7), false)  # false = a sapling
	arena.player.touch_mode = true  # stops the mouse overriding the aim
	arena.player.aim_direction = Vector2.RIGHT
	await get_tree().create_timer(1.3).timeout
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path(OUT_DIR + "trees_%s.png" % label)
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
	get_tree().quit()
