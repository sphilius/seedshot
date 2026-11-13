# Seedshot: AI-use log

One line per asset or system: tool, date, what it did. This feeds the itch page's AI tool list.

| Date | Tool | Asset or system | What the tool did |
|---|---|---|---|
| 2026-11-12 | Claude | `DESIGN.md` | Helped lock the design (pitch, verbs, waves, hidden cat, 20-hour plan). |
| 2026-11-13 | Image generator (name it here) | `art/source/*.jpg` (cat, gardener-bot, Scrapper x2, Sawbot x2, Spitter x2) | Generated the eight placeholder sprites. They came back as JPGs with a painted checkerboard instead of real transparency. |
| 2026-11-13 | Claude Code | `tools/clean_art.py` -> `art/placeholder/*.png` | Wrote the script that cuts the fake backgrounds out and saves 96 px transparent PNGs. Before/after: `art/source/<name>.jpg` vs `art/placeholder/<name>.png`. |
| 2026-11-13 | Claude Code | Gray-box build (`scripts/`, `scenes/`, `config/`) | Wrote the arena, grid pathfinding (AStarGrid2D), player (move, aim, seed pod, vine zip), Scrapper, kill-to-tree, seal guard, generated beep sounds. |
| 2026-11-13 | Claude Code | `tests/check.gd` | Wrote 60 headless checks covering each kickoff step. |
| 2026-11-13 | Claude Code | `scripts/touch_controls.gd` | Wrote the touch layer (two floating thumb-sticks, tap a tree for the vine) and 21 more checks for it. |
