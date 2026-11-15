# wave_director.gd - decides WHEN each machine walks in and when a wave is over.
# It lives in arena.tscn as the node WaveDirector.
class_name WaveDirector
extends Node
## The wave timetable.
##
## It never creates an enemy itself. It only keeps count and announces things
## with signals ("signal up"); the arena listens and does the actual spawning.
## That keeps this script small enough to test without an arena at all.
##
## ONE WAVE, STEP BY STEP
##   SPAWNING  machines walk in one at a time, wave_spawn_interval apart
##   FIGHTING  everything has been sent; waiting for the last one to fall
##   BREAK     a short rest, then the next wave starts by itself
##   DONE      the last wave is cleared
##
## WHAT IS IN A WAVE comes from three lists in the config (wave_scrappers,
## wave_spitters and wave_sawbots): entry 0 is wave 1, entry 1 is wave 2, and so
## on. The number of waves is simply the length of the Scrapper list.

## Emitted when a wave begins. `total` is how many waves there are.
signal wave_started(number: int, total: int)
## Emitted each time a machine should walk in. `kind` is SCRAPPER, SPITTER or SAWBOT.
signal spawn_requested(kind: StringName, wave_number: int)
## Emitted when every machine of a wave is down.
signal wave_cleared(number: int)
## Emitted after the last wave is cleared.
signal all_waves_cleared

## What the director is doing right now.
enum State { IDLE, SPAWNING, FIGHTING, BREAK, DONE }

const CONFIG: GameConfig = preload("res://config/game_config.tres")
const SCRAPPER: StringName = &"scrapper"
const SPITTER: StringName = &"spitter"
const SAWBOT: StringName = &"sawbot"

## Runs the timetable faster or slower. 1.0 is normal. The headless tests set
## this to 20 so a wave's worth of spawning takes a blink instead of seconds.
var time_scale: float = 1.0
## The current wave, counting from 1. 0 means no wave has started yet.
var wave: int = 0
var state: State = State.IDLE

## Machines still to send this wave, next one first.
var _queue: Array[StringName] = []
## Machines sent this wave that are still standing.
var _alive: int = 0
## Seconds until the next spawn (SPAWNING) or the next wave (BREAK).
var _timer: float = 0.0


## How many waves the config describes.
func total_waves() -> int:
	return CONFIG.wave_scrappers.size()


## Starts wave `number` (1 = the first) from the beginning.
func start_wave(number: int) -> void:
	wave = number
	_alive = 0
	_queue = _build_queue(number)
	_timer = CONFIG.wave_first_delay
	state = State.SPAWNING
	wave_started.emit(wave, total_waves())


## Starts the current wave again (used when the player goes down).
func restart_wave() -> void:
	start_wave(maxi(wave, 1))  # maxi = the larger of two whole numbers


## The arena calls this whenever a machine is gone (shot, or could not be placed).
func enemy_gone() -> void:
	_alive = maxi(_alive - 1, 0)
	_check_cleared()


## _physics_process runs 60 times per second: count down to the next spawn or
## the next wave. (`match` is GDScript's "switch": it picks the matching branch.)
func _physics_process(delta: float) -> void:
	delta *= time_scale  # stretch or squeeze time for this node only
	match state:
		State.SPAWNING:
			# A staged wave (wave 1) sends one machine at a time: the next one
			# waits until the one before it is down.
			if wave <= CONFIG.wave_staged_waves and _alive > 0:
				return
			_timer -= delta
			if _timer > 0.0:
				return
			_timer = CONFIG.wave_spawn_interval
			var kind: StringName = _queue.pop_front()  # take the next machine off the list
			_alive += 1
			spawn_requested.emit(kind, wave)
			if _queue.is_empty():
				state = State.FIGHTING
				_check_cleared()  # in case it was shot the instant it appeared
		State.BREAK:
			_timer -= delta
			if _timer <= 0.0:
				start_wave(wave + 1)


## If everything has been sent and nothing is standing, the wave is over.
func _check_cleared() -> void:
	if state != State.FIGHTING or _alive > 0:
		return
	wave_cleared.emit(wave)
	if wave >= total_waves():
		state = State.DONE
		all_waves_cleared.emit()
	else:
		state = State.BREAK
		_timer = CONFIG.wave_break_time


## Builds the order machines walk in for one wave: all its Scrappers, with its
## Spitters and Sawbots slotted in at even gaps so they do not arrive together.
func _build_queue(number: int) -> Array[StringName]:
	var index: int = clampi(number - 1, 0, total_waves() - 1)  # lists count from 0
	var queue: Array[StringName] = []
	for i: int in CONFIG.wave_scrappers[index]:
		queue.append(SCRAPPER)

	# The "specials" for this wave, Spitters and Sawbots taking turns.
	var spitters: int = _count_for(CONFIG.wave_spitters, index)
	var sawbots: int = _count_for(CONFIG.wave_sawbots, index)
	var specials: Array[StringName] = []
	for i: int in maxi(spitters, sawbots):
		if i < spitters:
			specials.append(SPITTER)
		if i < sawbots:
			specials.append(SAWBOT)

	for i: int in specials.size():
		# Spread them through the queue: with 2 specials, about 1/3 and 2/3 of the
		# way along. maxi(..., 1) keeps slot 0 for a Scrapper, so a wave always
		# opens with the simplest machine (unless it has no Scrappers at all).
		var slot: int = (i + 1) * queue.size() / (specials.size() + 1)
		if not queue.is_empty():
			slot = maxi(slot, 1)
		queue.insert(slot, specials[i])
	return queue


## How many of one kind wave `index` sends. A list may be shorter than the
## Scrapper list; a missing entry means none.
func _count_for(list: Array[int], index: int) -> int:
	return list[index] if index < list.size() else 0
