# spit_shot.gd - the Spitter's projectile. Slow, straight, and stopped by trees.
class_name SpitShot
extends Area2D
## A shot fired by a Spitter.
##
## It is the mirror image of the player's seed pod (seed_pod.gd): an Area2D that
## only DETECTS overlaps. The scene (spit_shot.tscn) puts it on physics layer 5,
## "enemy_shots", and sets its mask to layers 1 + 2 (world + player). So walls and
## grown trees stop it, and the player is hurt by it. Other enemies and seed pods
## are not on its mask, so it passes through them.
##
## It is slow on purpose (spit_speed, a little faster than the bot walks): you
## can sidestep it, zip away from it, or put a tree between you and the Spitter.

const CONFIG: GameConfig = preload("res://config/game_config.tres")
## Red is the colour reserved for "an enemy is about to hurt you".
const SHOT_COLOR: Color = Color(0.95, 0.30, 0.22)
const CORE_COLOR: Color = Color(1.0, 0.80, 0.60)

## Unit vector (length 1) the shot travels along. Set by the arena when spawning.
var direction: Vector2 = Vector2.RIGHT
## True for an ARC SPITTER's shot: drawn as a crackling bolt of electricity
## instead of a red dot. It flies and hurts exactly the same. Set by the arena.
var electric: bool = false

## Seconds this shot has existed.
var _age: float = 0.0
## True once the shot has hit something, so it only ever counts once.
var _is_spent: bool = false

@onready var _collision: CollisionShape2D = $CollisionShape2D


## _ready runs once when the shot enters the scene: size its hit circle from the
## config and start listening for overlaps.
func _ready() -> void:
	(_collision.shape as CircleShape2D).radius = CONFIG.spit_radius
	# connect(): when the body_entered signal fires, call _on_body_entered.
	body_entered.connect(_on_body_entered)


## _physics_process runs at a fixed 60 times per second; `delta` is the step length.
func _physics_process(delta: float) -> void:
	position += direction * CONFIG.spit_speed * delta
	_age += delta
	if electric:
		queue_redraw()  # the bolt crackles: a new jagged shape every frame
	if _age >= CONFIG.spit_lifetime:
		queue_free()


## _draw paints the shot: a red dot with a pale centre, or (electric) a bolt.
func _draw() -> void:
	if electric:
		_draw_bolt()
		return
	draw_circle(Vector2.ZERO, CONFIG.spit_radius, SHOT_COLOR)
	draw_circle(Vector2.ZERO, CONFIG.spit_radius * 0.45, CORE_COLOR)


## Paints an Arc Spitter's shot: a jagged streak of lightning trailing behind a
## bright ball, with a few short forks jumping off it. randf_range picks a new
## random number every frame, which is what makes it flicker.
func _draw_bolt() -> void:
	var color: Color = CONFIG.arc_spitter_spark_color
	var back: Vector2 = -direction            # the way the shot came from
	var across: Vector2 = direction.orthogonal()  # a quarter turn: "sideways"
	# The trail: six points going backwards, each knocked a little sideways.
	var trail := PackedVector2Array([Vector2.ZERO])
	for i: int in range(1, 6):
		trail.append(back * float(i) * 7.0 + across * randf_range(-5.0, 5.0))
	draw_polyline(trail, Color(color, 0.35), 6.0)       # a soft wide glow under it
	draw_polyline(trail, Color(color, 0.95), 2.5)       # the bolt itself
	draw_polyline(trail, Color(1.0, 1.0, 1.0, 0.9), 1.0)  # a white-hot core
	# Two short forks off the head, pointing in random directions.
	for i: int in 2:
		var fork: Vector2 = Vector2.from_angle(randf_range(0.0, TAU)) * randf_range(8.0, 15.0)
		draw_line(Vector2.ZERO, fork, Color(color, 0.8), 1.5)
	# The head: a glowing ball the size of the hit circle.
	draw_circle(Vector2.ZERO, CONFIG.spit_radius * 1.5, Color(color, 0.30))
	draw_circle(Vector2.ZERO, CONFIG.spit_radius * 0.8, Color(color.lightened(0.6), 1.0))


## Called when the shot overlaps a wall, a grown tree, or the player.
func _on_body_entered(body: Node2D) -> void:
	if _is_spent:
		return
	_is_spent = true
	# `as` gives the body as a Player, or null if it is something else.
	var player := body as Player
	if player != null:
		# Pass where the shot came from (one step back along its path), so Seven
		# can show which side it was hit from.
		player.take_damage(CONFIG.spit_damage, global_position - direction * 40.0)
	else:
		Sfx.play(&"thunk")  # stopped by a tree or a wall: cover did its job
	queue_free()
