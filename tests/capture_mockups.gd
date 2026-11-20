# capture_mockups.gd - stages PROPOSED looks (not in the game yet) and saves close-up
# pictures of them to docs/s20/, so Sasha can choose before anything is built.
#
# Run it from the project folder with the NON-mono console build, WITHOUT --headless
# (a headless run draws nothing):
#   <Godot_v4.7.2-stable_win64_console.exe> --path . res://tests/capture_mockups.tscn
#
# HOW: the real arena is built, then a small extra node is added on top of the wall or
# the shop. That node paints the proposed look over the existing one. The game's own
# scripts are not touched, so deleting this file removes every trace of the mockups.
extends Node

const CONFIG: GameConfig = preload("res://config/game_config.tres")
const ARENA_SCENE: PackedScene = preload("res://scenes/arena.tscn")
const OUT_DIR: String = "res://docs/s20/"

## Colours, written above 1.0 on purpose: the night tint multiplies colours down, and
## values over 1 keep a light glowing through it (same trick as back_wall.gd).
const GLASS_TOP: Color = Color(1.05, 0.70, 0.28)
const GLASS_BOTTOM: Color = Color(1.45, 1.00, 0.45)
const CURTAIN: Color = Color(0.62, 0.34, 0.16)
const SILHOUETTE: Color = Color(0.07, 0.10, 0.06)
const SILL: Color = Color(0.60, 0.62, 0.68)
const FRAME: Color = Color(0.09, 0.09, 0.11)
const SPILL: Color = Color(1.35, 0.9, 0.4)
const NEON: Color = Color(2.2, 0.55, 1.5)
const NEON_DIM: Color = Color(0.45, 0.12, 0.32)

var _arena: Arena


## _ready is Godot's "the node has entered the scene" callback: it runs once, so this is
## the whole program. Each `await` pauses here until that step (which itself waits for
## frames to be drawn) has finished, so the pictures are taken one after another.
func _ready() -> void:
	Sfx.effects_on = false  # no noise while the window is up
	CanopyFM.set_music_on(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await _fresh_arena()
	await _shot_back_wall()
	await _shot_neon_paw()
	await _shot_cat_silhouette()
	get_tree().quit()


## A new arena with no waves running, a few waves cleared so it is dark enough for the
## lights to read, and the real cat shop left closed.
func _fresh_arena() -> void:
	_arena = ARENA_SCENE.instantiate()
	_arena.autostart_waves = false
	_arena.random_cat_shop = false  # the shop always stands in its usual cell
	add_child(_arena)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_arena.waves.wave = 4
	_arena.waves_cleared = 3
	_arena.graffiti.reveal_up_to(3)
	_arena._update_light()
	await get_tree().create_timer(1.5).timeout  # let the night tint glide to its colour


## Adds an overlay node under `parent` that calls `painter` whenever it draws.
## `painter` is a Callable: a function stored in a variable, called with the overlay
## node so it can use that node's draw_* methods.
func _overlay(parent: Node2D, painter: Callable) -> Node2D:
	var node := Node2D.new()
	node.z_index = 5
	parent.add_child(node)
	node.draw.connect(func() -> void: painter.call(node))
	node.queue_redraw()
	return node


## Saves the rectangle `region` (screen pixels) of the current frame, scaled up
## `zoom` times with hard pixels, as docs/s20/<file_name>. Returns the cropped Image.
func _save_crop(file_name: String, region: Rect2i, zoom: int) -> Image:
	await RenderingServer.frame_post_draw
	var shot: Image = get_viewport().get_texture().get_image()
	var crop: Image = shot.get_region(region)
	crop.resize(region.size.x * zoom, region.size.y * zoom, Image.INTERPOLATE_NEAREST)
	crop.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
	print("saved ", file_name)
	return crop


# ---------------------------------------------------------------------------------------
# 1. Lit homes along the back wall
# ---------------------------------------------------------------------------------------

## The proposal: a lit window is a small scene, not a plain amber square. Each has
##   - glass that is dimmer at the top and brighter at the bottom (a lamp's glow),
##   - curtains pulled back at each side,
##   - a silhouette: a potted sprout on the sill, or a hanging lamp,
##   - a pale sill, and a faint pool of light spilling down the wall below.
## Front 1 and 6 here are the existing WINDOWS fronts; front 2's DOOR gets a porch lamp.
func _shot_back_wall() -> void:
	var wall: BackWall = _arena.back_wall
	# Hide the HUD layers for this picture: their words sit on top of the wall in the
	# real game and would hide what is being judged. (CanvasLayer = a drawing layer
	# that floats above the world.)
	for child: Node in _arena.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
	var origin: Vector2 = wall.front_rect(1).position
	# Two fronts: the DOOR front and the WINDOWS front next to it, at 5x.
	var region := Rect2i(int(origin.x), int(origin.y), 192, 52)
	await get_tree().create_timer(0.3).timeout
	# "Now" must show lit windows too, in today's flat style: a dark frame, flat amber
	# glass and a cross bar (a copy of BackWall._draw_pane), on the same two panes.
	var flat: Node2D = _overlay(wall, func(canvas: Node2D) -> void:
		for glass: Rect2 in [Rect2(origin + Vector2(56.0, 16.0), Vector2(24.0, 14.0)), Rect2(origin + Vector2(96.0 + 14.0, 16.0), Vector2(26.0, 16.0))]:
			canvas.draw_rect(glass.grow(2.0), BackWall.FRAME_COLOR)
			canvas.draw_rect(glass, BackWall.GLASS_LIT_COLOR)
			var mid: float = glass.position.x + glass.size.x / 2.0
			canvas.draw_line(Vector2(mid, glass.position.y), Vector2(mid, glass.end.y), BackWall.FRAME_COLOR, 2.0)
	)
	await get_tree().create_timer(0.3).timeout
	var before: Image = await _save_crop("mockup_1a_lit_homes_now.png", region, 5)
	flat.queue_free()
	var overlay: Node2D = _overlay(wall, func(canvas: Node2D) -> void:
		var shown: int = 0
		for i: int in wall.front_count():
			if wall.is_shop_front(i):
				continue
			var front: Rect2 = wall.front_rect(i)
			match wall.kind_of(i):
				BackWall.Kind.WINDOWS:
					# Same pane position as the real wall; the two styles alternate.
					_draw_lit_pane(canvas, Rect2(front.position + Vector2(14.0, 16.0), Vector2(26.0, 16.0)), shown % 2)
					shown += 1
				BackWall.Kind.DOOR:
					_draw_lit_pane(canvas, Rect2(front.position + Vector2(56.0, 16.0), Vector2(24.0, 14.0)), shown % 2)
					shown += 1
					# A porch lamp above the door: a bright dot and a soft halo.
					var lamp: Vector2 = front.position + Vector2(29.0, 9.0)
					canvas.draw_circle(lamp, 8.0, Color(SPILL, 0.10))
					canvas.draw_circle(lamp, 4.5, Color(SPILL, 0.18))
					canvas.draw_circle(lamp, 2.0, GLASS_BOTTOM)
	)
	await get_tree().create_timer(0.3).timeout
	var after: Image = await _save_crop("mockup_1b_lit_homes_proposed.png", region, 5)
	_stack("mockup_1_lit_homes.png", before, after)
	overlay.queue_free()
	for child: Node in _arena.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = true


## One lit window. `style` 0 = potted sprout on the sill, 1 = hanging lamp.
func _draw_lit_pane(canvas: Node2D, glass: Rect2, style: int) -> void:
	# The glow on the wall below, drawn first so the window sits on top of it.
	for step: int in 3:
		var spill := Rect2(glass.position.x - 2.0 - step, glass.end.y + 3.0, glass.size.x + 4.0 + step * 2.0, 4.0 + step * 3.0)
		canvas.draw_rect(spill, Color(SPILL, 0.07 - 0.02 * step))
	canvas.draw_rect(glass.grow(2.0), FRAME)
	# The glass in three bands, dim to bright going down.
	var band: float = glass.size.y / 3.0
	canvas.draw_rect(Rect2(glass.position, Vector2(glass.size.x, band + 1.0)), GLASS_TOP)
	canvas.draw_rect(Rect2(glass.position + Vector2(0.0, band), Vector2(glass.size.x, band + 1.0)), GLASS_TOP.lerp(GLASS_BOTTOM, 0.5))
	canvas.draw_rect(Rect2(glass.position + Vector2(0.0, band * 2.0), Vector2(glass.size.x, band)), GLASS_BOTTOM)
	var mid_x: float = glass.position.x + glass.size.x / 2.0
	if style == 0:
		# A potted sprout: a small pot, a stem, two leaves.
		canvas.draw_rect(Rect2(mid_x - 3.0, glass.end.y - 4.0, 6.0, 4.0), SILHOUETTE)
		canvas.draw_line(Vector2(mid_x, glass.end.y - 4.0), Vector2(mid_x, glass.end.y - 9.0), SILHOUETTE, 1.5)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(mid_x, glass.end.y - 8.0), Vector2(mid_x - 5.0, glass.end.y - 11.0), Vector2(mid_x - 1.5, glass.end.y - 6.5)]), SILHOUETTE)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(mid_x, glass.end.y - 9.0), Vector2(mid_x + 5.0, glass.end.y - 12.0), Vector2(mid_x + 1.5, glass.end.y - 7.0)]), SILHOUETTE)
	else:
		# A hanging lamp: a cord from the top, a dark shade, and a bright bulb under it.
		canvas.draw_line(Vector2(mid_x, glass.position.y), Vector2(mid_x, glass.position.y + 5.0), SILHOUETTE, 1.0)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(mid_x - 4.0, glass.position.y + 9.0), Vector2(mid_x, glass.position.y + 4.0), Vector2(mid_x + 4.0, glass.position.y + 9.0)]), SILHOUETTE)
		canvas.draw_circle(Vector2(mid_x, glass.position.y + 10.0), 1.6, Color(1.8, 1.4, 0.7))
	# Curtains pulled to each side, then the sill.
	canvas.draw_colored_polygon(PackedVector2Array([glass.position, glass.position + Vector2(5.0, 0.0), glass.position + Vector2(2.0, glass.size.y), glass.position + Vector2(0.0, glass.size.y)]), CURTAIN)
	canvas.draw_colored_polygon(PackedVector2Array([glass.position + Vector2(glass.size.x, 0.0), glass.position + Vector2(glass.size.x - 5.0, 0.0), glass.position + Vector2(glass.size.x - 2.0, glass.size.y), glass.position + glass.size]), CURTAIN)
	canvas.draw_rect(Rect2(glass.position.x - 3.0, glass.end.y + 1.0, glass.size.x + 6.0, 2.0), SILL)


# ---------------------------------------------------------------------------------------
# 2. Lucky's shop, option A: a neon paw that flickers
# ---------------------------------------------------------------------------------------

## The shop's screen rectangle with some margin: the shutter, the ledge, the wall around.
func _shop_region() -> Rect2i:
	var centre: Vector2 = _arena.cat_shop.get_global_transform_with_canvas().origin
	return Rect2i(int(centre.x) - 80, maxi(int(centre.y) - 26, 0), 160, 90)


## A neon paw sign in the middle of the shutter: tubes drawn as ring outlines (a pad and
## three toes), with two wider, fainter rings round them as the glow. `level` is how
## bright the tubes are, 0 to 1: the flicker is just this number changing.
func _draw_neon_paw(canvas: Node2D, level: float, toes_lit: int) -> void:
	var colour: Color = NEON_DIM.lerp(NEON, level)
	var pad: Vector2 = Vector2(0.0, 6.0)
	var toes: Array[Vector2] = [Vector2(-13.0, -4.0), Vector2(-5.0, -11.0), Vector2(5.0, -11.0), Vector2(13.0, -4.0)]
	# The glow first (behind): soft rings, bigger and fainter.
	if level > 0.5:
		canvas.draw_circle(pad, 18.0, Color(NEON, 0.06 * level))
		for toe_index: int in toes.size():
			canvas.draw_circle(toes[toe_index], 9.0, Color(NEON, 0.07 * level))
	# The tubes: an arc round the pad and each toe. A toe that has "dropped out" is dim.
	canvas.draw_arc(pad, 9.0, 0.0, TAU, 28, colour, 2.5)
	for toe_index: int in toes.size():
		var toe_colour: Color = colour if toe_index < toes_lit else NEON_DIM
		canvas.draw_arc(toes[toe_index], 4.2, 0.0, TAU, 20, toe_colour, 2.5)


## Takes the two neon pictures (sign on, sign mid-flicker) and stitches them together.
## The overlay's drawing function reads `state`, a Dictionary shared with this function:
## changing state["level"] and calling queue_redraw() makes the overlay repaint with
## the new values, which is how one overlay shows two moments.
func _shot_neon_paw() -> void:
	var shop: CatShop = _arena.cat_shop
	# A dark plate behind the sign so the neon reads, then the paw. It sits over the
	# shutter only; the real shutter is still there underneath.
	var state: Dictionary = {"level": 1.0, "toes": 4}
	var canvas: Node2D = _overlay(shop, func(node: Node2D) -> void:
		var half: Vector2 = Vector2(CatShop.WIDTH_CELLS * CONFIG.cell_size, CONFIG.cell_size) / 2.0
		node.draw_rect(Rect2(-half + Vector2(6.0, 6.0), half * 2.0 - Vector2(12.0, 12.0)), Color(0.07, 0.06, 0.09))
		_draw_neon_paw(node, state["level"], state["toes"])
		# A pink wash on the ledge below, as if the sign lights it.
		node.draw_rect(Rect2(-half.x, half.y, half.x * 2.0, CatShop.STICK_OUT), Color(NEON, 0.10 * state["level"]))
	)
	# Frame 1: fully on. Frame 2: the flicker - tubes half lit and two toes dropped out.
	canvas.queue_redraw()
	await get_tree().create_timer(0.3).timeout
	var on_frame: Image = await _save_crop("mockup_2a_neon_on.png", _shop_region(), 4)
	state["level"] = 0.25
	state["toes"] = 2
	canvas.queue_redraw()
	await get_tree().create_timer(0.3).timeout
	var off_frame: Image = await _save_crop("mockup_2b_neon_flicker.png", _shop_region(), 4)
	_stitch("mockup_2_neon_paw.png", on_frame, off_frame)
	canvas.queue_free()


# ---------------------------------------------------------------------------------------
# 3. Lucky's shop, option B: a waving cat silhouette behind the slats
# ---------------------------------------------------------------------------------------

func _shot_cat_silhouette() -> void:
	var shop: CatShop = _arena.cat_shop
	# The shutter is drawn again as: amber backlight, the cat as a black cut-out, then
	# the slats over the top, so the cat is seen THROUGH the slats.
	var state: Dictionary = {"paw_down": false}
	var canvas: Node2D = _overlay(shop, func(node: Node2D) -> void:
		var half: Vector2 = Vector2(CatShop.WIDTH_CELLS * CONFIG.cell_size, CONFIG.cell_size) / 2.0
		var window: Rect2 = Rect2(-half, half * 2.0).grow(-6.0)
		# The backlight: bright at the bottom, like a lamp left on in the shop.
		node.draw_rect(window, GLASS_TOP * 0.75)
		node.draw_rect(Rect2(window.position + Vector2(0.0, window.size.y * 0.5), Vector2(window.size.x, window.size.y * 0.5)), GLASS_BOTTOM * 0.8)
		# The cat: the real sprite, tinted nearly black so only its outline shows.
		var picture: Texture2D = CONFIG.cat_wave_texture if state["paw_down"] else CONFIG.cat_texture
		var size: float = CONFIG.cell_size * 0.8
		node.draw_texture_rect(picture, Rect2(Vector2(-size / 2.0, -size / 2.0), Vector2(size, size)), false, SILHOUETTE)
		# The slats over the cat, a little darker than the real shutter's.
		for i: int in range(1, 5):
			var y: float = window.position.y + window.size.y * i / 5.0
			node.draw_line(Vector2(window.position.x, y), Vector2(window.end.x, y), Color(0.10, 0.10, 0.12), 3.0)
	)
	canvas.queue_redraw()
	await get_tree().create_timer(0.3).timeout
	var up_frame: Image = await _save_crop("mockup_3a_cat_up.png", _shop_region(), 4)
	state["paw_down"] = true
	canvas.queue_redraw()
	await get_tree().create_timer(0.3).timeout
	var down_frame: Image = await _save_crop("mockup_3b_cat_down.png", _shop_region(), 4)
	_stitch("mockup_3_cat_silhouette.png", up_frame, down_frame)


## Puts two pictures one above the other with a small gap and saves them as one.
func _stack(file_name: String, top: Image, bottom: Image) -> void:
	var both := Image.create(top.get_width(), top.get_height() + bottom.get_height() + 8, false, top.get_format())
	both.fill(Color(0.1, 0.1, 0.1))
	both.blit_rect(top, Rect2i(Vector2i.ZERO, top.get_size()), Vector2i.ZERO)
	both.blit_rect(bottom, Rect2i(Vector2i.ZERO, bottom.get_size()), Vector2i(0, top.get_height() + 8))
	both.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
	print("saved ", file_name)


## Puts two pictures side by side with a small gap and saves them as one.
func _stitch(file_name: String, left: Image, right: Image) -> void:
	var both := Image.create(left.get_width() + right.get_width() + 8, left.get_height(), false, left.get_format())
	both.fill(Color(0.1, 0.1, 0.1))
	both.blit_rect(left, Rect2i(Vector2i.ZERO, left.get_size()), Vector2i.ZERO)
	both.blit_rect(right, Rect2i(Vector2i.ZERO, right.get_size()), Vector2i(left.get_width() + 8, 0))
	both.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
	print("saved ", file_name)
