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

## True while the player has sound switched off (M key, or the speaker button).
var is_muted: bool = false
## False when the player has switched sound EFFECTS off in the pause menu (the
## music carries on). Separate from is_muted, which silences everything.
var effects_on: bool = true

## Sound name -> audio clip. (A typed Dictionary: keys are StringNames.)
## AudioStream is the parent type of both the generated beeps (AudioStreamWAV)
## and real sound files (.mp3, .ogg, .wav), so one dictionary can hold either.
var _streams: Dictionary[StringName, AudioStream] = {}
## A small pool of players so several sounds can play at the same time.
var _players: Array[AudioStreamPlayer] = []
## Which player in the pool gets the next sound (round-robin).
var _next_player: int = 0
## Sound name -> the time (seconds since start) until which play_steady will
## not start that sound again.
var _steady_until: Dictionary[StringName, float] = {}


## _ready runs once, when this node enters the scene tree at game start.
func _ready() -> void:
	# name                          start Hz, end Hz, seconds, volume
	_streams[&"unlock"] = _make_blip(520.0, 1040.0, 0.12, 0.30)
	_streams[&"fire"] = _make_blip(900.0, 500.0, 0.06, 0.25)
	_streams[&"thunk"] = _make_blip(220.0, 140.0, 0.07, 0.30)
	_streams[&"plink"] = _make_blip(1400.0, 900.0, 0.05, 0.25)
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
	# s18 round 3: how machines arrive. A gate rumbling open, the whistle of a
	# heavy machine falling, and the crash of it landing on the concrete.
	_streams[&"gate"] = _make_blip(110.0, 70.0, 0.22, 0.30)
	_streams[&"drop"] = _make_blip(1100.0, 180.0, 0.55, 0.22)
	_streams[&"crash"] = _make_crash()
	# s18 round 4: a burst of radio static, played as a Helios notice cuts in
	# and again as it cuts out.
	_streams[&"static"] = _make_static(0.38, 0.30)

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


## _unhandled_key_input receives key presses nothing else used: M flips mute.
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"mute"):
		set_muted(not is_muted)


## Switches all game sound off or on. Bus 0 is the "Master" bus: every sound in
## the game passes through it, so muting it silences everything at once.
func set_muted(muted: bool) -> void:
	is_muted = muted
	AudioServer.set_bus_mute(0, muted)


## Plays a named sound. Silently does nothing before the first input (the browser
## would block it anyway) or if the name is unknown.
func play(sound_name: StringName) -> void:
	if not is_unlocked or not effects_on or not _streams.has(sound_name):
		return
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _streams[sound_name]
	player.play()


## Plays a named sound ONLY if it is not still playing from the last call, so a
## sound asked for many times a second plays through to its end and then starts
## again, instead of being cut off and restarted. (The Sawbot's saw: it used to
## restart on every bite, which sounded like a stutter, not a saw.)
func play_steady(sound_name: StringName) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0  # seconds since the game started
	if now < _steady_until.get(sound_name, 0.0):
		return
	play(sound_name)
	if _streams.has(sound_name):
		# get_length is the clip's length in seconds; a hair less, so two plays
		# run into each other without a gap.
		_steady_until[sound_name] = now + maxf(_streams[sound_name].get_length() - 0.03, 0.05)


## Builds a burst of radio static: random noise whose loudness jumps about in
## little steps (the crackle), fading in and out at the ends so it does not click.
func _make_static(seconds: float, volume: float) -> AudioStreamWAV:
	var sample_count: int = int(seconds * MIX_RATE)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)  # 16-bit audio = 2 bytes per sample
	var rng := RandomNumberGenerator.new()
	rng.seed = 11  # a fixed seed: the same burst every time
	var crackle: float = 1.0
	for i: int in sample_count:
		var progress: float = float(i) / float(sample_count)  # 0.0 at start, 1.0 at end
		# Every 120 samples (about 5 ms) pick a new loudness: that is the crackle.
		if i % 120 == 0:
			crackle = rng.randf_range(0.25, 1.0)
		# minf(...) is a short ramp up at the start and down at the end.
		var edge: float = minf(minf(progress / 0.08, (1.0 - progress) / 0.25), 1.0)
		var sample: float = rng.randf_range(-1.0, 1.0) * crackle * edge * volume
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


## Returns the clip a sound name will play (a beep or a real file), or null if
## the name is unknown. Used by the tests to prove the real files were picked up.
func stream_for(sound_name: StringName) -> AudioStream:
	return _streams.get(sound_name)


## Builds the sound of something heavy and metal hitting concrete, from three
## layers added together sample by sample:
##   1. THE THUD: a very low tone that drops in pitch (90 Hz down to 35 Hz);
##   2. THE CRUNCH: random noise that dies away quickly (rubble and dust);
##   3. THE RING: a few high tones that are NOT neat multiples of each other,
##      which is what makes a sound read as struck metal, fading more slowly.
## A real recording saved as audio/sfx/crash.mp3 replaces it (see _ready).
func _make_crash() -> AudioStreamWAV:
	var seconds: float = 0.9
	var sample_count: int = int(seconds * MIX_RATE)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)  # 16-bit audio = 2 bytes per sample
	var ring_hz: Array[float] = [311.0, 523.0, 847.0, 1290.0]
	var thud_phase: float = 0.0
	# Our own random-number generator with a fixed seed, so the crunch is the
	# same every time the game starts.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in sample_count:
		var t: float = float(i) / float(MIX_RATE)             # seconds since the start
		var progress: float = float(i) / float(sample_count)  # 0.0 at start, 1.0 at end
		# exp(-t * k) is a curve that starts at 1 and falls away; bigger k = faster.
		thud_phase += TAU * lerpf(90.0, 35.0, progress) / float(MIX_RATE)
		var thud: float = sin(thud_phase) * exp(-t * 5.0) * 0.75
		var crunch: float = rng.randf_range(-1.0, 1.0) * exp(-t * 14.0) * 0.45
		var ring: float = 0.0
		for hz: float in ring_hz:
			ring += sin(TAU * hz * t) * exp(-t * 6.0) * 0.07
		var sample: float = thud + crunch + ring
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


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
