# sfx.gd - gray-box sound effects, registered as the autoload "Sfx".
# An autoload is a script Godot loads once at startup and keeps alive for the whole
# game, so any script can call Sfx.play(&"fire") without holding a reference to it.
extends Node
## Tiny beeps generated in code, real sound files when they exist (see _ready),
## plus the browser audio unlock.
##
## THE BROWSER AUTOPLAY RULE: a web page may not make sound until the player has
## clicked or pressed a key. So this script stays silent until the first input,
## then plays a short chirp to prove audio is running. Real sound files can replace
## the generated beeps later without changing any caller: they all go through play().

## Samples per second for the generated beeps. Low is fine for simple tones.
const MIX_RATE: int = 22050
## How many sounds can overlap before the oldest player is reused.
const PLAYER_COUNT: int = 6
## Where real sound files go, and the file types looked for (in this order).
const SFX_FOLDER: String = "res://audio/sfx"
const SFX_EXTENSIONS: Array[String] = ["mp3", "ogg", "wav"]

## False until the player's first click or key press.
var is_unlocked: bool = false

## Sound name -> audio clip. (A typed Dictionary: keys are StringNames.)
## AudioStream is the parent type of both the generated beeps (AudioStreamWAV)
## and real sound files (.mp3, .ogg, .wav), so one dictionary can hold either.
var _streams: Dictionary[StringName, AudioStream] = {}
## A small pool of players so several sounds can play at the same time.
var _players: Array[AudioStreamPlayer] = []
## Which player in the pool gets the next sound (round-robin).
var _next_player: int = 0


## _ready runs once, when this node enters the scene tree at game start.
func _ready() -> void:
	# name                          start Hz, end Hz, seconds, volume
	_streams[&"unlock"] = _make_blip(520.0, 1040.0, 0.12, 0.30)
	_streams[&"fire"] = _make_blip(900.0, 500.0, 0.06, 0.25)
	_streams[&"thunk"] = _make_blip(220.0, 140.0, 0.07, 0.30)
	_streams[&"enemy_down"] = _make_blip(600.0, 120.0, 0.18, 0.35)
	_streams[&"zip"] = _make_blip(300.0, 1200.0, 0.14, 0.25)
	_streams[&"grow"] = _make_blip(400.0, 800.0, 0.20, 0.25)
	_streams[&"windup"] = _make_blip(180.0, 360.0, 0.10, 0.20)
	_streams[&"hurt"] = _make_blip(320.0, 90.0, 0.16, 0.40)
	_streams[&"player_down"] = _make_blip(440.0, 55.0, 0.60, 0.40)
	_streams[&"saw"] = _make_blip(150.0, 110.0, 0.09, 0.22)
	_streams[&"cat"] = _make_blip(660.0, 1320.0, 0.45, 0.35)
	_streams[&"bind"] = _make_blip(900.0, 300.0, 0.16, 0.25)
	_streams[&"spit"] = _make_blip(700.0, 250.0, 0.10, 0.25)
	_streams[&"wave_clear"] = _make_blip(500.0, 1000.0, 0.35, 0.30)

	# REAL SOUND FILES WIN: if audio/sfx/<name>.mp3 (or .ogg / .wav) exists, it
	# replaces the beep of the same name. So a sound is swapped in by dropping one
	# file into that folder; no code changes. Missing files keep their beep.
	for sound_name: StringName in _streams.keys():
		for extension: String in SFX_EXTENSIONS:
			var path: String = "%s/%s.%s" % [SFX_FOLDER, sound_name, extension]
			# ResourceLoader.exists is true only for files Godot has imported.
			if ResourceLoader.exists(path):
				_streams[sound_name] = load(path)
				break  # stop at the first file type found for this name

	for i: int in PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


## _input receives every input event. We only need the very first press.
func _input(event: InputEvent) -> void:
	if is_unlocked:
		return
	var is_press: bool = (
		event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch
	)
	if is_press and event.is_pressed():
		is_unlocked = true
		set_process_input(false)  # stop listening: the job is done
		play(&"unlock")


## Plays a named sound. Silently does nothing before the first input (the browser
## would block it anyway) or if the name is unknown.
func play(sound_name: StringName) -> void:
	if not is_unlocked or not _streams.has(sound_name):
		return
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _streams[sound_name]
	player.play()


## Builds a short sine-wave beep that slides from one pitch to another and fades out.
## Returns it as an AudioStreamWAV: raw 16-bit mono samples held in memory.
func _make_blip(start_hz: float, end_hz: float, seconds: float, volume: float) -> AudioStreamWAV:
	var sample_count: int = int(seconds * MIX_RATE)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)  # 16-bit audio = 2 bytes per sample

	var phase: float = 0.0  # where we are on the sine wave, in radians
	for i: int in sample_count:
		var progress: float = float(i) / float(sample_count)  # 0.0 at start, 1.0 at end
		var hz: float = lerpf(start_hz, end_hz, progress)      # pitch slides over time
		phase += TAU * hz / float(MIX_RATE)
		var fade: float = 1.0 - progress                       # louder at the start
		var sample: float = sin(phase) * fade * volume
		# encode_s16 writes one signed 16-bit number (-32768..32767) at a byte offset.
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav
