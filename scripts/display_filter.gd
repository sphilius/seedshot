extends Node
## display_filter.gd - s26 HD display. An AUTOLOAD (Project Settings > Autoload, name
## DisplayFilter): Godot creates one of these when the game starts and keeps it for
## the whole run, whatever scene is showing.
##
## WHAT IT DOES: picks how every sprite is filtered, at startup and on every window
## resize. The game's LAYOUT is always 1280 x 720 (stretch mode canvas_items), but it
## is DRAWN at the window's real pixel size, so the 128 px art can use the extra pixels.
##   - Big window (scale >= CONFIG.pixel_filter_min_scale): NEAREST, hard pixel edges.
##     Each art pixel covers about one screen pixel or more, so nothing is lost.
##   - Small window (below it): LINEAR WITH MIPMAPS. The art is shrunk, and hard-edged
##     shrinking drops whole rows of pixels (jagged, shimmering when things move);
##     mipmaps are pre-shrunk copies of each picture that keep it smooth.
## It sets the ROOT viewport's default, so every CanvasItem left on "inherit" follows it.

const CONFIG: GameConfig = preload("res://config/game_config.tres")


## _ready runs once at startup: choose now, and again whenever the window changes size.
func _ready() -> void:
	# size_changed is a signal the window sends after every resize (or fullscreen switch).
	get_tree().root.size_changed.connect(apply)
	apply()


## Look at the window's size and set the root viewport's default texture filter.
func apply() -> void:
	var root: Window = get_tree().root
	root.canvas_item_default_texture_filter = filter_for(Vector2(root.size), layout_size(), CONFIG.pixel_filter_min_scale)


## The game's layout size from the project settings (1280 x 720), so no size is typed twice.
static func layout_size() -> Vector2:
	return Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))


## How many real screen pixels one layout pixel gets: the smaller of the two ratios,
## because stretch aspect "keep" letterboxes the other direction.
## Example: a 2560 x 1440 window gives min(2.0, 2.0) = 2.0; a 375 x 812 phone held
## upright at ratio 3 is 1125 x 2436 pixels, min(0.88, 3.38) = 0.88.
static func window_scale(window_px: Vector2, layout: Vector2) -> float:
	if layout.x <= 0.0 or layout.y <= 0.0:
		return 1.0
	return minf(window_px.x / layout.x, window_px.y / layout.y)


## THE RULE (pure, so tests/check.gd can test it without a window): hard pixels at or
## above `threshold`, smooth with mipmaps below it.
static func filter_for(window_px: Vector2, layout: Vector2, threshold: float) -> Viewport.DefaultCanvasItemTextureFilter:
	if window_scale(window_px, layout) >= threshold:
		return Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	return Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
