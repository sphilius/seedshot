# capture_nozzle.gd - stages Seven aiming in each of the eight directions and saves one contact
# sheet (docs/s24/nozzle_facings.png), so the new gold nozzle arm can be checked against every
# facing of the sprite strip. Run it WITHOUT --headless (a headless run draws nothing):
#   <Godot_v4.7.2-stable_win64_console.exe> --path . res://tests/capture_nozzle.tscn
extends Node

const ARENA_SCENE: PackedScene = preload("res://scenes/arena.tscn")
const OUT_FILE: String = "res://docs/s24/nozzle_facings.png"
## The eight aim directions, in the same order as the facing strip: East first, then clockwise on screen.
const DIRECTIONS: Array[Vector2] = [
	Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1),
	Vector2(-1, 0), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),
]
## Each picture is a square this many screen pixels wide, cut out around Seven and shown 3x bigger.
const CROP: int = 96
const ZOOM: int = 3


func _ready() -> void:
	Sfx.effects_on = false  # no noise while the window is up
	CanopyFM.set_music_on(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/s24/"))
	var arena: Arena = ARENA_SCENE.instantiate()
	arena.autostart_waves = false
	arena.wave_end_beat_seconds = 0.0
	add_child(arena)
	await get_tree().physics_frame
	await get_tree().physics_frame
	arena.player.touch_mode = true  # stops the mouse overriding the aim we set
	var sheet: Image = Image.create(CROP * ZOOM * DIRECTIONS.size(), CROP * ZOOM, false, Image.FORMAT_RGBA8)
	for i: int in DIRECTIONS.size():
		arena.player.aim_direction = DIRECTIONS[i].normalized()
		await get_tree().create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		var shot: Image = get_viewport().get_texture().get_image()
		# Seven's spot on the screen (the canvas transform includes the camera).
		var centre: Vector2 = arena.player.get_global_transform_with_canvas().origin
		var corner: Vector2i = Vector2i(centre) - Vector2i(CROP / 2, CROP / 2)
		var piece: Image = shot.get_region(Rect2i(corner, Vector2i(CROP, CROP)))
		piece.resize(CROP * ZOOM, CROP * ZOOM, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i(i * CROP * ZOOM, 0))
	var path: String = ProjectSettings.globalize_path(OUT_FILE)
	sheet.save_png(path)
	print("saved ", path)
	get_tree().quit()
