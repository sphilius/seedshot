"""OBSOLETE since s24: Seven was redesigned (emerald Engineer) and its pixel strip now comes from
tools/gen_seven_sprites.py. DO NOT RUN THIS FILE: it would overwrite the new sprites with the old teal
cream-dome robot. Kept as history.

seven_sprite.py - draw Seven, the player's robot, in Sasha's locked design.

THE LOCKED DESIGN (art/ART_DIRECTION.md, the robot in concept 07_key_art_b)
    A cream dome head with a teal stripe and two small dark rectangular eyes; a teal barrel
    body with a cream chest patch and a cream band at the waist; round teal shoulder joints;
    short arms; small stumpy legs (no tracks, no wheels). It holds a glowing green seedling.

HOW
    The concept robot is too small and its background too busy to cut out, so this script
    draws the sprite directly, shape by shape, on a 64 x 64 grid: each shape is a "mask" (a
    grid of True/False saying which pixels it covers), painted in a game-palette colour.
    Shapes painted later cover earlier ones. Last, every empty pixel touching the robot gets
    the dark outline colour, like the other sprites.

    The robot faces the viewer (high top-down view). The game mirrors it left or right to
    follow the aim; it no longer spins round like the old round bot.

USAGE (from the project root)
    python tools/seven_sprite.py

OUT
    art/sprites/gardener_bot.png         64 x 64, the file the game loads
    art/source/klad/seven@8x.png         the same at 8x, only for looking at

Needs: Pillow, numpy, scipy  (pip install pillow numpy scipy)
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
SIZE = 64

# Game palette (art/source/klad/palette.ops.jsonl), plus two darker steps for shading,
# which the style allows ("darker or lighter steps of them").
OUTLINE = (0x1B, 0x1F, 0x1D)
TEAL = (0x2F, 0x8F, 0x8A)
TEAL_DARK = (0x1F, 0x5F, 0x5C)      # shading step of teal
CREAM = (0xEF, 0xE6, 0xC8)
CREAM_DARK = (0xC9, 0xBE, 0x9C)     # shading step of cream
LEAF_LIGHT = (0x7F, 0xC4, 0x5A)
LEAF_DARK = (0x2F, 0x6B, 0x3A)
RUST_DARK = (0x6B, 0x3A, 0x24)
STEEL_DARK = (0x4A, 0x52, 0x57)

# Pixel coordinates: Y counts down from the top, X counts right from the left.
# np.mgrid gives two 64 x 64 grids: the y and the x of every pixel.
Y, X = np.mgrid[0:SIZE, 0:SIZE]


def ellipse(cx: float, cy: float, rx: float, ry: float):
    """Mask of an ellipse (an oval) centred on (cx, cy) with half-widths rx and ry."""
    return ((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2 <= 1.0


def rect(x: int, y: int, w: int, h: int):
    """Mask of a w x h rectangle whose top-left pixel is (x, y)."""
    return (X >= x) & (X < x + w) & (Y >= y) & (Y < y + h)


def main() -> None:
    """Paint the shapes back to front, outline them, and save."""
    # An RGBA picture: 4 numbers per pixel (red, green, blue, alpha). Alpha 0 = see-through.
    image = np.zeros((SIZE, SIZE, 4), dtype=np.uint8)

    def paint(mask, colour) -> None:
        """Colour every pixel the mask covers, fully solid."""
        image[mask] = (*colour, 255)

    # Legs and feet: short and stumpy.
    for leg_x in (24, 35):
        paint(rect(leg_x, 49, 5, 6), RUST_DARK)
        paint(rect(leg_x - 1, 54, 7, 3), TEAL)
    # Body: a teal barrel, its right side in shadow (light comes from the top left).
    body = ellipse(32, 41, 12, 10)
    paint(body, TEAL)
    paint(body & (X > 37), TEAL_DARK)
    paint(body & rect(20, 47, 24, 3), CREAM)            # the cream band at the waist
    paint(body & rect(20, 47, 24, 3) & (X > 37), CREAM_DARK)
    paint(rect(28, 37, 8, 5), CREAM)                     # the chest patch
    paint(rect(29, 38, 2, 1), STEEL_DARK)                # two small marks on the patch
    paint(rect(32, 38, 3, 1), STEEL_DARK)
    # Shoulders (round teal joints) and short arms.
    paint(ellipse(19, 37, 4, 4), TEAL)
    paint(ellipse(45, 37, 4, 4), TEAL_DARK)
    paint(rect(17, 40, 4, 6), CREAM)                     # left arm, hanging
    paint(rect(44, 40, 4, 4), CREAM_DARK)                # right arm, raised to hold the seedling
    paint(rect(47, 38, 3, 3), CREAM_DARK)                # right hand
    # The glowing seedling in the right hand.
    paint(rect(48, 33, 1, 5), LEAF_DARK)                 # stem
    paint(ellipse(46.5, 32, 2, 1.4), LEAF_LIGHT)         # left leaf
    paint(ellipse(50.5, 31, 2, 1.4), LEAF_LIGHT)         # right leaf
    # Neck: a dark ring between head and body.
    paint(rect(25, 31, 14, 2), STEEL_DARK)
    # Head: a cream dome, shaded lower right, with a teal stripe over the top.
    head = ellipse(32, 20, 15, 12)
    paint(head, CREAM)
    paint(head & ~ellipse(29, 17, 15, 12), CREAM_DARK)   # crescent of shadow on the lower right
    paint(head & (X >= 23) & (X <= 28) & (Y <= 21), TEAL)  # the stripe
    paint(head & (X >= 23) & (X <= 28) & (Y <= 21) & (Y >= 18), TEAL_DARK)
    # Eyes: two small dark rectangles, low on the face.
    paint(rect(27, 22, 3, 5), OUTLINE)
    paint(rect(35, 22, 3, 5), OUTLINE)
    paint(rect(27, 22, 1, 1), CREAM)                     # a glint in each eye
    paint(rect(35, 22, 1, 1), CREAM)
    paint(rect(33, 11, 3, 2), (0xFF, 0xFA, 0xEA))        # shine on the dome

    # The outline: every see-through pixel that touches the robot (above, below, left,
    # right) turns dark. binary_dilation grows the robot's shape by one pixel.
    solid = image[..., 3] > 0
    ring = ndimage.binary_dilation(solid) & ~solid
    image[ring] = (*OUTLINE, 255)

    out = ROOT / "art/sprites/gardener_bot.png"
    Image.fromarray(image, "RGBA").save(out)
    big = Image.fromarray(image, "RGBA").resize((SIZE * 8, SIZE * 8), Image.NEAREST)
    preview = Image.new("RGBA", big.size, (58, 66, 72, 255))   # on the dark floor colour
    preview.alpha_composite(big)
    preview.save(ROOT / "art/source/klad/seven@8x.png")
    print("built:", out.name)


if __name__ == "__main__":
    main()
