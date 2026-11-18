# lucky_lines.gd - picks what Lucky (the hidden lucky cat) says. Words only: nothing here
# changes the game. Not a node: the arena calls LuckyLines.greeting_for(...) and so on.
class_name LuckyLines
extends RefCounted
## Lucky's two kinds of line (story spine, STORY.md "Lucky's lines"):
##
##   GREETING   said once, when the shutter opens. It depends on the wave the cat
##              was FOUND in: early (waves 1 to 3), middle (4 to 7), or late (8+).
##   SMALL TALK said each time Seven talks to Lucky (E key, or a tap on the shop).
##              It depends on the wave being PLAYED NOW, and cycles through that
##              wave's set, so talking again gives the next line.
##
## The words live in the config (group "Lucky cat"), so they can be rewritten
## without touching code. Every function is `static`: no object is needed.

const CONFIG: GameConfig = preload("res://config/game_config.tres")


## The greeting for a cat found during wave `found_wave`.
static func greeting_for(found_wave: int) -> String:
	if found_wave <= 3:
		return CONFIG.lucky_greeting_early
	if found_wave <= 7:
		return CONFIG.lucky_greeting_middle
	return CONFIG.lucky_greeting_late


## The small-talk set for wave `wave`: 1-3, 4-7, 8 (the block almost lit), 9-10.
static func small_talk_set(wave: int) -> Array[String]:
	if wave <= 3:
		return CONFIG.lucky_talk_waves_1_to_3
	if wave <= 7:
		return CONFIG.lucky_talk_waves_4_to_7
	if wave == 8:
		return CONFIG.lucky_talk_wave_8
	return CONFIG.lucky_talk_waves_9_to_10


## Line number `times_talked` of wave `wave`'s set, wrapping round to the start
## (% is "remainder after division", so 0, 1, 2, 0, 1, 2, ... for a set of three).
static func small_talk_for(wave: int, times_talked: int) -> String:
	var lines: Array[String] = small_talk_set(wave)
	if lines.is_empty():
		return ""
	return lines[times_talked % lines.size()]
