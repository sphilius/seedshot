# health_pips.gd - the row of hit-point squares at the top centre of the HUD.
# It lives in arena.tscn at Hud/HealthPips.
class_name HealthPips
extends Node2D
## Draws one square per hit point: filled for health left, hollow for health lost.
##
## It knows nothing about the player. The arena calls show_health() whenever the
## player's health_changed signal fires ("call down"), so this stays a dumb display.
##
## KEEPING CLEAR OF THE WAVE LABEL (s18): the row is centred when there is room.
## The arena tells it where the wave label ends (left_limit); the row never
## starts left of that, and if it still would not fit before the right margin,
## the pips shrink until it does.

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
## Grove rest: how far along the next pip is, 0 to 1. The first empty pip fills
## from the bottom as this rises. Written by the arena every frame.
var rest_progress: float = 0.0:
	set(value):
		if not is_equal_approx(value, rest_progress):
			rest_progress = value
			queue_redraw()
## The row may not start left of this screen x (the arena sets it to just past
## the end of the wave label). 0 = no limit.
var left_limit: float = 0.0:
	set(value):
		# A "setter": runs whenever left_limit is assigned. Redraw only on a real
		# change, because the arena assigns it every frame.
		if not is_equal_approx(value, left_limit):
			left_limit = value
			queue_redraw()


## Sets what the pips show and redraws them.
func show_health(new_current: int, new_maximum: int) -> void:
	current = new_current
	maximum = new_maximum
	queue_redraw()  # ask Godot to call _draw again on the next frame


## The screen rectangle of pip `index` (0 = leftmost). Public so the tests can
## check that the row stays clear of the wave label.
func pip_rect(index: int) -> Rect2:
	var screen_width: float = get_viewport_rect().size.x
	var right_limit: float = screen_width - CONFIG.hud_pips_right_margin
	# Width of the whole row at full size: every pip, plus the gaps between them.
	var full_width: float = maximum * PIP_SIZE + maxi(maximum - 1, 0) * PIP_GAP
	# Shrink everything by the same share if the row is wider than the room there
	# is. minf picks the smaller, so `shrink` is never above 1 (never enlarges).
	var room: float = maxf(right_limit - left_limit, 1.0)
	var shrink: float = minf(1.0, room / maxf(full_width, 1.0))
	var size: float = PIP_SIZE * shrink
	var gap: float = PIP_GAP * shrink
	var row_width: float = full_width * shrink
	# Centred if possible; otherwise pushed right of the label (or left of the margin).
	var left_edge: float = (screen_width - row_width) / 2.0
	left_edge = minf(maxf(left_edge, left_limit), right_limit - row_width)
	# Pip 0 is the leftmost; each one sits a pip-and-a-gap further right.
	return Rect2(left_edge + index * (size + gap), TOP_MARGIN, size, size)


## _draw paints the pips as one row at the top of the screen. (They started in
## the top-right corner; the first phone playtest found that too far from the
## fight to read at a glance.)
func _draw() -> void:
	for i: int in maximum:
		var pip: Rect2 = pip_rect(i)
		if i < current:
			draw_rect(pip, FULL_COLOR)
		else:
			# filled = false draws only the outline, 2 px wide.
			draw_rect(pip, EMPTY_COLOR, false, 2.0)
			if i == current and rest_progress > 0.0:
				# The pip being repaired: a paler fill rising from its bottom edge.
				var height: float = pip.size.y * clampf(rest_progress, 0.0, 1.0)
				draw_rect(Rect2(pip.position.x, pip.end.y - height, pip.size.x, height), Color(FULL_COLOR, 0.55))
