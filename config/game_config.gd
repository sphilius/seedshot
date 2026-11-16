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

## VINE ON A MACHINE: it is dragged towards the bot and tied up for this long.
@export var vine_bind_time: float = 1.5
## The drag stops this far from the bot. More than the Scrapper's melee reach
## (1.0), so a yanked Scrapper still has to step in before it can swing.
@export var vine_yank_stop_cells: float = 1.5
## How fast a yanked machine travels along the vine.
@export var vine_yank_speed: float = 900.0

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

@export_group("Sawbot")
## Slower than a Scrapper (120): you have time to reach it before a tree falls.
@export var sawbot_speed: float = 90.0
## Takes three pods. It ignores you, so the cost of leaving it alone is trees.
@export var sawbot_hp: int = 3
@export_range(0.1, 0.49) var sawbot_radius_cells: float = 0.36
## How often a Sawbot picks its next tree and recalculates its route.
@export var sawbot_repath_interval: float = 0.5
## A grown tree this close (to its centre) gets sawn. Just over one cell, so a
## Sawbot standing in the next cell reaches.
@export var sawbot_reach_cells: float = 1.15
## Damage per bite, and seconds between bites. With tree_hp 6 that is 3 seconds
## to fell one tree.
@export var sawbot_saw_damage: int = 1
@export var sawbot_saw_interval: float = 0.5

@export_group("Spitter")
@export var spitter_speed: float = 100.0
## Takes two pods.
@export var spitter_hp: int = 2
@export_range(0.1, 0.49) var spitter_radius_cells: float = 0.33
## How often a Spitter recalculates its route while closing in.
@export var spitter_repath_interval: float = 0.4
## It backs away if the player comes closer than this...
@export var spitter_min_range_cells: float = 3.5
## ...and walks closer if the player is further than this (or out of sight).
@export var spitter_max_range_cells: float = 7.0
## The warning: it glows red for this long before the shot leaves.
@export var spitter_windup: float = 0.5
## Rest time between shots.
@export var spitter_cooldown: float = 1.8
## Shot speed. Slow on purpose: the bot walks at 260 and zips at 1100.
@export var spit_speed: float = 300.0
@export var spit_damage: int = 1
## Collision (and drawn) radius of the shot in pixels.
@export var spit_radius: float = 7.0
## A shot that hits nothing deletes itself after this long.
@export var spit_lifetime: float = 3.0

@export_group("Lucky cat")
## Seed pods that must land on the shuttered shop before it opens.
@export var cat_hits_needed: int = 3
## Seconds between glints on the shop's shutter (the hint that it is special).
@export var cat_glint_interval: float = 3.0
## Gap in pixels between the two pods once the cat's gift is active.
@export var cat_pair_spacing: float = 14.0

@export_group("Waves")
## The first this-many waves are "staged": the next machine only walks in once
## the one before it is down. Wave 1 uses this to teach one thing at a time.
@export var wave_staged_waves: int = 1
## How many Scrappers each wave sends. Entry 0 is wave 1. The length of this
## list is the number of waves. Wave 1 is the single "teaching" Scrapper.
@export var wave_scrappers: Array[int] = [1, 3, 3, 4, 4, 5, 5, 6, 6, 7]
## How many Spitters each wave sends, lined up with the list above. They arrive
## first (wave 2), so cover matters before anything starts cutting it down.
@export var wave_spitters: Array[int] = [1, 1, 2, 2, 2, 2, 3, 3, 4, 4]
## How many Sawbots each wave sends, lined up with the list above.
@export var wave_sawbots: Array[int] = [0, 0, 0, 1, 2, 2, 2, 3, 3, 4]
## Seconds before the first machine of a wave walks in.
@export var wave_first_delay: float = 1.0
## Seconds between one machine walking in and the next.
@export var wave_spawn_interval: float = 1.4
## Rest time between clearing a wave and the next one starting.
@export var wave_break_time: float = 3.0
## After clearing this wave, the banner tells the player it is a fine place to
## stop and rate the game. Jam judges play many entries; this tells them they
## have seen the core of it. 0 switches the marker off.
@export var rate_marker_wave: int = 5
## Each wave's Scrappers are this much faster than the wave before
## (0.08 = 8%). Wave 10 Scrappers therefore walk at 172% speed: about 206,
## still slower than the bot's 260. (Was 0.12 when there were only five waves.)
@export var scrapper_speed_gain_per_wave: float = 0.08

@export_group("Touch")
## A finger must slide this far (in game pixels) before its touch becomes a
## thumb-stick. Anything shorter is finger wobble, so a tap stays a tap.
## (Was 20. On a real phone a tap wobbles more than that, so taps were being
## read as tiny stick pushes and the vine "sometimes missed".)
@export var touch_drag_threshold: float = 30.0
## How far the stick's knob can sit from its centre. If the thumb slides further,
## the whole stick follows it, so reversing direction is always a short move.
@export var touch_stick_radius: float = 80.0
## A touch that lifts sooner than this, without sliding, counts as a tap (the vine).
## (Was 0.30; loosened after the first phone playtest.)
@export var touch_tap_max_time: float = 0.40
## Like vine_pick_radius_cells, but for taps. Bigger, because a fingertip is wider
## and less exact than a mouse pointer.
@export var touch_vine_pick_radius_cells: float = 1.5
## On touch there is no pointer to draw the reticle at, so it floats this far in
## front of the bot, along the aim direction.
@export var touch_reticle_distance_cells: float = 2.5

@export_group("Art")
## The sprites are 64 x 64 pixel art drawn with Klad (recipes in art/source/klad).
## Leave a texture empty to fall back to a plain coloured rectangle.
@export var player_texture: Texture2D
@export var scrapper_texture: Texture2D
@export var sawbot_texture: Texture2D
@export var spitter_texture: Texture2D
@export var cat_texture: Texture2D
## One floor slab, 48 x 48 (exactly one cell), repeated across the arena floor.
## Leave empty for the plain floor colour.
@export var floor_texture: Texture2D
## How strongly the floor slab shows over the plain floor colour (0 = hidden,
## 1 = full strength). Kept low so the floor stays quieter than the sprites.
@export_range(0.0, 1.0) var floor_texture_strength: float = 0.35
## Drawn size of a sprite relative to one cell (1.0 = exactly one cell wide).
## 64 / 48 = 1.3333 draws a 64 px sprite at its real size, so no pixel is
## stretched or squeezed.
@export var sprite_size_cells: float = 1.3333
