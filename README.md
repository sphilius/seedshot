# Seedshot

Jamference AI Game Jam Hack 4 entry. Godot 4.7, GDScript, Compatibility renderer, web export without threads. The design is in [DESIGN.md](DESIGN.md).

## Controls (gray box)

| Input | Verb |
|---|---|
| WASD or arrow keys | Move |
| Mouse | Aim |
| Left click (hold) | Fire seed pods |
| Right click on a tree | Vine zip to it, stopping one cell short |
| Right click on a machine | Vine yanks it towards you and binds it for 1.5 s |

After the last wave, R or Enter starts a fresh run.

Pause with P or Esc, or the two-bar button in the top-right corner.

The green squares at the top centre are your hit points. A Scrapper glows red just before it swings: get out of its reach and the swing misses.

The itch page is `kingriot/seedshot` (channel `html5`).

### Playable builds on GitHub

Each web build is attached to a GitHub Release as a zip (the newest: [web-4e0fa3f](https://github.com/sphilius/seedshot/releases/tag/web-4e0fa3f)). Unzip it, run `python -m http.server 8079` inside the folder, and open http://127.0.0.1:8079. Opening `index.html` directly does not work: browsers block the game files from a `file://` address.

`.\tools\publish_pages.ps1` also puts the build on the `gh-pages` branch, ready for GitHub Pages. Pages does not serve it yet: on the current GitHub plan, Pages needs the repo to be public.

### Touch (phones and tablets, landscape)

| Input | Verb |
|---|---|
| Slide a thumb on the left half | Move |
| Slide a thumb on the right half | Aim, and fire while held |
| Quick tap on a tree | Vine zip to it |
| Quick tap on a machine | Vine yank and bind |

Touch switches on at the first finger and off again when a real mouse moves. It is one node (`Hud/TouchControls` in `scenes/arena.tscn`); delete that node to remove touch support.

## Commands (PowerShell, from this folder)

```powershell
.\tools\godot.ps1 editor    # open the project in Godot
.\tools\godot.ps1 test      # headless checks; prints "N passed, M failed"
.\tools\godot.ps1 export    # web build -> build\web\index.html
python tools\serve_web.py   # play the web build at http://127.0.0.1:8079
.\tools\publish_pages.ps1   # copy build\web onto the gh-pages branch and push it
python tools\clean_art.py   # re-cut art\source\*.jpg into art\placeholder\*.png
```

On a fresh clone run `.\tools\godot.ps1 import` once first.

## Where things live

| Path | What |
|---|---|
| `config/game_config.tres` | Every tunable (speeds, cooldowns, tree HP, zip speed). Edit in the Inspector. |
| `scripts/arena.gd` | The arena: owns the grid, spawns trees, pods and Scrappers. |
| `scripts/arena_grid.gd` | Grid maths, pathfinding, and the seal guard. No nodes, so it is easy to test. |
| `scripts/player.gd` | Move, aim, fire, vine. |
| `scripts/forest_tree.gd`, `seed_pod.gd` | One script per thing in the arena. |
| `scripts/enemy.gd` | What every machine shares: health, dying into a tree, walking a route. |
| `scripts/scrapper.gd`, `spitter.gd`, `sawbot.gd` | The three machines. All extend `enemy.gd`. |
| `scripts/spit_shot.gd` | The Spitter's shot. Trees stop it. |
| `scripts/cat_shop.gd` | The hidden lucky cat (the jam's mandatory restriction). |
| `scripts/wave_director.gd` | When each machine walks in and when a wave is over. Wave sizes are lists in the config. |
| `scripts/touch_controls.gd` | Thumb-sticks and tap-to-vine. Drives the same verbs as mouse and keyboard. |
| `scripts/sfx.gd` | Generated beeps and the browser audio unlock (autoload `Sfx`). |
| `tests/check.gd` | The headless checks. |
| `scripts/health_pips.gd` | The hit-point squares on the HUD. |
| `art/PROMPTS.md` | The art spec and the paste-ready prompts for the generator comparison. |
| `art/source/` | Raw generated images (ignored by Godot). |
| `art/placeholder/` | The first placeholder sprites. No longer loaded; kept for the before/after picture. |
| `art/sprites/` | The sprites the game loads. Rebuild them with `.\tools\klad_art.ps1`. |
| `art/source/klad/` | The drawing recipe for each sprite (one step per line). |
| `AI_LOG.md` | AI-use log for the itch page. |
