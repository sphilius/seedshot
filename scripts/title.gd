# title.gd - the title screen: Play, New Game + (once unlocked) and the Canopy FM station.
# It is the game's first scene (project.godot run/main_scene). It builds its own buttons
# in code, so the scene file (scenes/title.tscn) is just one node with this script.
extends Control
## THE TITLE SCREEN
##   Play         a normal run.
##   New Game +   locked (greyed out, with how to unlock it) until the player has
##                won once; then a harder run with great sunroots.
##   Canopy FM    once New Game + is unlocked, a button that cycles the radio
##                station. The choice is saved (RunState).
##
## Keyboard: arrow keys / Tab move between buttons, Enter or Space presses one.
## Mouse and touch: click or tap a button. The first click also unlocks browser
## audio (see sfx.gd), so the radio starts playing on this screen.

const ARENA_SCENE: String = "res://scenes/arena.tscn"
const TITLE_ART: String = "res://art/sprites/title_art.jpg"
## Width given to the story line under the title, in screen pixels.
const HOOK_WIDTH: float = 900.0
const CONFIG: GameConfig = preload("res://config/game_config.tres")

## The buttons. Public so the tests can check them.
var play_button: Button
var ng_plus_button: Button
var station_button: Button


## _ready runs once when the title screen appears: build everything.
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)  # fill the whole window

	# Background: the key art, darkened so the words read on top of it.
	var art := TextureRect.new()
	art.texture = load(TITLE_ART)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.modulate = Color(0.55, 0.55, 0.62)
	add_child(art)

	# A column of everything else, centred on screen.
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 14)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(column)

	var title := Label.new()
	title.text = "SEEDSHOT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if CONFIG.graffiti_font != null:
		title.add_theme_font_override(&"font", CONFIG.graffiti_font)
	title.add_theme_font_size_override(&"font_size", 96)
	title.add_theme_color_override(&"font_color", Color(0.35, 0.90, 0.85))
	title.add_theme_color_override(&"font_outline_color", Color(0.05, 0.05, 0.07))
	title.add_theme_constant_override(&"outline_size", 10)
	column.add_child(title)

	var hook := Label.new()
	hook.text = CONFIG.story_hook
	hook.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hook.add_theme_font_size_override(&"font_size", 22)
	hook.add_theme_color_override(&"font_color", Color(1.0, 0.80, 0.45))
	hook.add_theme_color_override(&"font_outline_color", Color(0.05, 0.05, 0.07))
	hook.add_theme_constant_override(&"outline_size", 6)
	# The line was cut off at its right edge ("...stopped paying for i"): the
	# column was only as wide as the buttons. Give the line a set width with room
	# to spare, and let it wrap onto a second line if the words ever get longer.
	hook.custom_minimum_size = Vector2(HOOK_WIDTH, 0.0)
	hook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hook)

	play_button = _make_button(column, "Play")
	play_button.pressed.connect(_start.bind(false))

	ng_plus_button = _make_button(column, "")
	ng_plus_button.pressed.connect(_start.bind(true))

	station_button = _make_button(column, "")
	station_button.pressed.connect(_next_station)

	refresh()
	play_button.grab_focus()  # so Enter starts a run straight away


## Updates the buttons to match what is unlocked and which station is chosen.
func refresh() -> void:
	ng_plus_button.disabled = not RunState.ng_plus_unlocked
	if RunState.ng_plus_unlocked:
		ng_plus_button.text = "New Game +  (50% more machines, great sunroots)"
	else:
		ng_plus_button.text = "New Game +  (beat the game once to unlock)"
	# The station picker appears only once New Game + is unlocked.
	station_button.visible = RunState.ng_plus_unlocked
	station_button.text = "Canopy FM:  %s   (change)" % CanopyFM.STATION_NAMES[CanopyFM.station]


## Makes one wide button in the column and returns it.
func _make_button(column: VBoxContainer, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(520.0, 52.0)
	button.add_theme_font_size_override(&"font_size", 22)
	column.add_child(button)
	return button


## Starts a run: normal (false) or New Game + (true).
func _start(new_game_plus: bool) -> void:
	RunState.ng_plus = new_game_plus
	RunState.just_unlocked = false
	get_tree().change_scene_to_file(ARENA_SCENE)


## Cycles to the next Canopy FM station and remembers it.
func _next_station() -> void:
	var ids: Array[StringName] = CanopyFM.STATIONS.keys()
	var next: int = (ids.find(CanopyFM.station) + 1) % ids.size()
	RunState.choose_station(ids[next])
	refresh()
