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
## Lucky's portrait: a square this many pixels wide at the left of the panel.
const FACE_SIZE: float = 52.0
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
## Plays the spoken version of the line on the air (audio/voice), if there is one.
var _voice: AudioStreamPlayer
## Which config variables hold lines that have a spoken file. The file for entry i
## of variable `name` is audio/voice/<name>_<i>.mp3. KEEP THIS LIST THE SAME AS
## tools/gen_voices.py (HELIOS_VARS + CANOPY_VARS); a test checks every file exists.
const VOICE_VARS: Array[StringName] = [
	&"helios_lines", &"helios_end_line", &"dj_intro", &"dj_intro_touch", &"dj_first_tree",
	&"dj_first_tree_touch", &"dj_bramble", &"dj_bramble_touch", &"dj_first_sawbot",
	&"dj_first_ripsaw", &"dj_first_linebreaker", &"dj_first_arc_spitter", &"dj_tap_points",
	&"heart_intro_line", &"heart_alarm_line", &"canopy_line_intro_line", &"sunburst_intro_line",
	&"grove_rest_line", &"dj_music_hint", &"ng_plus_wakeup_line", &"ng_plus_threat_line",
	&"dj_ng_plus_intro", &"dj_cat_hints",
]
const VOICE_DIR: String = "res://audio/voice/"
## Line text -> voice file id, built the first time it is needed (see voice_ids).
## `static var` is one shared copy for the whole game, not one per Radio.
static var _voice_ids: Dictionary = {}


## _ready runs once: the panel lets mouse clicks pass through to the game.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_voice = AudioStreamPlayer.new()
	add_child(_voice)


## Line text -> voice file id, for every line that has been spoken. Built from the
## config on first use: the same words the game shows, so a voice can never be
## matched to the wrong line. A line with a "%d" in it (the Sunburst tip) is also
## listed with its number filled in, because that is how the arena sends it.
## Public and static so the tests can read it.
static func voice_ids() -> Dictionary:
	if _voice_ids.is_empty():
		for variable: StringName in VOICE_VARS:
			var value: Variant = CONFIG.get(variable)
			# One config variable is either a single String or an Array of them.
			var texts: Array = value if value is Array else [value]
			for index: int in texts.size():
				var text: String = texts[index]
				var id: String = "%s_%d" % [variable, index]
				_voice_ids[text] = id
				if text.contains("%d"):
					_voice_ids[text % CONFIG.sunburst_charges_per_wave] = id
	return _voice_ids


## The file that speaks `line_text`, or "" if it has none (Lucky's lines, say).
static func voice_path_for(line_text: String) -> String:
	var ids: Dictionary = voice_ids()
	if not ids.has(line_text):
		return ""
	return VOICE_DIR + str(ids[line_text]) + ".mp3"


## Puts a new line on the air, replacing whatever was there.
## `voice_text` is the line as written in the config (`line` may have static
## mixed in, which would not match), so the right recording can be found. Leave it
## empty for a line that is not spoken.
func say(new_speaker: StringName, line: String, voice_text: String = "") -> void:
	speaker = new_speaker
	text = line
	_typed = 0.0
	_play_voice(voice_text)
	queue_redraw()


## Starts the recording of `voice_text`, cutting off the one still speaking. Silent
## when: there is no recording, the sound is not unlocked yet (a browser blocks sound
## before the first click or key), or Sound effects are switched off in the pause menu.
## Canopy FM is quieter while the block is dark: a weak signal.
func _play_voice(voice_text: String) -> void:
	if _voice == null:  # not in the scene tree yet
		return
	_voice.stop()
	if voice_text == "" or not Sfx.is_unlocked or not Sfx.effects_on:
		return
	var path: String = voice_path_for(voice_text)
	if path == "" or not ResourceLoader.exists(path):
		return
	_voice.stream = load(path)
	var drop: float = 0.0
	if speaker == CANOPY:
		drop = lerpf(CONFIG.radio_voice_dark_drop_db, 0.0, clampf(signal_strength, 0.0, 1.0))
	_voice.volume_db = CONFIG.radio_voice_db + drop
	_voice.play()


## True while a recording is playing. Public for the tests.
func is_voice_playing() -> bool:
	return _voice != null and _voice.playing


## Takes everyone off the air.
func clear() -> void:
	speaker = &""
	text = ""
	if _voice != null:
		_voice.stop()
	queue_redraw()


## True while someone is on the air.
func is_on() -> bool:
	return speaker != &""


## Types the rest of the line out at once (a tap on the panel does this).
func finish_typing() -> void:
	_typed = float(text.length())
	queue_redraw()


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
	# The panel is as tall as the WHOLE line needs (not just the part typed so
	# far), so it is the right size from the first letter and never jumps.
	var panel: Rect2 = panel_rect()
	draw_rect(panel, PANEL_COLOR)
	# A thin bar down the left edge in the speaker's colour.
	draw_rect(Rect2(panel.position, Vector2(4.0, panel.size.y)), TAG_COLORS[speaker])

	var left: float = _text_left()
	# Lucky gets a little portrait at the left of the panel, and the words move over.
	if speaker == LUCKY and CONFIG.cat_texture != null:
		var face := Rect2(PANEL_RECT.position + Vector2(10.0, 6.0), Vector2.ONE * FACE_SIZE)
		draw_texture_rect(CONFIG.cat_texture, face, false)
	var tag_y: float = PANEL_RECT.position.y + 20.0
	draw_string(font, Vector2(left, tag_y), TAGS[speaker], HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAG_FONT_SIZE, TAG_COLORS[speaker])
	if speaker == CANOPY:
		_draw_signal_bars(Vector2(left + font.get_string_size(TAGS[speaker], HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAG_FONT_SIZE).x + 12.0, tag_y))

	var shown: String = text.substr(0, int(_typed))
	if speaker == HELIOS:
		shown = _add_static(shown)
	# draw_multiline_string wraps the words to the panel's width.
	# The -1 means "as many rows as it takes" (it used to stop at 2 and a long
	# line ran out of the bottom of the box).
	draw_multiline_string(font, Vector2(left, tag_y + 22.0), shown, HORIZONTAL_ALIGNMENT_LEFT,
		_text_width(), TEXT_FONT_SIZE, -1, TEXT_COLORS[speaker])


## Where the words start, in pixels from the left of the screen. Lucky's
## portrait sits at the left of the panel, so Lucky's words start further in.
func _text_left() -> float:
	if speaker == LUCKY and CONFIG.cat_texture != null:
		return PANEL_RECT.position.x + 10.0 + FACE_SIZE + 10.0
	return PANEL_RECT.position.x + 14.0


## How wide a row of words may be before it wraps onto the next row.
func _text_width() -> float:
	return PANEL_RECT.end.x - 14.0 - _text_left()


## The panel's rectangle for the line on the air: PANEL_RECT, made taller when
## the line wraps onto more rows than fit. Public for the tests.
func panel_rect() -> Rect2:
	# get_multiline_string_size measures wrapped text without drawing it.
	var text_height: float = ThemeDB.fallback_font.get_multiline_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, _text_width(), TEXT_FONT_SIZE).y
	# 26 px for the tag row above the words, 12 px of space under them.
	var needed: float = 26.0 + text_height + 12.0
	return Rect2(PANEL_RECT.position, Vector2(PANEL_RECT.size.x, maxf(PANEL_RECT.size.y, needed)))


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
