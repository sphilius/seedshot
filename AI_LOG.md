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
| 2026-11-14 | Claude Code | Waves and the Sawbot (`scripts/wave_director.gd`, `enemy.gd`, `sawbot.gd`) | Wrote the five-wave timetable, the shared enemy base, the tree-cutting Sawbot and restart-the-wave on defeat, with 43 more checks. |
| 2026-11-14 | Claude Code | Playtest fixes (`scripts/arena_grid.gd`, `pause_overlay.gd`, `health_pips.gd`) | Read the phone playtest answers and screenshots; wrote the split guard that stops trees walling anyone in, the pause screen and the HUD move, with 17 more checks. |
| 2026-11-13 | Claude Code | `art/PROMPTS.md` | Wrote the shared art spec and the generation prompts for the SpriteCook / ChatGPT Images / Klad comparison. |
| 2026-11-13 | Claude Code | `scripts/touch_controls.gd` | Wrote the touch layer (two floating thumb-sticks, tap a tree for the vine) and 21 more checks for it. |
