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

## THE LOOK (s18): the same palette as the rest of the game's interface (the
## upgrade cards and the radio panel): near-black night panels, a teal edge,
## amber for anything picked out, and pale text.
const NIGHT_COLOR: Color = Color(0.04, 0.06, 0.08)
const TEAL_COLOR: Color = Color(0.35, 0.90, 0.85)
const AMBER_COLOR: Color = Color(1.0, 0.82, 0.50)
const TEXT_COLOR: Color = Color(0.96, 0.97, 0.98)
const DIM_COLOR: Color = Color(0.62, 0.66, 0.70)
## How dark the key art is drawn (1 = as painted). The panel behind the words
## does the work of making them readable, so the painting itself can stay visible.
const ART_TINT: Color = Color(0.52, 0.52, 0.60)
## Size of a button in screen pixels. Half the height as the corner radius
## makes the ends fully round: a "pill".
const BUTTON_SIZE: Vector2 = Vector2(280.0, 42.0)
const BUTTON_FONT_SIZE: int = 20
## Letter height of the small line under a button that explains it.
const NOTE_FONT_SIZE: int = 15

## The buttons. Public so the tests can check them.
var play_button: Button
var ng_plus_button: Button
var station_button: Button
## The small line under the New Game + button (how to unlock it, or what it is).
var ng_plus_note: Label


## _ready runs once when the title screen appears: build everything.
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)  # fill the whole window

	# Background: the key art, darkened so the words read on top of it.
	var art := TextureRect.new()
	art.texture = load(TITLE_ART)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.modulate = ART_TINT
	add_child(art)

	# A dark, see-through panel with round corners behind the words, so they
	# read whatever part of the painting is under them. A PanelContainer draws
	# its "panel" style and sizes itself round its one child (the column).
	var backing := PanelContainer.new()
	var backing_style := StyleBoxFlat.new()  # StyleBoxFlat = a plain coloured box
	backing_style.bg_color = Color(NIGHT_COLOR, 0.72)
	backing_style.set_corner_radius_all(28)
	backing_style.set_content_margin_all(28.0)  # space between the edge and the words
	backing_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	backing_style.shadow_size = 24  # a soft dark halo, so the panel has no hard edge
	backing.add_theme_stylebox_override(&"panel", backing_style)
	backing.set_anchors_preset(Control.PRESET_CENTER)
	backing.grow_horizontal = Control.GROW_DIRECTION_BOTH
	backing.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(backing)

	# A column of everything else, inside that panel.
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 12)
	backing.add_child(column)

	var title := Label.new()
	title.text = "SEEDSHOT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if CONFIG.graffiti_font != null:
		title.add_theme_font_override(&"font", CONFIG.graffiti_font)
	title.add_theme_font_size_override(&"font_size", 96)
	title.add_theme_color_override(&"font_color", TEAL_COLOR)
	title.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0))
	title.add_theme_constant_override(&"outline_size", 14)
	# A hard black shadow below and to the right lifts the letters off the art.
	title.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	title.add_theme_constant_override(&"shadow_offset_x", 4)
	title.add_theme_constant_override(&"shadow_offset_y", 5)
	column.add_child(title)

	var hook := Label.new()
	hook.text = CONFIG.story_hook
	hook.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hook.add_theme_font_size_override(&"font_size", 22)
	hook.add_theme_color_override(&"font_color", AMBER_COLOR)
	hook.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0))
	hook.add_theme_constant_override(&"outline_size", 8)
	# The line was cut off at its right edge ("...stopped paying for i"): the
	# column was only as wide as the buttons. Give the line a set width with room
	# to spare, and let it wrap onto a second line if the words ever get longer.
	hook.custom_minimum_size = Vector2(HOOK_WIDTH, 0.0)
	hook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hook)

	play_button = _make_button(column, "Play")
	play_button.pressed.connect(_start.bind(false))

	ng_plus_button = _make_button(column, "New Game +")
	ng_plus_button.pressed.connect(_start.bind(true))
	# The explanation used to be inside the button, which made it very wide.
	ng_plus_note = Label.new()
	ng_plus_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ng_plus_note.add_theme_font_size_override(&"font_size", NOTE_FONT_SIZE)
	ng_plus_note.add_theme_color_override(&"font_color", TEXT_COLOR)
	ng_plus_note.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0))
	ng_plus_note.add_theme_constant_override(&"outline_size", 5)
	column.add_child(ng_plus_note)

	station_button = _make_button(column, "")
	station_button.pressed.connect(_next_station)

	refresh()
	play_button.grab_focus()  # so Enter starts a run straight away


## Updates the buttons to match what is unlocked and which station is chosen.
func refresh() -> void:
	ng_plus_button.disabled = not RunState.ng_plus_unlocked
	if RunState.ng_plus_unlocked:
		ng_plus_note.text = "50% more machines, great sunroots"
	else:
		ng_plus_note.text = "Beat the game once to unlock"
	# The station picker appears only once New Game + is unlocked.
	station_button.visible = RunState.ng_plus_unlocked
	station_button.text = "Canopy FM:  %s" % CanopyFM.STATION_NAMES[CanopyFM.station]


## Makes one small pill-shaped button in the column and returns it.
##
## A Button looks different in each of its states, and each state has its own
## "stylebox" (the box drawn behind the text) and its own text colour:
##   normal    night fill, teal edge, pale text
##   hover     the mouse is over it: a little lighter, amber edge and text
##   pressed   being clicked: filled amber, dark text
##   focus     picked with the keyboard: an extra amber outline round it
##   disabled  cannot be used (New Game + before a win): faint edge, grey text
func _make_button(column: VBoxContainer, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	# SHRINK_CENTER: stay this size in the middle, instead of stretching to the
	# width of the column (which is as wide as the story line).
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override(&"font_size", BUTTON_FONT_SIZE)
	button.add_theme_stylebox_override(&"normal", _pill(Color(NIGHT_COLOR, 0.94), TEAL_COLOR, 2))
	button.add_theme_stylebox_override(&"hover", _pill(Color(0.09, 0.15, 0.17, 0.96), AMBER_COLOR, 2))
	button.add_theme_stylebox_override(&"pressed", _pill(AMBER_COLOR, AMBER_COLOR, 2))
	button.add_theme_stylebox_override(&"disabled", _pill(Color(NIGHT_COLOR, 0.80), Color(DIM_COLOR, 0.5), 2))
	# The focus box is drawn ON TOP of the others, so its inside is left clear.
	button.add_theme_stylebox_override(&"focus", _pill(Color(0.0, 0.0, 0.0, 0.0), AMBER_COLOR, 3))
	button.add_theme_color_override(&"font_color", TEXT_COLOR)
	button.add_theme_color_override(&"font_hover_color", AMBER_COLOR)
	button.add_theme_color_override(&"font_focus_color", TEXT_COLOR)
	button.add_theme_color_override(&"font_pressed_color", NIGHT_COLOR)
	button.add_theme_color_override(&"font_hover_pressed_color", NIGHT_COLOR)
	button.add_theme_color_override(&"font_disabled_color", DIM_COLOR)
	column.add_child(button)
	return button


## One pill-shaped box: `fill` inside, an `edge` line `edge_px` wide round it.
func _pill(fill: Color, edge: Color, edge_px: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(edge_px)
	# Half the button's height: the two ends become half circles.
	box.set_corner_radius_all(int(BUTTON_SIZE.y / 2.0))
	box.anti_aliasing = true  # smooth the curved edge
	# Room between the edge and the text, left and right.
	box.content_margin_left = 20.0
	box.content_margin_right = 20.0
	return box


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
