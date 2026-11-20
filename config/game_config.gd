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
## THE AIM LINE (s18): a beam from Seven along the aim, stopping at the first
## wall or tree, so it is clear where pods will go. Length in cells; the colour's
## values above 1 keep it bright at night, and its last number is see-through-ness.
@export var aim_line_cells: float = 9.0
@export var aim_line_color: Color = Color(1.6, 1.5, 0.9, 0.5)
@export var aim_line_width: float = 2.5
## The nozzle drawn over Seven, pointing along the aim, and its length in pixels.
@export var aim_nozzle_color: Color = Color(1.3, 1.25, 1.0)
@export var aim_nozzle_length: float = 16.0
## How far Seven's body leans toward the aim, in radians (0.2 is about 11 degrees).
@export var aim_lean_radians: float = 0.2
## Collision circle radius as a fraction of a cell. Under 0.5 so the player fits
## through a gap that is one cell wide.
@export_range(0.1, 0.49) var player_radius_cells: float = 0.33
## How many hits the bot can take. Each pip on the HUD is one hit point.
@export var player_max_hp: int = 5
## After a hit the bot blinks and cannot be hurt again for this long, so two
## enemies landing together cost one hit point, not two.
@export var player_hit_invulnerable_time: float = 0.8
## Seconds between the bot going down and the arena starting over. (s18 round 2:
## 1.8, was 1.2, so the knock-out can be watched. Real seconds, not slowed ones.)
@export var death_restart_delay: float = 2.8

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
## s18 (Sasha): doubled from 1.0 so the Quick Roots upgrade has something to
## speed up, then doubled again to 4.0 (half the growth rate once more).
@export var sapling_time: float = 4.0
## If someone is standing on a sapling when it should turn solid, it waits this
## long and tries again (so nobody gets trapped inside a tree).
@export var sapling_retry_time: float = 0.25

@export_group("Scrapper")
## s18: every machine walks 20% faster than before (this was 120).
@export var scrapper_speed: float = 144.0
## s18 round 2 (Sasha: "too easy"): every machine has double the hit points it
## had. A Scrapper now takes two seed pods (it was 1).
@export var scrapper_hp: int = 2
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
## LINEBREAKER (a heavy Scrapper, scrapper.gd `heavy`): hit points, size (1 =
## a Scrapper's), speed (share of a Scrapper's), melee damage and colour.
## s18 round 2: 30 hit points (15 before, 5 before that), and 30% SLOWER than
## in round 1: 0.47 of a Scrapper's speed is about 68 px/s. It is a slow wall
## that arrives with its own escort (see linebreaker_escorts).
@export var linebreaker_hp: int = 30
## Spitters that walk in with each Linebreaker and stay beside it.
@export var linebreaker_escorts: int = 3
## ESCORTS (spitter.gd): a Spitter guarding another machine (a Linebreaker's
## escort, or an Arc Spitter guarding a Sawbot) stays within this many cells of
## it, and walks back if it is left behind.
@export var escort_leash_cells: float = 3.0
@export var linebreaker_scale: float = 1.35
@export var linebreaker_speed_factor: float = 0.47
## A Linebreaker that has made no headway for stuck_seconds shoulders straight
## through whatever wedged it, for stuck_shoulder_seconds.
@export var stuck_seconds: float = 0.9
@export var stuck_shoulder_seconds: float = 0.5
@export var linebreaker_damage: int = 2
## Hazard gold (s18: the old red-brown looked like any other Scrapper).
@export var linebreaker_tint: Color = Color(1.45, 1.10, 0.35)
## The Linebreaker's FORCE FIELD (s18: it was a hard gold ring): a see-through
## gold bubble. Its bright rim is the share of hit points left.
@export var linebreaker_ring_color: Color = Color(1.60, 1.20, 0.20)
## SHIELDS (enemy.gd _draw_shield), shared by the Linebreaker and the Arc Spitter.
## Radius of the bubble in cells, how solid its inside is (0 = clear glass), and
## how many times brighter it flares for a moment when a pod lands on it.
@export var shield_radius_cells: float = 0.74
@export var shield_fill_alpha: float = 0.08
@export var shield_hit_flare: float = 2.2
## ARC SPITTER (spitter.gd `arc`): hit points, the angle between the shots of
## its three-shot fan, and colour.
## s18 round 2: 12 hit points (6 before, 3 before that). 0.96 of a Spitter's
## speed (115 px/s). It guards the Sawbots: it stays beside the nearest one.
@export var arc_spitter_hp: int = 12
@export var arc_spitter_speed_factor: float = 0.96
## An Arc Spitter's reload, as a share of a Spitter's (0.65 = about a third faster).
@export var arc_spitter_cooldown_factor: float = 0.65
@export var arc_spitter_spread_degrees: float = 18.0
## Electric cyan. Its force field is the same blue, with small lightning arcs
## crawling over it, and its shots are bolts of that colour (spit_shot.gd).
@export var arc_spitter_tint: Color = Color(0.55, 1.35, 1.45)
@export var arc_spitter_spark_color: Color = Color(0.50, 1.70, 1.90)
## s18: 20% faster (was 90).
@export var sawbot_speed: float = 108.0
## Takes six pods (three before s18 round 2). It ignores you, so the cost of
## leaving it alone is trees.
@export var sawbot_hp: int = 6
## THE RIPSAW (s18 round 4): the upgraded Sawbot. Bigger (ripsaw_scale), more
## hit points, a faster walk (x ripsaw_speed_factor), and its blade bites in
## half the time (x ripsaw_saw_interval_factor), so trees fall twice as fast.
@export var ripsaw_hp: int = 14
@export var ripsaw_scale: float = 1.4
@export var ripsaw_speed_factor: float = 1.2
@export var ripsaw_saw_interval_factor: float = 0.5
## Its tint: hot red steel. (Values above 1 brighten.)
@export var ripsaw_tint: Color = Color(1.5, 0.75, 0.6)
## Ripsaws per wave (entry 0 is wave 1). Regular game: from wave 7, never more
## than 3. New Game +: from wave 4, never more than 5. Used as written.
@export var wave_ripsaws: Array[int] = [0, 0, 0, 0, 0, 0, 1, 2, 2, 3]
@export var ng_plus_wave_ripsaws: Array[int] = [0, 0, 0, 1, 2, 2, 3, 4, 4, 5]
@export var dj_first_ripsaw: Array[String] = ["That big red one is a Ripsaw. It drops a tree in half the time. Stop it before it reaches the Heart Tree."]
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
## s18: 20% faster (was 100).
@export var spitter_speed: float = 120.0
## Takes four pods (two before s18 round 2).
@export var spitter_hp: int = 4
@export_range(0.1, 0.49) var spitter_radius_cells: float = 0.33
## How often a Spitter recalculates its route while closing in.
@export var spitter_repath_interval: float = 0.4
## It backs away if the player comes closer than this...
## (s18 round 2: they keep further off now. These were 3.5 and 7.)
@export var spitter_min_range_cells: float = 4.5
## ...and walks closer if the player is further than this (or out of sight).
@export var spitter_max_range_cells: float = 8.0
## COVER (s18 round 2): between shots a Spitter hides behind one of YOUR trees.
## It looks for a hiding cell within this many cells of where it stands...
@export var spitter_cover_search_cells: int = 6
## ...and steps back out this many seconds before its next shot is ready.
@export var spitter_peek_seconds: float = 0.4
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

@export_group("Entrances")
## HOW MACHINES ARRIVE (s18 round 3, gates.gd and Enemy.drop_in).
## GATES: each side wall has a gateway on these grid rows. Ordinary machines
## (Scrappers, Spitters, Sawbots) roll out of one.
@export var gate_rows: Array[int] = [3, 7, 11]
## Seconds a machine takes to roll from inside the gate onto the floor.
@export var gate_walk_in_seconds: float = 0.45
## Seconds a gate's red lamp stays lit when a machine comes through.
@export var gate_lamp_seconds: float = 1.2
## A machine uses a gate at least this many cells from Seven, if there is one.
@export var gate_min_player_cells: float = 6.0
## THE DROP: the two heavy machines (Linebreaker, Arc Spitter) fall in from
## above. Seconds the fall takes, how far above its landing spot the picture
## starts (pixels), and how far from Seven it must land (cells).
@export var drop_seconds: float = 0.7
@export var drop_height_px: float = 460.0
@export var drop_min_player_cells: float = 5.0
## The landing: how hard the screen shakes (pixels; a kill is 3, a hit on Seven
## 7), and how long the dust ring and the cracks in the concrete show.
@export var shake_land_px: float = 20.0
@export var land_fx_seconds: float = 0.9
## THE INTRO CLIP: the FIRST Linebreaker and the FIRST Arc Spitter of a run get
## a short clip as they drop in. The game runs at heavy_intro_slow_scale speed,
## the camera pushes in on the landing spot by heavy_intro_zoom (1.35 = 35%
## closer), black bars of heavy_intro_bar_px slide in at the top and bottom,
## and the machine's name is shown. All of it lasts heavy_intro_seconds of real
## time, then everything eases back.
@export var heavy_intro_seconds: float = 4.6
@export var heavy_intro_slow_scale: float = 0.4
@export var heavy_intro_zoom: float = 1.35
@export var heavy_intro_bar_px: float = 64.0
@export var linebreaker_intro_title: String = "LINEBREAKER\nHelios heavy recovery unit"
@export var arc_spitter_intro_title: String = "ARC SPITTER\nHelios escort unit"
## The title shown in the intro clip of each kind of machine, the first time one
## arrives in a run (s18 round 4: the three everyday machines get a clip too).
## The key is the kind's name, as the wave director spells it.
@export var intro_titles: Dictionary[StringName, String] = {
	&"scrapper": "SCRAPPER\nHunts you down and swings. Two pods.",
	&"spitter": "SPITTER\nShoots from range, hides behind your trees.",
	&"sawbot": "SAWBOT\nIgnores you. Cuts your trees. Heads for the Heart Tree.",
	&"linebreaker": "LINEBREAKER\nHeavy unit. Arrives with a Spitter escort.",
	&"arc_spitter": "ARC SPITTER\nGuards the Sawbots. Fires three bolts.",
	&"ripsaw": "RIPSAW\nUpgraded Sawbot. Faster, tougher, cuts twice as quick.",
}
## A Linebreaker's escorts drop in one after another, this many seconds apart.
@export var escort_drop_gap: float = 0.18
## How dark the shadow under a falling machine is: when the fall starts, and
## just before it lands (0 = invisible, 1 = solid black).
@export var drop_shadow_alpha_far: float = 0.40
@export var drop_shadow_alpha_near: float = 0.92
## LUCKY'S MOMENT: when the shop opens the game all but stops
## (lucky_intro_slow_scale; 1 = normal speed) for lucky_intro_seconds of real
## time, with the camera on the shop and this text on screen.
## The Sunburst clip (New Game +): shown the first time a wave starts with a
## great sunroot standing.
@export var sunburst_intro_title: String = "GREAT SUNROOT\nRight-click it to vine there: that sets off a SUNBURST.\nGold trees are ready. Nearby great sunroots chain."
@export var sunburst_intro_title_touch: String = "GREAT SUNROOT\nVine to it: that sets off a SUNBURST.\nGold trees are ready. Nearby great sunroots chain."
@export var lucky_intro_seconds: float = 8.0
@export var lucky_intro_slow_scale: float = 0.03
@export var lucky_intro_title: String = "LUCKY'S GIFT\nRight-click a machine to bind it with the vine.\nOne spare fuse: it saves Seven once this run."
@export var lucky_intro_title_touch: String = "LUCKY'S GIFT\nVine a machine to bind it.\nOne spare fuse: it saves Seven once this run."

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
## HIT FEEDBACK (s18, "make it clear when a shot lands and what is hurting Seven").
## A machine that takes a hit and survives flashes this colour for this long,
## with a ring that closes in on it.
## (First try was 0.14 s and plain white: Sasha found it too faint. Values above
## 1 keep it bright under the night tint.)
@export var hit_flash_seconds: float = 0.24
@export var hit_flash_color: Color = Color(2.4, 2.4, 2.0, 1.0)
## SCREEN SHAKE: the playfield (not the HUD) jitters by up to this many pixels,
## dying away over shake_seconds. One size for a machine going down, a bigger
## one for Seven being hurt. Set shake_scale to 0 to switch all shaking off.
@export var shake_seconds: float = 0.25
@export var shake_kill_px: float = 3.0
@export var shake_hurt_px: float = 7.0
@export var shake_scale: float = 1.0
## SEVEN IS HURT: the whole screen tints this colour and fades over
## hurt_flash_seconds, and a red arc on Seven points at whatever did it for
## hurt_arc_seconds (a full ring if the source is unknown).
@export var hurt_flash_seconds: float = 0.35
@export var hurt_flash_color: Color = Color(1.0, 0.12, 0.08, 0.3)
## (First try was 0.6 s and an arc only: Sasha could not tell what hit Seven. Now
## it lasts longer and a red beam of hurt_beam_cells points at the attacker.)
@export var hurt_arc_seconds: float = 1.1
@export var hurt_beam_cells: float = 2.2
@export var hurt_arc_color: Color = Color(1.6, 0.25, 0.2)
## KNOCK-OUT animation: Seven jolts, tips over and greys out, throwing sparks,
## over this many seconds. (Keep it shorter than death_restart_delay.)
@export var knockout_seconds: float = 0.9
@export var knockout_spark_color: Color = Color(1.8, 1.4, 0.4)
## FUSE REVIVE animation: a gold flash, two rings bursting outward and a
## lightning bolt over Seven, while the picture pops big and settles back.
@export var fuse_flash_seconds: float = 0.8
@export var fuse_flash_color: Color = Color(1.9, 1.6, 0.5)
## Seconds Seven cannot be hurt after the fuse saves it. A gold shield shows
## around Seven for that long, fading away as it runs out (s18 round 2: 3 s, was 2).
@export var fuse_invulnerable_time: float = 3.0
@export var fuse_shield_color: Color = Color(1.9, 1.5, 0.4)
## THE BIG MOMENTS (s18 round 2, Sasha: the fuse revive was "just a quick bolt").
## When Seven is knocked out, or the fuse brings it back, the whole game slows
## to drama_slow_scale (0.3 = 30% speed) and the screen darkens by
## drama_dim_alpha (0 = not at all, 1 = black), both easing back over
## knockout_drama_seconds / fuse_drama_seconds of real time.
@export var drama_slow_scale: float = 0.3
@export var drama_dim_alpha: float = 0.8
@export var knockout_drama_seconds: float = 2.2
@export var fuse_drama_seconds: float = 2.6
## WEAR AND TEAR: Seven shows its damage in three steps (player.gd wear_level).
##   level 1  at or under wear_dented_share of full health: scorch marks, a spark now and then
##   level 2  at or under wear_battered_share: more scorch, steady sparks, smoke
##   level 3  on the last pip: sparks all the time and a red warning light
@export var wear_dented_share: float = 0.67
@export var wear_battered_share: float = 0.34
@export var wear_scorch_color: Color = Color(0.05, 0.04, 0.04, 0.55)
@export var wear_spark_color: Color = Color(2.2, 1.7, 0.5)
@export var wear_smoke_color: Color = Color(0.6, 0.6, 0.65, 0.35)
@export var wear_warning_color: Color = Color(2.2, 0.3, 0.2)
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
## What Canopy FM says the first time tap points appear.
@export var dj_tap_points: String = "See the gold rings on the floor? Old grid taps. Grow a tree on one: Seven gets a pip back and more homes light up."
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
## New Game + machines also walk this much faster, and the two heavy kinds
## (Linebreaker, Arc Spitter) have this many times their hit points.
@export var ng_plus_speed_multiplier: float = 1.10
## No machine ever walks faster than this share of Seven's own speed, however
## the per-wave and New Game + speed-ups stack. (Without it a wave 10 Scrapper
## in New Game + would do 272 px/s against Seven's 260.)
@export var enemy_top_speed_share: float = 0.92
@export var ng_plus_heavy_hp_multiplier: float = 1.5
## In New Game +, a tree that was already grown when a wave started and is still
## standing when that wave is cleared matures into a GREAT SUNROOT (tree stage 4).
## Its hit points are this many times a normal tree's.
@export var great_sunroot_hp_multiplier: int = 3
## s18 round 2 (Sasha): great sunroots were too common (a late run had 30+ on
## screen). A tree must now stand, grown, through this many whole waves before
## it matures (it was 1)...
@export var great_sunroot_waves_needed: int = 3
## ...and the lot holds at most this many great sunroots. The trees that have
## stood longest mature first.
@export var great_sunroot_max: int = 8
## Picture of the great sunroot (tools/tree_sprites.py: tree_big.png).
@export var tree_great_texture: Texture2D

## CANOPY LINE (great_powers.gd): two great sunroots within this many cells of
## each other, with nothing between them, string a cable that snares machines.
@export var canopy_line_range_cells: float = 8.0
## How close (pixels) a machine's centre must come to the cable to be caught.
@export var canopy_line_catch_px: float = 16.0
## Seconds a caught machine stays SNARED (slowed, not frozen; see snare_speed_factor).
## s19 round 6: 1.5 (was 2.5), because the forest handled the machines so well
## that New Game + nearly played itself.
@export var canopy_line_bind_seconds: float = 1.5
## Seconds a cable needs to recharge after catching a machine. s19: 8.0 (was 4.0).
@export var canopy_line_recharge: float = 8.0
## Colour of a charged cable (alpha = how solid it looks).
@export var canopy_line_color: Color = Color(0.75, 1.0, 0.45, 0.85)
## THE CAPS (s18). A late New Game + run had 70+ great sunroots and a cable
## between every pair: the screen was a web, the game lagged, and one machine
## stayed snared for two minutes. So:
## Each great sunroot holds at most this many cables (it links to its nearest).
@export var canopy_line_links_per_tree: int = 2
## The whole lot holds at most this many cables; the shortest ones win.
@export var canopy_line_max: int = 12
## After a Canopy line lets a machine go, no Canopy line can catch that machine
## again for this many seconds, so it can always walk out of the web.
@export var canopy_line_immunity_seconds: float = 4.0

## THE HEART TREE (forest_tree.gd is_heart): the big tree in the middle of the
## lot. Its hit points are tree_hp times this.
@export var heart_tree_hp_multiplier: int = 5
## Sawbots judge the Heart Tree this many times as far away as it really is, so
## below 1 means they go for it first (0.4: it "feels" 2.5 times closer).
@export var heart_tree_lure: float = 0.4
## Colour multiplied over the Heart Tree's picture (above 1 = brighter).
@export var heart_tree_tint: Color = Color(1.25, 1.0, 1.1)
## THE HEART TREE'S MARKER (s18: Sasha forgot the Heart Tree existed and could
## not find it). A ring pulses around it and a label floats above it, both drawn
## over the glow so they are always visible.
@export var heart_marker_color: Color = Color(1.0, 0.45, 0.62)
@export var heart_tree_label: String = "HEART TREE"
## The ring and label show until this many waves are cleared, then fade over
## heart_label_fade_seconds. (They still come back, in red, when it is hit.)
@export var heart_label_waves: int = 1
@export var heart_label_fade_seconds: float = 2.5
## The soft pink glow the Heart Tree keeps for the whole run, and its radius.
@export var heart_glow_color: Color = Color(1.0, 0.45, 0.75, 0.16)
@export var heart_glow_radius_cells: float = 1.15
## Letter height of that label in pixels (big enough to read on a phone).
@export var heart_label_font_size: int = 20
## The ring and label switch to this colour and text for heart_alarm_show_seconds
## after every hit the Heart Tree takes.
@export var heart_alarm_color: Color = Color(1.0, 0.25, 0.2)
@export var heart_alarm_label: String = "HEART TREE UNDER ATTACK"
@export var heart_alarm_show_seconds: float = 2.0
## Canopy FM says this when the Heart Tree is hit, at most once every
## heart_alarm_cooldown seconds (so one Sawbot does not fill the radio).
@export var heart_alarm_line: String = "They are cutting the Heart Tree! Get to the middle of the lot!"
@export var heart_alarm_cooldown: float = 12.0
## Canopy FM points the Heart Tree out as wave 1 starts.
@export var heart_intro_line: String = "The big tree in the middle is the Heart Tree. If it falls, the wave starts over."

## TREE STATE YOU CAN READ (s18).
## A hurt tree shows a small health bar: full colour, nearly-felled colour, back.
@export var tree_bar_full_color: Color = Color(0.45, 1.0, 0.55)
@export var tree_bar_low_color: Color = Color(1.0, 0.3, 0.25)
@export var tree_bar_back_color: Color = Color(0.0, 0.0, 0.0, 0.75)
## A sapling shows a ring that fills as it roots; this is its colour.
@export var tree_growth_ring_color: Color = Color(0.6, 1.0, 0.6, 0.9)
## The moment a sapling becomes a tree (or a tree a great sunroot) it "pops":
## it swells to tree_pop_scale and settles back over tree_pop_seconds, while a
## ring of light spreads out from it.
@export var tree_pop_seconds: float = 0.45
@export var tree_pop_scale: float = 1.35

## BRAMBLE SEED (the third seed type, bramble.gd): Q or Space (or the touch
## button) throws it toward the aim; it lands as a thorn patch.
## How far it is thrown, in cells (it lands on the floor at most this far away).
@export var bramble_range_cells: float = 5.0
## Radius of the thorn patch, in cells.
@export var bramble_radius_cells: float = 1.5
## Seconds the patch lasts.
@export var bramble_seconds: float = 8.0
## Machines inside walk at this share of their speed (0.5 = half speed).
@export var bramble_slow_factor: float = 0.5
## Damage each machine inside takes every bramble_tick_seconds.
@export var bramble_damage: int = 1
@export var bramble_tick_seconds: float = 1.0
## Charges Seven can hold, and seconds for one charge to grow back.
@export var bramble_max_charges: int = 3
@export var bramble_recharge_seconds: float = 6.0
## Colour of the thorns.
@export var bramble_color: Color = Color(0.40, 0.62, 0.30)

## TRELLIS (great_powers.gd): a zip from beside one tree to another leaves the
## vine strung between them. Seconds it lasts:
@export var trellis_seconds: float = 6.0
## Seconds a machine snared by the trellis stays snared (slowed, not frozen).
## s19: 1.2 (was 2.0).
@export var trellis_bind_seconds: float = 1.2
## How close (cells) Seven must start a zip to a tree for it to count as "from" it.
@export var trellis_start_reach_cells: float = 1.6
## Colour of a trellis vine.
@export var trellis_color: Color = Color(0.45, 0.95, 0.40, 0.9)

## SUNBURST (great_powers.gd): zip to a great sunroot and it flares.
## Radius of the flare, in cells.
@export var sunburst_radius_cells: float = 3.5
## Seconds every machine in the flare stays stunned.
@export var sunburst_stun_seconds: float = 3.0
## Damage the flare deals to each machine in it.
@export var sunburst_damage: int = 1
## Seconds before the next Sunburst can go off (shared by all great trees).
## s18: now only a short guard against one zip firing two; the real limit is
## the charges below. (It was a hidden 8 seconds.)
@export var sunburst_cooldown: float = 1.0
## THE CHAIN (s18 round 2): a Sunburst sets off every other great sunroot
## within this many cells of it, each of those sets off its own neighbours, and
## so on, like dominoes. Each tree flares once per chain, and the whole chain
## costs one charge. Plant great sunroots in a line to carry it across the lot.
@export var sunburst_chain_range_cells: float = 4.5
## Seconds between one tree flaring and the next one in the chain.
@export var sunburst_chain_delay: float = 0.22
## Colour of the flare: a soft gold wash that spreads and fades.
@export var sunburst_flare_color: Color = Color(1.6, 1.3, 0.55)
## Sunbursts Seven gets each wave. Shown on the HUD; refilled when a wave starts.
@export var sunburst_charges_per_wave: int = 1
## While a Sunburst is ready, every great sunroot turns gold: its picture is
## multiplied by the sheen colour (values above 1 brighten) and its pool of
## light switches to the glow colour. (s18: this was a hard gold ring with rays
## on every great tree, which made a late New Game + screen unreadable.)
@export var sunburst_sheen_color: Color = Color(1.55, 1.25, 0.50)
@export var sunburst_glow_color: Color = Color(1.0, 0.78, 0.30, 0.30)
## Said once, the first time a canopy line forms between two great sunroots:
## where the vines come from (s19).
@export var canopy_line_intro_line: String = "Those glowing vines between the great sunroots? The roots string them on their own, and they snare any machine that crosses."
## Canopy FM explains Sunburst the first time great sunroots stand at a wave start.
## %d is the number of charges.
@export var sunburst_intro_line: String = "See the great sunroots glow gold? Zip to one for a Sunburst: it stuns every machine near it, and great sunroots close by catch and flare too. You get %d each wave."

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
## s18: about a third more Scrappers, Spitters and Sawbots from wave 2 on (85
## machines over a run became 113). Wave 1 is the tutorial and is unchanged.
## Linebreakers and Arc Spitters keep their numbers: they got tougher instead.
## s18 round 2: more Scrappers again (they are the ones that hunt Seven).
@export var wave_scrappers: Array[int] = [1, 5, 5, 6, 7, 8, 9, 10, 11, 12]
## How many Spitters each wave sends, lined up with the list above. They arrive
## first (wave 2), so cover matters before anything starts cutting it down.
## s18 round 2: fewer lone Spitters from wave 6, because every Linebreaker now
## brings linebreaker_escorts more of them (wave 10: 3 + 3 x 3 = 12 Spitters).
@export var wave_spitters: Array[int] = [1, 1, 3, 3, 3, 2, 2, 3, 3, 3]
## How many Sawbots each wave sends, lined up with the list above.
@export var wave_sawbots: Array[int] = [0, 0, 0, 1, 3, 3, 3, 4, 4, 5]
## UPGRADES (upgrade_picker.gd): after clearing this wave and each later one
## (but not the last), the player picks one of `upgrade_choices` cards.
@export var upgrade_from_wave: int = 1
@export var upgrade_choices: int = 3
## While the cards are up the whole screen is darkened with this colour, and
## Seven is parked within this many cells of the Heart Tree, unable to act.
@export var upgrade_dim_color: Color = Color(0.0, 0.0, 0.0, 0.62)
@export var upgrade_park_cells: int = 2
## LIGHT FOLLOWS THE FOREST (s18): cleared waves decide how much light the block
## has EARNED; the forest decides how much of that shines. Each grown tree counts
## as its share of health (a half-cut tree counts 0.5). The earned light is fully
## on when the forest has this many tree-points per wave cleared.
@export var light_trees_per_wave: float = 4.0
## How often the windows are brought up to date with the forest, in seconds.
@export var light_refresh_seconds: float = 0.4
## Seed Pouch multiplies the time between pods by this (0.9 = 10% faster). Every
## pick multiplies again, so the upgrade stacks.
@export var upgrade_fire_cooldown_factor: float = 0.9
## Heavy Seeds: extra damage per pod.
@export var upgrade_seed_damage: int = 1
## PATCH KIT (the card that used to be Thick Plating): refills a random number
## of pips between these two, and adds no max health, so picking it again never
## stacks. It is not dealt while Seven is unhurt.
@export var upgrade_repair_min_pips: int = 1
@export var upgrade_repair_max_pips: int = 3
## The most pips Seven can ever have, however many Thick Platings are taken, so
## the row of pips on the HUD always fits. At the cap the card stops being dealt.
@export var player_hp_cap: int = 10
## Empty space kept between the wave label and the first pip, in screen pixels.
@export var hud_pips_gap: float = 24.0
## Space kept clear at the right edge of the screen (the pause button lives there).
@export var hud_pips_right_margin: float = 120.0
## GROVE REST is how Seven repairs (s18; Thick Plating no longer does it): while
## Seven is within grove_rest_radius_cells of at least grove_rest_trees grown
## trees, one pip comes back every grove_rest_seconds_per_pip seconds.
## (First try was 2 cells and 4 s: Sasha could not tell it was working.)
@export var grove_rest_radius_cells: float = 3.0
@export var grove_rest_trees: int = 4
## s18 (Sasha): half as fast as before (was 2.5), and only while a wave is being
## fought: not between waves, and not before the wave's first machine walks in.
@export var grove_rest_seconds_per_pip: float = 5.0
## The small words under Seven: trees in reach while hurt, and while repairing.
@export var grove_rest_count_text: String = "Grove %d / %d"
@export var grove_rest_working_text: String = "Repairing"
@export var grove_rest_text_color: Color = Color(0.75, 1.5, 0.75)
## The glow around Seven while resting. Values above 1 stay bright at night.
@export var grove_rest_glow_color: Color = Color(0.55, 1.35, 0.55, 0.40)
## Radius of that glow, in cells.
@export var grove_rest_glow_radius_cells: float = 0.85
## Canopy FM explains it the first time Seven is hurt in a run.
@export var grove_rest_line: String = "Dented? Stand close to four grown trees and the grove patches you up, one pip at a time."
## Hardwood: extra hit points for every tree, per pick (it stacks).
@export var upgrade_tree_hp: int = 1
## Quick Roots: each pick makes saplings root this much faster (0.15 = 15%), and
## the picks add up: two picks is 30% faster, so the time is divided by 1.30.
@export var upgrade_sapling_rate_gain: float = 0.15
## Vine Trip Line (the card that was called Long Trellis): extra seconds for
## every trellis vine, per pick; the picks add up. (s18 round 3: 1.5, was 4.)
@export var upgrade_trellis_seconds: float = 1.5
## Linebreakers (heavy Scrappers) per wave. They arrive once the player has had
## a few upgrade picks to answer them with.
@export var wave_linebreakers: Array[int] = [0, 0, 0, 0, 0, 1, 1, 2, 2, 3]
## Arc Spitters (three-shot fans) per wave.
@export var wave_arc_spitters: Array[int] = [0, 0, 0, 0, 0, 0, 1, 1, 2, 2]
## Seconds before the first machine of a wave walks in.
@export var wave_first_delay: float = 1.0
## Seconds between one machine walking in and the next.
@export var wave_spawn_interval: float = 1.4
## Rest time between clearing a wave and the next one starting.
@export var wave_break_time: float = 3.0
## THE WAVE END BEAT: when the last machine of a wave goes down, the whole game
## runs at wave_end_slow_scale speed (0.3 = 30%) for wave_end_slow_seconds of
## real time. Then the upgrade cards come up, then the next wave.
@export var wave_end_slow_scale: float = 0.3
## (Was 0.9: Sasha found it too short.)
@export var wave_end_slow_seconds: float = 1.6
## After clearing this wave, the banner tells the player it is a fine place to
## stop and rate the game. Jam judges play many entries; this tells them they
## have seen the core of it. 0 switches the marker off.
@export var rate_marker_wave: int = 5
## Each wave's Scrappers are this much faster than the wave before
## (0.08 = 8%). Wave 10 Scrappers therefore walk at 172% speed: about 206,
## still slower than the bot's 260. (Was 0.12 when there were only five waves.)
## s18 round 2: 0.09. The top-speed cap (enemy_top_speed_share) still holds.
@export var scrapper_speed_gain_per_wave: float = 0.09

@export_group("Story")
## The words of the story (see STORY.md). Edit them here or in the Inspector;
## no script holds any story text.
## The opening line, shown once under the first "Wave 1" banner.
@export var story_hook: String = "Helios owns the sun. Your block stopped paying for it."
## What Helios customer service says as each wave starts. Entry 0 is wave 1.
@export var helios_lines: Array[String] = [
	"Courtesy Notice: This sector's account is 90 minutes past due.",
	"A technician is on the way to help you.",
	"Unlicensed generation is theft of sunlight.",
	"Disconnection crews dispatched. Thank you for your patience.",
	"We'd hate to lose you. Ask about our amnesty plan.",
	"Your neighbours are paying for your choices.",
	"Unit MR-7 is stolen Helios property.",
	"Your amnesty offer has expired. Recovery crews are on site.",
	"Service area reclassified. Recovering all assets, trees included.",
	"Final notice.",
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
## The last lines of the end screen. Kept short: the banner is 52 px text on a
## 1280 px screen, and the old single line ran off both edges.
@export var end_unlocked_line: String = "New Game + unlocked!"
@export var end_restart_line: String = "Press R for the title screen"
@export var end_restart_line_touch: String = "Tap here for the title screen"
## Empty space kept on each side of the banner, in screen pixels.
@export var banner_side_margin: float = 40.0
@export var helios_end_line: String = "Account closed."
## CANOPY FM IN THE DARK: with no light the song is this many decibels quieter
## and a radio hiss plays at radio_hiss_db; both fade away as the block lights.
@export var music_dark_drop_db: float = 13.0
@export var radio_hiss_db: float = -11.0
## While the lot's light is below this (0 to 1), Canopy FM's lines are shown
## with a "[static]" break in them: the signal is still weak.
@export var radio_static_clear_light: float = 0.45
## A RESTARTED WAVE gives Seven the health it began the wave with plus
## restart_bonus_pips, but never more than restart_hp_cap_share of full health.
@export var restart_bonus_pips: int = 1
@export var restart_hp_cap_share: float = 0.8
## THE HEART TREE UNDER ATTACK: a short, gentle slow-and-zoom on it
## (heart_clip_seconds at heart_clip_slow_scale speed, zoomed heart_clip_zoom),
## and then not again for heart_clip_cooldown seconds.
@export var heart_clip_seconds: float = 0.9
@export var heart_clip_slow_scale: float = 0.55
@export var heart_clip_zoom: float = 1.15
@export var heart_clip_cooldown: float = 3.0
@export var heart_clip_title: String = "THE HEART TREE IS UNDER ATTACK"
## The dark panel behind the end screen's words (the last number is how solid
## it is: 0 = invisible, 1 = solid).
@export var end_panel_color: Color = Color(0.03, 0.04, 0.06, 0.84)
## Canopy FM mentions, as this wave starts, that its music can be changed.
@export var dj_music_hint_wave: int = 4
@export var dj_music_hint: String = "Not your sound? Canopy FM has four stations. Pick another on the title screen."
## Seconds each radio line stays on the air once it has finished typing.
@export var story_line_seconds: float = 6.0

@export_group("Radio")
## THE RADIO PANEL (radio.gd): Helios's broadcasts and Canopy FM's DJ.
## How fast words "type" onto the panel, in letters per second.
@export var radio_chars_per_second: float = 22.0
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
## Canopy FM, on wave 2 (not in New Game +): the Bramble Seed. Keyboard and touch.
@export var dj_bramble: Array[String] = [
	"One more trick. Press Q or Space: a bramble seed. Thorns slow them down and chew them up.",
]
@export var dj_bramble_touch: Array[String] = [
	"One more trick. Tap the thorn button, right side: a bramble seed. Thorns slow them down and chew them up.",
]
## Canopy FM, the first time a Sawbot is sent in.
@export var dj_first_sawbot: Array[String] = [
	"Sawbot on the lot! It doesn't want you. It wants the trees. Drop it first.",
	"It'll go for the Heart, the big old tree in the middle. Lose the Heart, lose the wave.",
]
## Canopy FM, the first time a Linebreaker or an Arc Spitter is sent in.
@export var dj_first_linebreaker: Array[String] = [
	"Big one! That's a Linebreaker. Shielded, slow, hits twice as hard, and it brings three Spitters to cover it.",
]
@export var dj_first_arc_spitter: Array[String] = [
	"Arc Spitter. Fires a fan of three bolts and guards the Sawbots. One tree won't cover you: find a thicket.",
]
## NEW GAME + OPENING (s18). Before wave 1, Canopy FM wakes Seven up and asks
## whether a reminder is wanted (see tutorial_offer.gd). The wave waits for the
## answer; with no answer after ng_plus_refresher_seconds it skips the tutorial.
@export var ng_plus_wakeup_line: String = "You're finally back up! Not sure what happened, but we need your help again. Do you remember what to do?"
@export var ng_plus_refresher_seconds: float = 12.0
## Said as New Game + wave 1 starts, whatever the answer was.
@export var ng_plus_threat_line: String = "Heads up: Helios has sent tougher, faster drones after you this time."
## Canopy FM, wave 1 of New Game +: what great sunroots do.
@export var dj_ng_plus_intro: Array[String] = [
	"Trees that stand a whole wave grow GREAT now.",
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
## Street props from concept 05_props_b, one 64 x 64 frame each (tools/prop_sprites.py,
## frame order in scripts/props.gd).
@export var props_texture: Texture2D
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
## s18 (Sasha): the homes and the trees were too bright; both are down 20%.
@export_range(0.0, 1.0) var window_spill_strength: float = 0.36
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
@export var tree_glow_color: Color = Color(0.35, 0.95, 0.60, 0.24)
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

@export_group("Contact")
## s19: touching a machine hurts. How many pips one touch costs Seven.
@export var contact_damage: int = 1
## Seconds a machine waits before it can hurt Seven by touch again, in seconds.
## (Seven's own blink after a hit, player_hit_invulnerable_time, also protects her.)
@export var contact_damage_cooldown: float = 1.0
## How close to touching counts as touching, in pixels: the gap allowed between
## the machine's edge and Seven's edge. Seven cannot walk INTO a machine, so
## "touching" is really "pressed against". A few pixels covers the physics
## engine's own small safety gap.
@export var contact_margin_px: float = 6.0

@export_group("Snare")
## s19: the forest's own vines (canopy lines and the Vine Trip Line) SNARE a
## machine; only Seven's own vine on a machine fully BINDS it. A snared machine is
## slowed to this share of its walking speed (0 = held in place, 1 = not slowed)
## but can still wind up, swing, shoot and saw. How long a snare lasts is
## canopy_line_bind_seconds and trellis_bind_seconds (in the New Game + group).
@export_range(0.0, 1.0) var snare_speed_factor: float = 0.25
## Colour of the net drawn over a snared machine (amber, so it never looks like
## the green of a bound one or the red of an attack about to land).
@export var snare_color: Color = Color(1.0, 0.78, 0.2, 0.55)

@export_group("Art")
## The sprites are 64 x 64 pixel art drawn with Klad (recipes in art/source/klad).
## Leave a texture empty to fall back to a plain coloured rectangle.
@export var player_texture: Texture2D
@export var scrapper_texture: Texture2D
@export var sawbot_texture: Texture2D
@export var spitter_texture: Texture2D
@export var cat_texture: Texture2D
## Lucky's second frame, paw dipped (tools/lucky_wave.py). The shop swaps between
## the two every cat_wave_seconds, so Lucky beckons.
@export var cat_wave_texture: Texture2D
@export var cat_wave_seconds: float = 0.35
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
