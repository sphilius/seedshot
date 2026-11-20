# player.gd - the gardener-bot: WASD to move, mouse to aim, seed pods and the vine.
class_name Player
extends CharacterBody2D
## The player's gardener-bot.
##
## VERBS
##   Move   WASD / arrow keys. Full speed or stopped (no acceleration in v1).
##   Aim    the bot always faces the mouse pointer.
##   Seed   hold the "fire" action (left click). The player does not create the
##          pod itself: it emits seed_fired and the arena spawns it ("signal up").
##   Vine   press the "vine" action (right click) on a grown tree to zip to it in
##          a straight line, stopping one cell short. Empty space does nothing.
##          Once Lucky (the hidden cat) has given Seven the clamp, the vine on a
##          machine yanks it over and binds it instead.
##
## The scene (player.tscn) puts it on physics layer 2, "player", and it collides
## with layer 1, "world" (walls and grown trees).

## Emitted for every shot. `direction` is a unit vector (length 1).
signal seed_fired(origin: Vector2, direction: Vector2)
## Emitted when a vine zip finishes. (Tests wait on this with `await`.)
signal zip_finished
## Emitted when Seven throws a Bramble Seed; `at` is where it lands (world pixels,
## before the arena keeps it on the floor).
signal bramble_thrown(at: Vector2)
## Emitted whenever hit points change. The arena forwards it to the HUD pips.
signal health_changed(current: int, maximum: int)
## Emitted once, when hit points reach zero. The arena restarts the run.
signal died
## Emitted when a reload starts, and when it is done and the load is full again.
signal reload_started
signal reloaded
## Emitted when the spare fuse saves Seven from going down.
signal fuse_used
## Emitted for every hit that counts (also the one that knocks Seven out). The
## arena shakes the screen and flashes it red.
signal hurt

const CONFIG: GameConfig = preload("res://config/game_config.tres")
## Physics layer 1 ("world") as a bit mask, for ray and shape queries.
const WORLD_MASK: int = 1
# Emerald (#0b8f5c), Seven's colour since the s24 redesign; used only if the texture is missing.
const FALLBACK_COLOR: Color = Color(0.043, 0.561, 0.361)
const VINE_COLOR: Color = Color(0.45, 0.85, 0.35)
const RETICLE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.8)
## How long the vine stays drawn after it lashes a machine.
const LASH_SHOW_SECONDS: float = 0.25

## The part of the floor a Bramble Seed can land on, in world pixels. The arena
## fills this in (a bramble is kept off the walls). An empty Rect2 means "no limit".
var bramble_bounds: Rect2 = Rect2()
## Unit vector from the bot towards the mouse pointer.
var aim_direction: Vector2 = Vector2.RIGHT
## True while the bot is travelling along the vine. Walking is locked meanwhile.
var is_zipping: bool = false
## Set by TouchControls (scripts/touch_controls.gd) on a phone or tablet. While
## true, the bot ignores the mouse: aim_direction is written by the aim thumb-stick
## and seeds fire while touch_fire_held is true.
var touch_mode: bool = false
var touch_fire_held: bool = false
## THE LUCKY CAT'S GIFT. Both stay for the rest of the run, wave restarts included.
## can_bind: the vine can yank and bind a machine (before the cat, it only zips).
var can_bind: bool = false
## has_fuse_slot: Seven carries a spare fuse from now on (see has_fuse).
var has_fuse_slot: bool = false
## has_fuse: a fuse is fitted right now. Used up when it saves Seven; refitted
## only when Seven is really defeated and the wave restarts (in revive), never
## by clearing a wave.
var has_fuse: bool = false
## Hit points left. Starts at max_hp.
var hp: int = 0
## Most hit points Seven can have: the config's player_max_hp, plus any
## Thick Plating upgrades (the arena raises it).
var max_hp: int = CONFIG.player_max_hp
## Multiplies the time between seed pods (Seed Pouch upgrades make it smaller).
var fire_cooldown_scale: float = 1.0
## RELOAD (s22). Pods left in the shooter, out of CONFIG.seed_clip_size.
var seeds_in_clip: int = CONFIG.seed_clip_size
## How long a reload takes. Starts at the config's reload_seconds; the arena
## lowers it when a Quick Reload card is picked ("call down").
var reload_seconds: float = CONFIG.reload_seconds
## Seconds left of the reload in progress; 0 = not reloading. Public so the HUD
## drawing and the tests can read it.
var reload_left: float = 0.0
## Bramble Seeds in hand (the third seed type), and seconds until the next one
## grows back. Public so the HUD and tests can read them.
var bramble_charges: int = CONFIG.bramble_max_charges
var bramble_recharge_left: float = 0.0
## True once hp reaches zero: the bot stops moving, firing and zipping.
var is_dead: bool = false
## True while the grove is repairing Seven (Grove rest). The arena decides this
## and writes it every frame ("call down"); the player only draws the glow.
var is_resting: bool = false
## How far along the next Grove rest pip is, 0 to 1, and how many grown trees
## are in reach while Seven is hurt. Both written by the arena, drawn here.
var rest_progress: float = 0.0
var rest_trees: int = 0
## True while the upgrade cards are up: Seven cannot move, shoot or use the vine.
## The arena sets it with park() and clears it when a card is picked.
var locked: bool = false
## The Tween moving Seven along the vine, kept so park() can stop it.
var _zip_tween: Tween
## Seconds left of the gold shield the fuse gives (see _draw_fuse_shield).
## Public so the tests can read it.
var fuse_shield_left: float = 0.0
## Seconds left of the knock-out animation and of the fuse-revive animation.
var _knockout_left: float = 0.0
var _fuse_flash_left: float = 0.0
## Seconds left of the red "this is what hit me" arc, and where the hit came
## from in world pixels (Vector2.INF = unknown: draw a full ring). Public so the
## tests can read them.
var hurt_arc_left: float = 0.0
var hurt_from: Vector2 = Vector2.INF
## The Tween that plays either animation on the picture, kept so revive() can stop it.
var _body_tween: Tween
## The picture's normal size, remembered so the animations can put it back.
var _sprite_base_scale: Vector2 = Vector2.ONE
## Where the aim line stops, in world pixels: the first wall or tree along the
## aim, or the end of its reach. Public so the tests can read it.
var aim_line_end: Vector2 = Vector2.ZERO
## A small node drawn ABOVE the sprite, for the nozzle (see _draw_nozzle).
var _aim_overlay: Node2D

## The machine the vine last lashed, and how much longer to draw that vine.
var _lash_target: Enemy = null
var _lash_time_left: float = 0.0
## Seconds of "cannot be hurt" left after the last hit (the bot blinks meanwhile).
var _invulnerable_left: float = 0.0

## Seconds until the next seed / next vine is allowed.
var _fire_cooldown_left: float = 0.0
var _vine_cooldown_left: float = 0.0
## Centre of the tree the vine is attached to (only meaningful while zipping).
var _vine_anchor: Vector2 = Vector2.ZERO
## The tree the latest zip was aimed at. The arena reads it when the zip ends
## (a zip to a great sunroot sets off its Sunburst).
var zip_tree: ForestTree
## Where Seven stood when the latest zip started (for the Trellis).
var zip_from: Vector2 = Vector2.ZERO

## @onready fills these in just before _ready, once the child nodes exist.
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _sprite: Sprite2D = $Sprite2D


## _ready runs once when the player enters the scene: size the hit circle and the
## placeholder sprite from the config.
func _ready() -> void:
	hp = max_hp
	(_collision.shape as CircleShape2D).radius = CONFIG.player_radius_cells * CONFIG.cell_size
	_sprite.texture = CONFIG.player_texture
	if CONFIG.player_facings_texture != null:
		# A strip of facings: the Sprite2D cuts it into equal frames (hframes), and
		# _update_aim picks the frame that points the way Seven is aiming.
		_sprite.texture = CONFIG.player_facings_texture
		_sprite.hframes = CONFIG.player_facing_count
		_sprite.frame = facing_frame(Vector2.DOWN, CONFIG.player_facing_count)
	if _sprite.texture != null:
		var wanted_px: float = CONFIG.sprite_size_cells * CONFIG.cell_size
		# One frame's width, not the whole strip's.
		var frame_width: float = float(_sprite.texture.get_width()) / float(_sprite.hframes)
		_sprite.scale = Vector2.ONE * (wanted_px / frame_width)
	_sprite_base_scale = _sprite.scale
	# The nozzle must show in front of the sprite. A node's own _draw is painted
	# behind its children, so the nozzle gets a child node of its own, with a
	# higher z_index, and we connect its `draw` signal to our drawing function.
	_aim_overlay = Node2D.new()
	_aim_overlay.z_index = 1
	add_child(_aim_overlay)
	_aim_overlay.draw.connect(_draw_bramble_preview)  # under the nozzle: connected first, drawn first
	_aim_overlay.draw.connect(_draw_nozzle)
	_aim_overlay.draw.connect(_draw_hurt_arc)  # a signal can call several functions
	_aim_overlay.draw.connect(_draw_wear)
	_aim_overlay.draw.connect(_draw_fuse_shield)
	_aim_overlay.draw.connect(_draw_reload)


## _physics_process runs 60 times per second: cooldowns, aiming, walking, firing.
func _physics_process(delta: float) -> void:
	_fire_cooldown_left = maxf(_fire_cooldown_left - delta, 0.0)
	_vine_cooldown_left = maxf(_vine_cooldown_left - delta, 0.0)
	_lash_time_left = maxf(_lash_time_left - delta, 0.0)
	_knockout_left = maxf(_knockout_left - delta, 0.0)
	_fuse_flash_left = maxf(_fuse_flash_left - delta, 0.0)
	fuse_shield_left = maxf(fuse_shield_left - delta, 0.0)
	hurt_arc_left = maxf(hurt_arc_left - delta, 0.0)
	_update_hit_blink(delta)
	_tick_brambles(delta)
	_tick_reload(delta)
	if is_dead:
		return  # a downed bot does nothing until the arena restarts
	if locked:
		velocity = Vector2.ZERO
		return  # the upgrade cards are up: stand still
	_update_aim()
	_update_aim_line()

	if not is_zipping:
		# get_vector reads the four move actions and returns a direction of length
		# 0 (no keys) or 1 (any keys), so diagonals are not faster than straights.
		var input_direction: Vector2 = Input.get_vector(
			&"move_left", &"move_right", &"move_up", &"move_down"
		)
		velocity = input_direction * CONFIG.player_speed
		move_and_slide()  # moves by `velocity` and slides along walls and trees

	# `a if condition else b` picks one of two values. On touch the "fire" action
	# is ignored, because Godot presses it for every finger that lands (see the
	# note about the fake mouse in touch_controls.gd).
	var wants_fire: bool = touch_fire_held if touch_mode else Input.is_action_pressed(&"fire")
	if wants_fire:
		fire(aim_direction)


## _process runs every drawn frame: keep the reticle and vine line up to date.
func _process(_delta: float) -> void:
	queue_redraw()
	_aim_overlay.queue_redraw()


## _unhandled_input receives input events that no UI element used. The vine is a
## single press (not a hold), so it is handled here as an event.
func _unhandled_input(event: InputEvent) -> void:
	if locked:
		return
	if event.is_action_pressed(&"bramble"):
		throw_bramble()
	if event.is_action_pressed(&"reload"):
		start_reload()
	if event.is_action_pressed(&"vine"):
		try_vine(get_global_mouse_position())


## _draw paints, in order: the vine (while zipping), the fallback body square (only
## if there is no sprite), and the aiming reticle at the mouse pointer.
func _draw() -> void:
	_draw_knockout_sparks()
	_draw_fuse_flash()
	if is_resting:
		# Grove rest: a soft green glow that breathes in and out. It is drawn here,
		# before the sprite (a child node), so it sits behind Seven like a halo.
		# sin() swings between -1 and 1; this turns it into 0.75 to 1.0, about
		# once a second. Time.get_ticks_msec() is milliseconds since the game began.
		var breath: float = 0.875 + 0.125 * sin(float(Time.get_ticks_msec()) / 160.0)
		var radius: float = CONFIG.grove_rest_glow_radius_cells * CONFIG.cell_size * breath
		draw_circle(Vector2.ZERO, radius, CONFIG.grove_rest_glow_color)
		# A brighter rim (same colour, fully solid), so it reads against lit floor.
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(CONFIG.grove_rest_glow_color, 0.9), 2.0)
		# A thick arc that fills clockwise from 12 o'clock as the next pip gets nearer.
		draw_arc(Vector2.ZERO, radius + 5.0, -PI / 2.0, -PI / 2.0 + TAU * rest_progress, 32, CONFIG.grove_rest_text_color, 4.0)
	if rest_trees > 0:
		# Small words under Seven: how many trees are in reach, or that it is working.
		var words: String = CONFIG.grove_rest_working_text if is_resting else CONFIG.grove_rest_count_text % [rest_trees, CONFIG.grove_rest_trees]
		var shade: Color = CONFIG.grove_rest_text_color if is_resting else Color(CONFIG.grove_rest_text_color, 0.6)
		var at := Vector2(-80.0, CONFIG.cell_size * 1.15)
		draw_string_outline(ThemeDB.fallback_font, at, words, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 14, 4, Color(0.0, 0.0, 0.0, 0.85))
		draw_string(ThemeDB.fallback_font, at, words, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 14, shade)
		# While repairing, a small spanner-and-sprout icon sits just left of the words.
		if is_resting and CONFIG.repair_icon_texture != null:
			var words_width: float = ThemeDB.fallback_font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14).x
			var icon_px: float = CONFIG.repair_icon_px
			draw_texture_rect(CONFIG.repair_icon_texture, Rect2(Vector2(-words_width / 2.0 - icon_px - 4.0, at.y - icon_px + 3.0), Vector2.ONE * icon_px), false)
	if is_zipping:
		# to_local converts a world position into this node's own coordinates.
		draw_line(Vector2.ZERO, to_local(_vine_anchor), VINE_COLOR, 4.0)
	# The vine to a machine that was just lashed. is_instance_valid: it may have
	# been shot and deleted since.
	if _lash_time_left > 0.0 and is_instance_valid(_lash_target):
		draw_line(Vector2.ZERO, to_local(_lash_target.global_position), VINE_COLOR, 4.0)
	if CONFIG.player_texture == null:
		var size: float = CONFIG.player_radius_cells * CONFIG.cell_size * 2.0
		draw_rect(Rect2(-size / 2.0, -size / 2.0, size, size), FALLBACK_COLOR)
		draw_line(Vector2.ZERO, aim_direction * size * 0.8, FALLBACK_COLOR, 6.0)
	_draw_aim_line()
	# The reticle sits on the mouse pointer. On touch there is no pointer, so it
	# floats a fixed distance in front of the bot instead.
	var reticle: Vector2 = get_local_mouse_position()
	if touch_mode:
		reticle = aim_direction * CONFIG.touch_reticle_distance_cells * CONFIG.cell_size
	draw_arc(reticle, 9.0, 0.0, TAU, 24, RETICLE_COLOR, 2.0)
	draw_circle(reticle, 2.0, RETICLE_COLOR)


## Fires one seed pod along `direction` if the cooldown allows.
## Returns true if a pod was fired.
## Throws a Bramble Seed (the third seed type) toward the aim, if one is in hand.
## Seven does not make the patch: the arena hears bramble_thrown and grows it
## ("signal up"). Returns true if a seed was thrown.
func throw_bramble() -> bool:
	if is_dead or locked or bramble_charges <= 0:
		return false
	bramble_charges -= 1
	if bramble_recharge_left <= 0.0:
		bramble_recharge_left = CONFIG.bramble_recharge_seconds
	bramble_thrown.emit(bramble_landing_point())
	Sfx.play(&"grow")
	return true


## Where a Bramble Seed thrown right now would land: bramble_range_cells along
## the aim, kept on the floor (inside bramble_bounds). The arena's spawn_bramble
## clamps to the same floor, so what is drawn is where the patch grows.
func bramble_landing_point() -> Vector2:
	var spot: Vector2 = global_position + aim_direction * CONFIG.bramble_range_cells * CONFIG.cell_size
	if bramble_bounds.has_area():
		# Vector2.clamp(min, max) limits each of x and y to that range.
		spot = spot.clamp(bramble_bounds.position, bramble_bounds.end)
	return spot


## True while the landing ring should show: Seven is up and has a seed in hand.
func is_bramble_preview_shown() -> bool:
	return is_aim_shown() and bramble_charges > 0


## Draws a faint ring where the bramble would land, the size of the patch, while
## Seven has a seed to throw. (On a phone the seed is thrown by tapping its
## button, which gives no "held" state to show this on, so it is simply always
## shown there while a charge is in hand.)
func _draw_bramble_preview() -> void:
	if not is_bramble_preview_shown():
		return
	var centre: Vector2 = to_local(bramble_landing_point())
	var color: Color = Color(CONFIG.bramble_color.lightened(0.25), CONFIG.bramble_preview_alpha)
	_aim_overlay.draw_circle(centre, Bramble.radius_px(), Color(color, color.a / 3.0))
	_aim_overlay.draw_arc(centre, Bramble.radius_px(), 0.0, TAU, 40, color, 2.0)


## Grows Bramble Seeds back, one every bramble_recharge_seconds, up to the max.
func _tick_brambles(delta: float) -> void:
	if bramble_charges >= CONFIG.bramble_max_charges:
		bramble_recharge_left = 0.0
		return
	bramble_recharge_left -= delta
	if bramble_recharge_left <= 0.0:
		bramble_charges += 1
		if bramble_charges < CONFIG.bramble_max_charges:
			bramble_recharge_left = CONFIG.bramble_recharge_seconds


## Fires one seed pod along `direction`, if the cooldown allows. Returns true if fired.
## While reloading (or with an empty load) nothing fires. The last pod of a load
## starts the reload by itself.
func fire(direction: Vector2) -> bool:
	if is_dead or locked or _fire_cooldown_left > 0.0 or direction == Vector2.ZERO:
		return false
	if is_reloading() or seeds_in_clip <= 0:
		return false
	_fire_cooldown_left = CONFIG.seed_cooldown * fire_cooldown_scale
	seeds_in_clip -= 1
	if seeds_in_clip == 0:
		start_reload()
	var unit: Vector2 = direction.normalized()
	# Start the pod just outside our own hit circle, so it never begins inside us.
	var muzzle_distance: float = CONFIG.player_radius_cells * CONFIG.cell_size + CONFIG.seed_radius
	var muzzle: Vector2 = global_position + unit * muzzle_distance
	seed_fired.emit(muzzle, unit)
	Sfx.play(&"fire")
	return true


## True while a reload is under way.
func is_reloading() -> bool:
	return reload_left > 0.0


## Starts a reload: the R key, or the last pod of a load. Does nothing if one is
## already going, the load is full, or Seven is down. Returns true if it started.
func start_reload() -> bool:
	if is_dead or is_reloading() or seeds_in_clip >= CONFIG.seed_clip_size:
		return false
	# A reload time of 0 or less (too many cards) would never count down: refill now.
	if reload_seconds <= 0.0:
		refill_seeds()
		return true
	reload_left = reload_seconds
	reload_started.emit()
	return true


## Fills the load at once and stops any reload. The arena calls this at the start
## of every wave; revive() calls it too.
func refill_seeds() -> void:
	seeds_in_clip = CONFIG.seed_clip_size
	reload_left = 0.0


## Counts the reload down; when it reaches zero the load is full again. It keeps
## counting while the cards are up, which only matters if the wave start refill
## comes first (it always does).
func _tick_reload(delta: float) -> void:
	if not is_reloading():
		return
	reload_left = maxf(reload_left - delta, 0.0)
	if reload_left == 0.0:
		seeds_in_clip = CONFIG.seed_clip_size
		Sfx.play(&"reload")
		reloaded.emit()


## Paints the reload state on the overlay node: while reloading, a ring that fills
## clockwise from 12 o'clock; otherwise a row of small pips under Seven, one per
## pod, bright for the pods left and dim for the ones used.
func _draw_reload() -> void:
	if not is_aim_shown():
		return
	var cell_px: float = float(CONFIG.cell_size)
	if is_reloading():
		# 0 just after the reload starts, 1 when it is done.
		var done: float = 1.0 - reload_left / maxf(reload_seconds, 0.001)
		var radius: float = CONFIG.reload_ring_radius_cells * cell_px
		# A faint full circle first, so the player can see how far there is to go.
		_aim_overlay.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(CONFIG.reload_ring_color, 0.2), 4.0, true)
		_aim_overlay.draw_arc(Vector2.ZERO, radius, -PI / 2.0, -PI / 2.0 + TAU * done, 40, CONFIG.reload_ring_color, 4.0, true)
		return
	# The pips: centred under Seven, left to right. The leftmost ones are the full ones.
	var count: int = CONFIG.seed_clip_size
	var spacing: float = CONFIG.clip_pip_spacing
	var first_x: float = -spacing * float(count - 1) / 2.0
	var y: float = CONFIG.clip_pips_below_cells * cell_px
	for i: int in count:
		var at := Vector2(first_x + spacing * float(i), y)
		var full: bool = i < seeds_in_clip
		# A dark dot behind each pip, so the row reads on light and dark floor.
		_aim_overlay.draw_circle(at, 2.6, Color(0.0, 0.0, 0.0, 0.6))
		_aim_overlay.draw_circle(at, 1.8, CONFIG.clip_pip_color if full else CONFIG.clip_pip_empty_color)


## Tries to latch the vine onto the tree at `world_point` and zip to it.
## Returns true if a zip started; false means nothing happened (no tree there,
## out of range, a wall in the way, already next to it, or still cooling down).
## `pick_radius_cells` is how close `world_point` must be to a tree's centre. Leave
## it out to use the mouse value from the config; touch taps pass a bigger one.
func try_vine(world_point: Vector2, pick_radius_cells: float = -1.0) -> bool:
	if is_dead or locked or is_zipping or _vine_cooldown_left > 0.0:
		return false
	# -1.0 is the "not given" marker (a radius can never really be negative).
	if pick_radius_cells < 0.0:
		pick_radius_cells = CONFIG.vine_pick_radius_cells
	var pick_radius: float = pick_radius_cells * CONFIG.cell_size

	# A machine under the pointer comes first: yank it over and tie it up. Only
	# with Lucky's clamp; before that, the vine is for zipping to trees.
	if can_bind:
		var enemy: Enemy = _pick_enemy(world_point, pick_radius)
		if enemy != null and _lash_enemy(enemy):
			return true

	var picked: ForestTree = _pick_tree(world_point, pick_radius)
	if picked == null:
		return false  # right click on empty space: do nothing

	# Shoot an invisible ray at the tree. Whatever solid thing it meets first is
	# what the vine really grabs: a nearer tree is fine, a wall means no latch.
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var ray := PhysicsRayQueryParameters2D.create(global_position, picked.global_position, WORLD_MASK)
	var hit: Dictionary = space.intersect_ray(ray)
	if hit.is_empty():
		return false
	var latched := hit["collider"] as ForestTree
	if latched == null:
		return false
	if global_position.distance_to(latched.global_position) > CONFIG.vine_range:
		return false
	return _start_zip(latched)


## Takes `amount` hit points away. Returns true if the hit counted, false if it
## was ignored (already down, or still blinking from the previous hit).
## `from` is where the hit came from in world pixels, so Seven can show it; it
## is optional (`= Vector2.INF` is the value used when the caller leaves it out).
func take_damage(amount: int, from: Vector2 = Vector2.INF) -> bool:
	if is_dead or _invulnerable_left > 0.0 or amount <= 0:
		return false
	hp = maxi(hp - amount, 0)  # maxi = the larger of two whole numbers: never below 0
	hurt_from = from
	hurt_arc_left = CONFIG.hurt_arc_seconds
	hurt.emit()
	if hp == 0 and has_fuse:
		# The spare fuse blows instead of Seven: back up, with a long blink.
		has_fuse = false
		hp = CONFIG.fuse_revive_hp
		_invulnerable_left = CONFIG.fuse_invulnerable_time
		fuse_shield_left = CONFIG.fuse_invulnerable_time
		_play_fuse_flash()
		health_changed.emit(hp, max_hp)
		Sfx.play(&"cat")
		fuse_used.emit()
		return true
	health_changed.emit(hp, max_hp)
	if hp == 0:
		is_dead = true
		velocity = Vector2.ZERO
		_play_knockout()  # tips over and greys out (see below)
		Sfx.play(&"player_down")
		died.emit()
		return true
	_invulnerable_left = CONFIG.player_hit_invulnerable_time
	Sfx.play(&"hurt")
	return true


## Brings a downed bot back at full health at `world_position`. Called by the
## arena when a wave restarts. The short blink gives a moment of safety.
## `start_hp` (optional) is the health to come back with; 0 or less, or leaving
## it out, means full health. The arena passes the health Seven had when the
## wave first began, so dying is not a free repair.
func revive(world_position: Vector2, start_hp: int = 0) -> void:
	global_position = world_position
	velocity = Vector2.ZERO
	# clampi keeps a whole number between two bounds: at least 1 pip, at most all.
	hp = max_hp if start_hp <= 0 else clampi(start_hp, 1, max_hp)
	is_dead = false
	is_zipping = false
	bramble_charges = CONFIG.bramble_max_charges  # a fresh start refills the seeds
	bramble_recharge_left = 0.0
	refill_seeds()  # ...and a full load of seed pods
	modulate = Color.WHITE
	fuse_shield_left = 0.0
	_reset_body()  # stand the picture back up after the knock-out
	_invulnerable_left = CONFIG.player_hit_invulnerable_time
	# The spare fuse is NOT refitted: Lucky gives one, and it saves Seven once
	# per run (until s18 round 4 every restarted wave fitted a new one).
	health_changed.emit(hp, max_hp)


## Gives back up to `amount` hit points, never above the maximum. (A tap tree does this.)
func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	hp = mini(hp + amount, max_hp)  # mini = the smaller of two whole numbers
	health_changed.emit(hp, max_hp)


## True while the knock-out animation is playing. Public for the tests.
func is_knockout_playing() -> bool:
	return _knockout_left > 0.0


## True while the fuse-revive animation is playing. Public for the tests.
func is_fuse_flash_playing() -> bool:
	return _fuse_flash_left > 0.0


## Stops any body animation and puts the picture back: upright, normal size,
## in the middle, normal colours.
func _reset_body() -> void:
	if _body_tween != null and _body_tween.is_valid():
		_body_tween.kill()  # kill stops a Tween for good
	_knockout_left = 0.0
	_sprite.rotation = 0.0
	_sprite.position = Vector2.ZERO
	_sprite.scale = _sprite_base_scale
	_sprite.self_modulate = Color.WHITE


## KNOCK-OUT: Seven jolts up, tips over sideways and settles on the ground while
## fading to grey. A Tween plays the steps in order; set_parallel(true) makes
## the steps that follow run at the same time instead of one after another.
func _play_knockout() -> void:
	_reset_body()
	_knockout_left = CONFIG.knockout_seconds
	var total: float = CONFIG.knockout_seconds
	# Fall away from the way Seven was facing: +1 tips right, -1 tips left.
	var side: float = -1.0 if aim_direction.x < 0.0 else 1.0
	_body_tween = create_tween()
	# 1. The jolt: a quick hop up and a swell, like a shock going through.
	_body_tween.set_parallel(true)
	_body_tween.tween_property(_sprite, "position", Vector2(0.0, -12.0), total * 0.15)
	_body_tween.tween_property(_sprite, "scale", _sprite_base_scale * 1.2, total * 0.15)
	# 2. The fall: a quarter turn onto its side, landing with a small bounce
	#    (TRANS_BOUNCE), back to normal size, and the colour drains to grey.
	_body_tween.chain().set_parallel(true)  # chain() = "after the steps above"
	_body_tween.tween_property(_sprite, "rotation", side * PI / 2.0, total * 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_body_tween.tween_property(_sprite, "position", Vector2(0.0, 10.0), total * 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_body_tween.tween_property(_sprite, "scale", _sprite_base_scale, total * 0.3)
	_body_tween.tween_property(self, "modulate", Color(0.45, 0.45, 0.45, 0.8), total * 0.85)


## FUSE REVIVE: the opposite feeling. The picture flashes gold and pops up big,
## then springs back to normal (TRANS_BACK overshoots a little, like a spring).
func _play_fuse_flash() -> void:
	_reset_body()
	_fuse_flash_left = CONFIG.fuse_flash_seconds
	_sprite.scale = _sprite_base_scale * 1.6
	_sprite.self_modulate = CONFIG.fuse_flash_color
	_body_tween = create_tween().set_parallel(true)
	_body_tween.tween_property(_sprite, "scale", _sprite_base_scale, CONFIG.fuse_flash_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_body_tween.tween_property(_sprite, "self_modulate", Color.WHITE, CONFIG.fuse_flash_seconds)


## Sparks thrown out by the knock-out: eight short streaks flying outward and
## fading. Called from _draw.
func _draw_knockout_sparks() -> void:
	if _knockout_left <= 0.0:
		return
	var done: float = 1.0 - _knockout_left / CONFIG.knockout_seconds  # 0 at the start, 1 at the end
	var color := Color(CONFIG.knockout_spark_color, 1.0 - done)
	for i: int in 8:
		# Eight directions, evenly round the circle, each a slightly different length.
		var direction: Vector2 = Vector2.from_angle(TAU * float(i) / 8.0 + 0.3)
		var reach: float = CONFIG.cell_size * (0.5 + 1.1 * done) * (0.8 + 0.1 * float(i % 3))
		draw_line(direction * reach, direction * (reach + 9.0), color, 3.0)


## The fuse blowing: two gold rings bursting outward (the second a beat behind
## the first) and a zigzag lightning bolt above Seven. Called from _draw.
func _draw_fuse_flash() -> void:
	if _fuse_flash_left <= 0.0:
		return
	var done: float = 1.0 - _fuse_flash_left / CONFIG.fuse_flash_seconds
	var cell_px: float = float(CONFIG.cell_size)
	for delay: float in [0.0, 0.25]:
		# Each ring has its own 0-to-1 clock, started `delay` late.
		var ring_done: float = clampf((done - delay) / (1.0 - delay), 0.0, 1.0)
		if ring_done > 0.0:
			draw_arc(Vector2.ZERO, cell_px * lerpf(0.4, 1.8, ring_done), 0.0, TAU, 48, Color(CONFIG.fuse_flash_color, 1.0 - ring_done), 5.0)
	# The bolt: a fixed zigzag of points, drawn as one bent line that fades out.
	var bolt := PackedVector2Array([
		Vector2(6.0, -cell_px * 1.9), Vector2(-8.0, -cell_px * 1.35),
		Vector2(5.0, -cell_px * 1.25), Vector2(-6.0, -cell_px * 0.7),
	])
	draw_polyline(bolt, Color(CONFIG.fuse_flash_color, 1.0 - done), 4.0)


## Puts Seven at `world_position` and locks it there (the upgrade cards are up).
## Any vine zip in progress is stopped first, or it would drag Seven away again.
func park(world_position: Vector2) -> void:
	if _zip_tween != null and _zip_tween.is_valid():
		_zip_tween.kill()  # kill stops a Tween for good
	is_zipping = false
	velocity = Vector2.ZERO
	global_position = world_position
	locked = true


## Raises the maximum by up to `amount`, never past the config's player_hp_cap.
## The NEW pips arrive filled; damage Seven already had stays. Returns how many
## pips were really added. (No upgrade uses this since s18, when Thick Plating
## became the Patch Kit; it is kept for the tests and for a later upgrade.)
func add_plating(amount: int) -> int:
	# clampi keeps a whole number between two bounds: here 0 and the room left under the cap.
	var added: int = clampi(amount, 0, CONFIG.player_hp_cap - max_hp)
	max_hp += added
	if not is_dead:
		hp += added
	health_changed.emit(hp, max_hp)
	return added


## Lucky's gift: the clamp (bind machines with the vine) and a spare fuse.
func receive_cat_gift() -> void:
	can_bind = true
	has_fuse_slot = true
	has_fuse = true


## How battered Seven looks, 0 (fine) to 3 (about to go down). It follows the
## share of health left, so it still works after health upgrades.
func wear_level() -> int:
	if is_dead or hp >= max_hp:
		return 0
	if hp <= 1:
		return 3
	var share: float = float(hp) / float(maxi(max_hp, 1))
	if share <= CONFIG.wear_battered_share:
		return 2
	if share <= CONFIG.wear_dented_share:
		return 1
	return 0


## Paints Seven's wear and tear on the overlay node (in front of the sprite):
## scorch marks, sparks, smoke, and on the last pip a red warning light.
## Everything here is drawn from the clock, so nothing needs remembering:
## `tick` is a whole number that steps up several times a second, and feeding
## it to sin() gives "random-looking" places that hold still between steps.
func _draw_wear() -> void:
	var level: int = wear_level()
	if level == 0:
		return
	var cell_px: float = float(CONFIG.cell_size)
	var seconds: float = float(Time.get_ticks_msec()) / 1000.0
	# SCORCH: two dark blotches per level, always in the same places on the body.
	var scorch_spots: Array[Vector2] = [
		Vector2(-0.16, -0.10), Vector2(0.14, 0.12), Vector2(0.10, -0.20),
		Vector2(-0.12, 0.18), Vector2(0.20, -0.02), Vector2(-0.22, 0.04),
	]
	for i: int in level * 2:
		_aim_overlay.draw_circle(scorch_spots[i] * cell_px, 3.0 + float(i % 3), CONFIG.wear_scorch_color)
	# SPARKS: a few short bright streaks jumping off the body. Level 1 sparks
	# only now and then (one tick in three), level 2 most of the time, level 3 always.
	var tick: float = floorf(seconds * 9.0)
	var sparking: bool = level >= 3 or (level == 2 and int(tick) % 3 != 0) or (level == 1 and int(tick) % 3 == 0)
	if sparking:
		for i: int in level + 1:
			var angle: float = tick * 2.4 + float(i) * 2.1
			var from: Vector2 = Vector2.from_angle(angle) * cell_px * 0.22
			var to: Vector2 = from + Vector2.from_angle(angle + sin(tick + float(i)) * 0.8) * (6.0 + 4.0 * float(level))
			_aim_overlay.draw_line(from, to, CONFIG.wear_spark_color, 2.0)
			_aim_overlay.draw_circle(to, 1.5, CONFIG.wear_spark_color)
	# SMOKE (level 2 and up): two grey puffs rising and fading, over and over.
	# fmod(x, 1.0) is the part of x after the decimal point: it runs 0 to 1 again and again.
	if level >= 2:
		for i: int in 2:
			var rise: float = fmod(seconds * 0.7 + float(i) * 0.5, 1.0)
			var puff := Vector2((float(i) - 0.5) * 12.0 + sin(seconds * 2.0 + float(i)) * 3.0, -cell_px * (0.35 + 0.6 * rise))
			_aim_overlay.draw_circle(puff, 4.0 + 5.0 * rise, Color(CONFIG.wear_smoke_color, CONFIG.wear_smoke_color.a * (1.0 - rise)))
	# WARNING LIGHT (level 3): a small red lamp on Seven that blinks fast.
	if level >= 3 and fmod(seconds * 3.0, 1.0) < 0.5:
		_aim_overlay.draw_circle(Vector2(0.0, -cell_px * 0.42), 4.0, CONFIG.wear_warning_color)


## Paints the gold shield the spare fuse gives Seven: a bubble that is solid at
## first and fades away as the "cannot be hurt" time runs out, so the player
## can see exactly how long the second wind lasts.
func _draw_fuse_shield() -> void:
	if fuse_shield_left <= 0.0 or is_dead:
		return
	var left: float = fuse_shield_left / CONFIG.fuse_invulnerable_time  # 1 at the start, 0 when over
	var radius: float = float(CONFIG.cell_size) * 0.78
	var color: Color = CONFIG.fuse_shield_color
	_aim_overlay.draw_circle(Vector2.ZERO, radius, Color(color, 0.14 * left))
	_aim_overlay.draw_arc(Vector2.ZERO, radius - 4.0, 0.0, TAU, 40, Color(color, 0.25 * left), 3.0, true)
	# The rim shortens like a clock hand running down: what is left of the shield.
	_aim_overlay.draw_arc(Vector2.ZERO, radius, -PI / 2.0, -PI / 2.0 + TAU * left, 48, Color(color, 0.4 + 0.5 * left), 3.0, true)


## Paints the red arc that shows what just hurt Seven: a quarter circle on the
## side the hit came from, fading out. With no known source it is a full ring.
## Drawn on the overlay node, so it sits in front of the sprite.
func _draw_hurt_arc() -> void:
	if hurt_arc_left <= 0.0:
		return
	var left: float = hurt_arc_left / CONFIG.hurt_arc_seconds  # 1 at the hit, 0 when over
	var color := Color(CONFIG.hurt_arc_color, left)
	var radius: float = float(CONFIG.cell_size) * 0.85
	if hurt_from == Vector2.INF:
		_aim_overlay.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color, 4.0)
		return
	# angle() is the direction of a vector in radians; the arc spans an eighth of
	# a turn (PI / 4) to each side of it.
	var toward: float = (hurt_from - global_position).angle()
	_aim_overlay.draw_arc(Vector2.ZERO, radius, toward - PI / 4.0, toward + PI / 4.0, 16, color, 8.0)
	# A red beam from the arc out toward the attacker, ending in an arrowhead, so
	# it is plain which way the hit came from. It shortens as it fades.
	var out: Vector2 = Vector2.from_angle(toward)
	var tip: Vector2 = out * (radius + CONFIG.hurt_beam_cells * float(CONFIG.cell_size) * left)
	_aim_overlay.draw_line(out * radius, tip, color, 5.0)
	# orthogonal() is the same vector turned a quarter turn: the arrowhead's width.
	var side: Vector2 = out.orthogonal() * 9.0
	_aim_overlay.draw_colored_polygon(PackedVector2Array([tip + out * 14.0, tip + side, tip - side]), color)


## Counts down the "cannot be hurt" time and blinks the bot while it lasts.
func _update_hit_blink(delta: float) -> void:
	if is_dead or _invulnerable_left <= 0.0:
		return
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	if _invulnerable_left == 0.0:
		modulate = Color.WHITE  # white = fully visible, no tint
		return
	# Flip between faint and solid about eight times a second. fmod is the
	# remainder after division, so this repeats every 0.12 s.
	var is_faint: bool = fmod(_invulnerable_left, 0.12) < 0.06
	modulate = Color(1.0, 1.0, 1.0, 0.35 if is_faint else 1.0)


## Makes the sprite (and aim_direction) point at the mouse. On touch, the aim
## thumb-stick has already written aim_direction, so only the sprite is turned.
func _update_aim() -> void:
	if not touch_mode:
		var to_mouse: Vector2 = get_global_mouse_position() - global_position
		if to_mouse.length() > 1.0:
			aim_direction = to_mouse.normalized()
	# With the facings strip (tools/seven_facings.py) Seven is drawn turned to each of
	# eight ways, so we just pick the frame that matches the aim. No mirroring, no
	# lean: the turn is in the picture.
	if _sprite.hframes > 1:
		_sprite.frame = facing_frame(aim_direction, _sprite.hframes)
		_sprite.rotation = 0.0
		return
	# Without it, Seven stands facing the viewer (the locked design,
	# tools/seven_sprite.py) and does not spin round: it turns to look left or right
	# with the aim. flip_h mirrors the picture; the drawing holds its seedling on the right.
	if absf(aim_direction.x) > 0.1:
		_sprite.flip_h = aim_direction.x < 0.0
	# ...and it leans a little toward the aim: forward-and-down when aiming down,
	# back-and-up when aiming up. The sign flips with the facing so the lean
	# always tips the head toward the target.
	var facing: float = -1.0 if _sprite.flip_h else 1.0
	_sprite.rotation = aim_direction.y * CONFIG.aim_lean_radians * facing


## Which frame of a facings strip points along `direction`. Frames are evenly spaced
## round the compass starting at East (angle 0) and going clockwise on screen, which
## is the way Godot's angles count (y points down), so South = down the screen = 2.
## roundi() picks the nearest frame; posmod() wraps a negative angle (up the screen)
## round to the end of the strip. `static`: needs no Player to exist. Public for tests.
static func facing_frame(direction: Vector2, frames: int) -> int:
	return posmod(roundi(direction.angle() / (TAU / float(frames))), frames)


## True while the aim line and nozzle should show: not when down, and not while
## the upgrade cards have Seven locked.
func is_aim_shown() -> bool:
	return not is_dead and not locked


## Finds where the aim line stops: an invisible ray along the aim that only
## looks at walls and trees. Called from _physics_process, where ray queries
## are allowed.
func _update_aim_line() -> void:
	var reach: Vector2 = global_position + aim_direction * CONFIG.aim_line_cells * CONFIG.cell_size
	var ray := PhysicsRayQueryParameters2D.create(global_position, reach, WORLD_MASK)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
	# An empty Dictionary means the ray met nothing: the line runs its full reach.
	aim_line_end = reach if hit.is_empty() else hit["position"]


## Draws the aim line: ten short pieces from Seven's edge to aim_line_end, each
## fainter than the last, so it reads as a beam that fades with distance. A
## small dot marks where it stops. Called from _draw.
func _draw_aim_line() -> void:
	if not is_aim_shown():
		return
	var start: Vector2 = aim_direction * (CONFIG.player_radius_cells * CONFIG.cell_size + 6.0)
	var end: Vector2 = to_local(aim_line_end)
	if end.length() <= start.length():
		return  # standing right against a wall: nothing to draw
	var pieces: int = 10
	for i: int in pieces:
		# lerp(a, b, t) is the point a share t of the way from a to b.
		var from: Vector2 = start.lerp(end, float(i) / float(pieces))
		var to: Vector2 = start.lerp(end, float(i + 1) / float(pieces))
		var fade: float = 1.0 - 0.75 * float(i) / float(pieces)
		draw_line(from, to, Color(CONFIG.aim_line_color, CONFIG.aim_line_color.a * fade), CONFIG.aim_line_width)
	draw_circle(end, 3.0, Color(CONFIG.aim_line_color, 0.8))


## Draws the nozzle on the overlay node: a short thick barrel pointing along the
## aim, so Seven visibly points where it shoots. (Every draw call starts with
## "_aim_overlay." because we are painting on that node, above the sprite.)
func _draw_nozzle() -> void:
	if not is_aim_shown():
		return
	var base: Vector2 = aim_direction * (CONFIG.player_radius_cells * CONFIG.cell_size - 4.0)
	var tip: Vector2 = base + aim_direction * CONFIG.aim_nozzle_length
	_aim_overlay.draw_line(base, tip, Color(0.05, 0.07, 0.09), 8.0)  # dark outline
	_aim_overlay.draw_line(base, tip, CONFIG.aim_nozzle_color, 4.0)
	_aim_overlay.draw_circle(tip, 3.0, CONFIG.aim_line_color)


## Returns the machine nearest to `world_point`, if one is within `pick_radius`
## pixels; otherwise null.
func _pick_enemy(world_point: Vector2, pick_radius: float) -> Enemy:
	var best: Enemy = null
	var best_distance: float = pick_radius
	# Every machine adds itself to the "enemies" group.
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead:
			continue
		var distance: float = enemy.global_position.distance_to(world_point)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


## The vine's second use: lash a machine, drag it towards the bot and bind it.
## Returns false (nothing happens) if it is out of range or behind a wall or tree.
func _lash_enemy(enemy: Enemy) -> bool:
	if global_position.distance_to(enemy.global_position) > CONFIG.vine_range:
		return false
	# The vine needs a clear line: a ray that only looks at walls and trees must
	# reach the machine without touching anything.
	var ray := PhysicsRayQueryParameters2D.create(global_position, enemy.global_position, WORLD_MASK)
	if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		return false
	enemy.yank_and_bind(global_position, CONFIG.vine_yank_stop_cells * CONFIG.cell_size, CONFIG.vine_bind_time)
	_vine_cooldown_left = CONFIG.vine_cooldown
	# Remember it for a moment so _draw can show the vine reaching out.
	_lash_target = enemy
	_lash_time_left = LASH_SHOW_SECONDS
	Sfx.play(&"bind")
	return true


## Returns the grown tree nearest to `world_point`, if one is within
## `pick_radius` pixels; otherwise null.
func _pick_tree(world_point: Vector2, pick_radius: float) -> ForestTree:
	var best: ForestTree = null
	var best_distance: float = pick_radius
	# Every tree adds itself to the "trees" group, so this loop sees all of them.
	for node: Node in get_tree().get_nodes_in_group(ForestTree.GROUP):
		var tree := node as ForestTree
		if tree == null or tree.stage != ForestTree.Stage.GROWN:
			continue
		var distance: float = tree.global_position.distance_to(world_point)
		if distance <= best_distance:
			best = tree
			best_distance = distance
	return best


## Starts the straight-line zip towards `tree`. Returns false if there is nowhere to go.
func _start_zip(tree: ForestTree) -> bool:
	var to_tree: Vector2 = tree.global_position - global_position
	var distance: float = to_tree.length()
	var stop_short: float = CONFIG.vine_stop_short_cells * CONFIG.cell_size
	if distance <= stop_short + 1.0:
		return false  # already as close as the vine would bring us

	# The full move we would like to make: towards the tree, stopping one cell short.
	var motion: Vector2 = (to_tree / distance) * (distance - stop_short)

	# The tween below moves us without collision checks, so we check first: sweep
	# our own hit circle along the line and see how far it gets before touching
	# anything solid. cast_motion answers with fractions of the motion (0.0 to 1.0);
	# the first one is the furthest SAFE fraction.
	var sweep := PhysicsShapeQueryParameters2D.new()
	sweep.shape = _collision.shape
	sweep.transform = Transform2D(0.0, global_position)
	sweep.motion = motion
	sweep.collision_mask = WORLD_MASK
	var fractions: PackedFloat32Array = get_world_2d().direct_space_state.cast_motion(sweep)
	var safe_fraction: float = fractions[0] if fractions.size() > 0 else 1.0
	var travel: Vector2 = motion * safe_fraction
	if travel.length() < 4.0:
		return false  # blocked almost immediately: not worth a zip

	is_zipping = true
	velocity = Vector2.ZERO
	_vine_anchor = tree.global_position
	zip_tree = tree
	zip_from = global_position
	Sfx.play(&"zip")

	# A Tween animates a property over time. This one slides global_position to the
	# destination; the duration comes from distance / speed.
	var tween: Tween = create_tween()
	_zip_tween = tween
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)  # step in time with physics
	tween.tween_property(
		self, "global_position", global_position + travel, travel.length() / CONFIG.vine_zip_speed
	)
	tween.finished.connect(_on_zip_tween_finished)
	return true


## Runs when the zip tween ends: unlock walking and start the vine cooldown.
func _on_zip_tween_finished() -> void:
	is_zipping = false
	_vine_cooldown_left = CONFIG.vine_cooldown
	zip_finished.emit()
