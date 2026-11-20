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
## False when the player has switched the MUSIC off in the pause menu. Public so
## the menu can show it; change it with set_music_on.
var music_on: bool = true
## The hiss's loudness when it should not be heard at all, in decibels.
const HISS_SILENT_DB: float = -70.0
## Where the hiss's loudness is heading right now (dB). Public for the tests.
var hiss_target_db: float = HISS_SILENT_DB
## The player that loops the radio hiss under the song.
var _hiss: AudioStreamPlayer
## Where in the song to carry on from when the music is switched back on, in seconds.
var _resume_at: float = 0.0
## The filter cutoff the song is gliding toward, in Hz (Hertz = pitch). Public for tests.
var target_cutoff_hz: float = 0.0

## The player that plays the song.
var _player: AudioStreamPlayer
## The filter on the Music bus.
var _filter: AudioEffectLowPassFilter
## The lot's light level last reported by the arena, 0 to 1.
var _light: float = 1.0  # clear until an arena says how dark its lot is
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
	# THE HISS (s18 round 4): a loop of radio static under the song. Loud while
	# the block is dark, gone once it is lit, so the station "tunes in" as the
	# forest grows. It works in the web build too, where the filter cannot.
	_hiss = AudioStreamPlayer.new()
	_hiss.stream = _make_hiss()
	_hiss.volume_db = HISS_SILENT_DB
	add_child(_hiss)
	_load_station(station)


## The cutoff (Hz) for light level `level`. Pitch is heard on a multiplying
## scale (each doubling sounds like an equal step up), so the cutoff climbs from
## the dark value to the lit value by multiplying, not adding.
static func cutoff_for(level: float) -> float:
	var ratio: float = CONFIG.music_cutoff_lit_hz / CONFIG.music_cutoff_dark_hz
	return CONFIG.music_cutoff_dark_hz * pow(ratio, clampf(level, 0.0, 1.0))


## How loud the radio hiss is at light level `level`, in decibels: radio_hiss_db
## in full darkness, silent once the block is fully lit. Public for the tests.
static func hiss_for(level: float) -> float:
	return lerpf(HISS_SILENT_DB, CONFIG.radio_hiss_db, 1.0 - clampf(level, 0.0, 1.0))


## Called by the arena every frame with the lot's light level (0 to 1).
func set_light(level: float) -> void:
	_light = level


## Called by the arena when a tree is cut down: the song dulls for a moment.
func dull() -> void:
	_dull_left = CONFIG.music_dull_seconds


## True while a "tree was cut" dulling is running. Used by the tests.
func is_dulled() -> bool:
	return _dull_left > 0.0


## Switches the music off or on (the pause menu's Music button). stream_paused
## holds the song at its place, so switching back on carries on from there.
## The song is STOPPED, not just paused, and its place remembered: in the web
## build a paused stream carried on playing (Sasha: "the Music still plays if
## you switch it off"). _process starts it again from `_resume_at`.
func set_music_on(on: bool) -> void:
	if on == music_on:
		return
	music_on = on
	if not on:
		_resume_at = _player.get_playback_position()
		_player.stop()
		_hiss.stop()
	elif Sfx.is_unlocked and _player.stream != null:
		# Start it here and now: _process does not run while the pause menu is up.
		_player.play(_resume_at)
		_resume_at = 0.0


## The name of the station playing, as shown to the player.
func station_name() -> String:
	return STATION_NAMES[station]


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
	if music_on and Sfx.is_unlocked and not _player.playing and _player.stream != null:
		_player.play(_resume_at)  # from where it was switched off (0 = the start)
		_resume_at = 0.0
	_dull_left = maxf(_dull_left - delta, 0.0)
	target_cutoff_hz = cutoff_for(_light)
	var volume: float = CONFIG.music_volume_db
	# FAINT AND STATICKY IN THE DARK: `dark` is 1 with no light and 0 fully lit.
	# The song is quieter by up to music_dark_drop_db, and the hiss is louder.
	var dark: float = 1.0 - clampf(_light, 0.0, 1.0)
	volume -= CONFIG.music_dark_drop_db * dark
	var wants_hiss: bool = music_on and _player.playing
	if wants_hiss and not _hiss.playing:
		_hiss.play()
	elif not wants_hiss and _hiss.playing:
		_hiss.stop()
	hiss_target_db = hiss_for(_light)
	_hiss.volume_db = lerpf(_hiss.volume_db, hiss_target_db, minf(1.0, CONFIG.music_change_speed * delta))
	if _dull_left > 0.0:
		target_cutoff_hz = minf(target_cutoff_hz, CONFIG.music_cutoff_dark_hz)
		volume -= CONFIG.music_dull_drop_db
	# Glide, do not jump: lerp moves a share of the remaining distance each frame.
	var step: float = minf(1.0, CONFIG.music_change_speed * delta)
	_filter.cutoff_hz = lerpf(_filter.cutoff_hz, target_cutoff_hz, step)
	_player.volume_db = lerpf(_player.volume_db, volume, step)


## Builds two seconds of soft radio hiss that repeats without end: random noise,
## smoothed a little so it is a hiss and not a harsh buzz, with a faint pop now
## and then.
func _make_hiss() -> AudioStreamWAV:
	var mix_rate: int = 22050
	var sample_count: int = mix_rate * 2
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)  # 16-bit audio = 2 bytes per sample
	var rng := RandomNumberGenerator.new()
	rng.seed = 23  # a fixed seed: the same hiss every time
	var smooth: float = 0.0
	for i: int in sample_count:
		# Each sample moves only part of the way to a new random value: that is
		# the smoothing (a simple "low-pass filter").
		smooth = lerpf(smooth, rng.randf_range(-1.0, 1.0), 0.55)
		var sample: float = smooth * 0.5
		if rng.randf() < 0.0006:
			sample += rng.randf_range(-0.6, 0.6)  # a pop
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = bytes
	# LOOP_FORWARD plays from loop_begin to loop_end again and again.
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = sample_count
	return wav


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
