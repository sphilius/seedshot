# seed_pod.gd - the player's projectile. Flies straight, stops on the first thing it hits.
class_name SeedPod
extends Area2D
## A seed pod fired by the gardener-bot.
##
## An Area2D does not bump into things; it only DETECTS overlaps. The scene
## (seed_pod.tscn) sets its collision mask to layers 1 + 3 (world + enemies), so
## walls, grown trees and enemies trigger `body_entered`. Saplings have their
## collision switched off, so pods pass straight through them.

const CONFIG: GameConfig = preload("res://config/game_config.tres")
const POD_COLOR: Color = Color(0.85, 0.95, 0.35)

## Unit vector (length 1) the pod travels along. Set by the arena when spawning.
var direction: Vector2 = Vector2.RIGHT
## Damage this pod does to a machine. Set by the arena when it fires.
var damage: int = 1

## Seconds this pod has existed.
var _age: float = 0.0
## True once the pod has hit something. Two overlaps can arrive in the same
## physics step, and the pod must only count once.
var _is_spent: bool = false

@onready var _collision: CollisionShape2D = $CollisionShape2D


## _ready runs once when the pod enters the scene: size its hit circle from the
## config and start listening for overlaps.
func _ready() -> void:
	(_collision.shape as CircleShape2D).radius = CONFIG.seed_radius
	# connect(): when the body_entered signal fires, call _on_body_entered.
	body_entered.connect(_on_body_entered)


## _physics_process runs at a fixed 60 times per second; `delta` is the step length.
func _physics_process(delta: float) -> void:
	# Speed is pixels per second, so multiply by delta to get pixels this step.
	position += direction * CONFIG.seed_speed * delta
	_age += delta
	if _age >= CONFIG.seed_lifetime:
		queue_free()


## _draw is Godot's custom-drawing callback: the gray-box pod is just a dot.
func _draw() -> void:
	draw_circle(Vector2.ZERO, CONFIG.seed_radius, POD_COLOR)


## Called when the pod overlaps a wall, a grown tree, or an enemy.
func _on_body_entered(body: Node2D) -> void:
	if _is_spent:
		return
	_is_spent = true
	# `as` tries to treat the body as an Enemy (any machine: Scrapper, Sawbot...)
	# and gives null if it is something else, such as a tree or a wall.
	var enemy := body as Enemy
	if enemy != null:
		enemy.take_damage(damage)
	elif body is CatShop:
		(body as CatShop).hit_by_seed()  # the hidden lucky cat's shop counts pods
	else:
		Sfx.play(&"thunk")  # stopped by a tree or a wall
	queue_free()
