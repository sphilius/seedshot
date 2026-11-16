# glow.gd - makes soft pools of light for the night look.
# Not a node: a small helper other scripts call as Glow.make_sprite(...).
class_name Glow
extends RefCounted
## Soft round lights.
##
## The lot is dark at night, and light comes from the things that matter: the
## sunroot trees and Seven's lamp. Each light is a Sprite2D showing one shared
## picture: a white disc that fades to nothing at its edge.
##
## ADDITIVE BLENDING: a normal sprite covers what is under it. An additive sprite
## ADDS its colour to what is under it, so the floor gets brighter instead of
## being painted over. That is what makes it read as light and not as a sticker.

## Width and height of the shared disc picture, in pixels.
const TEXTURE_SIZE: int = 128
## The name every glow sprite gets, so other scripts and the tests can find it.
const NODE_NAME: String = "Glow"

## The one disc picture, made the first time it is needed and then reused.
## `static` means it belongs to the script itself, not to any one object.
static var _texture: GradientTexture2D
## The one "add, do not cover" material, shared by every glow.
static var _material: CanvasItemMaterial


## Returns a new glow sprite `radius_px` wide from centre to edge, tinted `color`.
## The caller adds it as a child of whatever should carry the light.
static func make_sprite(radius_px: float, color: Color) -> Sprite2D:
	if _texture == null:
		# A Gradient is a list of colours along a line from 0.0 to 1.0. Here:
		# solid white at the start, fully see-through white at the end.
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		_texture = GradientTexture2D.new()
		_texture.gradient = gradient
		_texture.width = TEXTURE_SIZE
		_texture.height = TEXTURE_SIZE
		# FILL_RADIAL runs the gradient outward from fill_from (the centre of
		# the picture) to fill_to (the middle of its right edge).
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1.0, 0.5)
		_material = CanvasItemMaterial.new()
		_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var sprite := Sprite2D.new()
	sprite.name = NODE_NAME
	sprite.texture = _texture
	sprite.material = _material
	sprite.modulate = color
	# The disc is TEXTURE_SIZE wide, so this scale makes it 2 x radius_px wide.
	sprite.scale = Vector2.ONE * (radius_px * 2.0 / float(TEXTURE_SIZE))
	# A soft light should stay smooth, not turn into chunky pixels like the art.
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Draw under the thing carrying the light, so the light never hides it.
	sprite.show_behind_parent = true
	return sprite
