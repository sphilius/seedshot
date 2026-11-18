"""tree_sprites.py - build the sunroot tree sprites from Sasha's concept art.

WHERE FROM
    art/concept/04_sunroot/04_sunroot_f.png shows four stages of the tree side by side on a
    flat dark blue-grey background: sapling, grown, cut (almost sawn through), big.

WHAT IT DOES (for each stage)
    1. Cut the stage's box out of the concept picture.
    2. Make the background see-through: flood-fill inward from the box's border through every
       pixel close to the background colour. The tree's dark outline stops the flood, so dark
       pixels INSIDE the tree survive. The soft glow around the tree goes too: the game adds
       its own glow (scripts/glow.gd).
    3. Shrink it to sprite size, smooth out lone noisy pixels, snap every pixel to the game's
       palette (without teal), and draw a 1-pixel dark outline like the other sprites.
       (Klad's own `pixelize` was tried first: it kept the painted leaf texture as speckle.)

    All stages are shrunk by the SAME amount, so a sapling stays small next to a grown tree.

USAGE (from the project root)
    python tools/tree_sprites.py

OUT
    art/sprites/tree_<stage>.png             64 x 64 (the big tree a little more), the files the game loads
    art/source/klad/tree_sprites@8x.png      all stages side by side at 8x, only for looking at

Needs: Pillow, numpy, scipy  (pip install pillow numpy scipy)
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
CONCEPT = ROOT / "art/concept/04_sunroot/04_sunroot_f.png"

SPRITE = 64            # sprite canvas, in pixels (the game draws every sprite at 64 x 64)
# Concept pixels -> game pixels. The grown tree's box is 421 concept pixels tall, so this makes
# it 58 pixels tall: nearly the whole 64 px canvas, with room for the outline.
SCALE = 58.0 / 421.0
# How far (sum of the R, G and B differences) a pixel may be from the background colour and
# still count as background. The tree's darkest outline is about 110 away, so 90 keeps it.
BACKGROUND_TOLERANCE = 90

# Each stage's box in the concept picture: (left, top, right, bottom), measured from the picture.
STAGES = {
    "sapling": (52, 414, 294, 644),
    "grown":   (351, 223, 703, 644),
    "cut":     (754, 227, 1108, 646),
    "big":     (1131, 168, 1612, 665),
}


def cut_out(picture: np.ndarray, box: tuple) -> Image.Image:
    """Steps 1 and 2: crop one stage and make its background see-through."""
    left, top, right, bottom = box
    crop = picture[top:bottom, left:right]
    # The background colour is read from the crop's corners (they are always background).
    corners = np.concatenate([crop[:6, :6], crop[:6, -6:], crop[-6:, :6], crop[-6:, -6:]]).reshape(-1, 3)
    background = np.median(corners, axis=0)
    near_background = np.abs(crop - background).sum(axis=2) < BACKGROUND_TOLERANCE
    # ndimage.label gives every connected patch of near-background pixels its own number.
    # The patches that touch the border are the real background; the rest are inside the tree.
    patches, _count = ndimage.label(near_background)
    border = np.unique(np.concatenate([patches[0], patches[-1], patches[:, 0], patches[:, -1]]))
    see_through = np.isin(patches, border[border > 0])
    alpha = np.where(see_through, 0, 255).astype(np.uint8)
    return Image.fromarray(np.dstack([crop.astype(np.uint8), alpha]), "RGBA")


# The game palette, minus teal: in the concept the leaves' blue-green shading lies closest
# to teal, which turned the trees speckly. Every colour here is from art/source/klad/palette.ops.jsonl.
TREE_PALETTE = {
    "outline": (0x1b, 0x1f, 0x1d), "leaf-dark": (0x2f, 0x6b, 0x3a), "leaf-light": (0x7f, 0xc4, 0x5a),
    "gold": (0xe8, 0xb9, 0x3a), "cream": (0xef, 0xe6, 0xc8), "rust-dark": (0x6b, 0x3a, 0x24),
    "rust-mid": (0xa6, 0x5a, 0x2e), "rust-light": (0xd0, 0x8a, 0x4a), "steel-dark": (0x4a, 0x52, 0x57),
    "steel-light": (0x9a, 0xa5, 0xa8), "enemy-red": (0xe0, 0x41, 0x2f),
}
# Patches of the cut-out smaller than this (in concept pixels) are stray glow, not tree.
MIN_PATCH = 400


def shrink(name: str, cutout: Image.Image) -> Path:
    """Step 3: shrink the cut-out to sprite size, tidy it, snap it to the palette, outline it."""
    rgba = np.asarray(cutout).copy()
    solid = rgba[..., 3] > 0
    # Keep only the big patches (the tree), drop small floating specks of glow, then
    # fill any holes inside the tree. ndimage.label numbers each separate patch.
    patches, count = ndimage.label(solid)
    sizes = ndimage.sum(solid, patches, range(1, count + 1))
    keep = np.isin(patches, [i + 1 for i, size in enumerate(sizes) if size >= MIN_PATCH])
    keep = ndimage.binary_fill_holes(keep)
    rgba[..., 3] = np.where(keep, 255, 0)

    # Shrink. Image.BOX makes each new pixel the plain average of the area it covers.
    width, height = round(cutout.width * SCALE), round(cutout.height * SCALE)
    small = Image.fromarray(rgba, "RGBA").resize((width, height), Image.BOX)
    # ModeFilter(3) sets each pixel to the most common colour around it: lone noisy pixels go.
    colours = small.convert("RGB").filter(ImageFilter.ModeFilter(3))
    small_alpha = np.asarray(small)[..., 3] >= 128          # at least half solid = keep

    # Snap every pixel to the nearest palette colour (smallest squared RGB distance).
    palette = np.array(list(TREE_PALETTE.values()))
    pixels = np.asarray(colours).astype(int)
    distance = ((pixels[:, :, None, :] - palette[None, None, :, :]) ** 2).sum(axis=3)
    snapped = palette[distance.argmin(axis=2)]

    # Place it on the canvas: centred left to right, standing 2 px above the bottom. The canvas
    # is 64 x 64 unless the stage is too big for it (the big tree), then just big enough.
    size = max(SPRITE, max(width, height) + 4)
    canvas = np.zeros((size, size, 4), dtype=np.uint8)
    at_x, at_y = (size - width) // 2, size - 2 - height
    region = canvas[at_y:at_y + height, at_x:at_x + width]
    region[..., :3] = snapped
    region[..., 3] = np.where(small_alpha, 255, 0)

    # A 1-pixel dark outline: every see-through pixel that touches a solid one.
    solid_px = canvas[..., 3] > 0
    ring = ndimage.binary_dilation(solid_px) & ~solid_px
    canvas[ring] = (*TREE_PALETTE["outline"], 255)

    out = ROOT / f"art/sprites/tree_{name}.png"
    Image.fromarray(canvas, "RGBA").save(out)
    return out

def main() -> None:
    """Build every stage's sprite, then one side-by-side preview for checking by eye."""
    # np.asarray turns the picture into a grid of numbers: picture[y, x] = [R, G, B].
    # .astype(int) allows negative numbers, needed when colours are subtracted.
    picture = np.asarray(Image.open(CONCEPT).convert("RGB")).astype(int)
    # A list comprehension: run cut_out then shrink for each (name, box) pair in
    # STAGES, and collect the results into a list. .items() yields those pairs.
    outputs = [shrink(name, cut_out(picture, box)) for name, box in STAGES.items()]

    # One preview: every stage side by side at 8x on the game's dark floor colour.
    sprites = [Image.open(path).convert("RGBA") for path in outputs]
    tallest = max(s.height for s in sprites) * 8
    preview = Image.new("RGBA", (sum(s.width for s in sprites) * 8, tallest), (58, 66, 72, 255))
    x = 0
    for sprite in sprites:
        big = sprite.resize((sprite.width * 8, sprite.height * 8), Image.NEAREST)
        preview.alpha_composite(big, (x, tallest - big.height))   # all standing on one ground line
        x += big.width
    preview.save(ROOT / "art/source/klad/tree_sprites@8x.png")
    print("built:", ", ".join(p.name for p in outputs))


if __name__ == "__main__":
    main()
