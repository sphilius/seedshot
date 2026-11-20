# 128-class art (s25 drafts, s26 picks)

Every sprite in the game, redrawn at TWICE its size (64 px characters -> 128 px; 48 px floor tiles -> 96 px;
52 x 32 roofs -> 104 x 64) by `tools/gen_128.py`. `.gdignore` keeps Godot from importing or exporting this folder.

- `sprites/` : the finished sheets and strips, named exactly like `art/sprites/`. Since s26 these ARE the game's
  art: `python tools/gen_128.py install` copies them over `art/sprites/`.
- `source64/` : the 64 px originals the tool starts from (the game no longer has them; git history does too).
- `compare_<group>.png` : the 64 px original doubled on the left, the two 128 px takes on the right.
- `picks_all.png` : every finished sheet on one page (`python tools/gen_128.py picks`).
- `strip_check.png` : Seven's 8 facings (top) and the no-nozzle "aiming" strip (bottom), from s25.
- `raw/` what the model drew, `parts/` the snapped pieces, `refs/` what the model was shown.

Picks live in `DEFAULT_PICKS` at the top of `tools/gen_128.py` (take 1 unless listed). One-off override:
`python tools/gen_128.py build --pick name=take ...`. The build also repaints Seven's hat cream-and-gold,
takes the nozzle's outline out of the aiming strip, smooths the roofs and puts the repair icon's sprout back.

Order after changing a pick: `build`, `picks` (look), `install`, then `.\tools\godot.ps1 import`.
