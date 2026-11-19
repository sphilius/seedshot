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
## Seconds between blinks of the cat's eyes behind the shutter (the only visual
## hint that the shop is special). Long on purpose: the cat is meant to be hard.
@export var cat_glint_interval: float = 7.0
## THE CAT'S GIFT (story step 3): the live clamp (right-click a machine to yank
## and bind it; locked until the cat is found) and a spare fuse. With a fuse
## fitted, the first time Seven would go down it gets back up instead, with this
## many hit points.
@export var fuse_revive_hp: int = 3
## Seconds Seven cannot be hurt after the fuse saves it (it blinks meanwhile).
@export var fuse_invulnerable_time: float = 2.0
## Talking to Lucky: Seven must be within this many cells of the open shop for
## the E key to work. (A tap on the shop works from anywhere.)
@export var lucky_talk_range_cells: float = 3.5

## Lucky's greeting when the shutter opens, by the wave the cat was found in.
## Words only: nothing Lucky says changes the game. (Placeholders, STORY.md.)
@export_multiline var lucky_greeting_early: String = "Early. I like early. Take the clamp, kid. And a fuse, on the house."
@export_multiline var lucky_greeting_middle: String = "Thought you'd never knock. Clamp. Fuse. Don't tell Helios."
@export_multiline var lucky_greeting_late: String = "The whole block's lit and NOW you find me? Take the clamp anyway."
## Lucky's small talk, by the wave being played. Each talk gives the next line.
@export var lucky_talk_waves_1_to_3: Array[String] = [
	"They used to queue down the alley for me.",
	"That saw-thing's coming. They always send the saw-thing.",
	"Seven's a lucky number. I'd know.",
]
@export var lucky_talk_waves_4_to_7: Array[String] = [
	"Watch the trees, not yourself. You, I can fix.",
	"Hear that? Somebody's got the radio going.",
	"I've sold fuses to worse causes.",
]
@export var lucky_talk_wave_8: Array[String] = [
	"Look at that. Haven't seen my own sign lit in years.",
	"Don't get soft. They'll want it back.",
]
@export var lucky_talk_waves_9_to_10: Array[String] = [
	"They're not sending notices any more.",
	"Hold it one more night. Next block's watching.",
]

@export_group("Tap points")
## TAP POINTS (story step 5): soil patches on the floor where the old grid can
## be tapped. A machine downed on one grows a TAP TREE: it lights extra windows
## while it stands, heals Seven when it grows, and is slow to saw. New patches
## are picked at the start of every wave from `tap_points_from_wave` on.
@export var tap_points_per_wave: int = 2
@export var tap_points_from_wave: int = 2
## Extra windows each standing tap tree lights.
@export var tap_tree_bonus_windows: int = 3
## Hit points (pips) a tap tree gives Seven back when it grows.
@export var tap_tree_heal: int = 1
## A tap tree has this many times a normal tree's hit points.
@export var tap_tree_hp_multiplier: int = 2
## Tint of a tap tree (warm gold), so it stands out from the others.
@export var tap_tree_tint: Color = Color(1.15, 1.05, 0.72)
## The soil patch picture (tools/floor_tiles.ps1 makes it).
@export var tap_point_texture: Texture2D

@export_group("New Game +")
## NEW GAME + (unlocked by winning once): every wave sends this many times the
## machines (rounded up), and sends them this many times faster. 1.5 = 50% more.
@export var ng_plus_count_multiplier: float = 1.5
@export var ng_plus_pace_multiplier: float = 1.5
## In New Game +, a tree that was already grown when a wave started and is still
## standing when that wave is cleared matures into a GREAT SUNROOT (tree stage 4).
## Its hit points are this many times a normal tree's.
@export var great_sunroot_hp_multiplier: int = 3
## Picture of the great sunroot (tools/tree_sprites.py: tree_big.png).
@export var tree_great_texture: Texture2D

## CANOPY LINE (great_powers.gd): two great sunroots within this many cells of
## each other, with nothing between them, string a cable that binds machines.
@export var canopy_line_range_cells: float = 8.0
## How close (pixels) a machine's centre must come to the cable to be caught.
@export var canopy_line_catch_px: float = 16.0
## Seconds a caught machine stays bound.
@export var canopy_line_bind_seconds: float = 2.5
## Seconds a cable needs to recharge after catching a machine.
@export var canopy_line_recharge: float = 4.0
## Colour of a charged cable (alpha = how solid it looks).
@export var canopy_line_color: Color = Color(0.75, 1.0, 0.45, 0.85)

## SUNBURST (great_powers.gd): zip to a great sunroot and it flares.
## Radius of the flare, in cells.
@export var sunburst_radius_cells: float = 3.5
## Seconds every machine in the flare stays stunned.
@export var sunburst_stun_seconds: float = 3.0
## Damage the flare deals to each machine in it.
@export var sunburst_damage: int = 1
## Seconds before the next Sunburst can go off (shared by all great trees).
@export var sunburst_cooldown: float = 8.0

@export_group("Canopy FM")
## The block's pirate radio (scripts/canopy_fm.gd). How loud the song is, in
## decibels (0 = as recorded; every -6 roughly halves it).
@export var music_volume_db: float = -9.0
## The radio's muffle filter: its cutoff with the block dark, and fully lit, in
## Hz. Low = muffled, like a radio through a wall; high = clear.
@export var music_cutoff_dark_hz: float = 500.0
@export var music_cutoff_lit_hz: float = 16000.0
## When a tree is cut down the song drops back to muffled for this many
## seconds, and this many decibels quieter.
@export var music_dull_seconds: float = 2.5
@export var music_dull_drop_db: float = 6.0
## How quickly the filter and volume glide to a new setting. Higher is snappier.
@export var music_change_speed: float = 2.0

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

@export_group("Story")
## The words of the story (see STORY.md). Edit them here or in the Inspector;
## no script holds any story text.
## The opening line, shown once under the first "Wave 1" banner.
@export var story_hook: String = "Helios owns the sun. Your block stopped paying for it."
## What Helios customer service says as each wave starts. Entry 0 is wave 1.
@export var helios_lines: Array[String] = [
	"Courtesy notice: your account is 90 days past due.",
	"A technician is on the way to help you.",
	"Unlicensed generation is theft of sunlight.",
	"Disconnection crews dispatched. Thank you for your patience.",
	"We'd hate to lose you. Ask about our amnesty plan.",
	"Your neighbours are paying for your choices.",
	"Unit MR-7 is stolen Helios property.",
	"Final notice.",
	"Service area reclassified. Recovering assets.",
	"Please hold.",
]
## What the Block paints on the walls when each wave is cleared. Entry 0 is wave 1.
@export var graffiti_lines: Array[String] = [
	"KEEP THE LIGHTS ON!",
	"NOT YOURS",
	"THE SUN IS FREE",
	"GUARD THE TREES",
	"NO DEAL",
	"WE ARE THE NEIGHBOURS",
	"SEVEN IS OURS",
	"WE ARE THE GRID",
	"STILL HERE",
	"PASS IT ON",
]
## The end screen: the big headline, and Helios's last word under it.
@export var end_headline: String = "PASS IT ON"
@export var helios_end_line: String = "Account closed."
## Seconds each radio line stays on the air once it has finished typing.
@export var story_line_seconds: float = 3.0

@export_group("Radio")
## THE RADIO PANEL (radio.gd): Helios's broadcasts and Canopy FM's DJ.
## How fast words "type" onto the panel, in letters per second.
@export var radio_chars_per_second: float = 40.0
## Chance (0 to 1) that a letter of Helios's broadcast flickers into static.
@export var radio_helios_static: float = 0.03
## Canopy FM's DJ, wave 1 (keyboard and mouse): the tutorial. Feeble signal.
@export var dj_intro: Array[String] = [
	"...is this on? Meter-bot. Seven. If you can hear me, move. WASD.",
	"Point the mouse at a Helios machine. Hold left click. Plant a seed in it.",
]
## The same tutorial for touch screens.
@export var dj_intro_touch: Array[String] = [
	"...is this on? Meter-bot. Seven. If you can hear me, move. Left thumb.",
	"Right thumb aims and fires. Plant a seed in that Helios machine.",
]
## Canopy FM, the first time a machine goes down (keyboard and mouse).
@export var dj_first_tree: Array[String] = [
	"Ha! It rooted. That's a tree now. Spitter shots stop dead on bark: get behind it.",
	"And kid? Right-click any tree. The vine zips you straight to it.",
]
## The same, for touch screens.
@export var dj_first_tree_touch: Array[String] = [
	"Ha! It rooted. That's a tree now. Spitter shots stop dead on bark: get behind it.",
	"And kid? Tap any tree. The vine zips you straight to it.",
]
## Canopy FM, the first time a Sawbot is sent in.
@export var dj_first_sawbot: Array[String] = [
	"Sawbot on the lot! It doesn't want you. It wants the trees. Drop it first.",
]
## Canopy FM, wave 1 of New Game +: what great sunroots do.
@export var dj_ng_plus_intro: Array[String] = [
	"Back again? Trees that stand a whole wave grow GREAT now.",
	"Two great ones in sight of each other string a Canopy line. Machines get tangled.",
	"Zip to a great one and it bursts with light. Use it when they crowd you.",
]
## The waves on which Canopy FM drops a hint about the lucky cat (only while
## the shop is still shut), and the hints, in the same order.
@export var dj_cat_hint_waves: Array[int] = [2, 4, 6, 8]
@export var dj_cat_hints: Array[String] = [
	"Shout-out to Mrs. Maneki. Her shop on the north wall's been shuttered since Helios came. Her cat never left.",
	"Funny thing about shutters. They don't blink.",
	"Lucky cats like a polite knock. Three seeds, if you're asking.",
	"Still dark up by the north wall. Somebody should knock.",
]


@export_group("Night and windows")
## The homes along the bottom wall: one entry per home, saying how many windows
## it has. Ten homes and 24 windows in all.
@export var home_window_counts: Array[int] = [2, 3, 2, 3, 2, 2, 3, 2, 3, 2]
## Roofs for the homes, built from the concept by tools/home_roofs.ps1: six
## roof units side by side, each 52 x 32 (one unit sits over each window).
## Leave empty for plain grey roofs.
@export var home_roofs: Texture2D
## Windows already lit before any wave is cleared: the block's first two lamps.
@export var windows_lit_at_start: int = 2
## How strongly a lit window shines before any wave is cleared (0 to 1). It
## climbs evenly to 1.0 by the last wave.
@export_range(0.0, 1.0) var window_strength_at_start: float = 0.4
## The colour everything in the lot is tinted by, from a dark block (first) to a
## fully lit one (second). Sprites, floor and walls all shift between the two as
## windows come on, so the art always matches the light.
@export var ambient_dark: Color = Color(0.38, 0.42, 0.64)
@export var ambient_lit: Color = Color(1.0, 0.96, 0.88)
## How long the lot stays dark. The tint follows light_level raised to this
## power: 1 = it brightens evenly with every wave; 2.5 = it hardly moves until
## the last few waves. Before then, the light comes from the windows, lanterns
## and trees as separate pools, and the rest of the lot stays dark (Sasha's pick,
## concept 06_light_progression_h: "fewer lights on", not "a darker tint").
@export var ambient_curve: float = 2.5
## The pool of light each lit window throws onto the lot: reach in cells, and
## strength at full brightness (0 to 1).
@export var window_spill_radius_cells: float = 2.4
@export_range(0.0, 1.0) var window_spill_strength: float = 0.45
## How much brighter than its window the pool of light is. The whole lot is
## darkened by the night tint, lights included; values above 1 make a light
## shine through that darkness instead of being dimmed with everything else.
@export var light_boost: float = 2.2
## Lantern strings strung across the lot. One string goes up after each wave in
## this list is cleared (so three strings by the end). The first hangs nearest
## the homes, the next ones further up the lot.
@export var lantern_string_waves: Array[int] = [5, 8, 10]
## Where each string hangs: its share of the way UP the floor from the homes
## (0 = just above the homes, 1 = just under the top wall).
@export var lantern_string_heights: Array[float] = [0.22, 0.55, 0.85]
## Space between two lanterns on a string, in pixels.
@export var lantern_spacing_px: float = 78.0
## How far the middle of a string droops below its ends, in pixels.
@export var lantern_sag_px: float = 22.0
## Each lantern's little pool of light: reach in cells, and colour (alpha =
## strength).
@export var lantern_glow_radius_cells: float = 1.1
@export var lantern_glow_color: Color = Color(1.0, 0.72, 0.35, 0.40)
## How quickly the tint follows a change in light. Higher is snappier.
@export var ambient_change_speed: float = 1.5
## The controls line at the bottom hides when this wave starts, leaving the
## bottom wall to the windows.
@export var hint_hide_wave: int = 3
## How far a grown tree's glow reaches, in cells, and its colour. The alpha
## (last number) is the strength of the light.
@export var tree_glow_radius_cells: float = 1.7
@export var tree_glow_color: Color = Color(0.35, 0.95, 0.60, 0.30)
## Seven's lamp: reach in cells, and colour.
@export var player_glow_radius_cells: float = 2.2
@export var player_glow_color: Color = Color(1.0, 0.85, 0.60, 0.22)

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
## The sunroot tree, built from the concept art by tools/tree_sprites.py. A
## sapling, a grown tree, and the "cut" look a grown tree takes once a Sawbot
## has bitten it. Leave empty for the old circle drawing.
@export var tree_sapling_texture: Texture2D
## The graffiti lettering: Permanent Marker (Apache 2.0, art/fonts), a marker /
## spray-paint hand. Leave empty for Godot's plain built-in font.
@export var graffiti_font: Font
@export var tree_grown_texture: Texture2D
@export var tree_cut_texture: Texture2D
## The floor slabs: one row of 48 x 48 tiles (one grid cell each), built from
## the concept floor sheet by tools/floor_tiles.ps1. Leave empty for the plain
## floor colour.
@export var floor_tiles: Texture2D
## How many tiles at the START of that row are plain slabs. Most cells get one
## of these; the tiles after them (crater, moss, puddle, oil, grate, hatch)
## are rarer.
@export var floor_plain_count: int = 3
## Share of cells that get a detail tile instead of a plain slab (0.07 = about 1 in 14).
@export_range(0.0, 1.0) var floor_detail_chance: float = 0.07
## Colour the floor tiles are multiplied by. White = as drawn; darker = a
## quieter floor, so the sprites stand out more.
@export var floor_tint: Color = Color(0.85, 0.85, 0.88)
## Drawn size of a sprite relative to one cell (1.0 = exactly one cell wide).
## 64 / 48 = 1.3333 draws a 64 px sprite at its real size, so no pixel is
## stretched or squeezed.
@export var sprite_size_cells: float = 1.3333
