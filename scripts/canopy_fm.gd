# canopy_fm.gd - Canopy FM, the block's pirate radio. Registered as the autoload "CanopyFM".
# An autoload stays alive for the whole game, so the song keeps playing (and keeps its
# place) when a run restarts or a new scene loads.
extends Node
## One song at a time, on its own audio bus called "Music".
##
## HOW THE BLOCK'S LIGHT CHANGES THE SONG (story step 4)
##   The Music bus has a LOW-PASS FILTER: it lets low sounds through and cuts the
##   high ones above a "cutoff" pitch. A low cutoff sounds muffled, like a radio
##   through a wall; a high cutoff sounds clear and full.
##   - The arena calls set_light(level) every frame with the lot's light level
##     (0 = dark block, 1 = every window lit): the cutoff rises with it.
##   - The arena calls dull() when a tree is cut down: for a moment the song drops
##     back to muffled and quieter (trailer shot 2, "the music dulls").
##   It is ONE recording made to sound fuller or duller, not stacked parts.
##
## STATIONS: four songs (tools/gen_music.ps1 makes them). The first plays by
## default; the player picks another in New Game +, which unlocks after a win.
##
## The browser will not play sound before the player's first click or key, so
## the song waits for Sfx.is_unlocked. Mute (M) silences the Master bus, which
## the Music bus feeds into, so it covers the radio too.
##
## WEB BUILD: there is no Music bus and no filter in a browser (see
## uses_music_bus for why); the song plays straight into the Master bus.

const CONFIG: GameConfig = preload("res://config/game_config.tres")
## Station id -> song file, in the order the menu lists them.
const STATIONS: Dictionary[StringName, String] = {
	&"lofi": "res://audio/music/lofi.mp3",
	&"dub": "res://audio/music/dub.mp3",
	&"chip": "res://audio/music/chip.mp3",
	&"trap": "res://audio/music/trap.mp3",
}
## Station id -> the name shown to the player.
const STATION_NAMES: Dictionary[StringName, String] = {
	&"lofi": "Rooftop Lo-fi",
	&"dub": "Block Dub",
	&"chip": "Switch-On Chip",
	&"trap": "Corner Drill",
}
const BUS_NAME: StringName = &"Music"

## The station playing (or about to play). Public so the menu and tests can read it.
var station: StringName = &"lofi"
## The filter cutoff the song is gliding toward, in Hz (Hertz = pitch). Public for tests.
var target_cutoff_hz: float = 0.0

## The player that plays the song.
var _player: AudioStreamPlayer
## The filter on the Music bus.
var _filter: AudioEffectLowPassFilter
## The lot's light level last reported by the arena, 0 to 1.
var _light: float = 0.0
## Seconds left of a "tree was cut" dulling.
var _dull_left: float = 0.0


## Should the song get its own "Music" bus with the low-pass filter?
## Everywhere except in a browser. `is_web` is passed in (instead of asked for
## inside) so the tests can check the browser answer without being a browser.
##
## WHY NOT ON WEB (s18, the "no sound at all" bug): the web build plays sounds
## through the browser's own audio engine, and Godot 4.7.2's code for that has a
## bug. Any bus after Master, whether added in code or in a bus layout file, is
## put BEFORE Master in the browser's list. Master's output is then plugged into
## the new bus and the new bus back into Master: a closed loop that never reaches
## the speakers, so every sound in the game is silent. Bus effects such as the
## filter do nothing in a browser anyway, so on web the song simply plays into
## Master and only the "tree was cut" volume dip is heard.
static func uses_music_bus(is_web: bool) -> bool:
	return not is_web


## _ready runs once at game start: make the Music bus with its filter (not on web,
## see uses_music_bus), and the player that plays the song.
func _ready() -> void:
	_filter = AudioEffectLowPassFilter.new()
	_filter.cutoff_hz = CONFIG.music_cutoff_dark_hz
	target_cutoff_hz = CONFIG.music_cutoff_dark_hz

	_player = AudioStreamPlayer.new()
	# OS.has_feature("web") is true only in the web export (a browser).
	if uses_music_bus(OS.has_feature("web")):
		# A bus is a mixing channel. Add one called "Music" that feeds into Master
		# (bus 0), so the mute switch on Master silences the radio too.
		AudioServer.add_bus()
		var bus: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, BUS_NAME)
		AudioServer.set_bus_send(bus, &"Master")
		AudioServer.add_bus_effect(bus, _filter)
		_player.bus = BUS_NAME
	# On web the player stays on its default bus, Master, and _filter is attached
	# to nothing: _process still moves its cutoff, which is harmless.
	_player.volume_db = CONFIG.music_volume_db
	add_child(_player)
	_load_station(station)


## The cutoff (Hz) for light level `level`. Pitch is heard on a multiplying
## scale (each doubling sounds like an equal step up), so the cutoff climbs from
## the dark value to the lit value by multiplying, not adding.
static func cutoff_for(level: float) -> float:
	var ratio: float = CONFIG.music_cutoff_lit_hz / CONFIG.music_cutoff_dark_hz
	return CONFIG.music_cutoff_dark_hz * pow(ratio, clampf(level, 0.0, 1.0))


## Called by the arena every frame with the lot's light level (0 to 1).
func set_light(level: float) -> void:
	_light = level


## Called by the arena when a tree is cut down: the song dulls for a moment.
func dull() -> void:
	_dull_left = CONFIG.music_dull_seconds


## True while a "tree was cut" dulling is running. Used by the tests.
func is_dulled() -> bool:
	return _dull_left > 0.0


## Switches to another station. Keeps playing if a song was already playing.
func set_station(new_station: StringName) -> void:
	if not STATIONS.has(new_station) or new_station == station:
		return
	station = new_station
	var was_playing: bool = _player.playing
	_load_station(station)
	if was_playing:
		_player.play()


## _process runs every frame: start the song once audio is allowed, and glide the
## filter (and the volume, while dulled) toward where the light says they should be.
func _process(delta: float) -> void:
	if Sfx.is_unlocked and not _player.playing and _player.stream != null:
		_player.play()
	_dull_left = maxf(_dull_left - delta, 0.0)
	target_cutoff_hz = cutoff_for(_light)
	var volume: float = CONFIG.music_volume_db
	if _dull_left > 0.0:
		target_cutoff_hz = minf(target_cutoff_hz, CONFIG.music_cutoff_dark_hz)
		volume -= CONFIG.music_dull_drop_db
	# Glide, do not jump: lerp moves a share of the remaining distance each frame.
	var step: float = minf(1.0, CONFIG.music_change_speed * delta)
	_filter.cutoff_hz = lerpf(_filter.cutoff_hz, target_cutoff_hz, step)
	_player.volume_db = lerpf(_player.volume_db, volume, step)


## Loads a station's song and makes it repeat. If the file is missing, the
## player is left empty and the radio stays silent (never an error).
func _load_station(id: StringName) -> void:
	var path: String = STATIONS[id]
	if not ResourceLoader.exists(path):
		_player.stream = null
		return
	# duplicate() so that switching loop on does not change the shared file resource.
	var song: AudioStreamMP3 = (load(path) as AudioStreamMP3).duplicate()
	song.loop = true
	_player.stream = song
