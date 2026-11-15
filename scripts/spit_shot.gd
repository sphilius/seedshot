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
	if _age >= CONFIG.spit_lifetime:
		queue_free()


## _draw paints the shot: a red dot with a pale centre.
func _draw() -> void:
	draw_circle(Vector2.ZERO, CONFIG.spit_radius, SHOT_COLOR)
	draw_circle(Vector2.ZERO, CONFIG.spit_radius * 0.45, CORE_COLOR)


## Called when the shot overlaps a wall, a grown tree, or the player.
func _on_body_entered(body: Node2D) -> void:
	if _is_spent:
		return
	_is_spent = true
	# `as` gives the body as a Player, or null if it is something else.
	var player := body as Player
	if player != null:
		player.take_damage(CONFIG.spit_damage)
	else:
		Sfx.play(&"thunk")  # stopped by a tree or a wall: cover did its job
	queue_free()
