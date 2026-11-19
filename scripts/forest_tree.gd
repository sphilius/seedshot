# forest_tree.gd - one tree: starts as a walk-through sapling, becomes solid cover.
# It is called ForestTree because Godot already has a built-in UI class named Tree.
class_name ForestTree
extends StaticBody2D
## A tree growing where a machine fell.
##
## LIFE OF A TREE
##   1. SAPLING: drawn small, no collision, for CONFIG.sapling_time seconds.
##   2. It then ASKS the arena "may I turn solid?" by emitting ready_to_solidify.
##      (The arena says no if someone is standing on it, or if it would seal the
##      player in. A tree does not know about the grid: "signal up, call down".)
##   3. GROWN: solid. Blocks movement and seed pods, and the vine can latch on.
##
## WHAT THE PLAYER SEES (s18, see _draw_overlay): a sapling has a ring that fills
## as it roots; becoming a tree is a quick swell and a ring of light; a hurt tree
## has a health bar; the Heart Tree has a pulsing ring and a label.
##
## The scene (forest_tree.tscn) puts this on physics layer 1, "world".

## Emitted when the sapling timer runs out. The arena answers by calling
## solidify(), retry_later(), or nothing (the sapling then stays a sapling).
signal ready_to_solidify(tree: ForestTree)
## Emitted just before a grown tree is removed because its HP reached zero.
signal felled(tree: ForestTree)
## Emitted when a grown tree loses HP but is still standing. The arena listens so
## Canopy FM can raise the alarm when it is the Heart Tree.
signal hurt(tree: ForestTree)

enum Stage { SAPLING, GROWN }

const CONFIG: GameConfig = preload("res://config/game_config.tres")
## Group that every tree joins, so the player can ask the scene tree for "all trees".
const GROUP: StringName = &"trees"

## Night colours: a dark base and a bright canopy, so the tree looks lit from
## inside. Sunroot stores the day's sun and glows with it at night.
const SAPLING_COLOR: Color = Color(0.55, 0.95, 0.55)
const TRUNK_COLOR: Color = Color(0.07, 0.17, 0.14)
const CANOPY_COLOR: Color = Color(0.36, 0.88, 0.56)

## The grid cell this tree stands on. Set by the arena before the tree is added.
var cell: Vector2i
## Set to true BEFORE adding the tree to the scene to skip the sapling stage
## (used for the three hand-placed test trees).
var starts_grown: bool = false
## Set to true BEFORE adding the tree to make it a TAP TREE (it grew on a tap
## point): more hit points and a gold tint. The arena handles its other effects.
var is_tap: bool = false
## True once the tree has matured into a GREAT SUNROOT (tree stage 4, New Game +
## only): a bigger picture, a wider glow, and far more hit points. See mature().
var is_great: bool = false
## True for the HEART TREE: the big old tree in the middle of the lot that the
## whole block's roots run through. Lots of hit points, Sawbots go for it first,
## and if it falls the wave starts again. Set by the arena before the tree is added.
var is_heart: bool = false
## Extra hit points from Hardwood upgrades. Set by the arena.
var bonus_hp: int = 0
## Multiplies how long the sapling takes to root (Quick Roots makes it smaller).
var sapling_time_scale: float = 1.0
var stage: Stage = Stage.SAPLING
var hp: int = 0
## While true, a ring pulses on the tree: "you can vine to this". The arena
## switches it on for the first tree you grow and off after your first zip.
var show_vine_hint: bool = false

## How brightly every tree draws its markers (above 1 shines through the night
## tint). `static` means ONE value shared by all trees, not one each, so the
## arena sets it once a frame for the whole forest: ForestTree.light_boost = ...
static var light_boost: float = 1.0
## How strongly every Heart Tree marker (ring and label) is drawn, 0 to 1. The
## arena fades it out after the first wave. Shared, like light_boost.
static var heart_marker_fade: float = 1.0

## Seconds this tree has spent as a sapling (fills the growth ring).
var _sapling_age: float = 0.0
## Seconds left of the "pop" that plays when it becomes a tree or a great sunroot.
var _pop_left: float = 0.0
## Seconds left of showing the Heart Tree's alarm colours after a hit.
var _alarm_left: float = 0.0
## A child node that draws the markers (label, rings, health bar) ABOVE the
## machines, the glow and the cables, so they are never hidden. See _draw_overlay.
var _overlay: Node2D

## @onready means "fill this in just before _ready runs", once the child node exists.
@onready var _collision: CollisionShape2D = $CollisionShape2D


## _ready runs once when the tree enters the scene.
func _ready() -> void:
	add_to_group(GROUP)
	hp = max_hp()
	# The overlay: a plain Node2D with a high z_index (drawn later = on top).
	# Every CanvasItem has a `draw` signal that fires when it is time to paint;
	# connecting our own function to it lets this script do the overlay's drawing.
	_overlay = Node2D.new()
	_overlay.z_index = 2
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	# Whenever the tree itself redraws, the overlay redraws too.
	draw.connect(_overlay.queue_redraw)
	# The collision square is exactly one cell, so pods cannot slip between two
	# trees standing side by side.
	(_collision.shape as RectangleShape2D).size = Vector2.ONE * float(CONFIG.cell_size)
	if starts_grown:
		stage = Stage.GROWN
		_add_glow()
	else:
		_collision.disabled = true  # saplings can be walked and shot through
		_start_timer(CONFIG.sapling_time * sapling_time_scale)


## Called by the arena: become solid cover.
func solidify() -> void:
	stage = Stage.GROWN
	# set_deferred changes the property at a safe moment, after the physics engine
	# has finished its current step. Changing collision mid-step is an error.
	_collision.set_deferred(&"disabled", false)
	_add_glow()
	_pop_left = CONFIG.tree_pop_seconds  # the visible "it grew!" moment
	queue_redraw()  # ask Godot to call _draw again with the new look


## Gives a grown tree its pool of light (see glow.gd). Saplings have none.
func _add_glow() -> void:
	if has_node(Glow.NODE_NAME):
		return  # already glowing
	add_child(Glow.make_sprite(CONFIG.tree_glow_radius_cells * float(CONFIG.cell_size), CONFIG.tree_glow_color))


## Called by the arena when someone is standing on the sapling: ask again shortly.
func retry_later() -> void:
	_start_timer(CONFIG.sapling_retry_time)


## Removes HP from a grown tree and fells it at zero. Saplings cannot be hurt.
func take_damage(amount: int) -> void:
	if stage != Stage.GROWN:
		return
	hp -= amount
	queue_redraw()  # the picture and the health bar change with HP (see _draw)
	if hp <= 0:
		felled.emit(self)  # tell the arena first, so it can clear the grid cell
		queue_free()       # then remove this node at the end of the frame
		return
	_alarm_left = CONFIG.heart_alarm_show_seconds  # only the Heart Tree shows it
	hurt.emit(self)


## _process runs every drawn frame. It counts the little animations down, and
## asks for a redraw only while something on this tree is actually moving (a
## sapling's growth ring, a pop, the Heart Tree's pulse, the vine hint). A plain
## grown tree does nothing here.
func _process(delta: float) -> void:
	var moving: bool = show_vine_hint or is_heart or stage == Stage.SAPLING or _pop_left > 0.0
	if stage == Stage.SAPLING:
		_sapling_age += delta
	_pop_left = maxf(_pop_left - delta, 0.0)
	_alarm_left = maxf(_alarm_left - delta, 0.0)
	if moving:
		queue_redraw()


## How far a sapling is along, 0 (just planted) to 1 (ready to become a tree).
## Public for the tests.
func growth() -> float:
	if stage != Stage.SAPLING:
		return 1.0
	return clampf(_sapling_age / maxf(CONFIG.sapling_time * sapling_time_scale, 0.01), 0.0, 1.0)


## True while the "it grew!" pop is playing. Public for the tests.
func is_popping() -> bool:
	return _pop_left > 0.0


## True while the Heart Tree is showing its alarm colours. Public for the tests.
func is_alarmed() -> bool:
	return is_heart and _alarm_left > 0.0


## How much bigger than normal to draw the picture right now: 1.0 normally, and
## a quick swell up to tree_pop_scale and back while the pop plays.
## sin() of 0..PI goes 0 -> 1 -> 0, which is exactly "swell, then settle".
func pop_scale() -> float:
	if _pop_left <= 0.0:
		return 1.0
	var done: float = 1.0 - _pop_left / CONFIG.tree_pop_seconds  # 0 at the start, 1 at the end
	return 1.0 + (CONFIG.tree_pop_scale - 1.0) * sin(PI * done)


## How strongly to draw the Heart Tree's ring and label, 0 (hidden) to 1: the
## shared fade the arena sets, but always full while the alarm is showing.
func heart_marker_strength() -> float:
	return 1.0 if _alarm_left > 0.0 else heart_marker_fade


## A colour brightened by the shared light_boost (its see-through-ness unchanged).
static func _lit(color: Color) -> Color:
	return Color(color.r * light_boost, color.g * light_boost, color.b * light_boost, color.a)


## Paints the markers on the overlay node (above everything in the lot):
##   sapling     a ring that fills as it roots
##   just grown  a ring of light spreading out (the pop)
##   Heart Tree  a pulsing ring and a label, red for a moment after each hit
##   hurt tree   a health bar under it
## Every draw call starts with "_overlay." because we are painting on that node,
## not on the tree itself.
func _draw_overlay() -> void:
	var cell_px: float = float(CONFIG.cell_size)
	if stage == Stage.SAPLING:
		# An arc from 12 o'clock (-PI/2) clockwise; TAU is a full turn.
		_overlay.draw_arc(Vector2.ZERO, cell_px * 0.42, -PI / 2.0, -PI / 2.0 + TAU * growth(), 32, _lit(CONFIG.tree_growth_ring_color), 3.0, true)
		return
	if _pop_left > 0.0:
		var done: float = 1.0 - _pop_left / CONFIG.tree_pop_seconds
		var ring: Color = _lit(CONFIG.tree_growth_ring_color)
		ring.a *= 1.0 - done  # fades out as it spreads
		_overlay.draw_arc(Vector2.ZERO, cell_px * lerpf(0.5, 1.3, done), 0.0, TAU, 48, ring, 4.0, true)
	if is_heart:
		var alarmed: bool = _alarm_left > 0.0
		# The soft pink glow it keeps all run: two see-through discs, one inside the other.
		var glow: Color = _lit(CONFIG.heart_glow_color)
		_overlay.draw_circle(Vector2.ZERO, cell_px * CONFIG.heart_glow_radius_cells, glow)
		_overlay.draw_circle(Vector2.ZERO, cell_px * CONFIG.heart_glow_radius_cells * 0.6, glow)
	if is_heart and heart_marker_strength() > 0.01:
		var alarmed: bool = _alarm_left > 0.0
		var color: Color = _lit(CONFIG.heart_alarm_color if alarmed else CONFIG.heart_marker_color)
		color.a *= heart_marker_strength()  # fades out after the first wave
		# A slow pulse (faster while alarmed): sin() swings the radius in and out.
		var speed: float = 10.0 if alarmed else 3.0
		var pulse: float = sin(Time.get_ticks_msec() / 1000.0 * speed) * 0.04
		_overlay.draw_arc(Vector2.ZERO, cell_px * (0.80 + pulse), 0.0, TAU, 48, color, 3.0, true)
		# The label, centred above the tree: a dark outline first so it reads on
		# any background, then the letters.
		var font: Font = ThemeDB.fallback_font
		var text: String = CONFIG.heart_alarm_label if alarmed else CONFIG.heart_tree_label
		var width: float = cell_px * 6.0
		var at := Vector2(-width / 2.0, -cell_px * 1.0)
		_overlay.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, CONFIG.heart_label_font_size, 5, Color(0.0, 0.0, 0.0, 0.9 * heart_marker_strength()))
		_overlay.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, CONFIG.heart_label_font_size, color)
	if hp < max_hp():
		# The health bar: a dark back, and a fill that shortens and reddens.
		var share: float = clampf(float(hp) / float(max_hp()), 0.0, 1.0)
		var bar_width: float = cell_px * (1.5 if is_heart else 0.8)
		var bar_height: float = 7.0 if is_heart else 5.0
		var top_left := Vector2(-bar_width / 2.0, cell_px * (0.62 if is_heart else 0.42))
		_overlay.draw_rect(Rect2(top_left - Vector2.ONE, Vector2(bar_width, bar_height) + Vector2.ONE * 2.0), CONFIG.tree_bar_back_color)
		var fill: Color = _lit(CONFIG.tree_bar_low_color.lerp(CONFIG.tree_bar_full_color, share))
		_overlay.draw_rect(Rect2(top_left, Vector2(bar_width * share, bar_height)), fill)


## _draw is Godot's custom-drawing callback. Coordinates are relative to this node,
## so (0, 0) is the centre of the cell.
func _draw() -> void:
	var cell_px: float = float(CONFIG.cell_size)
	var picture: Texture2D = current_texture()
	if picture != null:
		# Drawn at the same size as every other sprite (64 px), centred on the cell.
		# 64 px pictures are drawn at sprite size; a bigger picture (the great
		# sunroot is 72 px) is drawn bigger by the same proportion.
		# pop_scale() is 1.0 except during the brief "it grew!" swell.
		var size: float = CONFIG.sprite_size_cells * cell_px * float(picture.get_width()) / 64.0 * pop_scale()
		# A tap tree is drawn with a warm gold tint (the last argument multiplies its colours).
		var tint: Color = CONFIG.tap_tree_tint if is_tap else Color.WHITE
		if is_heart:
			tint = CONFIG.heart_tree_tint
		draw_texture_rect(picture, Rect2(-size / 2.0, -size / 2.0, size, size), false, tint)
		_draw_vine_hint(cell_px)
		return
	# No pictures in the config: the old shapes (a sprout, or a circle on a square).
	if stage == Stage.SAPLING:
		draw_line(Vector2(0.0, cell_px * 0.2), Vector2(0.0, -cell_px * 0.05), SAPLING_COLOR, 3.0)
		draw_circle(Vector2(-cell_px * 0.08, -cell_px * 0.1), cell_px * 0.09, SAPLING_COLOR)
		draw_circle(Vector2(cell_px * 0.08, -cell_px * 0.1), cell_px * 0.09, SAPLING_COLOR)
	else:
		var half: float = cell_px * 0.5
		draw_rect(Rect2(-half, -half, cell_px, cell_px), TRUNK_COLOR)
		# A hurt tree shows it: the canopy shrinks from full size down to 45% as
		# HP falls, so you can see at a glance which trees a Sawbot has bitten.
		var health: float = clampf(float(hp) / float(max_hp()), 0.0, 1.0)
		draw_circle(Vector2.ZERO, cell_px * 0.36 * lerpf(0.45, 1.0, health), CANOPY_COLOR)
		_draw_vine_hint(cell_px)


## A tree's full hit points: a tap tree has more (it is slow to saw).
func max_hp() -> int:
	var multiplier: int = CONFIG.tap_tree_hp_multiplier if is_tap else 1
	if is_great:
		multiplier *= CONFIG.great_sunroot_hp_multiplier
	if is_heart:
		multiplier *= CONFIG.heart_tree_hp_multiplier
	return CONFIG.tree_hp * multiplier + bonus_hp


## Stage 4: a grown tree becomes a great sunroot. It is healed to its new, much
## higher hit points, and its pool of light widens. The arena decides when.
func mature() -> void:
	if stage != Stage.GROWN or is_great:
		return
	is_great = true
	hp = max_hp()
	_pop_left = CONFIG.tree_pop_seconds  # the same visible step as growing up
	var glow: Node2D = get_node_or_null(Glow.NODE_NAME)
	if glow != null:
		glow.scale *= 1.6
	queue_redraw()


## The picture this tree shows right now: sapling, grown, or cut (a grown tree
## that has lost any HP, so you can see at a glance which trees a Sawbot has
## bitten). Null when the config has no tree pictures. Public for the tests.
func current_texture() -> Texture2D:
	if stage == Stage.SAPLING:
		return CONFIG.tree_sapling_texture
	if (is_great or is_heart) and CONFIG.tree_great_texture != null:
		# A great sunroot only shows the cut picture once it is down to half.
		return CONFIG.tree_great_texture if hp * 2 > max_hp() else CONFIG.tree_cut_texture
	if hp < max_hp():
		return CONFIG.tree_cut_texture
	return CONFIG.tree_grown_texture


## While show_vine_hint is on, a ring that grows and fades once a second.
func _draw_vine_hint(cell_px: float) -> void:
	if not show_vine_hint:
		return
	# fmod(x, 1.0) is the part of x after the decimal point, so `beat` runs 0 -> 1 over and over.
	var beat: float = fmod(Time.get_ticks_msec() / 1000.0, 1.0)
	var ring := Color(SAPLING_COLOR, 1.0 - beat)  # same colour, fading out
	draw_arc(Vector2.ZERO, cell_px * lerpf(0.45, 0.95, beat), 0.0, TAU, 40, ring, 3.0)


## Waits `seconds`, then asks the arena whether this sapling may turn solid.
func _start_timer(seconds: float) -> void:
	# create_timer makes a one-shot timer; `timeout` is its signal, and connect()
	# tells Godot which function to call when the signal fires.
	get_tree().create_timer(seconds).timeout.connect(_on_timer_timeout)


## Runs when the timer above fires. If the tree is still a sapling, it emits the
## ready_to_solidify signal so the arena can decide what happens next.
func _on_timer_timeout() -> void:
	if stage == Stage.SAPLING:
		ready_to_solidify.emit(self)
