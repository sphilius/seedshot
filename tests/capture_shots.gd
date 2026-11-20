# capture_shots.gd - stages a few scenes in the real arena and saves them as
# 1280 x 720 PNG screenshots for the itch.io page (attached to capture_shots.tscn).
#
# Run it from the project folder with the NON-mono Godot console build, WITHOUT
# --headless (a headless run draws nothing, so the pictures would be empty):
#   <Godot_v4.7.2-stable_win64_console.exe> --path . res://tests/capture_shots.tscn
# A game window opens for a few seconds, then closes by itself.
#
# The pictures land in the project's itch/ folder. They are STAGED: trees and
# machines are placed by hand so one frame shows a lot. They are honest about
# what the game looks like, but a real playthrough capture is better if you
# have one.
extends Node

const CONFIG: GameConfig = preload("res://config/game_config.tres")
const ARENA_SCENE: PackedScene = preload("res://scenes/arena.tscn")
## Where the pictures are saved. "res://" is the project folder.
const OUT_DIR: String = "res://itch/"

## Cells for a mid-run forest: scattered clumps, clear of Seven's start cell
## and of the Heart Tree in the middle.
const FOREST_CELLS: Array[Vector2i] = [
	Vector2i(4, 3), Vector2i(5, 3), Vector2i(4, 4), Vector2i(8, 5), Vector2i(9, 5),
	Vector2i(8, 10), Vector2i(9, 10), Vector2i(9, 11), Vector2i(11, 3), Vector2i(12, 4),
	Vector2i(15, 9), Vector2i(16, 9), Vector2i(16, 10), Vector2i(18, 4), Vector2i(19, 4),
	Vector2i(20, 8), Vector2i(21, 8), Vector2i(21, 11), Vector2i(4, 10), Vector2i(12, 11),
]
## More cells, added for the late-game picture.
const LATE_CELLS: Array[Vector2i] = [
	Vector2i(3, 6), Vector2i(3, 8), Vector2i(6, 12), Vector2i(7, 2), Vector2i(10, 8),
	Vector2i(11, 9), Vector2i(14, 3), Vector2i(15, 4), Vector2i(17, 7), Vector2i(18, 11),
	Vector2i(19, 12), Vector2i(22, 5), Vector2i(22, 6), Vector2i(23, 10), Vector2i(14, 12),
	Vector2i(6, 5), Vector2i(10, 2), Vector2i(20, 2), Vector2i(2, 12), Vector2i(16, 2),
]

## The arena being photographed. Rebuilt fresh for each picture.
var _arena: Arena


## _ready runs once when the scene starts: take each picture in turn, then quit.
## `await` pauses here until the awaited function has finished.
func _ready() -> void:
	# No noise while the window is up. (Not Sfx.set_muted: that would put the
	# crossed-out speaker icon in every picture.)
	Sfx.effects_on = false
	CanopyFM.set_music_on(false)
	# Make sure the output folder exists. globalize_path turns "res://itch/"
	# into a real folder path on this computer.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await _shot_mid_fight()
	await _shot_upgrade_cards()
	await _shot_block_lit()
	await _shot_linebreaker_drop()
	get_tree().quit()


## Throws the old arena away and builds a new one with no waves running, so
## each picture controls exactly what is on screen.
func _fresh_arena() -> void:
	if _arena != null:
		_arena.queue_free()
		await get_tree().physics_frame
	_arena = ARENA_SCENE.instantiate()
	_arena.autostart_waves = false
	_arena.wave_end_beat_seconds = 0.0  # no slow motion: the cards come at once
	add_child(_arena)
	await get_tree().physics_frame
	await get_tree().physics_frame


## Lets the game run for `seconds`, so tints glide, trees glow and machines walk.
func _run_for(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Saves what is on screen right now as itch/<file_name>.
func _save(file_name: String) -> void:
	# Wait until the current frame has really been drawn, then copy the screen.
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(OUT_DIR + file_name)
	picture.save_png(path)
	print("saved ", path)


## Plants a grown tree on every cell in `cells` that is free.
func _plant(cells: Array[Vector2i]) -> void:
	for cell: Vector2i in cells:
		if _arena.tree_at(cell) == null:
			_arena.spawn_tree(cell, true)


## Pretends `cleared` waves are done and wave `current` is being played, so the
## HUD, the windows and the lanterns show a run that far along.
func _set_progress(cleared: int, current: int) -> void:
	_arena.waves.wave = current
	_arena.waves_cleared = cleared
	_arena.graffiti.reveal_up_to(cleared)
	_arena._update_light()
	# The controls line along the bottom is only shown in the first two waves.
	_arena._hint.visible = current < CONFIG.hint_hide_wave


## Picture 1: the middle of a run. A forest, every kind of machine, Seven aiming.
func _shot_mid_fight() -> void:
	await _fresh_arena()
	_plant(FOREST_CELLS)
	_set_progress(5, 6)
	_arena.trees_planted = FOREST_CELLS.size()
	# One of each machine, far enough from Seven that nothing lands a hit yet.
	_arena.spawn_scrapper_at(Vector2i(18, 7))
	_arena.spawn_scrapper_at(Vector2i(20, 5))
	_arena.spawn_scrapper_at(Vector2i(22, 9), true)   # true = a Linebreaker
	_arena.spawn_spitter_at(Vector2i(23, 3))
	_arena.spawn_spitter_at(Vector2i(19, 12), true)   # true = an Arc Spitter
	_arena.spawn_sawbot_at(Vector2i(13, 9))
	# Aim at the nearest Scrapper. touch_mode stops the mouse overriding the aim.
	var player: Player = _arena.player
	player.touch_mode = true
	player.aim_direction = (_arena.grid.cell_to_world(Vector2i(18, 7)) - player.global_position).normalized()
	await _run_for(1.3)
	player.fire(player.aim_direction)
	await _run_for(0.12)  # long enough for the pod to be in flight
	await _save("screenshot_1_mid_fight.png")


## Picture 2: the upgrade cards between waves, over the dimmed lot.
func _shot_upgrade_cards() -> void:
	await _fresh_arena()
	_plant(FOREST_CELLS.slice(0, 12))  # slice(0, 12) = the first twelve cells
	_set_progress(3, 3)
	_arena.waves.hold_break = true
	_arena._end_wave_end_beat()  # deals the cards and parks Seven by the Heart Tree
	await _run_for(1.2)
	await _save("screenshot_2_upgrade_cards.png")


## Picture 3: late in New Game +. The block nearly lit, great sunroots with
## their gold Sunburst sheen and Canopy lines, a graffiti tag on every roof.
func _shot_block_lit() -> void:
	await _fresh_arena()
	_arena.apply_ng_plus()
	_plant(FOREST_CELLS)
	_plant(LATE_CELLS)
	_set_progress(9, 10)
	_arena.trees_planted = FOREST_CELLS.size() + LATE_CELLS.size()
	# Every third tree of the first set becomes a great sunroot.
	for i: int in range(0, FOREST_CELLS.size(), 3):
		var tree: ForestTree = _arena.tree_at(FOREST_CELLS[i])
		if tree != null:
			tree.mature()
	_arena.spawn_scrapper_at(Vector2i(22, 12))
	_arena.spawn_scrapper_at(Vector2i(23, 7), true)
	_arena.spawn_spitter_at(Vector2i(22, 2), true)
	var player: Player = _arena.player
	player.touch_mode = true
	player.aim_direction = Vector2.RIGHT
	await _run_for(1.6)
	await _save("screenshot_3_block_lit.png")


## Picture 4: the first Linebreaker's intro clip, a moment after it lands. The
## camera is pushed in, the black bars are up and its name is on the banner.
func _shot_linebreaker_drop() -> void:
	await _fresh_arena()
	_plant(FOREST_CELLS)
	_set_progress(5, 6)
	_arena.waves.state = WaveDirector.State.FIGHTING
	# Ask for a Linebreaker the way the wave director does, so it drops in with
	# its clip and its three escorts roll out of the gates.
	_arena._on_spawn_requested(WaveDirector.LINEBREAKER, 6)
	# The clip runs in slow motion, so wait in REAL seconds: the last `true`
	# tells the timer to ignore the game's slowed clock. 1.9 s is just after the
	# landing (a 0.7 s fall at 40% speed takes 1.75 s).
	await get_tree().create_timer(1.9, true, false, true).timeout
	await _save("screenshot_4_linebreaker_drop.png")
	Engine.time_scale = 1.0
