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
