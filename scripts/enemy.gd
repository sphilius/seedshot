# enemy.gd - what every rogue machine has in common: hit points, dying (the arena
# then plants a tree where it fell), and walking a route over the arena grid.
# Scrapper and Sawbot both start with `extends Enemy`, so they get all of this
# for free and only add what makes them different.
class_name Enemy
extends CharacterBody2D
## Base class for the rogue machines.
##
## "extends" is inheritance: a Scrapper IS an Enemy, with extra behaviour on top.
## Anything written here (take_damage, the path helpers) exists on every machine,
## and code that only cares about "some enemy" (the seed pod, the wave director)
## can use the type Enemy without knowing which kind it has.
##
## Each enemy scene puts its body on physics layer 3, "enemies", and it collides
## with layer 1, "world" (walls and grown trees).

## Emitted once, when HP reaches zero. The arena plants a sapling where it fell.
signal died(enemy: Enemy)
## Emitted the moment a machine that dropped in hits the floor (see drop_in).
## The arena answers with a screen shake and the crash sound.
signal landed(enemy: Enemy)

const CONFIG: GameConfig = preload("res://config/game_config.tres")
## Group that every machine joins, so code can ask the scene tree for "all enemies".
const GROUP: StringName = &"enemies"
## How close (pixels) to a cell centre counts as "arrived at this waypoint".
const WAYPOINT_REACHED_DISTANCE: float = 5.0

## Tint while tied up by the vine (values above 1.0 brighten): leafy green.
const BOUND_TINT: Color = Color(0.6, 1.5, 0.6)
## Physics layer 1 ("world") as a bit mask, for the yank's safety sweep.
const WORLD_BODY_MASK: int = 1

## Multiplies walking speed. 1.0 is normal; later waves send faster machines.
var speed_scale: float = 1.0
## True while the player's vine has this machine tied up: it cannot walk, swing,
## shoot or saw. It can still be shot.
var is_bound: bool = false
## Physics steps left walking slowly because of a bramble patch. Public so the
## tests can read it; bramble.gd renews it every step the machine stays inside.
var _slowed_steps: int = 0
## Seconds of binding left.
var _bound_time_left: float = 0.0
var hp: int = 0
## The hit points it started with (for the Linebreaker's armour ring).
var max_hp: int = 0
var is_dead: bool = false
## True while the machine is still arriving (rolling out of a gate, or falling):
## it does nothing until it is in. Public so the tests can read it.
var is_entering: bool = false
## Seconds of the fall left, and how long the whole fall takes (see drop_in).
var _drop_left: float = 0.0
var _drop_total: float = 1.0
## Seconds left of the dust ring and cracks after a landing. Public for the tests.
var land_fx_left: float = 0.0
## Seconds left of the "I was hit" flash. Public so the tests can read it.
var hit_flash_left: float = 0.0
## A small node drawn ABOVE the sprite, for the hit flash. (A node's own _draw
## is painted behind its children, so the flash needs a child of its own.)
var _hit_overlay: Node2D

## The grid to find routes over. Handed in by setup().
var _grid: ArenaGrid
## Remaining cells to walk through, next one first.
var _path: Array[Vector2i] = []
## Seconds until the next route recalculation.
var _repath_time_left: float = 0.0
## Colour of the plain square drawn when there is no sprite texture.
var _fallback_color: Color = Color.WHITE

## @onready fills these in just before _ready, once the child nodes exist.
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _sprite: Sprite2D = $Sprite2D


## Called by the arena right after creating the machine ("call down").
func setup(grid: ArenaGrid) -> void:
	_grid = grid


## Removes HP; at zero the machine announces its death and deletes itself.
func take_damage(amount: int) -> void:
	if is_dead:
		return
	hp -= amount
	queue_redraw()  # the Linebreaker's armour ring shows hit points left
	if hp <= 0:
		is_dead = true
		died.emit(self)
		queue_free()
		return
	# Still standing: flash, so the player can see the shot landed.
	hit_flash_left = CONFIG.hit_flash_seconds
	if _hit_overlay != null:
		_hit_overlay.queue_redraw()


## The colour of this machine's force field, or a fully see-through colour for
## "no shield". Nothing here; the Linebreaker and the Arc Spitter write their
## own versions ("overriding").
func _shield_color() -> Color:
	return Color(0.0, 0.0, 0.0, 0.0)


## True if the shield should crackle with small lightning arcs (the Arc Spitter).
func _shield_sparks() -> bool:
	return false


## Paints the force field on the overlay node, so it sits OVER the machine like
## a glass bubble:
##   1. a faint filled disc (the glass);
##   2. three thin rings just inside the edge, each fainter, so the rim looks
##      soft and thick instead of like a drawn circle;
##   3. the bright rim, only as long as the share of hit points left;
##   4. a glint that slides round it, so it reads as energy and not as paint;
##   5. (Arc Spitter) short jagged arcs that jump about on the rim.
## The whole bubble flares for a moment when a pod lands on it.
func _draw_shield() -> void:
	var color: Color = _shield_color()
	if color.a <= 0.0 or is_dead:
		return
	var radius: float = CONFIG.shield_radius_cells * float(CONFIG.cell_size)
	var seconds: float = float(Time.get_ticks_msec()) / 1000.0  # the clock, in seconds
	# 1.0 normally, up to shield_hit_flare just after a hit.
	var flare: float = 1.0
	if hit_flash_left > 0.0:
		flare = lerpf(1.0, CONFIG.shield_hit_flare, hit_flash_left / CONFIG.hit_flash_seconds)
	# A slow breathing of the glass (sin swings -1..1).
	var breath: float = 1.0 + 0.15 * sin(seconds * 2.2)
	_hit_overlay.draw_circle(Vector2.ZERO, radius, Color(color, CONFIG.shield_fill_alpha * breath * flare))
	for i: int in 3:
		var inner: float = radius - 3.0 * float(i + 1)
		_hit_overlay.draw_arc(Vector2.ZERO, inner, 0.0, TAU, 40, Color(color, 0.22 * flare / float(i + 1)), 3.0, true)
	# The rim: from 12 o'clock (-PI / 2) clockwise; TAU is a full turn.
	var share: float = clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	_hit_overlay.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color, 0.18), 2.0, true)
	_hit_overlay.draw_arc(Vector2.ZERO, radius, -PI / 2.0, -PI / 2.0 + TAU * share, 48, Color(color * flare, 0.9), 3.0, true)
	# The glint: a short, nearly white arc that travels round the bubble.
	var glint: float = seconds * 1.6
	_hit_overlay.draw_arc(Vector2.ZERO, radius - 2.0, glint, glint + 0.6, 10, Color(color.lightened(0.6), 0.75), 2.5, true)
	if _shield_sparks():
		# Three jagged arcs. Their places change eight times a second: floorf
		# drops the part after the decimal point, so `tick` is a whole number
		# that steps up, and each step gives new "random-looking" angles.
		var tick: float = floorf(seconds * 8.0)
		for i: int in 3:
			var start: float = fmod(tick * 2.399 + float(i) * 2.1, TAU)
			var points := PackedVector2Array()
			for step: int in 5:
				# Each point sits a little further round the rim, pushed in or
				# out by a few pixels, which makes the line zigzag.
				var wobble: float = 4.0 * sin(tick * 7.3 + float(i * 5 + step) * 2.7)
				points.append(Vector2.from_angle(start + float(step) * 0.16) * (radius + wobble))
			_hit_overlay.draw_polyline(points, Color(color.lightened(0.5), 0.95), 2.0, true)


## Paints the hit flash on the overlay node: a pale disc over the machine that
## fades out, and a ring that closes in on it. Connected to the overlay's `draw`
## signal in _configure_body. (The force field, if any, is painted first.)
func _draw_hit_flash() -> void:
	_draw_shield()
	if hit_flash_left <= 0.0:
		return
	var left: float = hit_flash_left / CONFIG.hit_flash_seconds  # 1 at the hit, 0 when over
	var radius: float = (_collision.shape as CircleShape2D).radius
	# Color(colour, alpha) copies a colour with a new see-through value.
	var color := Color(CONFIG.hit_flash_color, CONFIG.hit_flash_color.a * left)
	_hit_overlay.draw_circle(Vector2.ZERO, radius * 1.15, color)
	# lerpf(a, b, t) slides from a to b: the ring starts wide and shrinks.
	_hit_overlay.draw_arc(Vector2.ZERO, radius * lerpf(1.2, 2.0, left), 0.0, TAU, 24, color, 3.0)


## ARRIVING BY GATE: the machine was created on its floor cell; this puts it
## back inside the gate at `from` and slides it out to that cell over `seconds`.
## Until it is out it does nothing (is_entering). Called by the arena.
func walk_in_from(from: Vector2, seconds: float) -> void:
	var target: Vector2 = global_position
	global_position = from
	is_entering = true
	# A Tween changes a property smoothly over time. PHYSICS mode steps it in
	# time with the physics engine, since it is moving a physics body.
	var tween: Tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "global_position", target, seconds)
	# tween_callback runs a function when the steps before it are done. The small
	# function in brackets is a "lambda": it just switches the flag back off.
	tween.tween_callback(func() -> void: is_entering = false)


## ARRIVING BY AIR (the heavy machines): the machine is already standing on its
## landing cell, but its PICTURE starts `height` pixels above and falls for
## `seconds`, getting faster (EASE_IN), while a shadow grows on the floor under
## it (see _draw_entrance). When it lands it emits `landed`. Called by the arena.
func drop_in(seconds: float, height: float) -> void:
	is_entering = true
	_drop_total = maxf(seconds, 0.01)
	_drop_left = _drop_total
	_sprite.position = Vector2(0.0, -height)
	_hit_overlay.visible = false  # no shield or flash drawn on the ground while it is in the air
	var tween: Tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(_sprite, "position", Vector2.ZERO, _drop_total).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_land)


## The fall is over: the machine wakes up, the dust flies, the arena is told.
func _land() -> void:
	is_entering = false
	_drop_left = 0.0
	_hit_overlay.visible = true
	land_fx_left = CONFIG.land_fx_seconds
	queue_redraw()
	landed.emit(self)


## Paints what belongs to an arrival, behind the machine:
##   while falling  a round shadow that grows and darkens as the machine nears;
##   after landing  a ring of dust spreading out, and cracks in the concrete.
func _draw_entrance() -> void:
	var radius: float = (_collision.shape as CircleShape2D).radius
	if _drop_left > 0.0:
		var near: float = 1.0 - _drop_left / _drop_total  # 0 high up, 1 about to land
		draw_circle(Vector2.ZERO, radius * (0.5 + 0.8 * near), Color(0.0, 0.0, 0.0, 0.15 + 0.4 * near))
	if land_fx_left > 0.0:
		var done: float = 1.0 - land_fx_left / CONFIG.land_fx_seconds  # 0 at the landing, 1 when gone
		var fade: float = 1.0 - done
		# The cracks shoot out fast (done in the first third), then just fade.
		var shoot: float = minf(done * 3.0, 1.0)
		for i: int in 7:
			# Seven directions round the circle, each a slightly different length.
			var direction: Vector2 = Vector2.from_angle(TAU * float(i) / 7.0 + 0.4)
			var reach: float = radius * (1.3 + (1.2 + 0.25 * float(i % 3)) * shoot)
			draw_line(direction * radius * 0.7, direction * reach, Color(0.02, 0.02, 0.03, 0.85 * fade), 3.0)
		draw_arc(Vector2.ZERO, radius * (1.0 + 2.4 * done), 0.0, TAU, 40, Color(0.80, 0.78, 0.70, 0.7 * fade), 5.0)
		draw_arc(Vector2.ZERO, radius * (0.8 + 1.5 * done), 0.0, TAU, 40, Color(0.80, 0.78, 0.70, 0.35 * fade), 9.0)


## The vine's second use: drags this machine towards `puller` in a straight line,
## stopping `stop_distance` pixels short, and ties it up for `seconds`.
## Called by the player when the vine lands on a machine instead of a tree.
func yank_and_bind(puller: Vector2, stop_distance: float, seconds: float) -> void:
	if is_dead:
		return
	is_bound = true
	_bound_time_left = seconds
	velocity = Vector2.ZERO
	modulate = BOUND_TINT
	_on_bound()  # let the machine drop whatever it was in the middle of

	var to_puller: Vector2 = puller - global_position
	var distance: float = to_puller.length()
	if distance <= stop_distance + 1.0:
		return  # already close enough: bind it where it stands
	var motion: Vector2 = (to_puller / distance) * (distance - stop_distance)

	# Same safety check as the player's zip: sweep our own hit circle along the
	# line and only travel as far as it stays clear of walls and trees.
	var sweep := PhysicsShapeQueryParameters2D.new()
	sweep.shape = _collision.shape
	sweep.transform = Transform2D(0.0, global_position)
	sweep.motion = motion
	sweep.collision_mask = WORLD_BODY_MASK
	var fractions: PackedFloat32Array = get_world_2d().direct_space_state.cast_motion(sweep)
	var travel: Vector2 = motion * (fractions[0] if fractions.size() > 0 else 1.0)
	if travel.length() < 4.0:
		return

	# A Tween slides global_position to the end point over distance / speed seconds.
	var tween: Tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)  # step in time with physics
	tween.tween_property(self, "global_position", global_position + travel, travel.length() / CONFIG.vine_yank_speed)


## Called by a bramble patch: walk slowly for the next `steps` physics steps.
func slow_for(steps: int) -> void:
	_slowed_steps = maxi(_slowed_steps, steps)


## True while a bramble is slowing this machine. Used by the tests.
func is_slowed() -> bool:
	return _slowed_steps > 0


## Called the moment the vine binds this machine. Does nothing here; a machine
## that has something to cancel (a windup, a saw cut) writes its own version.
## (This is "overriding": a child class replaces a parent's function.)
func _on_bound() -> void:
	pass


## Each machine calls this first thing in its _physics_process. It counts the
## binding down and returns true while the machine must stay frozen.
func _tick_bound(delta: float) -> bool:
	# Every machine calls this each step, so the hit flash is counted down here too.
	if hit_flash_left > 0.0:
		hit_flash_left = maxf(hit_flash_left - delta, 0.0)
		_hit_overlay.queue_redraw()
	elif _shield_color().a > 0.0:
		_hit_overlay.queue_redraw()  # a force field is always moving
	# The arrival: count the fall and the landing dust down, redrawing meanwhile.
	if _drop_left > 0.0 or land_fx_left > 0.0:
		_drop_left = maxf(_drop_left - delta, 0.0)
		land_fx_left = maxf(land_fx_left - delta, 0.0)
		queue_redraw()
	if is_entering:
		velocity = Vector2.ZERO
		return true  # still rolling out of a gate or falling: do nothing yet
	if not is_bound:
		return false
	_bound_time_left -= delta
	if _bound_time_left <= 0.0:
		is_bound = false
		modulate = Color.WHITE  # white = "no tint"
		return false
	velocity = Vector2.ZERO
	return true


## _draw paints a plain square, only when there is no sprite texture.
func _draw() -> void:
	if _sprite.texture == null:
		var size: float = (_collision.shape as CircleShape2D).radius * 2.0
		draw_rect(Rect2(-size / 2.0, -size / 2.0, size, size), _fallback_color)
	_draw_entrance()
	_draw_marks()


## Extra marks a kind of machine paints around itself. Nothing here; the
## Linebreaker and the Arc Spitter write their own versions ("overriding").
## It is drawn BEHIND the sprite, which is a child node, so it shows around it.
func _draw_marks() -> void:
	pass


## Called by the arena for New Game +: more hit points and a faster walk.
## ceili rounds up to a whole number.
func toughen(hp_multiplier: float, speed_multiplier: float) -> void:
	hp = ceili(float(hp) * hp_multiplier)
	max_hp = hp
	speed_scale *= speed_multiplier
	queue_redraw()


## Each kind of machine calls this from its own _ready with its own numbers:
## join the "enemies" group, set HP, and size the hit circle and the sprite.
## (The leading underscore marks it as "for this class and its children only".)
func _configure_body(start_hp: int, radius_cells: float, texture: Texture2D, fallback_color: Color) -> void:
	add_to_group(GROUP)
	hp = start_hp
	max_hp = start_hp
	_fallback_color = fallback_color
	# The hit flash is drawn on a child node with a higher z_index, so it shows
	# in front of the sprite. Its `draw` signal calls our drawing function.
	_hit_overlay = Node2D.new()
	_hit_overlay.z_index = 1
	add_child(_hit_overlay)
	_hit_overlay.draw.connect(_draw_hit_flash)
	(_collision.shape as CircleShape2D).radius = radius_cells * CONFIG.cell_size
	_sprite.texture = texture
	if texture != null:
		var wanted_px: float = CONFIG.sprite_size_cells * CONFIG.cell_size
		_sprite.scale = Vector2.ONE * (wanted_px / float(texture.get_width()))


## Counts down the repath timer. Returns true each time a fresh route is due.
func _repath_due(delta: float, interval: float) -> bool:
	_repath_time_left -= delta
	if _repath_time_left > 0.0:
		return false
	_repath_time_left = interval
	return true


## Asks the grid for a fresh route to `target_cell`. If that cell is solid (a
## tree), the route ends at the closest cell that can be reached.
func _path_to(target_cell: Vector2i) -> void:
	_path = _grid.find_path(_grid.world_to_cell(global_position), target_cell)
	# The first entry is the cell we are already standing in. Drop it, or we would
	# walk backwards to our own cell's centre before setting off.
	if not _path.is_empty():
		_path.remove_at(0)


## The pixel position to walk towards right now. `final_position` is where the
## machine really wants to end up (the player, a tree).
func _next_goal(final_position: Vector2) -> Vector2:
	# Tick off waypoints we have already reached.
	while not _path.is_empty():
		var waypoint: Vector2 = _grid.cell_to_world(_path[0])
		if global_position.distance_to(waypoint) > WAYPOINT_REACHED_DISTANCE:
			break
		_path.remove_at(0)
	# One cell (or none) left means the goal is in this cell or the next one:
	# head for its exact position instead of a cell centre.
	if _path.size() <= 1:
		return final_position
	return _grid.cell_to_world(_path[0])


## Takes one physics step towards `goal` at `speed` (times speed_scale), turning
## the sprite to face the way it is going.
func _walk_towards(goal: Vector2, speed: float) -> void:
	velocity = global_position.direction_to(goal) * speed * speed_scale
	# limit_length shortens a vector that is too long: the top speed for machines.
	velocity = velocity.limit_length(CONFIG.player_speed * CONFIG.enemy_top_speed_share)
	# In a bramble patch: walk slower, and count down the steps left in the thorns.
	if _slowed_steps > 0:
		velocity *= CONFIG.bramble_slow_factor
		_slowed_steps -= 1
	# The art faces "up", and angle() measures from "right", hence the quarter turn.
	_sprite.rotation = velocity.angle() + PI / 2.0
	move_and_slide()  # moves by `velocity`, sliding along anything solid
