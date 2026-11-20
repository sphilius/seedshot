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
	&"seed_pouch": ["Seed Loader Pouch", "Fire %d%% faster. Stacks."],
	&"heavy_seeds": ["Heavy Seeds", "Seed pods hit %s harder. Stacks."],
	# The id is still "thick_plating" (its picture file is named after it), but
	# since s18 the card is a repair, not extra max health.
	&"thick_plating": ["Patch Kit", "Repairs %d to %d pips, by luck. Does not stack."],
	&"hardwood": ["Hardwood", "Every tree gets +%d hit points. Stacks."],
	&"quick_roots": ["Quick Roots", "Saplings root %d%% faster. Stacks."],
	# The id is still "long_trellis" (its picture file is named after it). Since
	# s24 it is only dealt once the Trip Line itself is unlocked (the card below).
	&"long_trellis": ["Vine Trip Line", "Your trip line lasts %s s longer. Stacks."],
	# s24 SKILL UNLOCKS: these two are not there at the start of a run. Each is
	# picked once; the arena stops dealing it after that.
	&"trip_line": ["Vine Trip Line", "Zip from beside one tree to another: a vine stays %s s and trips machines."],
	&"bramble_seed": ["Bramble Seed", "Throw thorns that slow a crowd and chew it up. Hold %d; they grow back."],
	# s22: takes time off the seed shooter's reload, up to a limit (see the config).
	&"quick_reload": ["Quick Reload", "Reloads %s s faster. Stacks %d times."],
}

## (Wider and taller since s18, to make room for the picture on the left.)
const CARD_SIZE: Vector2 = Vector2(372.0, 120.0)
## Where each card's picture lives: one 64 px PNG per upgrade id, drawn by Klad
## (art/source/klad/upgrades/make_upgrade_icons.py). %s is the upgrade's id.
const ICON_PATH: String = "res://art/sprites/upgrades/%s.png"
## Cards that use another card's picture: id -> the id whose picture to show.
## (The Trip Line unlock and its "lasts longer" card are the same vine.)
const ICON_SHARED_WITH: Dictionary[StringName, StringName] = {
	&"trip_line": &"long_trellis",
}
## The picture is drawn this big on the card, in screen pixels, with this much
## space around it.
const ICON_SIZE: float = 88.0
const ICON_MARGIN: float = 16.0
const CARD_GAP: float = 24.0
## Top edge of the row of cards, in screen pixels (under the wave-cleared banner).
const CARDS_TOP: float = 400.0
const CARD_COLOR: Color = Color(0.05, 0.07, 0.09, 0.9)
const EDGE_COLOR: Color = Color(0.35, 0.90, 0.85)
const TITLE_COLOR: Color = Color(1.0, 0.82, 0.50)
## A card's title is drawn this big, or smaller (down to the minimum) if it
## would not fit on the card otherwise.
const TITLE_FONT_SIZE: int = 24
const TITLE_FONT_MIN: int = 16
const TEXT_COLOR: Color = Color(0.92, 0.94, 0.96)

## The ids on offer right now (empty = hidden). Public so the tests can read them.
var offered: Array[StringName] = []

var _rng := RandomNumberGenerator.new()
## Upgrade id -> its picture. An upgrade with no picture file is simply left out
## and its card shows text only.
var _icons: Dictionary[StringName, Texture2D] = {}


## _ready runs once: hidden until offer() is called.
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# IGNORE: clicks pass through to the game except where _gui_input says otherwise.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	# NEAREST keeps pixel art crisp when it is drawn bigger than its 64 px.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for id: StringName in CATALOG.keys():
		# Some cards borrow another card's picture (ICON_SHARED_WITH).
		var icon_file: String = ICON_PATH % ICON_SHARED_WITH.get(id, id)
		if ResourceLoader.exists(icon_file):
			_icons[id] = load(icon_file)


## True if upgrade `id` has a picture to show. Public for the tests.
func has_icon(id: StringName) -> bool:
	return _icons.has(id)


## Deals `count` different upgrades at random and shows them. Ids in `left_out`
## are not dealt (the arena leaves out the Patch Kit while Seven is unhurt).
## Ids in `always_shown` (s24: the skill unlocks, on the screen they first
## appear) come first, in that order; random cards fill the rest of the row.
func offer(count: int, left_out: Array[StringName] = [], always_shown: Array[StringName] = []) -> void:
	var ids: Array[StringName] = []
	for id: StringName in CATALOG.keys():
		if not left_out.has(id) and not always_shown.has(id):
			ids.append(id)
	# Shuffle with our own random-number generator (a "Fisher-Yates" shuffle:
	# swap each entry with a random one at or before it).
	for i: int in range(ids.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var swap: StringName = ids[i]
		ids[i] = ids[j]
		ids[j] = swap
	# The must-show cards go in front of the shuffled deck, then the row is cut
	# to `count` cards.
	var row: Array[StringName] = []
	for id: StringName in always_shown:
		if CATALOG.has(id):
			row.append(id)
	row.append_array(ids)
	offered = row.slice(0, mini(count, row.size()))
	visible = true
	# STOP: while the cards are up, this node takes the clicks that land on it.
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


## Takes the cards away WITHOUT picking one (the wave is being restarted).
func cancel() -> void:
	offered = []
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
			# "%.1f" writes 0.5 as "0.5"; the card says "+0.5".
			return template % ("+%.1f" % CONFIG.upgrade_seed_damage)
		&"thick_plating":
			# Two numbers to fill in, so they go in a list.
			return template % [CONFIG.upgrade_repair_min_pips, CONFIG.upgrade_repair_max_pips]
		&"hardwood":
			return template % CONFIG.upgrade_tree_hp
		&"quick_roots":
			return template % roundi(CONFIG.upgrade_sapling_rate_gain * 100.0)
		&"long_trellis":
			# "%.1f" writes the number with one digit after the point: 1.5.
			return template % ("%.1f" % CONFIG.upgrade_trellis_seconds)
		&"quick_reload":
			return template % ["%.1f" % CONFIG.upgrade_reload_seconds_off, CONFIG.upgrade_reload_max_picks]
		&"trip_line":
			# "%.0f" writes 6.0 as "6".
			return template % ("%.0f" % CONFIG.trellis_seconds)
		&"bramble_seed":
			return template % CONFIG.bramble_max_charges
	return template


## The biggest font size, from TITLE_FONT_SIZE down to TITLE_FONT_MIN, at which
## `title` fits in `width` pixels. (s24: "Seed Loader Pouch" was cut off at the
## card's edge.) get_string_size measures text without drawing it. Static and
## public so the tests can ask it.
static func title_font_size(font: Font, title: String, width: float) -> int:
	var size: int = TITLE_FONT_SIZE
	while size > TITLE_FONT_MIN and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x > width:
		size -= 1
	return size


## _draw paints the heading and the three cards.
func _draw() -> void:
	if not is_open():
		return
	# Darken the whole screen behind the cards, so the choice has the player's eye.
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), CONFIG.upgrade_dim_color)
	var font: Font = ThemeDB.fallback_font
	var heading: String = "The block chips in. Pick one  (1 / 2 / 3, or tap)"
	draw_string(font, Vector2(0.0, CARDS_TOP - 14.0), heading, HORIZONTAL_ALIGNMENT_CENTER, get_viewport_rect().size.x, 20, TITLE_COLOR)
	for i: int in offered.size():
		var rect: Rect2 = card_rect(i)
		draw_rect(rect, CARD_COLOR)
		draw_rect(rect, EDGE_COLOR, false, 2.0)  # false = outline only
		var id: StringName = offered[i]
		var title: String = "%d   %s" % [i + 1, CATALOG[id][0]]
		# The picture on the left (if this upgrade has one); the words start to
		# its right, or at the card's edge when there is no picture.
		var text_left: float = ICON_MARGIN
		if _icons.has(id):
			var icon_rect := Rect2(rect.position + Vector2(ICON_MARGIN, (rect.size.y - ICON_SIZE) / 2.0), Vector2.ONE * ICON_SIZE)
			draw_texture_rect(_icons[id], icon_rect, false)  # false = stretch, do not tile
			text_left = ICON_MARGIN + ICON_SIZE + 14.0
		var text_width: float = rect.size.x - text_left - ICON_MARGIN
		draw_string(font, rect.position + Vector2(text_left, 38.0), title, HORIZONTAL_ALIGNMENT_LEFT, text_width, title_font_size(font, title, text_width), TITLE_COLOR)
		draw_multiline_string(font, rect.position + Vector2(text_left, 66.0), _describe(id), HORIZONTAL_ALIGNMENT_LEFT, text_width, 17, 3, TEXT_COLOR)
