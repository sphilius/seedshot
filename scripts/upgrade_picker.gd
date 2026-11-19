# upgrade_picker.gd - the between-wave upgrade cards: pick 1 of 3.
# Created by the arena in code and added to the HUD (so the night tint leaves it
# alone). The arena calls offer() when a wave is cleared and listens for `picked`.
class_name UpgradePicker
extends Control
## HOW IT WORKS
##   After a wave is cleared, three different upgrades are dealt at random from
##   CATALOG. The next wave waits (WaveDirector.hold_break) until the player
##   picks one: press 1, 2 or 3, or click / tap a card. Upgrades last the whole
##   run (a restarted wave keeps them) and the same one can be picked again.
##
## This node only shows the cards and reports the choice ("signal up"); the
## arena applies the upgrade (Arena.apply_upgrade), because it owns the player,
## the trees and the vines that the upgrades change.

## Emitted with the chosen upgrade's id.
signal picked(id: StringName)

const CONFIG: GameConfig = preload("res://config/game_config.tres")

## Every upgrade: id -> [name, description]. The numbers in the descriptions are
## filled in from the config in _describe(), so they always match the game.
const CATALOG: Dictionary[StringName, Array] = {
	&"seed_pouch": ["Seed Pouch", "Fire %d%% faster."],
	&"heavy_seeds": ["Heavy Seeds", "Seed pods hit %d harder."],
	&"thick_plating": ["Thick Plating", "+%d max health. No repair: rest by 4 trees."],
	&"hardwood": ["Hardwood", "Every tree gets +%d hit points."],
	&"quick_roots": ["Quick Roots", "Saplings root %d%% faster."],
	&"long_trellis": ["Long Trellis", "Trellis vines last %d s longer."],
}

const CARD_SIZE: Vector2 = Vector2(330.0, 104.0)
const CARD_GAP: float = 24.0
## Top edge of the row of cards, in screen pixels (under the wave-cleared banner).
const CARDS_TOP: float = 400.0
const CARD_COLOR: Color = Color(0.05, 0.07, 0.09, 0.9)
const EDGE_COLOR: Color = Color(0.35, 0.90, 0.85)
const TITLE_COLOR: Color = Color(1.0, 0.82, 0.50)
const TEXT_COLOR: Color = Color(0.92, 0.94, 0.96)

## The ids on offer right now (empty = hidden). Public so the tests can read them.
var offered: Array[StringName] = []

var _rng := RandomNumberGenerator.new()


## _ready runs once: hidden until offer() is called.
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# IGNORE: clicks pass through to the game except where _gui_input says otherwise.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Deals `count` different upgrades at random and shows them. Ids in `left_out`
## are not dealt (the arena leaves out Thick Plating once health is at its cap).
func offer(count: int, left_out: Array[StringName] = []) -> void:
	var ids: Array[StringName] = []
	for id: StringName in CATALOG.keys():
		if not left_out.has(id):
			ids.append(id)
	# Shuffle with our own random-number generator (a "Fisher-Yates" shuffle:
	# swap each entry with a random one at or before it).
	for i: int in range(ids.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var swap: StringName = ids[i]
		ids[i] = ids[j]
		ids[j] = swap
	offered = ids.slice(0, mini(count, ids.size()))
	visible = true
	# STOP: while the cards are up, this node takes the clicks that land on it.
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


## True while the cards are showing.
func is_open() -> bool:
	return not offered.is_empty()


## Picks card number `index` (0 = the first). Public so the tests can pick.
func choose(index: int) -> void:
	if index < 0 or index >= offered.size():
		return
	var id: StringName = offered[index]
	offered = []
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	picked.emit(id)


## The screen rectangle of card `index`: three cards in a row, centred.
func card_rect(index: int) -> Rect2:
	var width: float = offered.size() * CARD_SIZE.x + (offered.size() - 1) * CARD_GAP
	var left: float = (get_viewport_rect().size.x - width) / 2.0
	return Rect2(Vector2(left + index * (CARD_SIZE.x + CARD_GAP), CARDS_TOP), CARD_SIZE)


## Keys 1, 2 and 3 pick a card. (_unhandled_input: only input nothing else used.)
func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		# physical_keycode is the key's place on the keyboard, whatever the layout.
		var index: int = key.physical_keycode - KEY_1  # KEY_1 -> 0, KEY_2 -> 1, ...
		if index >= 0 and index < offered.size():
			choose(index)
			get_viewport().set_input_as_handled()


## A click or tap on a card picks it. (Touches arrive as mouse clicks too: Godot
## turns touches into mouse events unless told not to.)
func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	for i: int in offered.size():
		if card_rect(i).has_point(click.position):
			choose(i)
			accept_event()  # this click is used up
			return


## True if `point` (screen pixels) is on any card. _has_point decides which
## clicks this Control receives: only those on a card, so the rest of the screen
## still reaches the game.
func _has_point(point: Vector2) -> bool:
	for i: int in offered.size():
		if card_rect(i).has_point(point):
			return true
	return false


## The description of upgrade `id`, with its number from the config.
static func _describe(id: StringName) -> String:
	var template: String = CATALOG[id][1]
	match id:
		&"seed_pouch":
			return template % roundi((1.0 - CONFIG.upgrade_fire_cooldown_factor) * 100.0)
		&"heavy_seeds":
			return template % CONFIG.upgrade_seed_damage
		&"thick_plating":
			return template % CONFIG.upgrade_max_hp
		&"hardwood":
			return template % CONFIG.upgrade_tree_hp
		&"quick_roots":
			return template % roundi((1.0 - CONFIG.upgrade_sapling_time_factor) * 100.0)
		&"long_trellis":
			return template % roundi(CONFIG.upgrade_trellis_seconds)
	return template


## _draw paints the heading and the three cards.
func _draw() -> void:
	if not is_open():
		return
	var font: Font = ThemeDB.fallback_font
	var heading: String = "The block chips in. Pick one  (1 / 2 / 3, or tap)"
	draw_string(font, Vector2(0.0, CARDS_TOP - 14.0), heading, HORIZONTAL_ALIGNMENT_CENTER, get_viewport_rect().size.x, 20, TITLE_COLOR)
	for i: int in offered.size():
		var rect: Rect2 = card_rect(i)
		draw_rect(rect, CARD_COLOR)
		draw_rect(rect, EDGE_COLOR, false, 2.0)  # false = outline only
		var id: StringName = offered[i]
		var title: String = "%d   %s" % [i + 1, CATALOG[id][0]]
		draw_string(font, rect.position + Vector2(16.0, 36.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, TITLE_COLOR)
		draw_multiline_string(font, rect.position + Vector2(16.0, 68.0), _describe(id), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 32.0, 18, 2, TEXT_COLOR)
