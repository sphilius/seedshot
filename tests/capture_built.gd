# capture_built.gd - saves close-ups of the REAL game's back wall and Lucky's shop, as
# built (not the mockup overlays of capture_mockups.gd): lit homes, and the neon paw
# once the shop is open, caught in its dim and bright moments.
#
# Run WITHOUT --headless (a headless run draws nothing):
#   <Godot_v4.7.2-stable_win64_console.exe> --path . res://tests/capture_built.tscn
extends Node

const ARENA_SCENE: PackedScene = preload("res://scenes/arena.tscn")
const OUT_DIR: String = "res://docs/s20/"


## Runs once: build the arena, take the pictures, quit. `await` pauses until frames
## have really been drawn, so each picture shows the state set just before it.
func _ready() -> void:
	Sfx.effects_on = false
	CanopyFM.set_music_on(false)
	var arena: Arena = ARENA_SCENE.instantiate()
	arena.autostart_waves = false
	arena.random_cat_shop = false
	add_child(arena)
	await get_tree().physics_frame
	await get_tree().physics_frame
	arena.waves.wave = 4
	arena.waves_cleared = 3
	arena.graffiti.reveal_up_to(3)
	arena._update_light()
	await get_tree().create_timer(1.5).timeout
	# Hide the HUD layers so their words do not sit over the wall.
	for child: Node in arena.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
	var wall: BackWall = arena.back_wall
	var origin: Vector2 = wall.front_rect(0).position
	# Closed shop first (faded paw print), then open it and catch the neon both ways.
	await _save(Rect2i(int(origin.x), int(origin.y), 480, 60), 3, "built_1_wall_closed.png")
	for i: int in 3:
		arena.cat_shop.hit_by_seed()
	var shop_at: Vector2 = arena.cat_shop.get_global_transform_with_canvas().origin
	var region := Rect2i(int(shop_at.x) - 60, maxi(int(shop_at.y) - 26, 0), 150, 60)
	arena.cat_shop._time = 0.0  # the start of a period: the stutter, dim
	await get_tree().process_frame
	await _save(region, 5, "built_2_neon_dim.png")
	arena.cat_shop._time = 1.0  # between flickers: steady and bright
	await get_tree().process_frame
	await _save(region, 5, "built_3_neon_bright.png")
	get_tree().quit()


## Saves `region` of the screen, enlarged `zoom` times, as docs/s20/<file_name>.
func _save(region: Rect2i, zoom: int, file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var crop: Image = get_viewport().get_texture().get_image().get_region(region)
	crop.resize(region.size.x * zoom, region.size.y * zoom, Image.INTERPOLATE_NEAREST)
	crop.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
	print("saved ", file_name)
