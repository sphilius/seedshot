# health_pips.gd - the row of hit-point squares at the top centre of the HUD.
# It lives in arena.tscn at Hud/HealthPips.
class_name HealthPips
extends Node2D
## Draws one square per hit point: filled for health left, hollow for health lost.
##
## It knows nothing about the player. The arena calls show_health() whenever the
## player's health_changed signal fires ("call down"), so this stays a dumb display.

const CONFIG: GameConfig = preload("res://config/game_config.tres")
const PIP_SIZE: float = 26.0
const PIP_GAP: float = 8.0
## Distance from the top edge of the screen to the pips.
const TOP_MARGIN: float = 11.0
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


## _draw paints the pips as one row, centred at the top of the screen. (They
## started in the top-right corner; the first phone playtest found that too far
## from the fight to read at a glance.)
func _draw() -> void:
	# Width of the whole row: every pip, plus the gaps between them.
	var row_width: float = maximum * PIP_SIZE + maxi(maximum - 1, 0) * PIP_GAP
	var left_edge: float = (get_viewport_rect().size.x - row_width) / 2.0
	for i: int in maximum:
		# Pip 0 is the leftmost; each one sits a pip-and-a-gap further right.
		var x: float = left_edge + i * (PIP_SIZE + PIP_GAP)
		var pip := Rect2(x, TOP_MARGIN, PIP_SIZE, PIP_SIZE)
		if i < current:
			draw_rect(pip, FULL_COLOR)
		else:
			# filled = false draws only the outline, 2 px wide.
			draw_rect(pip, EMPTY_COLOR, false, 2.0)
