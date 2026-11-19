"""lucky_wave.py - make Lucky's second animation frame: the raised paw dipped down.

A maneki-neko (beckoning cat) "waves" by bringing its raised paw down and up again.
This script copies art/sprites/lucky_cat.png and moves the raised paw (a fixed box at the
top right) down by DIP pixels. The game swaps between the two pictures to animate the wave
(scripts/cat_shop.gd). Run it again if lucky_cat.png ever changes.

USAGE (from the project root):   python tools/lucky_wave.py
OUT:                              art/sprites/lucky_cat_wave.png
Needs: Pillow, numpy
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
# The raised paw and forearm: columns 47 to 59, rows 2 to 34 (in the 64 x 64 picture).
PAW_BOX = (47, 2, 60, 35)   # left, top, right, bottom
DIP = 5                     # how many pixels the paw moves down


def main() -> None:
    picture = np.asarray(Image.open(ROOT / "art/sprites/lucky_cat.png").convert("RGBA")).copy()
    left, top, right, bottom = PAW_BOX
    paw = picture[top:bottom, left:right].copy()
    # Clear the paw's old place, then paste it lower down. Only the paw's solid pixels are
    # pasted (alpha > 0), so whatever is behind it (the cat's head edge) stays.
    picture[top:bottom, left:right][paw[..., 3] > 0] = 0
    target = picture[top + DIP:bottom + DIP, left:right]
    solid = paw[..., 3] > 0
    target[solid] = paw[solid]
    Image.fromarray(picture, "RGBA").save(ROOT / "art/sprites/lucky_cat_wave.png")
    print("built: lucky_cat_wave.png")


if __name__ == "__main__":
    main()
