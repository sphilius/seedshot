# gates.gd - the service gates in the side walls that Helios's machines come in by.
# Created by the arena in code (see arena.gd _ready). It only draws, and answers
# "which gate is next to this floor cell?".
class_name Gates
extends Node2D
## WHERE MACHINES COME FROM (s18 round 3).
##
## Until now a machine simply appeared on a random cell at the edge of the floor.
## Now each side wall has a few dark gateways (one per entry in the config's
## `gate_rows`), and an ordinary machine starts INSIDE a gateway and rolls out of
## it onto the floor cell in front. The two heavy machines do not use the gates:
## they drop in from above (see Enemy.drop_in).
##
## A gate is one WALL cell. Its "floor cell" is the open cell beside it:
##   left wall   gate (0, row)          floor cell (1, row)
##   right wall  gate (cols - 1, row)   floor cell (cols - 2, row)
##
## A gate's warning lamp lights for gate_lamp_seconds whenever a machine comes
## through it, so the player learns to watch the gates.

const CONFIG: GameConfig = preload("res://config/game_config.tres")

## Colours: the dark of the tunnel, its steel frame, the hazard stripes on the
## doorstep, and the warning lamp (dull when idle, bright when a machine comes).
const TUNNEL_COLOR: Color = Color(0.01, 0.01, 0.02)
const FRAME_COLOR: Color = Color(0.34, 0.36, 0.42)
const STRIPE_COLOR: Color = Color(1.0, 0.75, 0.25)
const LAMP_IDLE_COLOR: Color = Color(0.35, 0.10, 0.08)
## Values above 1 keep the lamp bright under the night tint.
const LAMP_LIT_COLOR: Color = Color(2.6, 0.5, 0.3)

## The grid, for turning cells into pixels. Set by setup().
var _grid: ArenaGrid
## Every gate's wall cell.
var _gate_cells: Array[Vector2i] = []
## Gate wall cell -> seconds its lamp stays lit.
var _lamp_left: Dictionary[Vector2i, float] = {}


## Called once by the arena: works out where the gates are.
func setup(grid: ArenaGrid) -> void:
	_grid = grid
	_gate_cells.clear()
	for row: int in CONFIG.gate_rows:
		if row <= 0 or row >= grid.rows - 1:
			continue  # a row that is itself wall cannot hold a gate
		_gate_cells.append(Vector2i(0, row))              # left wall
		_gate_cells.append(Vector2i(grid.cols - 1, row))  # right wall
	queue_redraw()


## Every gate's wall cell. Public for the tests.
func gate_cells() -> Array[Vector2i]:
	return _gate_cells


## The open floor cell in front of gate `gate`: one step in from its wall.
func floor_cell_of(gate: Vector2i) -> Vector2i:
	return gate + (Vector2i.RIGHT if gate.x == 0 else Vector2i.LEFT)


## The floor cell in front of every gate, in the same order as gate_cells().
func floor_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for gate: Vector2i in _gate_cells:
		cells.append(floor_cell_of(gate))
	return cells


## The gate whose floor cell is `cell`, or ArenaGrid.NO_CELL if `cell` is not in
## front of a gate.
func gate_for(cell: Vector2i) -> Vector2i:
	for gate: Vector2i in _gate_cells:
		if floor_cell_of(gate) == cell:
			return gate
	return ArenaGrid.NO_CELL


## A machine is coming through `gate`: light its warning lamp for a moment.
func open(gate: Vector2i) -> void:
	_lamp_left[gate] = CONFIG.gate_lamp_seconds


## True while gate `gate`'s lamp is lit. Public for the tests.
func is_lit(gate: Vector2i) -> bool:
	return _lamp_left.get(gate, 0.0) > 0.0


## _process runs every drawn frame: count the lamps down, and redraw only while
## one is lit (it pulses).
func _process(delta: float) -> void:
	if _lamp_left.is_empty():
		return
	# .keys() makes a copy of the keys, so erasing while looping is safe.
	for gate: Vector2i in _lamp_left.keys():
		_lamp_left[gate] -= delta
		if _lamp_left[gate] <= 0.0:
			_lamp_left.erase(gate)
	queue_redraw()


## _draw paints every gate over its wall cell: a steel frame, a black tunnel
## mouth, hazard stripes on the side that faces the floor, and the lamp above.
func _draw() -> void:
	if _grid == null:
		return
	var cell_px: float = float(CONFIG.cell_size)
	for gate: Vector2i in _gate_cells:
		# The wall cell's rectangle: its centre, minus half a cell each way.
		var rect := Rect2(_grid.cell_to_world(gate) - Vector2.ONE * cell_px / 2.0, Vector2.ONE * cell_px)
		draw_rect(rect, FRAME_COLOR)
		# grow(-n) shrinks a rectangle by n on every side: the tunnel inside the frame.
		draw_rect(rect.grow(-4.0), TUNNEL_COLOR)
		# The doorstep: a strip along the edge that touches the floor, striped.
		var faces_right: bool = gate.x == 0
		var step_x: float = rect.end.x - 6.0 if faces_right else rect.position.x
		for i: int in 6:
			# Alternate amber and black blocks down the strip.
			var block := Rect2(step_x, rect.position.y + float(i) * cell_px / 6.0, 6.0, cell_px / 6.0)
			draw_rect(block, STRIPE_COLOR if i % 2 == 0 else TUNNEL_COLOR)
		# The lamp, above the gate. Lit, it pulses: sin() swings its brightness.
		var lamp_at := Vector2(rect.get_center().x, rect.position.y - 7.0)
		var lamp: Color = LAMP_IDLE_COLOR
		if is_lit(gate):
			var pulse: float = 0.65 + 0.35 * sin(float(Time.get_ticks_msec()) / 60.0)
			lamp = LAMP_LIT_COLOR * pulse
			lamp.a = 1.0
			draw_circle(lamp_at, 11.0, Color(lamp, 0.25))  # a soft halo round the lit lamp
		draw_circle(lamp_at, 5.0, lamp)
