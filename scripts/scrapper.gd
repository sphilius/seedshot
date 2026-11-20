# scrapper.gd - the baseline enemy: walks at the player around trees, swings at
# melee range, dies in one pod. Health, dying and path-walking come from enemy.gd.
class_name Scrapper
extends Enemy
## A rogue machine that rushes the player.
##
## HOW IT FINDS ITS WAY: a few times per second it asks the ArenaGrid for a path
## (a list of cells) from its own cell to the player's cell, then walks from cell
## centre to cell centre. Because the path is recalculated on a timer, it reacts
## when a new tree grows or the player moves.

## Emitted when a melee swing lands. The Scrapper does not touch the player's
## health itself: the arena connects this to the player ("signal up").
signal struck(damage: int)

const FALLBACK_COLOR: Color = Color(0.72, 0.42, 0.25)
## The Scrapper is tinted this colour during the windup. Values above 1.0 brighten.
## Red is the one colour reserved for "an enemy is about to hurt you".
const WINDUP_TINT: Color = Color(1.9, 0.55, 0.45)

## True from the start of a swing's warning glow until the hit lands or misses.
## Public (no underscore) so the tests can watch it.
var is_winding_up: bool = false

## The node to chase. Handed in by chase().
var _target: Node2D
## Seconds left in the current windup / until the next swing is allowed.
var _windup_time_left: float = 0.0
var _melee_cooldown_left: float = 0.0


## True for a LINEBREAKER: Helios's heavy repo unit, from wave 6. Same brain as a
## Scrapper, but big, slow, armoured (more hit points) and hits for more. Set by
## the arena before the machine is added to the scene.
var heavy: bool = false


## _ready runs once when the Scrapper enters the scene.
func _ready() -> void:
	var start_hp: int = CONFIG.linebreaker_hp if heavy else CONFIG.scrapper_hp
	_configure_body(start_hp, CONFIG.scrapper_radius_cells, CONFIG.scrapper_texture, FALLBACK_COLOR)
	if heavy:
		# Scaling the whole node makes the picture AND the hit circle bigger.
		scale = Vector2.ONE * CONFIG.linebreaker_scale
		# self_modulate tints only this node's own drawing; the sprite is a child,
		# so tint it directly. (modulate is kept free for the windup's red glow.)
		_sprite.self_modulate = CONFIG.linebreaker_tint


## Overrides Enemy._shield_color: a Linebreaker has a gold force field (drawn by
## Enemy._draw_shield). Its bright rim is the share of hit points left, so the
## player can see the pods working. A plain Scrapper has none.
func _shield_color() -> Color:
	return CONFIG.linebreaker_ring_color if heavy else Color(0.0, 0.0, 0.0, 0.0)


## How fast this machine walks, in pixels per second.
func _speed() -> float:
	return CONFIG.scrapper_speed * (CONFIG.linebreaker_speed_factor if heavy else 1.0)


## Called by the arena: which node to run at ("call down").
func chase(target: Node2D) -> void:
	_target = target


## _physics_process runs 60 times per second: refresh the route on a timer, deal
## with the melee swing, then take one step.
func _physics_process(delta: float) -> void:
	# is_instance_valid guards against the target having been deleted.
	if _grid == null or not is_instance_valid(_target):
		return
	if _tick_bound(delta):
		return  # tied up by the vine: do nothing this step
	if _repath_due(delta, CONFIG.scrapper_repath_interval):
		_path_to(_grid.world_to_cell(_target.global_position))

	var distance: float = global_position.distance_to(_target.global_position)
	_update_melee(delta, distance)
	# A Scrapper commits to its swing: it stands still while winding up. It also
	# stands still once it is close enough that walking further would only shove.
	if is_winding_up or distance <= CONFIG.scrapper_stop_distance_cells * CONFIG.cell_size:
		velocity = Vector2.ZERO
		return
	_walk_towards(_next_goal(_target.global_position), _speed())


## Overrides Enemy._on_bound: being tied up cancels a swing that was winding up.
func _on_bound() -> void:
	is_winding_up = false


## The melee attack, one step at a time. `distance` is how far the target is.
##   1. Target in range and the cooldown is over: start the windup (red glow).
##   2. Windup ends: if the target is STILL in range the swing lands (emit
##      `struck`); if it got away, the swing misses. Either way, cool down.
## The windup is the player's chance to react, which is what makes the hit fair.
func _update_melee(delta: float, distance: float) -> void:
	var in_range: bool = distance <= CONFIG.scrapper_melee_range_cells * CONFIG.cell_size
	_melee_cooldown_left = maxf(_melee_cooldown_left - delta, 0.0)

	if not is_winding_up:
		if in_range and _melee_cooldown_left <= 0.0:
			is_winding_up = true
			_windup_time_left = CONFIG.scrapper_melee_windup
			modulate = WINDUP_TINT  # tints this node and everything it draws
			Sfx.play(&"windup")
		return

	_windup_time_left -= delta
	if _windup_time_left > 0.0:
		return
	# The windup just ended: resolve the swing.
	is_winding_up = false
	_melee_cooldown_left = CONFIG.scrapper_melee_cooldown
	modulate = Color.WHITE  # white = "no tint"
	if in_range:
		struck.emit(CONFIG.linebreaker_damage if heavy else CONFIG.scrapper_melee_damage)
