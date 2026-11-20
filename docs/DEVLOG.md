# Seedshot devlog

The record of design choices, newest first. The design lock itself is [DESIGN.md](../DESIGN.md); this file records what was decided while building, and why.

Statuses: Made, Changed, Removed, Revisited, Parked, Archived, Proposed.

## At a glance

| ID | Date | Status | Choice |
|---|---|---|---|
| D-022 | 2026-11-15 | Made | End of a run: the forest is left standing, with a tree count and a restart |
| D-021 | 2026-11-15 | Made | Staged wave 1: Scrapper, then a Spitter from behind the new tree; first tree pulses |
| D-020 | 2026-11-15 | Made | Hidden lucky cat: shuttered shop in the top wall, three pods, paired pods |
| D-019 | 2026-11-15 | Made | Ten waves; Scrapper speed gain lowered to 8% per wave |
| D-018 | 2026-11-15 | Made | Vine on a machine: yank it to 1.5 cells and bind it for 1.5 s |
| D-017 | 2026-11-15 | Made | Spitter: keeps range, red windup, slow shot that trees stop; waves reshuffled |
| D-016 | 2026-11-14 | Made | Sawbot: saws any tree in reach, takes 3 pods, never attacks |
| D-015 | 2026-11-14 | Made | Five waves from two config lists; Scrappers 12% faster per wave; defeat restarts the wave |
| D-014 | 2026-11-14 | Proposed | Something to protect: not yet, build waves, Sawbot and Spitter first |
| D-013 | 2026-11-14 | Proposed | Movement: keep walk and zip until the Spitter exists, then ask again |
| D-012 | 2026-11-14 | Made | Health at top centre, pause button, looser vine tap |
| D-011 | 2026-11-14 | Changed | Split guard replaces the seal guard: no tree may cut the floor in two |
| D-010 | 2026-11-13 | Made | One art spec for every tool: 64 px, top-down, 12 colours, red for enemies only |
| D-009 | 2026-11-13 | Made | Scrapper melee is a telegraphed swing; 5 hit points; defeat restarts the arena |
| D-008 | 2026-11-13 | Revisited | Final art source: three-way test first (SpriteCook, ChatGPT Images, Klad) |
| D-007 | 2026-11-13 | Made | Upload the web build to itch as a draft (waiting on the game page) |
| D-006 | 2026-11-13 | Made | Touch controls: two floating thumb-sticks, tap a tree for the vine |
| D-005 | 2026-11-13 | Made | Placeholder sprites are in the gray box (player and Scrapper) |
| D-004 | 2026-11-13 | Made | Debug respawn: a new Scrapper 2 s after each death |
| D-003 | 2026-11-13 | Made | Seal guard keeps a sapling walk-through for good; an occupied sapling retries |
| D-002 | 2026-11-13 | Made | The vine latches the first tree its ray meets |
| D-001 | 2026-11-13 | Made | Every tunable in one config resource |

## D-029: Windows follow waves, and the lot's tint follows the windows (Made, 2026-11-16)

Sasha's change to D-028, replacing its one-window-per-tree rule and its wave 8 "all on" moment. Now: ten homes with two or three windows each (24 windows, `home_window_counts`). Windows lit and their strength both climb evenly with waves cleared: 2 windows at 40% before any wave, 20 of 24 after wave 8 ("almost"), all 24 at full strength after wave 10. Lit windows throw a pool of light onto the floor. Sprites are "recoloured" by one `CanvasModulate` node that tints everything in the lot between `ambient_dark` and `ambient_lit` according to `light_level()` (share of windows lit times their strength); the HUD is on its own layer and is not tinted. Trees no longer change the window count, so the blackout beat is kept as a flicker: a felled tree drops one lit window dark for 1.2 s. The corner label is now "Homes lit a / 10" plus "Trees n". Consequence to watch: the forest's size no longer shows in the windows at all, only in the Trees number.
## D-028: Night look and the block's windows (Made, 2026-11-16)

Story step 2. The lot is now dark and cool; light comes from grown trees and Seven's lamp (`scripts/glow.gd`: one shared soft disc, drawn additively so it brightens the floor instead of covering it). `scripts/block_windows.gd` draws 40 windows along the bottom wall, one lit per standing tree, filling from both ends inward. Clearing wave 8 (`block_lit_wave`) lights all of them and makes the forest of that moment the new "full", so trees lost in waves 9 and 10 darken windows again. Winning lights a row of small windows along the top edge: the next block. The screen has no room outside the walls, so the windows share the bottom wall with the controls line, which now hides from wave 3 (`hint_hide_wave`). Open risk: nobody has played to wave 8 with this yet, so 40 homes is a guess; if a normal run passes 40 trees before wave 8, the block-lit moment arrives early and quietly. Test gotcha: `await get_tree().process_frame` resumes before the arena's own `_process` that frame; wait a few frames instead.
## D-027: Story redesign, "Lights Out" (Made, 2026-11-16)

Sasha found the game thin on fun, solarpunk and story, and designs from story first. `STORY.md` is now the spine: Helios owns the sun, the block grows pirate solar, the bot is Seven (a jailbroken meter-reader). Step 1 (words) is built: Helios says one line under the banner as each wave starts, the Block paints one line on the side walls as each is cleared (`scripts/graffiti.gd`), the opening line shows once, the corner score reads "Homes powered", and the end screen is the config's headline with Helios's last word. All story text lives in the config's Story group. Fixed on the way: the end banner's count was frozen at the moment the last wave cleared, before the last machines grew into trees; it now stays current. Still to build, in order: night look and windows, Lucky's new gift and lines, Canopy FM, tap points.
## D-026: Mute, a halfway marker, and one fragile test order (Made, 2026-11-16)

From the Jamference feedback threads: players ask to turn sound off, and judges play many entries. So: M (or the speaker button left of pause) mutes the Master bus; clearing wave 5 (`rate_marker_wave`) adds "Halfway! Stop and rate here, or play on" to the banner; the hint line now lists M. The on-screen controls line already existed, so nothing else was added there. Gotcha: the new check failed 8 unrelated Sawbot and cat checks when it ran before the first arena test, and passes after the pause test. Some scene tests depend on run order; put new scene tests after the existing ones.
## D-025: ElevenLabs sound effects (Made, 2026-11-16)

All 14 beeps are replaced by ElevenLabs Sound Effects (API, key in the `ELEVENLABS_API_KEY` user environment variable).

- **Generate:** `.\tools\gen_sfx.ps1` reads the table in `audio/SOUNDS.md` (name, duration, prompt) and saves 2 takes per sound to `audio/sfx/candidates/` (git-tracked, hidden from Godot by a `.gdignore`, so they are not shipped in the build).
- **Pick:** `.\tools\pick_sfx.ps1 fire=1 thunk=3 ...` copies a take into `audio/sfx/<name>.mp3` and evens out its loudness with ffmpeg: each sound gets a target average loudness (frequent sounds like `fire` and `saw` quieter, rare ones like `cat` louder) and a limiter stops clipping.
- **Why loudness matters:** the raw takes ranged from silent to full blast. Three `thunk` takes and one `unlock` take were nearly silent; two more `thunk` takes were made and take 3 used.
- **First picks** were made by measured loudness, not by ear. Sasha picks by ear on the listening page (https://claude.ai/artifact/1uBh35gAQ52gztxxJqBDBX).
- **Gotcha:** after adding audio files run `.\tools\godot.ps1 import` on its own and let it finish; once, the checks ran before the import had written the `.import` files and every sound failed to load.

## D-024: Floor slab, checked with texkit (Made, 2026-11-16)

The arena floor now repeats one 48 px slab (`art/sprites/floor_tile.png`, drawn with Klad on a canvas that wraps). `texkit check` scored it PASS (seam 0.65, limit 1.5; lighting 0.004, limit 0.08). texkit only works on textures that repeat, so it was used for the floor and not for the sprites. The slab is drawn at 35% strength (`floor_texture_strength`) so the floor stays quieter than the machines.

## D-023: Final art comes from Klad (Made, 2026-11-15, built 2026-11-16)

Sasha chose Klad over SpriteCook, ChatGPT Images and the cleaned placeholders. Closes guidebook decision `d2-final-art-source`.

- **Sprites:** gardener-bot (Sasha's test run, used as is), Scrapper, Sawbot, Spitter and the lucky cat. All 64 x 64, the 12 colours from `art/PROMPTS.md`, top-down with the front at the top (the cat is a front view).
- **Recipes, not just pictures:** each sprite is a list of drawing steps in `art/source/klad/<name>.ops.jsonl`. `.\tools\klad_art.ps1` replays them into `art/sprites/`. Change a line, run the script, the sprite changes.
- **No recipe for the gardener-bot here:** its steps live in Sasha's untracked `art/source/compare/klad-claude/` folder; only the finished PNG was copied.
- **Sharp pixels:** the project's default texture filter is now Nearest, and `sprite_size_cells` is 1.3333 so a 64 px sprite is drawn at exactly 64 px. The cat is the exception: it is drawn smaller than its art, so it uses smooth scaling.
- **Not done:** no animation frames. Every machine is still one still image that turns.
- The Nano Banana placeholders stay in `art/placeholder/` for the before/after picture on the itch page.

## D-022: The end of a run (Made, 2026-11-15)

- Clearing wave 10 leaves the arena exactly as it is, with a banner: how many trees are standing, and "Press R or tap here to plant again". DESIGN.md: "The final screen shows the arena as you left it."
- **Bloom meter:** the corner label reads "Wave 3 / 10   Trees 12" throughout the run.
- R, Enter, or a tap or click on the banner starts a fresh run. A fresh run closes the cat's shop again.
- No score, no time, no menu. The tree count is the score.

## D-021: Staged wave 1 (Made, 2026-11-15)

From DESIGN.md: one Scrapper walks in, dies in one pod, grows into a tree, and a Spitter's shot visibly stops on that tree; a vine icon pulses on the tree until the player zips once.

- **One at a time:** in a staged wave the next machine only walks in after the one before is down (`wave_staged_waves = 1`). Wave 1 is now one Scrapper, then one Spitter.
- **The Spitter comes from behind the tree:** of the possible entry cells, the arena picks the one whose straight line to the player passes closest to the newly grown tree. The player can still walk out of cover, so the shot stopping on the tree is likely, not guaranteed.
- **The pulse:** the first tree the player grows shows an expanding ring until the first zip finishes. A ring, not an icon: no art needed.
- No text is added for any of this.

## D-020: The hidden lucky cat (Made, 2026-11-15)

The jam's mandatory restriction. Built as DESIGN.md describes it.

- **Where:** a shuttered shop set into the top wall, towards the right (cells 20 and 21), away from the middle.
- **Hints:** the shutter glints every 3 seconds, and a paw print is painted on the wall beside it.
- **How:** three seed pods on the shop. A vine grows up the front with each hit; on the third the shutter lifts and the cat rocks from side to side.
- **Reward:** every shot is a pair of pods, 14 px apart, for the rest of the run. It survives wave restarts.
- **A ledge, for a technical reason:** the shop front sticks 16 px out of the wall. Flush with the wall, the wall behind it registered the pod first and the hit did not count.
- **Still to do for the jam (s11):** the itch description must say the game has a hidden lucky cat, and a screenshot goes to the organiser.

## D-019: Ten waves (Made, 2026-11-15)

- `wave_scrappers = [1, 3, 3, 4, 4, 5, 5, 6, 6, 7]`, `wave_spitters = [0, 1, 2, 2, 2, 2, 3, 3, 4, 4]`, `wave_sawbots = [0, 0, 0, 1, 2, 2, 2, 3, 3, 4]`. Wave 10 is 15 machines.
- **Speed gain lowered from 12% to 8% per wave.** At 12% a wave 10 Scrapper would walk at 250, almost the bot's 260, and could not be outrun. At 8% it walks at about 206.
- These numbers are a first guess and have not been played. DESIGN.md aims at 6 to 8 minutes for a full run; tune the lists after the first playthrough.

## D-018: Vine on a machine (Made, 2026-11-15)

From DESIGN.md: "On an enemy: yank it toward you and bind it for 1.5 s."

- **Same input as the zip.** Right click (or tap) on a machine instead of a tree. A machine under the pointer wins over a tree.
- **Yank:** dragged in a straight line to 1.5 cells from the bot. That is outside a Scrapper's 1.0 cell reach, so a yanked Scrapper still has to step in and wind up.
- **Bind:** 1.5 s tinted green. It cannot walk, swing, shoot or saw, and a windup or saw cut in progress is cancelled. It can still be shot.
- **Needs a clear line:** a wall or tree between the bot and the machine blocks it, the same rule as the Spitter's line of sight.
- **Shares the vine cooldown** (0.35 s) with the zip.
- **Why it matters for the open movement decision (D-013):** the vine is now also how you pull a Spitter out of cover, stop a Sawbot mid-cut, or line a machine up where you want its tree.

## D-017: The Spitter (Made, 2026-11-15)

- **Behaviour:** it wants a clear line to the player from 3.5 to 7 cells away. No clear line or too far: it walks closer along the grid route. Too close: it backs away. Clear line and ready: it glows red for 0.5 s, then fires one shot at where the player is.
- **The shot** is slow (300; the bot walks at 260 and zips at 1100), costs 1 hit point, and stops on walls and grown trees. That is the design's "trees block shots, yours and theirs".
- **Shots do not damage trees.** Felling trees is the Sawbot's job; if Spitters eroded cover too, the two machines would blur together.
- **2 hit points, 1.8 s between shots.** A new Spitter waits half a cooldown before its first shot, so nothing fires the instant it walks in.
- **Own physics layer:** layer 5, "enemy_shots", looking only at world and player, so shots pass through other machines and seed pods.
- **Waves reshuffled** now that all three machines exist: `wave_scrappers = [1, 3, 3, 4, 4]`, `wave_spitters = [0, 1, 2, 2, 2]`, `wave_sawbots = [0, 0, 0, 1, 2]`. Spitters first (cover matters before anything cuts it down), as DESIGN.md orders them. The lock has Sawbots from wave 5; they start at wave 4 here so a five-wave build shows them twice. Revisit when waves 6 to 10 are added.

## D-016: The Sawbot (Made, 2026-11-14)

- **Behaviour:** walks to the nearest grown tree and saws it: 1 damage every 0.5 s, so 3 s for a 6 HP tree. It never attacks the player (DESIGN.md: "ignores you, cuts down trees").
- **"Any tree in reach", not "my chosen tree":** if the tree it picked is buried behind others, it cuts its way in through the outer ones instead of getting stuck.
- **Nothing to cut:** it waits by the nearest sapling, or drifts to the middle.
- **3 hit points, speed 90:** tougher and slower than a Scrapper, so ignoring it costs trees and hunting it costs time.
- **Trees show damage:** the canopy shrinks as HP drops.
- **Shared base class:** Scrapper and Sawbot both extend `Enemy` (health, dying into a tree, path-walking). The Spitter will too.

## D-015: Waves (Made, 2026-11-14)

- **What is in a wave** is two lists in the config, one number per wave: `wave_scrappers = [1, 3, 4, 5, 6]` and `wave_sawbots = [0, 0, 1, 1, 2]`. The number of waves is the length of the lists.
- **Differs from DESIGN.md:** the lock puts Spitters in waves 2 to 4 and Sawbots in 5 to 7. The Sawbot was built first because the phone playtest asked for it, so Sawbots start at wave 3. Reshuffle when the Spitter exists.
- **Faster Scrappers** (asked for in the playtest): 12% per wave. A wave 5 Scrapper walks at about 178 against the player's 260.
- **Defeat** restarts the current wave with the forest as it stood at wave start, as the lock asks. This replaces the whole-arena reload from D-009.
- **The debug respawn (D-004) is removed.** Waves replace it.
- **How it is wired:** `WaveDirector` only keeps time and count and emits signals; the arena does the spawning. Tests speed it up with `WaveDirector.time_scale`, because writes to the shared config from a test are ignored.

## D-014: Something to protect (Proposed, 2026-11-14)

From the phone playtest: "some type of item or character to protect". Not in the design lock. The lock says to raise tree HP and Spitter count before adding anything else, and the gate it refers to has not been reached because waves, the Spitter and the Sawbot do not exist yet. Recommended: not yet. The cheapest version if wanted later is a Heart Tree in the middle that Sawbots head for. Guidebook decision `d4-something-to-protect`.

## D-013: Walk and zip overlap (Proposed, 2026-11-14)

From the phone playtest: the zip feels redundant next to the thumb-stick. True today, because the only enemy is slow and melee. The design's bet is that the zip becomes the dodge once Spitters shoot. Recommended: keep both, build the Spitter, ask again. The bold alternative is zip-only movement, where the forest becomes the board; it is also the nearest thing to the chess / Go idea from the same playtest. Guidebook decision `d3-movement`.

## D-012: HUD and touch fixes from the phone playtest (Made, 2026-11-14)

- **Health squares:** top centre, 26 px. They were in the top-right corner at 18 px and were marked not readable at a glance. Bottom centre was the other request, but thumbs cover the bottom on a phone.
- **Pause:** two-bar button top-right, or P, or Esc. Any tap or click carries on. The tap that pauses or resumes is swallowed so it cannot fire or zip.
- **Vine tap:** a tap may now wobble 30 px (was 20) and last 0.40 s (was 0.30). "Sometimes missed" on a real phone.
- **Hint line:** moved to the bottom centre to make room.

## D-011: Split guard replaces the seal guard (Changed, 2026-11-14)

Was (D-003): a sapling stays walk-through if growing would cut the player off from the arena centre. That is what DESIGN.md asks for.

The first phone playtest broke it: the player built a ring of trees around a pocket that contained the centre cell. "Can the player reach the centre?" stayed true, the last tree grew, and the Scrapper could never get in.

Now: a sapling stays walk-through if growing would cut the open floor into two areas at all (`ArenaGrid.would_split`). Nobody can be walled in and no enemy can be walled out. Trees that touch only at corners count as a wall, the same way the pathfinder treats them.

Still true: a long maze slows enemies down. That is the Sawbot's job to answer.

## D-010: One art spec for every tool (Made, 2026-11-13)

Written down in `art/PROMPTS.md` so any generator gets the same brief.

- **64 x 64 pixels.** A cell is 48 px and sprites are drawn slightly larger than a cell. When final art goes in, set `sprite_size_cells` to 1.333 so one art pixel is exactly one screen pixel.
- **Top-down, front at the top.** The game rotates sprites to face their aim or travel. The placeholders are front views, which look wrong when rotated. The cat is the exception: it never rotates.
- **12 colours, red for enemies only.** DESIGN.md asks for one accent colour reserved for enemy tells; the melee windup glow (D-009) already uses red.
- **Differs from DESIGN.md:** the lock says "grayscale kit plus palette-swap shader". The test uses colour so results compare directly with the colour placeholders. Revisit once a tool wins.

## D-009: Telegraphed melee, 5 hit points, restart on defeat (Made, 2026-11-13)

First slice of Saturday's work, pulled forward.

- **The swing:** within 1.0 cells a Scrapper glows red for 0.35 s and stands still, then hits if the bot is still in reach. Leaving its reach makes it miss. A hit you could not have avoided would make trees feel pointless; a hit you can dodge by zipping makes them matter.
- **Health:** 5 hit points, one per swing, 0.8 s of blinking invulnerability after a hit so two enemies landing together cost one point.
- **Defeat:** the whole arena reloads after 1.2 s. This is a stand-in. DESIGN.md says death restarts the current wave with the forest as it stood at wave start; that needs waves first.
- **How it is wired:** the Scrapper emits `struck`, the arena connects it to the player. The Scrapper never touches the player's health directly.

## D-008: Final art source (Revisited, 2026-11-13)

Was: SpriteCook Pixel Engine, proposed. Now: Sasha wants a three-way test first, SpriteCook vs ChatGPT Images vs Klad, against the Nano Banana placeholders as the baseline. Three sprites per tool, scorecard in `art/PROMPTS.md`. Guidebook decision `d2-final-art-source` stays open until the scorecard is filled in.

## D-007: itch draft (Made, 2026-11-13)

Decided in chat: upload now. The first `butler push` to `kingriot/seedshot:html5` was refused because the game page did not exist; butler cannot create one. Sasha created the page and build `07c75f4` went up on 2026-11-13. Each later push still needs a yes.

## D-006: Touch controls (Made, 2026-11-13)

Asked for in chat: touch friendly without changing core gameplay. Left-half slide moves, right-half slide aims and fires while held, a quick tap on a tree is the vine.

- **Why sticks, not tap-to-aim:** a finger on the target hides the target. Seed pods only need a direction.
- **Why tap-versus-slide:** a touch is a tap or a stick, never both, so trees under the thumbs can still be tapped.
- **What stayed the same:** the touch layer presses the normal move actions and calls the same `fire` and `try_vine` code. Speeds, cooldowns, range and stop-short are untouched.
- **What differs:** movement is any angle (keyboard is 8 directions), aim is a direction (mouse is a point), and the tap radius is 1.5 cells (mouse is 0.9).
- **Cut-list note:** DESIGN.md lists touch as the third thing to cut. It is one node, `Hud/TouchControls`; deleting it removes the feature.

## D-005: Placeholder sprites in the gray box (Made, 2026-11-13)

The kickoff said no art, but placeholders were supplied in the same message. Player and Scrapper use them. Clearing the two textures in `config/game_config.tres` brings the rectangles back.

## D-004: Debug respawn (Made, 2026-11-13)

With one Scrapper and no waves there is nothing to do after the first kill. A new one walks in after `debug_respawn_delay` (2 s; 0 turns it off). Real waves replace this.

## D-003: Seal guard behaviour (Made, 2026-11-13)

DESIGN.md says a sapling that would cut the player off from the arena centre stays non-solid. Built as: it stays a sapling permanently (no later retry). Separately, a sapling someone is standing on waits 0.25 s and tries again, so nobody is trapped inside a tree.

## D-002: Vine latches the first tree on the line (Made, 2026-11-13)

If another tree stands between the bot and the clicked tree, the vine grabs the nearer one. A wall in the way means no latch. This keeps the zip an honest straight line.

## D-001: One config resource (Made, 2026-11-13)

From the kickoff. `config/game_config.tres` holds every speed, cooldown and size, so tuning never needs a code edit.

## D-030 (s14): floor tiles and rooftops from the concept art

- **Floor:** nine 48 px slabs, built by `tools/floor_tiles.ps1`: it cuts slabs out of Sasha's combined concept sheet
  and Klad's `pixelize` shrinks each one into the game palette. Three plain slabs fill most cells; six detail slabs
  (crater, moss, puddle, oil, grate, hatch) appear in about 1 in 14 cells. The pick is a hash of the cell's x and y,
  so the floor never reshuffles. The grid lines are gone: each slab has its own dark edge.
- **Two floor-only steel steps** (`floor_palette.ops.jsonl`). Without them the slab's light bevel snapped to teal.
- **Homes:** one roof unit (52 x 32, from `03_wall_and_homes_b`, built by `tools/home_roofs.ps1`) over each of the
  24 windows, packed edge to edge (24 x 52 = 1248, the arena's width). A home is 2 or 3 units with a dark seam
  between homes; the game draws the brick front wall and the two-pane windows itself so each window still lights
  on its own. Spread-out homes (the first try) left more bare wall than homes.
- The concept's dark and lit strips do not line up (the lit one is 7 px taller), so the lit strip is not used.
- PowerShell gotcha: variable names ignore case, so `$TILE` and `$tile` are the same variable.

## D-031 (s14): sunroot sprites, and light from sources

- **Trees** are sprites now (`tools/tree_sprites.py`, from `04_sunroot_f`): sapling, grown, and a "cut" picture a
  grown tree shows once a Sawbot has bitten it (it replaces the shrinking circle). Klad's `pixelize` kept the
  painted leaves as speckle, so the script does its own shrink: keep the big patches, fill holes, mode filter,
  snap to the palette without teal, 1-pixel outline. A "big" tree is built too but not used yet.
- **Lighting follows `06_light_progression_h`:** the night tint now follows `light_level ^ ambient_curve` (2.5), so
  it barely moves until the last waves; the middle of the run is lit by pools: bigger window spills, the trees, and
  **lantern strings** (`scripts/lanterns.gd`) that go up after waves 5, 8 and 10.
- **Light boost:** the night tint dims lights too, so pools are drawn with colour values above 1. The boost fades
  to 1.0 as the lot reaches full light; without that, the last wave turned the bottom of the screen into glare.
- Graffiti line 1 is "KEEP THE LIGHTS ON!" (Sasha), matching the chosen key art `07_key_art_g`.

## D-032 (s15): Lucky, story step 3

- **The cat's gift** is now the clamp and a spare fuse (Sasha's redesign); paired pods are gone. The vine zips to
  trees from the start; binding a machine needs the clamp. The fuse saves Seven once (back up at `fuse_revive_hp`
  with a long blink) and is refitted only by `revive()`, which runs on a real defeat; clearing a wave never refits it.
- **Talking to Lucky:** E near the open shop (`lucky_talk_range_cells`) or a tap on the shop. Greeting by the wave
  the cat was found in; small talk by the wave being played, cycling. Lines live in the config; `lucky_lines.gd`
  picks them. Words only.
- **KNOCK x3:** from `knock_hint_wave` (3), a pink floor arrow points at a still-shut shop.
- Controls line now reads "Right click: zip to a tree" (binding is announced by Lucky's banner).

## D-033 (s15): Canopy FM, story step 4

- Three stations generated with the ElevenLabs music API (`tools/gen_music.ps1`): Rooftop Lo-fi (default), Block Dub,
  Switch-On Chip. 90 s each, looped. The station picker lives in New Game + (unlocked by a win).
- `CanopyFM` autoload: its own "Music" bus feeding Master (so M mutes it) with a low-pass filter. The cutoff climbs
  from 500 Hz to 16 kHz with the light level, on a multiplying scale; a felled tree drops it back to muffled and
  6 dB quieter for 2.5 s. One recording, filtered: generated tracks would not line up as stems.
- PowerShell gotcha: two values for a `[string[]]` parameter need the name, `-Names dub,chip`; a second bare word
  goes to the next parameter.

## D-034 (s15): spray-paint lettering, Seven, tap points, title screen and New Game +

- **Graffiti** uses Permanent Marker (Apache 2.0, already shipped with Klad, so nothing was downloaded) with a soft
  overspray outline. Sasha rejected pasted-on lettering in the concepts; the built-in font looked exactly like that.
- **Seven** is drawn by `tools/seven_sprite.py` in the locked design and mirrors left/right with the aim instead of
  spinning (a standing robot spinning on the spot reads wrong).
- **Tap points (story step 5):** from wave 2, two soil patches (gold ring, so they read at night) per wave. A tree
  grown on one is a tap tree: +3 windows while standing, heals 1 pip, 2x HP, gold tint; restarts replant it as one.
- **Title screen** is now the main scene (07_key_art_g behind it). A finished run returns to it.
- **New Game +** (`RunState` autoload, saved to `user://seedshot.cfg`): unlocked by any win. 1.5x machines per
  wave (rounded up), sent 1.5x faster, no staged tutorial. Trees grown at a wave's start that still stand when it is
  cleared mature into **great sunroots** (stage 4: 3x HP, wider glow, the big tree picture). The Canopy FM station
  picker appears on the title screen once unlocked.
- Not yet decided: the New Game + mechanic that makes great sunroots worth planning for (brainstorm sent to Sasha).

## D-035 (s16): Sasha's 10-point list of 2026-11-18

- **Hidden cat (item 4):** the KNOCK x3 floor arrow is gone. The shop is painted in the wall's own colours with
  the wall's bricks across its front; the only tells are amber cat eyes that blink between the slats every 7 s, a
  faded paw print, and Canopy FM's hints. A win unlocks New Game + whether or not Lucky was found (item 5; it
  already worked, now it has a check).
- **Radio (items 2 and 3):** the centred story line is replaced by a radio panel at the top left. Helios's wave
  notices arrive as a red "HELIOS UTILITIES :: PUBLIC NOTICE" broadcast with static in the letters. Canopy FM's DJ
  (weak signal, bars grow with the light) is the tutorial: move and shoot on wave 1, cover and the vine when the
  first machine roots, Sawbots and the Heart Tree on the first Sawbot, the new machines when they first appear,
  and lucky-cat hints on waves 2, 4, 6 and 8 while the shop is shut. Tips play once per run and are skipped in
  New Game +, which gets a great-sunroot briefing instead. Keyboard or touch wording is picked by device.
- **Trellis (item 6, DESIGN.md):** a zip that starts beside one tree and ends at another leaves the vine strung
  between them for 6 s; each machine crossing it is bound once for 2 s. Always on (it was planned as an upgrade;
  Long Trellis is now the upgrade).
- **Heart Tree (item 6, guidebook d4):** a 5x-HP tree in the middle of the lot. Sawbots judge it 2.5x closer than
  it is, so they go for it first. If it falls the wave restarts; it heals between waves.
- **Great sunroot powers (item 10, both):** Canopy line: two great sunroots within 8 cells with a clear view
  string a cable that binds the first machine crossing it for 2.5 s, then recharges for 4 s. Sunburst: zipping to a
  great sunroot stuns every machine within 3.5 cells for 3 s and deals 1 damage; 8 s shared cooldown.
- **Upgrades and new machines (item 9):** after every wave but the last, pick 1 of 3 cards (keys 1/2/3 or a
  click/tap) and the next wave waits for it: Seed Pouch, Heavy Seeds, Thick Plating, Hardwood, Quick Roots, Long
  Trellis. To answer them: Linebreakers (heavy Scrappers: 5 HP, 1.35x size, 0.7x speed, hit for 2) from wave 6
  and Arc Spitters (3 HP, three-shot fan) from wave 7. Waves 6 to 10 are longer, as Sasha allowed.
- **Art pass (items 7 and 8):** faint brick mortar on the three plain walls; props cut from 05_props_b by
  `tools/prop_sprites.py` (meters and Helios notices on the walls, a broken solar panel flat on the floor, and a
  barrel, planter, bike and chair as solid props in the four floor corners). Left out: the lantern string (already
  in), the cable coil (lost its black cable in the cut-out), the glowing-cat shutter and the arrow (both would
  point at Lucky). Lucky beckons (two frames, `tools/lucky_wave.py`) and shows its face on the radio.

## D-036 (s17): the third seed type, Bramble Seed

- **Design:** pods are single-target and the vine is one machine at a time; the missing answer is crowds. A Bramble
  Seed (Q or Space; a "thorns" button on touch) is thrown 5 cells along the aim and grows a 1.5-cell thorn patch
  for 8 s. Machines inside walk at half speed and take 1 damage a second; machines it kills root as usual. Seven
  walks through unharmed. 3 charges, one regrows every 6 s, full again on a restart. The HUD shows "Brambles 2 / 3".
  Canopy FM introduces it on wave 2 (not in New Game +).
- Cable coil prop remade: its dark rubber matched the dark background and was cut away; a lower background
  tolerance for that one prop keeps it. It lies flat on the floor near the top-left.

## D-037 (s18): the web build was completely silent

- **Found in the 2026-11-19 phone playtest:** no music, no sound effects, no radio. It was not the phone and not
  the mute button: the web export sent nothing to the speakers in any browser, on desktop too.
- **Cause:** `canopy_fm.gd` added a "Music" bus with `AudioServer.add_bus()`. The web export plays sounds through
  the browser's own audio engine ("sample" playback), and in Godot 4.7.2 that code inserts the new bus BEFORE
  Master in its list. Master's output is then wired into the Music bus and the Music bus back into Master: a closed
  loop with no way out to the speakers. Desktop builds mix audio themselves and were never affected.
- **Fix:** `CanopyFM.uses_music_bus()` is false on web, so the web build has only the Master bus and the song plays
  straight into it. Desktop keeps the bus and its low-pass filter.
- **Known gap:** bus effects do nothing in a browser, so on web the song does not get clearer as the block lights.
  The quieter moment when a tree is cut still works (it is a volume change, not an effect).
- **How it was measured:** a throwaway page loaded the web export with a meter on the browser's audio output and
  an audio context that starts blocked, as on a phone. Before: peak level 0.0 after tapping Play. After: about 0.2
  with the song alone, back to 0.0 with the speaker button off. Headless checks cannot hear a browser, so re-measure
  like this if another audio bus is ever added.
- **Not verified:** a real phone. The fix has only been measured in a desktop browser emulating one.

## D-038 (s18): Canopy lines are capped, lazy, and let machines go

- **Found in the 2026-11-19 playtest (New Game +):** every surviving tree matures, so the run had 70+ great
  sunroots, and every pair in range strung a cable, checked with a physics ray every step. The game lagged, the
  screen was a web, and one Sawbot was re-snared for two minutes, stalling wave 5.
- **Caps:** a great sunroot holds at most 2 cables (`canopy_line_links_per_tree`) and the lot at most 12
  (`canopy_line_max`). Pairs are taken shortest first, so each tree ties to its nearest neighbours.
- **Lazy:** the cables are worked out only when the forest changes (a tree is planted, grows, is cut, falls or
  matures), not every physics step. Rays are cast only for pairs that would actually get a cable.
- **Immunity:** a machine a Canopy line lets go cannot be caught by any Canopy line for 4 s
  (`canopy_line_immunity_seconds`). Trellis vines and Seven's own bind are not affected.
- **Cards:** the cables are hidden while the upgrade cards are up (they shone through the cards).
- **Not changed:** every surviving tree still matures. If New Game + is still too bright (checklist: "washed
  out"), limiting how many trees mature is the next lever.
- **Not verified:** on a phone, or by eye in a late New Game + run. The checks cover 60 great sunroots headless.

## D-039 (s18): the Heart Tree and tree state are readable

- **Found in the 2026-11-19 playtest ("must fix before I submit"):** Sasha forgot the Heart Tree existed, could not
  tell which tree it was, and could not see when trees were growing.
- **Heart Tree:** a pulsing pink ring and a "HEART TREE" label, drawn on an overlay above the glow, the machines and
  the Canopy lines. For 2 s after each hit both turn red and the label reads "HEART TREE UNDER ATTACK".
- **Radio:** Canopy FM points the Heart Tree out as wave 1 starts (every run, New Game + too), and raises an alarm
  when it is hit, at most once every 12 s. The alarm jumps to the front of the radio queue.
- **Health:** any hurt tree shows a small health bar that shortens and reddens; the Heart Tree's is wider.
- **Growth:** a sapling shows a ring that fills as it roots; becoming a tree (or a great sunroot) is a quick swell
  to 135% and a ring of light.
- All the colours, texts and timings are in the config (`heart_marker_color`, `heart_alarm_*`, `tree_bar_*`,
  `tree_pop_*`, `tree_growth_ring_color`).
- **Seen by eye:** the ring and label, in the web build at 1280 x 720. **Not seen by eye:** the alarm colours, the
  health bar and the pop (covered by headless checks of their state only).

## D-040 (s18): sound round 2

- **Sasha's picks by ear (2026-11-19):** enemy_down, zip, player_down and cat move to take 2. windup is take 2
  played 16% slower (about 3 semitones lower and a little longer) and set 3 dB softer; it is saved as take 3.
- **New candidates, waiting for a pick:** thunk (hollow metallic plink), enemy_down (motor winding down), bind
  (ratchet winding up), spit (soft "pewm" pop), saw (chainsaw), hurt (electric zap, a new direction), wave_clear
  (louder fanfare; its loudness target went from -20 to -16 dB), unlock (take 3 a soft beep, take 4 two clicks).
  16 ElevenLabs generations. `audio/SOUNDS.md` holds the new prompts.
- The thunk and spit candidates came back very quiet (mean below -36 dB) and need a lot of gain; listen for hiss.
- The listening page now plays every take evened out to its in-game loudness.

## D-053: Entrances: gates, drops and an intro clip; title screen; two more numbers (Made, 2026-11-19)

Sasha, after round 2. Not played by a person yet.

- **Gates.** Machines used to appear on a random edge cell. Each side wall now has a gateway on rows 3, 7 and 11 (`gate_rows`, `scripts/gates.gd`). Scrappers, Spitters, Sawbots and a Linebreaker's escorts start inside a gate and slide out onto the cell in front of it (`Enemy.walk_in_from`); the gate's red lamp lights as they come. A gate at least 6 cells from Seven is used if there is one. A tree never grows in a gateway (`_nearest_free_cell(cell, true)`), so the gates cannot be planted shut; if every gateway is somehow blocked, the old edge rule is the fallback. Top and bottom walls have no gates: they are the shop fronts and the homes.
- **Drops.** Linebreakers and Arc Spitters fall in from above onto an open cell at least 5 cells from Seven (`Enemy.drop_in`): the picture falls 460 px over 0.7 s, a shadow grows under it, and on landing there is a dust ring, cracks, a 12 px shake and a crash. The machine does nothing until it has landed.
- **Intro clip.** The first Linebreaker and the first Arc Spitter of a run get a clip (`Arena.start_clip`): 40% speed, the camera pushed in 35% on the landing spot (clamped so it never shows past the picture), black bars, and the machine's name low on the screen, for 2.6 real seconds. Seven can still move and shoot during it. The tests switch clips off (`intro_clips_on`), except the one written for them.
- **Sounds.** `crash`, `drop` and `gate` are generated in code (`Sfx._make_crash`: a low thud, a burst of noise and a few inharmonic ringing tones). A real recording saved as `audio/sfx/crash.mp3` replaces it with no code change. Generating one with ElevenLabs spends credits, so it waits for Sasha's yes.
- **Title screen.** Text on a dark rounded panel with a heavier outline; buttons are 280 x 42 pills in the interface's night, teal and amber palette; the New Game + note moved under its button.
- **Later the same evening.** Sasha said yes to ElevenLabs for the crash: udio/sfx/crash.mp3 is take 2 of 2 (prompt in udio/SOUNDS.md row 16), levelled to -17 dB by 	ools/pick_sfx.ps1. It was chosen by measurement (the louder, fuller take), not by ear. Lucky's shop now hides behind a random shutter front of the back wall each run (Arena.cat_shop_cell, BackWall.shop_cells: cells 6, 10, 16 or 20; the corner front is left out). Per run, not per wave: a shop that moved mid-run would make Canopy FM's hints useless and could move after it was opened.
- **Numbers.** Saplings take 4 s (2 in round 2, 1 before). Long Trellis is renamed **Vine Trip Line** and adds 1.5 s per pick (was 4), still stacking.
## D-052: Playtest round 2: roles, shields, stacking upgrades, Sunburst chain (Made, 2026-11-19)

From Sasha's playtest of build 9daf41a (ten chat notes and the S18 guidebook sheet: too easy, waves too short, hit flash too faint, could not tell what hurt Seven, wave end slow-down too short, Sunburst rings ugly, fuse revive too slight, lights 20% too bright). Built in six commits on `s18-playtest-fixes`; nothing below has been played by a person yet.

- **Upgrades.** Saplings take 2 s (was 1) so Quick Roots has something to speed up. Quick Roots adds 15% to the rooting rate per pick and the picks add up (`upgrade_sapling_rate_gain`; time = base / (1 + 0.15 x picks)). Hardwood is +1, Seed Pouch 10%. Thick Plating became the **Patch Kit**: a random 1 to 3 pip refill and no max health, so it cannot stack; it is not dealt at full health. Sasha wrote "the repair upgrade", and no card was a repair any more, so this reading (the card that used to repair) is Claude's; the old `Player.add_plating` is kept in case max health should come back.
- **Grove rest** heals at 5 s a pip (was 2.5) and only while a wave is being fought: not between waves, not with the cards up, not before the wave's first machine has walked in (`Arena.is_grove_rest_allowed`).
- **Machines.** Every machine has double hit points (Scrapper 2, Spitter 4, Sawbot 6, Arc Spitter 12, Linebreaker 30). The Linebreaker is 30% slower and walks in with three escort Spitters (`linebreaker_escorts`) that stay within `escort_leash_cells` of it; the wave director is told about them (`enemy_added`). Arc Spitters guard the nearest Sawbot the same way. Every Spitter now hides behind a tree or wall while it reloads and steps out `spitter_peek_seconds` before its shot is ready (`Spitter._find_cover`: nearest open cell within 4 cells that a ray to Seven cannot reach). More Scrappers per wave and 9% faster per wave; lone Spitters cut from wave 6 because the escorts replace them. Staged wave 1 now waits for the sapling to grow before sending the Spitter.
- **Look.** The Linebreaker's gold ring and the Arc Spitter's circling sparks are force-field bubbles drawn over the machine (`Enemy._draw_shield`); the bright rim is health left. Arc Spitter shots are lightning (`SpitShot.electric`). Graffiti is one tag per home roof, tilted, see-through, with no black outline (third layout; the two-row band "looked pasted on"). A ready Sunburst is a gold sheen on the great sunroot and a gold pool of light, not a ring with rays; a sapling that has finished growing but cannot turn solid no longer keeps its ring. Tree glow and window spill are down 20%.
- **Sunburst chain.** A Sunburst sets off every great sunroot within `sunburst_chain_range_cells` (4.5) after `sunburst_chain_delay`, and those set off their neighbours; each tree flares once and the chain costs one charge. To keep that from being a screen-wide stun every wave, a tree must stand through 3 waves to become great (was 1) and the lot holds 8 at most (`great_sunroot_waves_needed`, `great_sunroot_max`), oldest first.
- **Feel.** Hit flash is brighter and longer; a hurt Seven shows a red beam with an arrowhead toward the attacker; the wave end slow-down is 1.6 s. Knock-out and fuse revive run in slow motion on a darkened screen (`Arena.start_drama`), only during a wave. The fuse gives a 3 s gold shield that runs down. Seven shows wear in three levels (`Player.wear_level`): scorch, sparks, smoke, then a red warning lamp on the last pip. It is drawn in code; no new sprite frames.

Not done: Seven's sprite turning to face each direction (Sasha's "one thing to fix") needs new art. Open risk: the difficulty jump is large and stacked (double health, escorts, cover, more Scrappers) on top of weaker healing; if it overshoots, pull back `linebreaker_escorts`, the hit points, or `grove_rest_seconds_per_pip` first. The checks now take about 100 s, so `tools/godot.ps1 test` waits 240 s.
## D-051: Hit flash, screen shake and a hurt cue (Made, 2026-11-19)

Checklist rows `hit-read` and `impact`. (1) A machine that survives a hit flashes pale for 0.14 s with a ring closing in on it (`hit_flash_*`), drawn on a child node above the sprite so it does not fight the bound, windup and heavy tints. (2) The playfield shakes: 3 px when a machine goes down, 7 px when Seven is hurt, fading over 0.25 s (`shake_*`; `shake_scale` 0 switches it off). The shake moves the viewport's `canvas_transform`, so the HUD stays still and physics is untouched; a weaker shake never replaces a stronger one. (3) When Seven is hurt the screen tints red for 0.35 s (`hurt_flash_*`, a ColorRect under the HUD) and a red arc on Seven points at what did it for 0.6 s (`hurt_arc_*`): `Player.take_damage` takes an optional `from` position, passed by Scrapper swings and Spitter shots. New signal `Player.hurt`; the arena does the shake and flash ("signal up"). Not done: no new sounds (they cost ElevenLabs credits), and no shake for a pod that only wounds (it would shake constantly at Seven's fire rate). Not seen on screen: headless checks only, so the strengths are a first guess.
## D-050: Harder waves, the aim line, Sunburst on charges (Made, 2026-11-19)

Work-order groups 6, 8 and 9. (6) About a third more Scrappers, Spitters and Sawbots from wave 2 on: 85 machines over a run became 113 (`wave_scrappers`, `wave_spitters`, `wave_sawbots`). Linebreakers and Arc Spitters keep their numbers because D-044 already made them tougher. New Game + keeps its 1.5 times count and pace on top, plus D-044's speed and hit points. Consequence to watch: this stacks with D-044's 20% speed-up, so the regular game is likely more than a third harder; nobody has played it through yet. (8) A fading aim line runs from Seven along the aim to the first wall or tree (`aim_line_*`), a nozzle is drawn over the sprite pointing the same way, and the body leans toward the aim (`aim_lean_radians`) as well as flipping. Both hide while Seven is down or locked by the cards. (9) Sunburst no longer has a hidden 8 s cooldown: Seven gets `sunburst_charges_per_wave` (2) each wave, shown on the HUD once a great sunroot stands; great sunroots wear a gold ring with rays while one is ready; Canopy FM explains it the first wave a great sunroot is standing.
## D-049: Back wall as home fronts; graffiti across the roofs (Made, 2026-11-19)

Sasha: the back wall should look like homes, which also hides Lucky better, and the graffiti should not run sideways up the side walls. `scripts/back_wall.gd` draws thirteen fronts along the top wall, each two cells wide like Lucky's shop: shutters, doors and windows in turn, a few windows faintly lit. Shutter fronts copy the closed shop exactly (colours, slats, bricks, ledge), so the real shop is one shutter among five. Graffiti now sits level in two rows of slots across the roofs of the bottom wall (`Graffiti.line_place`), over a dark backing so it reads on roof tiles. The back wall itself could not take the graffiti because the HUD text sits over it. Seen on screen: the back wall. Not seen: the graffiti on the roofs (needs a cleared wave).
## D-048: A real pause menu (Made, 2026-11-19)

Sasha asked for a traditional pause menu. `scripts/pause_overlay.gd` now draws, over a much darker screen: five buttons on the left (Resume, Restart this wave, Sound effects on/off, Music on/off, Quit to main menu; click, tap or keys 1 to 5) and on the right this run's numbers (mode and wave, homes lit, trees standing, trees planted, health, upgrades, the Canopy FM station) and the controls. Restart and Quit need two presses in a row. A click beside the buttons no longer resumes; P or Esc still does. The overlay signals up (`restart_wave_requested`, `quit_requested`) and the arena acts. Sound effects and music switch separately (`Sfx.effects_on`, `CanopyFM.set_music_on`); M still mutes everything. Not built: saving a run in progress. "Quit" loses the run; only the New Game + unlock is saved, and the menu says so. Seen on screen in a desktop browser; not tried on a phone.
## D-047: Banner wrap, Final notice on wave 10, a radio that queues, and the wave end beat (Made, 2026-11-19)

Work-order group 7. (1) The banner wraps inside a 40 px side margin, and the end screen is one short line each (`end_unlocked_line`, `end_restart_line`, `end_restart_line_touch`), so nothing is cut off. (2) Helios says "Final notice." on wave 10; waves 8 and 9 have new lines. (3) The radio never cuts a line off: `_show_story_lines` now queues behind what is on the air, the same text is never queued twice, a wave clearing no longer wipes the queue, and a new wave drops only Helios notices that had not started. Lucky's answers break in at once (`_radio_interrupt`) and the interrupted line is said again afterwards. Consequence to watch: after a fast wave 1 the tutorial tips can still be playing during wave 2. (4) The last kill of a wave slows the whole game to 30% for 0.9 real seconds (`wave_end_slow_scale`, `wave_end_slow_seconds`, via `Engine.time_scale`), then the cards come up, then the next wave after the usual break. The headless checks switch the beat off except in its own test. Not seen on screen.
## D-046: Knock-out and fuse-revive animations (Made, 2026-11-19)

Sasha asked for a specific animation when Seven is knocked out and a different one for the spare fuse. Both are played in code on the existing picture, so no new art was needed. Knock-out (`knockout_seconds`, 0.9 s): a jolt up, a quarter turn onto its side with a bounce, colour draining to grey, eight sparks flying out. Fuse (`fuse_flash_seconds`, 0.8 s): the picture flashes gold and pops to 1.6 times its size before springing back, with two gold rings bursting outward and a lightning bolt overhead. `Player.revive` stands the picture back up. Not seen on screen: headless checks only.
## D-045: Light follows the forest; Heart Tree label fades; cards lock Seven (Made, 2026-11-19)

Three of Sasha's playtest notes. (1) Changes D-029: cleared waves now decide how much light the block has earned, and the forest decides how much of it shines. Each grown tree counts as its share of health; the earned windows and strength are fully on at `light_trees_per_wave` (4) tree-points per wave cleared (`Arena.forest_share`, `lit_windows_now`, `window_strength_now`), refreshed every 0.4 s. Winning still lights everything. (2) The Heart Tree's ring and label fade once `heart_label_waves` (1) is cleared; it keeps a soft pink glow, and the red alarm label still shows while it is hit. (3) While the upgrade cards are up the screen is dimmed and Seven is parked on a random open cell within 2 cells of the Heart Tree, locked (`Player.park`, `Arena.park_cell`); any open cell is safe because the split guard keeps the floor in one piece. Grove rest was also made easier to see and use after Sasha could not tell it was working: 3 cells and 2.5 s per pip, a filling arc round Seven, a filling pip on the HUD, and small words under a hurt Seven ("Grove 2 / 4", "Repairing").
## D-044: Tougher, faster, recoloured machines (Made, 2026-11-19)

Work-order group 5 merged with Sasha's later notes. Linebreaker 15 hit points (was 5), Arc Spitter 6 (was 3), both 15% faster than before; Scrapper, Sawbot and Spitter 20% faster (144, 108, 120). The Linebreaker ends at about 97 px/s, a third slower than a Scrapper, which also fits the work order's "slower than the others". Looks: Linebreaker is hazard gold with a thick ring that shows its hit points; Arc Spitter is cyan with three circling sparks. New sprites are still wanted later. New Game +: every machine 10% faster and the two heavy kinds 1.5 times the hit points (`Enemy.toughen`). No machine may pass 92% of Seven's speed (`enemy_top_speed_share`).
## D-043: Thick Plating without repair, a health cap, and Grove rest (Made, 2026-11-19)

Work-order group 4, from Sasha's New Game + notes: Thick Plating was the obvious pick every time because it also repaired fully. Now it gives +2 max health (`upgrade_max_hp`) and no repair: the new pips arrive filled, damage already taken stays (`Player.add_plating`). Health stops at `player_hp_cap` = 10; at the cap the card is no longer dealt (`Arena.upgrades_left_out`). The pip row is told where the wave label's text ends and never starts left of it; if it still would not fit before `hud_pips_right_margin` it shrinks (`HealthPips.pip_rect`). Repair moved to Grove rest (`Arena.tick_grove_rest`): a hurt Seven within `grove_rest_radius_cells` (2) of `grove_rest_trees` (4) grown trees of any kind gets 1 pip every `grove_rest_seconds_per_pip` (4 s), with a breathing green glow drawn by the player. It works during a fight and does not need Seven to stand still; stepping out resets the count. Canopy FM explains it the first time Seven is hurt in a run, New Game + included. Tap trees still give a pip. Not seen on screen: the glow and the shifted pip row are covered by headless checks only.
## D-042: Sound round 3 (Made, 2026-11-19)

Sasha's picks by ear: thunk 5, enemy down 3, hurt 4, wave clear 3, unlock 4. Saw is take 4 at half speed (ffmpeg `atempo=0.5`, same pitch, twice as long, saved as take 5) and 3 dB softer (`pick_sfx.ps1` target -28). Still open: bind (takes 5 and 6 blend the whip crack of take 2 with the ratchet of take 4) and spit (takes 5 and 6 are a toy laser, take 7 a cap-pistol shot; two more gunshot takes came back nearly silent and were deleted).
## D-041 (s18): New Game + opens with a wake-up and an optional tutorial

- **Sasha's request (2026-11-19).** Before wave 1 of New Game +, Canopy FM says "You're finally back up! Not sure
  what happened, but we need your help again. Do you remember what to do?" and two buttons appear: Remind me (1) or
  I remember: skip (2). Wave 1 waits for the answer; with none after 12 s it skips.
- **Remind me** switches the tutorial back on for that run: the staged first wave (one machine at a time) and
  Canopy FM's tips. **Skip** is New Game + as before.
- Either way, as wave 1 starts Canopy FM says Helios has sent tougher, faster drones.
- The old greeting "Back again?" was cut from the great-sunroot lines so Seven is not greeted twice.
- New script `scripts/tutorial_offer.gd`; texts and the 12 s are in the config (`ng_plus_*`).
- **Not seen by eye:** the buttons need a saved win to reach, so only headless checks cover them so far.
