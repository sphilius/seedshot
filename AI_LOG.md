# Seedshot: AI-use log

One line per asset or system: tool, date, what it did. This feeds the itch page's AI tool list.

| Date | Tool | Asset or system | What the tool did |
|---|---|---|---|
| 2026-11-12 | Claude | `DESIGN.md` | Helped lock the design (pitch, verbs, waves, hidden cat, 20-hour plan). |
| 2026-11-13 | Nano Banana 2 and 2.1 | `art/source/*.jpg` (cat, gardener-bot, Scrapper x2, Sawbot x2, Spitter x2) | Generated the eight placeholder sprites. They came back as JPGs with a painted checkerboard instead of real transparency. |
| 2026-11-13 | Claude Code | `tools/clean_art.py` -> `art/placeholder/*.png` | Wrote the script that cuts the fake backgrounds out and saves 96 px transparent PNGs. Before/after: `art/source/<name>.jpg` vs `art/placeholder/<name>.png`. |
| 2026-11-13 | Claude Code | Gray-box build (`scripts/`, `scenes/`, `config/`) | Wrote the arena, grid pathfinding (AStarGrid2D), player (move, aim, seed pod, vine zip), Scrapper, kill-to-tree, seal guard, generated beep sounds. |
| 2026-11-13 | Claude Code | `tests/check.gd` | Wrote 60 headless checks covering each kickoff step. |
| 2026-11-13 | Claude Code | Health and melee (`scripts/player.gd`, `scrapper.gd`, `health_pips.gd`) | Wrote player hit points, the Scrapper's telegraphed swing, the HUD pips and restart on defeat, with 24 more checks. |
| 2026-11-16 | ElevenLabs Sound Effects | `audio/sfx/*.mp3` (14 sounds) | Generated every sound effect from the prompts in `audio/SOUNDS.md`, 2 takes each. Claude Code wrote the scripts that request them and even out their loudness. |
| 2026-11-16 | Klad (driven by Claude Code) | `art/sprites/*.png` (gardener-bot, Scrapper, Sawbot, Spitter, lucky cat, floor slab) | Drew the final 64 px pixel sprites and the 48 px floor slab from step-by-step recipes in `art/source/klad/`. Before/after: `art/placeholder/<name>.png` vs `art/sprites/<name>.png`. |
| 2026-11-16 | texkit | `art/sprites/floor_tile.png` | Checked that the floor slab repeats without a visible seam (PASS, seam 0.65). |
| 2026-11-15 | Claude Code | Hidden lucky cat, staged wave 1, end screen (`scripts/cat_shop.gd`, `arena.gd`) | Wrote the shuttered shop and its paired-pod reward, the one-at-a-time first wave, the bloom meter and the end-of-run banner, with 34 more checks. |
| 2026-11-15 | Claude Code | Vine bind and waves 6 to 10 (`scripts/enemy.gd`, `player.gd`, `config/game_config.gd`) | Wrote the vine's yank-and-bind on machines and extended the wave lists to ten, with 18 more checks. |
| 2026-11-15 | Claude Code | The Spitter (`scripts/spitter.gd`, `spit_shot.gd`) | Wrote the ranged enemy, its shot and the wave reshuffle, with 19 more checks. |
| 2026-11-14 | Claude Code | Waves and the Sawbot (`scripts/wave_director.gd`, `enemy.gd`, `sawbot.gd`) | Wrote the five-wave timetable, the shared enemy base, the tree-cutting Sawbot and restart-the-wave on defeat, with 43 more checks. |
| 2026-11-14 | Claude Code | Playtest fixes (`scripts/arena_grid.gd`, `pause_overlay.gd`, `health_pips.gd`) | Read the phone playtest answers and screenshots; wrote the split guard that stops trees walling anyone in, the pause screen and the HUD move, with 17 more checks. |
| 2026-11-13 | Claude Code | `art/PROMPTS.md` | Wrote the shared art spec and the generation prompts for the SpriteCook / ChatGPT Images / Klad comparison. |
| 2026-11-13 | Claude Code | `scripts/touch_controls.gd` | Wrote the touch layer (two floating thumb-sticks, tap a tree for the vine) and 21 more checks for it. |
| 2026-11-16 | Claude Code | Mute and halfway marker (`scripts/sfx.gd`, `pause_overlay.gd`, `arena.gd`) | Wrote the M-key and speaker-button mute and the wave 5 "stop and rate" banner line, with 10 more checks. |
| 2026-11-16 | Claude Code | Story spine and words (`STORY.md`, `scripts/graffiti.gd`, `arena.gd`, `config/game_config.gd`) | Brainstormed premises with Sasha, wrote the spine Sasha edited, then wrote the Helios lines, wall graffiti, opening line and end screen, with 16 more checks. |
| 2026-11-16 | Claude Code | Night look and windows (`scripts/glow.gd`, `block_windows.gd`, `arena.gd`, `forest_tree.gd`) | Wrote the dark palette, tree and lamp glows, the block's windows, the wave 8 block-lit moment and the next-block ending, with 15 more checks. |
- Floor tiles (s14): 9 slabs pixelized by Klad from Sasha's Gemini concept sheet 02_floor_sheet_final (tools/floor_tiles.ps1), snapped to the game palette plus two floor-only steel steps.
- Home roofs (s14): six roofs pixelized by Klad from Sasha's Gemini concept 03_wall_and_homes_b (tools/home_roofs.ps1), in narrow and wide versions; the game draws the front walls and windows.
- Tree sprites (s14): sapling, grown, cut and big, cut out of Sasha's Gemini concept 04_sunroot_f and shrunk to 64 px by tools/tree_sprites.py (palette snap, speckle filter, outline).
- Canopy FM (s15): three 90 s songs (lofi, dub, chip) generated with the ElevenLabs music API by tools/gen_music.ps1; played by the CanopyFM autoload through a low-pass filter that opens as the block lights.
- Seven sprite (s15): drawn shape by shape by tools/seven_sprite.py in Sasha's locked design (the robot in her Gemini concept 07_key_art_b); faces the viewer and mirrors to follow the aim.
- Title screen + New Game + (s15): title art is Sasha's Gemini key art 07_key_art_g, cropped to 1280x720; NG+ unlocks after a win (saved in user://), +50% machines sent 50% faster, great sunroots, Canopy FM station picker.
- Radio panel (s16): Helios broadcasts and the Canopy FM DJ tutorial and cat hints; the lines are written in the config with Claude Code from Sasha's direction.
- Props (s16): nine props cut from Sasha's Gemini concept 05_props_b by tools/prop_sprites.py (palette snap, outline); eight are placed in the lot.
- Lucky wave frame (s16): tools/lucky_wave.py moves the raised paw of the existing Klad sprite down 5 px for a two-frame beckon.
- Great sunroot powers, Trellis, Heart Tree, upgrades, Linebreakers and Arc Spitters (s16): game code by Claude Code from Sasha's design list.
- Bramble Seed (s17): the third seed type, game code by Claude Code from Sasha's request (design proposed by Claude, see DEVLOG D-036).
- Tree overlay (s18): Heart Tree ring and label, tree health bars, sapling growth ring and grow pop, drawn in code by Claude Code from Sasha's playtest notes (see DEVLOG D-039).

- Sound round 2 (s18): 16 new ElevenLabs Sound Effects takes (thunk, enemy_down, bind, spit, saw, hurt, wave_clear, unlock) from prompts written by Claude Code to Sasha's notes; windup take 3 is take 2 slowed with ffmpeg. Sasha picks by ear.
- New Game + opening (s18): wake-up line, Remind me / Skip buttons (scripts/tutorial_offer.gd) and the tougher-drones line; code by Claude Code, wording from Sasha.
- Sound round 3 (s18): 5 more ElevenLabs Sound Effects takes (bind 5-6, spit 5-7) from prompts by Claude Code; saw take 5 is take 4 slowed with ffmpeg. Picks by Sasha.
- Grove rest, health cap and Thick Plating change (s18): code by Claude Code to Sasha's design (scripts/arena.gd, player.gd, health_pips.gd).
- Machines, light and cards (s18): Linebreaker ring and Arc Spitter sparks drawn in code, forest-driven window light, Heart Tree glow, upgrade-card lock; code by Claude Code to Sasha's playtest notes. Spit take 5 and bind take 5 picked by Sasha.
- Knock-out and fuse-revive animations (s18): tweened in code by Claude Code (scripts/player.gd), no new art.
- Group 7 (s18): banner wrap, radio queue and wave end slow-down in code by Claude Code; new Helios lines for waves 8 and 9 written by Claude Code.
- Pause menu (s18): buttons, run stats and controls list drawn in code by Claude Code (scripts/pause_overlay.gd).
- Back wall fronts and roof graffiti (s18): drawn in code by Claude Code (scripts/back_wall.gd, graffiti.gd), no new art.
- Aim line, Sunburst charges and wave counts (s18): code and numbers by Claude Code to Sasha's work order.
- Plink (s18): the metallic thunk take 5 (ElevenLabs) reused as a new 'plink' sound for pods hitting machines; thunk is back on take 3. Sasha's call.
- Itch cover and screenshots (s18): cover cropped from the title art with the logo by tools/make_cover.py; three staged 1280 x 720 screenshots taken in the real arena by tests/capture_shots.gd. Both written by Claude Code.
- Upgrade card icons (s18): six 64 px icons (seed pouch, heavy seeds, thick plating, hardwood, quick roots, long trellis) drawn with Klad 0.2.0 by a Claude Code subagent from art/source/klad/upgrades/make_upgrade_icons.py, in the game's 12-colour palette. Placeholders until Sasha's own art.
- Hit flash, screen shake and hurt cue (s18): code and numbers by Claude Code from Sasha's playtest notes (hit-read, impact). No new assets.
- Playtest round 2 (s18): machine roles and cover AI, force-field shields, lightning shots, roof graffiti tags, Sunburst chain, wear and tear on Seven, slow-motion knock-out and fuse revive: code and numbers by Claude Code from Sasha's playtest notes. No new assets; staged screenshots in itch/ retaken.
