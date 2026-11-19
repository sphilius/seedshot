# run_state.gd - what carries over between runs. Registered as the autoload "RunState".
# An autoload survives scene changes (title screen -> arena -> title screen), so this is
# where "which mode is this run" and "has the player ever won" live.
extends Node
## Remembers, between runs AND between visits to the page:
##   - ng_plus_unlocked: the player has beaten the game once, so New Game + is open.
##   - the Canopy FM station they picked.
## And, for the current run only:
##   - ng_plus: this run is New Game + (harder waves, great sunroots).
##
## SAVING: a ConfigFile is a small text file of "section / key = value" lines.
## "user://" is the game's own save folder; in a browser build Godot keeps it in
## the browser's storage, so it survives closing the tab. Nothing here is
## sensitive: two settings and a flag.

const SAVE_PATH: String = "user://seedshot.cfg"

## True once the player has won a run (any mode). Unlocks New Game +.
var ng_plus_unlocked: bool = false
## True while the current run is New Game +. Set by the title screen.
var ng_plus: bool = false
## Set when a win unlocks New Game + for the first time, so the end screen can
## say so. Cleared when the next run starts.
var just_unlocked: bool = false


## _ready runs once at game start: read the save file, if there is one.
func _ready() -> void:
	var save := ConfigFile.new()
	# load() returns OK (zero) only if the file exists and could be read.
	if save.load(SAVE_PATH) != OK:
		return
	ng_plus_unlocked = save.get_value("progress", "ng_plus_unlocked", false)
	var station: StringName = StringName(save.get_value("radio", "station", "lofi"))
	CanopyFM.set_station(station)


## Called by the arena when the last wave is cleared.
func record_win() -> void:
	if not ng_plus_unlocked:
		just_unlocked = true
	ng_plus_unlocked = true
	save()


## Picks a Canopy FM station and remembers it.
func choose_station(station: StringName) -> void:
	CanopyFM.set_station(station)
	save()


## Writes the save file.
func save() -> void:
	var save_file := ConfigFile.new()
	save_file.set_value("progress", "ng_plus_unlocked", ng_plus_unlocked)
	save_file.set_value("radio", "station", String(CanopyFM.station))
	save_file.save(SAVE_PATH)
