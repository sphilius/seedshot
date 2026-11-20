# 128-class art drafts (s25)

Every sprite in the game, redrawn at TWICE its size (64 px characters -> 128 px; 48 px floor tiles -> 96 px;
52 x 32 roofs -> 104 x 64) by `tools/gen_128.py`. **Not wired into the game.** `.gdignore` keeps Godot from
importing or exporting this folder.

- `sprites/` : the finished sheets and strips, named exactly like `art/sprites/` (swap-ready).
- `compare_<group>.png` : the 64 px original doubled on the left, the two 128 px takes on the right.
- `strip_check.png` : Seven's 8 facings (top) and the no-nozzle "aiming" strip (bottom).
- `raw/` what the model drew, `parts/` the snapped pieces, `refs/` what the model was shown.

Default pick is take 1 of every piece, except `seven_e` = take 2 (so East matches West's seed tank).
Rebuild with `python tools/gen_128.py build --pick name=take ...`.
