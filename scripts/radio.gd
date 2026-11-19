# radio.gd - the radio panel: who is on the air, and what they are saying.
# Created by the arena in code and added to the HUD (a CanvasLayer), so it is not
# tinted by the night and stays readable. It replaces the old centred story line.
class_name Radio
extends Control
## THREE VOICES, one small panel in the top-left corner of the lot:
##   HELIOS     the utility's cold broadcast: notices, threats, "please hold".
##              Pale blue text; the words come through with static.
##   CANOPY FM  the block's pirate radio. Its DJ teaches Seven the controls,
##              warns about machines and drops hints about the lucky cat.
##              Amber text; signal bars that grow as the block gets its light back.
##   LUCKY      the cat, once found. Pink text.
## Words "type" onto the panel a few letters at a time, like a live broadcast.
## The arena decides WHAT is said and WHEN (see arena.gd _radio_*); this node
## only shows one line at a time.

const CONFIG: GameConfig = preload("res://config/game_config.tres")

const HELIOS: StringName = &"helios"
const CANOPY: StringName = &"canopy"
const LUCKY: StringName = &"lucky"

## Where the panel sits on screen and how big it is, in pixels.
const PANEL_RECT: Rect2 = Rect2(28.0, 84.0, 560.0, 64.0)
const PANEL_COLOR: Color = Color(0.03, 0.04, 0.06, 0.78)
const TAG_FONT_SIZE: int = 15
const TEXT_FONT_SIZE: int = 18
## Characters Helios's static may swap in while a line is still typing.
const STATIC_CHARS: String = "#%/\\|~"

## Per speaker: the tag shown at the top of the panel, its colour, and the text colour.
const TAGS: Dictionary[StringName, String] = {
	HELIOS: "HELIOS UTILITIES  ::  PUBLIC NOTICE",
	CANOPY: "CANOPY FM  88.3",
	LUCKY: "LUCKY",
}
const TAG_COLORS: Dictionary[StringName, Color] = {
	HELIOS: Color(1.0, 0.36, 0.30),
	CANOPY: Color(0.35, 0.90, 0.85),
	LUCKY: Color(1.0, 0.55, 0.75),
}
const TEXT_COLORS: Dictionary[StringName, Color] = {
	HELIOS: Color(0.78, 0.86, 1.0),
	CANOPY: Color(1.0, 0.82, 0.50),
	LUCKY: Color(1.0, 0.82, 0.90),
}

## Who is speaking now (empty = the panel is hidden). Public for the tests.
var speaker: StringName = &""
## The full line being said. Public for the tests.
var text: String = ""
## How strong Canopy FM's signal is, 0 to 1 (the arena passes the light level).
var signal_strength: float = 0.0

## How many characters of `text` have been "typed" so far (a float, so it can
## grow by a fraction each frame).
var _typed: float = 0.0
## Random numbers for Helios's static.
var _rng := RandomNumberGenerator.new()


## _ready runs once: the panel lets mouse clicks pass through to the game.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Puts a new line on the air, replacing whatever was there.
func say(new_speaker: StringName, line: String) -> void:
	speaker = new_speaker
	text = line
	_typed = 0.0
	queue_redraw()


## Takes everyone off the air.
func clear() -> void:
	speaker = &""
	text = ""
	queue_redraw()


## True while someone is on the air.
func is_on() -> bool:
	return speaker != &""


## True once the whole line has been typed out. Used by the tests.
func is_fully_typed() -> bool:
	return int(_typed) >= text.length()


## _process runs every frame: type a few more letters.
func _process(delta: float) -> void:
	if not is_on():
		return
	if not is_fully_typed():
		_typed += CONFIG.radio_chars_per_second * delta
		queue_redraw()
	elif speaker == HELIOS:
		queue_redraw()  # Helios's static crackles even after the line is typed


## _draw paints the panel, the tag, the signal bars and the typed words.
func _draw() -> void:
	if not is_on():
		return
	var font: Font = ThemeDB.fallback_font
	draw_rect(PANEL_RECT, PANEL_COLOR)
	# A thin bar down the left edge in the speaker's colour.
	draw_rect(Rect2(PANEL_RECT.position, Vector2(4.0, PANEL_RECT.size.y)), TAG_COLORS[speaker])

	var left: float = PANEL_RECT.position.x + 14.0
	var tag_y: float = PANEL_RECT.position.y + 20.0
	draw_string(font, Vector2(left, tag_y), TAGS[speaker], HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAG_FONT_SIZE, TAG_COLORS[speaker])
	if speaker == CANOPY:
		_draw_signal_bars(Vector2(left + font.get_string_size(TAGS[speaker], HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAG_FONT_SIZE).x + 12.0, tag_y))

	var shown: String = text.substr(0, int(_typed))
	if speaker == HELIOS:
		shown = _add_static(shown)
	# draw_multiline_string wraps the words to the panel's width.
	draw_multiline_string(font, Vector2(left, tag_y + 22.0), shown, HORIZONTAL_ALIGNMENT_LEFT,
		PANEL_RECT.size.x - 28.0, TEXT_FONT_SIZE, 2, TEXT_COLORS[speaker])


## Four little bars, like a phone's signal meter: more of them light up as the
## block gets its power back. A weak signal is the story: the DJ is barely on.
func _draw_signal_bars(at: Vector2) -> void:
	var lit_bars: int = 1 + int(signal_strength * 3.0)
	for i: int in 4:
		var height: float = 4.0 + i * 3.0
		var color: Color = TAG_COLORS[CANOPY] if i < lit_bars else Color(0.3, 0.3, 0.35)
		draw_rect(Rect2(at + Vector2(i * 6.0, -height), Vector2(4.0, height)), color)


## Helios's signal is clean but cold: a few letters flicker into static marks.
func _add_static(line: String) -> String:
	var noisy: String = line
	for i: int in noisy.length():
		if noisy[i] != " " and _rng.randf() < CONFIG.radio_helios_static:
			noisy[i] = STATIC_CHARS[_rng.randi() % STATIC_CHARS.length()]
	return noisy
