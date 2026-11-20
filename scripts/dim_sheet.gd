# dim_sheet.gd - the black sheet that darkens the screen during a "big moment"
# (Seven knocked out, the fuse blowing, Lucky found). Created by the arena in
# code and added to the HUD, under the labels.
class_name DimSheet
extends Control
## A dark sheet with an optional POOL OF LIGHT in it.
##
## Until s18 round 4 this was a plain ColorRect: it darkened everything alike,
## Seven included. Sasha asked for the background to go much darker while the
## subject stays readable. So this sheet can leave a soft round hole:
##   color  the darkness (only its alpha, the see-through-ness, matters: 0 = off)
##   focus  the middle of the hole in screen pixels; Vector2.INF = no hole
##
## HOW THE HOLE IS DRAWN: one square picture that is see-through in the middle
## and black at its rim (a "radial gradient") is drawn around `focus`, and four
## plain black rectangles cover the rest of the screen around that square.

## How wide the square holding the pool of light is, in pixels.
const POOL_SIZE: float = 620.0

## The darkness. A "setter" (the `set` block) runs whenever the value is
## changed, so the sheet redraws itself.
var color: Color = Color(0.0, 0.0, 0.0, 0.0):
	set(value):
		color = value
		queue_redraw()
## Where the pool of light is (screen pixels). Vector2.INF = no pool.
var focus: Vector2 = Vector2.INF:
	set(value):
		focus = value
		queue_redraw()

## The picture of the hole, made once in _ready.
var _pool: GradientTexture2D


## _ready runs once: build the gradient picture.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A Gradient is a list of colours at positions from 0 to 1. Here: fully
	# see-through until a third of the way out, then fading to solid black.
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.30, 1.0])
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 1)])
	_pool = GradientTexture2D.new()
	_pool.gradient = gradient
	_pool.fill = GradientTexture2D.FILL_RADIAL
	# fill_from is the centre, fill_to a point on the rim (both as 0-to-1 shares
	# of the picture): a circle that just touches the picture's edges.
	_pool.fill_from = Vector2(0.5, 0.5)
	_pool.fill_to = Vector2(1.0, 0.5)
	_pool.width = 128
	_pool.height = 128


## _draw paints the darkness.
func _draw() -> void:
	if color.a <= 0.0:
		return
	var screen := Rect2(Vector2.ZERO, size)
	if focus == Vector2.INF:
		draw_rect(screen, color)  # no hole: one plain sheet
		return
	var hole := Rect2(focus - Vector2.ONE * POOL_SIZE / 2.0, Vector2.ONE * POOL_SIZE)
	# The picture is black, so tinting it with (1, 1, 1, alpha) only fades it.
	draw_texture_rect(_pool, hole, false, Color(1.0, 1.0, 1.0, color.a))
	# The four rectangles around the hole: above, below, left and right of it.
	# A rectangle that ends up with no width or height is simply skipped.
	var around: Array[Rect2] = [
		Rect2(0.0, 0.0, size.x, hole.position.y),
		Rect2(0.0, hole.end.y, size.x, size.y - hole.end.y),
		Rect2(0.0, hole.position.y, hole.position.x, POOL_SIZE),
		Rect2(hole.end.x, hole.position.y, size.x - hole.end.x, POOL_SIZE),
	]
	for rect: Rect2 in around:
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			draw_rect(rect, color)
