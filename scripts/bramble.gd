# bramble.gd - a patch of thorns grown from a Bramble Seed (the third seed type).
# Created by the arena when Seven throws one (Player.bramble_thrown -> Arena.spawn_bramble).
class_name Bramble
extends Node2D
## WHAT IT DOES
##   For CONFIG.bramble_seconds a ring of thorns covers the floor around this
##   node. Every machine whose centre is inside it:
##     - walks at bramble_slow_factor of its speed (Enemy.slow_for), and
##     - takes bramble_damage every bramble_tick_seconds.
##   A machine that dies in the thorns roots into a tree like any other.
##   Seven walks through it unharmed (it is not solid, and only machines are hurt).
##
## The patch only reads the "enemies" group; it never needs to know about the
## arena (it is a leaf node: it acts on what it finds and frees itself).

const CONFIG: GameConfig = preload("res://config/game_config.tres")
## How many thorns are drawn around the edge.
const THORN_COUNT: int = 14

## Seconds the patch has left. Public so the tests can read it.
var time_left: float = 0.0
## Seconds until the next damage tick.
var _tick_left: float = 0.0


## _ready runs once when the patch is added: start its timers.
func _ready() -> void:
	time_left = CONFIG.bramble_seconds
	_tick_left = CONFIG.bramble_tick_seconds


## The patch's radius in pixels.
static func radius_px() -> float:
	return CONFIG.bramble_radius_cells * CONFIG.cell_size


## _physics_process runs every physics step: slow the machines inside, hurt them
## on each tick, and wither away when the time is up.
func _physics_process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		queue_free()
		return
	_tick_left -= delta
	var tick_now: bool = _tick_left <= 0.0
	if tick_now:
		_tick_left = CONFIG.bramble_tick_seconds
	# Copy the list: a machine that dies here leaves the group during the loop.
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP).duplicate():
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead:
			continue
		if enemy.global_position.distance_to(global_position) > radius_px():
			continue
		enemy.slow_for(2)  # slowed for the next 2 steps; renewed while it stays inside
		if tick_now:
			enemy.take_damage(CONFIG.bramble_damage)
	queue_redraw()


## _draw paints a dark mat of brambles with thorns around the edge. It fades out
## over its last second.
func _draw() -> void:
	var fade: float = clampf(time_left, 0.0, 1.0)
	var green: Color = CONFIG.bramble_color
	var radius: float = radius_px()
	draw_circle(Vector2.ZERO, radius, Color(green.darkened(0.55), 0.45 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(green, 0.9 * fade), 2.0)
	# Thorns: little spikes pointing out from the edge, and a few tangled stems inside.
	for i: int in THORN_COUNT:
		var angle: float = TAU * float(i) / float(THORN_COUNT)
		var out := Vector2.from_angle(angle)
		draw_line(out * radius * 0.85, out * radius * 1.12, Color(green.lightened(0.2), fade), 2.0)
		var stem_end: Vector2 = Vector2.from_angle(angle + 0.9) * radius * 0.45
		draw_line(out * radius * 0.8, stem_end, Color(green, 0.7 * fade), 2.0)
