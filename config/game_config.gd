# game_config.gd - the "knobs" file: every tunable number in Seedshot, in one place.
# `class_name GameConfig` gives this script a global type name, so other scripts can
# write `const CONFIG: GameConfig = preload(...)` and get autocomplete on the fields.
# `@export` makes a variable editable in the Godot Inspector and saved in the .tres.
class_name GameConfig
extends Resource
## Every tunable number in Seedshot, in one place.
##
## HOW TO TUNE: open res://config/game_config.tres in the Godot editor. Each
## `@export var` below appears in the Inspector, grouped under the `@export_group`
## headings. Change a number, press F5, feel the difference. No code edits needed.
##
## WHY A RESOURCE: a Resource is a data file Godot can save and load. Every script
## preloads the same .tres file, so there is exactly one copy of each number and the
## scripts can never disagree about (for example) how big a grid cell is.
##
## UNITS: distances are pixels unless the name ends in `_cells` (then multiply by
## `cell_size`). Speeds are pixels per second. Times are seconds.

@export_group("Arena")
## Width and height of one grid square, in pixels.
@export var cell_size: int = 48
## Arena size in cells. The outer ring of cells is solid wall.
## 26 x 15 cells at 48 px = 1248 x 720, which fills the 1280 x 720 window.
@export var grid_cols: int = 26
@export var grid_rows: int = 15

@export_group("Player")
## Walking speed. There is no acceleration curve in v1: full speed or stopped.
@export var player_speed: float = 260.0
## Collision circle radius as a fraction of a cell. Under 0.5 so the player fits
## through a gap that is one cell wide.
@export_range(0.1, 0.49) var player_radius_cells: float = 0.33
## How many hits the bot can take. Each pip on the HUD is one hit point.
@export var player_max_hp: int = 5
## After a hit the bot blinks and cannot be hurt again for this long, so two
## enemies landing together cost one hit point, not two.
@export var player_hit_invulnerable_time: float = 0.8
## Seconds between the bot going down and the arena starting over.
@export var death_restart_delay: float = 1.2

@export_group("Seed pod")
@export var seed_speed: float = 720.0
## Minimum time between two shots while the fire button is held.
@export var seed_cooldown: float = 0.22
## A pod that hits nothing deletes itself after this long.
@export var seed_lifetime: float = 1.6
@export var seed_damage: int = 1
## Collision (and drawn) radius of the pod in pixels.
@export var seed_radius: float = 6.0

@export_group("Vine")
## How fast the player travels along the vine.
@export var vine_zip_speed: float = 1100.0
## Trees further away than this cannot be latched.
@export var vine_range: float = 560.0
## Rest time after a zip ends before the next one can start.
@export var vine_cooldown: float = 0.35
## How close the mouse pointer must be to a tree's centre to count as "on the tree".
@export var vine_pick_radius_cells: float = 0.9
## The zip stops this far from the tree's centre ("one cell short").
@export var vine_stop_short_cells: float = 1.0

@export_group("Trees")
## Hit points of a grown tree. Nothing damages trees yet; Sawbots will (waves 5+).
@export var tree_hp: int = 6
## A downed enemy is a walk-through sapling for this long, then a solid tree.
@export var sapling_time: float = 1.0
## If someone is standing on a sapling when it should turn solid, it waits this
## long and tries again (so nobody gets trapped inside a tree).
@export var sapling_retry_time: float = 0.25

@export_group("Scrapper")
@export var scrapper_speed: float = 120.0
## 1 = dies to a single seed pod.
@export var scrapper_hp: int = 1
@export_range(0.1, 0.49) var scrapper_radius_cells: float = 0.33
## How often a Scrapper recalculates its route to the player.
@export var scrapper_repath_interval: float = 0.35
## The Scrapper stops walking when it is this close to the player (melee range).
@export var scrapper_stop_distance_cells: float = 0.8
## The player must be this close for a swing to start, and still this close when
## it lands. A little more than the stop distance, so a standing Scrapper reaches.
@export var scrapper_melee_range_cells: float = 1.0
@export var scrapper_melee_damage: int = 1
## The warning: the Scrapper glows for this long before the hit lands. Walk (or
## zip) out of range in that time and the swing misses.
@export var scrapper_melee_windup: float = 0.35
## Rest time after a swing (hit or miss) before the next windup can start.
@export var scrapper_melee_cooldown: float = 0.9

@export_group("Touch")
## A finger must slide this far (in game pixels) before its touch becomes a
## thumb-stick. Anything shorter is finger wobble, so a tap stays a tap.
@export var touch_drag_threshold: float = 20.0
## How far the stick's knob can sit from its centre. If the thumb slides further,
## the whole stick follows it, so reversing direction is always a short move.
@export var touch_stick_radius: float = 80.0
## A touch that lifts sooner than this, without sliding, counts as a tap (the vine).
@export var touch_tap_max_time: float = 0.30
## Like vine_pick_radius_cells, but for taps. Bigger, because a fingertip is wider
## and less exact than a mouse pointer.
@export var touch_vine_pick_radius_cells: float = 1.5
## On touch there is no pointer to draw the reticle at, so it floats this far in
## front of the bot, along the aim direction.
@export var touch_reticle_distance_cells: float = 2.5

@export_group("Debug")
## Gray-box helper: seconds after a Scrapper dies before a new one walks in.
## Set to 0 to turn respawning off. Real waves will replace this.
@export var debug_respawn_delay: float = 2.0

@export_group("Placeholder art")
## Leave a texture empty to fall back to a plain coloured rectangle.
@export var player_texture: Texture2D
@export var scrapper_texture: Texture2D
## Drawn size of a sprite relative to one cell (1.0 = exactly one cell wide).
@export var sprite_size_cells: float = 1.3
