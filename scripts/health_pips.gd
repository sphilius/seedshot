# health_pips.gd - the row of hit-point squares in the top-right corner of the HUD.
# It lives in arena.tscn at Hud/HealthPips.
class_name HealthPips
extends Node2D
## Draws one square per hit point: filled for health left, hollow for health lost.
##
## It knows nothing about the player. The arena calls show_health() whenever the
## player's health_changed signal fires ("call down"), so this stays a dumb display.

const CONFIG: GameConfig = preload("res://config/game_config.tres")
const PIP_SIZE: float = 18.0
const PIP_GAP: float = 6.0
## Distance from the top-right corner of the screen to the last pip.
const MARGIN: Vector2 = Vector2(28.0, 14.0)
const FULL_COLOR: Color = Color(0.50, 0.85, 0.40)
const EMPTY_COLOR: Color = Color(1.0, 1.0, 1.0, 0.30)

## What is currently shown. Public so the tests can read them.
var current: int = 0
var maximum: int = 0


## Sets what the pips show and redraws them.
func show_health(new_current: int, new_maximum: int) -> void:
	current = new_current
	maximum = new_maximum
	queue_redraw()  # ask Godot to call _draw again on the next frame


## _draw paints the pips right-aligned: the row grows leftwards from the corner.
func _draw() -> void:
	var right_edge: float = get_viewport_rect().size.x - MARGIN.x
	for i: int in maximum:
		# Pip 0 is the leftmost. Work out its left edge from the right-hand side.
		var slots_from_right: int = maximum - i
		var x: float = right_edge - slots_from_right * PIP_SIZE - (slots_from_right - 1) * PIP_GAP
		var pip := Rect2(x, MARGIN.y, PIP_SIZE, PIP_SIZE)
		if i < current:
			draw_rect(pip, FULL_COLOR)
		else:
			# filled = false draws only the outline, 2 px wide.
			draw_rect(pip, EMPTY_COLOR, false, 2.0)
