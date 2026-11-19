"""prop_sprites.py - cut the props from Sasha's props pick (05_props_b) into game sprites.

WHAT
    05_props_b (art/ART_DIRECTION.md) holds a sheet of street props. This script cuts nine of
    them out, shrinks each to game size, snaps it to the game palette, outlines it, and packs
    them side by side into ONE picture, art/sprites/props.png, one 64 x 64 frame per prop, in
    the order of PROPS below. scripts/props.gd draws them by that order, so keep the two in step.

    Left out on purpose: the lantern string (the game already has lanterns), the shuttered shop
    with the glowing cat (it would point straight at Lucky, who must stay hard to find), and the
    painted arrow (Sasha removed floor arrows for the same reason).

HOW
    1. Crop each prop (its box is in the concept's own pixels) and make the background
       see-through: reuse tree_sprites.cut_out, which reads the background colour from the
       crop's corners. The wall-mounted props are cropped tightly inside their grey wall
       square, so the square's grey is what gets removed.
    2. Shrink so its longest side is the prop's `size`, tidy, snap to the palette, outline.

USAGE (from the project root)
    python tools/prop_sprites.py

OUT
    art/sprites/props.png                 9 frames of 64 x 64, left to right
    art/source/klad/props@4x.png          the same at 4x on the floor colour, for looking at

Needs: Pillow, numpy, scipy  (pip install pillow numpy scipy)
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

# Reuse the tree script's cut-out step (same folder).
sys.path.insert(0, str(Path(__file__).resolve().parent))
from tree_sprites import TREE_PALETTE, cut_out  # noqa: E402  (import after the path fix)

ROOT = Path(__file__).resolve().parent.parent
CONCEPT = ROOT / "art/concept/05_props/05_props_b.png"
FRAME = 64

# name: (box in concept pixels: left, top, right, bottom), longest side in game pixels.
# The ORDER matters: it is the frame order in props.png (see scripts/props.gd).
PROPS = {
    "meter":      ((182, 268, 364, 530), 34),   # the Helios meter, red seal on it
    "notice":     ((160, 1011, 334, 1228), 28),  # a Helios notice pasted on the wall
    "notice_x":   ((524, 990, 754, 1247), 30),   # one the block crossed out in red paint
    "planter":    ((958, 287, 1297, 554), 58),   # a wooden planter box of seedlings
    "barrel":     ((1418, 187, 1685, 623), 50),  # a rusty barrel turned into a planter
    "cable":      ((514, 257, 867, 572), 46),    # a coil of cut Helios cable
    "panel":      ((1808, 947, 2242, 1279), 60), # a broken solar panel lying flat
    "bike":       ((2354, 877, 2627, 1359), 56), # a bike, seen from above
    "chair":      ((2263, 230, 2680, 599), 62),  # a folding chair and a card table
}

# The tree palette plus teal and two steel steps (the panel's glass and the meter's casing).
PALETTE = dict(TREE_PALETTE, **{
    "teal": (0x2f, 0x8f, 0x8a), "steel-mid": (0x5f, 0x68, 0x6f), "steel-deep": (0x3a, 0x42, 0x48),
})
MIN_PATCH = 150


def shrink(cutout: Image.Image, longest: int) -> np.ndarray:
    """Shrink one cut-out into a 64 x 64 frame: tidy, palette-snapped, outlined, centred."""
    rgba = np.asarray(cutout).copy()
    solid = rgba[..., 3] > 0
    # Keep the big patches (the prop), drop specks, fill holes inside it.
    patches, count = ndimage.label(solid)
    sizes = ndimage.sum(solid, patches, range(1, count + 1))
    keep = np.isin(patches, [i + 1 for i, size in enumerate(sizes) if size >= MIN_PATCH])
    keep = ndimage.binary_fill_holes(keep)
    rgba[..., 3] = np.where(keep, 255, 0)

    scale = longest / max(cutout.width, cutout.height)
    width, height = max(1, round(cutout.width * scale)), max(1, round(cutout.height * scale))
    small = Image.fromarray(rgba, "RGBA").resize((width, height), Image.BOX)
    colours = small.convert("RGB").filter(ImageFilter.ModeFilter(3))
    small_alpha = np.asarray(small)[..., 3] >= 128

    palette = np.array(list(PALETTE.values()))
    pixels = np.asarray(colours).astype(int)
    distance = ((pixels[:, :, None, :] - palette[None, None, :, :]) ** 2).sum(axis=3)
    snapped = palette[distance.argmin(axis=2)]

    frame = np.zeros((FRAME, FRAME, 4), dtype=np.uint8)
    at_x, at_y = (FRAME - width) // 2, (FRAME - height) // 2
    region = frame[at_y:at_y + height, at_x:at_x + width]
    region[..., :3] = snapped
    region[..., 3] = np.where(small_alpha, 255, 0)
    solid_px = frame[..., 3] > 0
    ring = ndimage.binary_dilation(solid_px) & ~solid_px
    frame[ring] = (*PALETTE["outline"], 255)
    return frame


def main() -> None:
    """Cut every prop, pack them into one strip, and save it plus a big preview."""
    picture = np.asarray(Image.open(CONCEPT).convert("RGB")).astype(int)
    frames = [shrink(cut_out(picture, box), longest) for box, longest in PROPS.values()]
    strip = np.concatenate(frames, axis=1)   # side by side, left to right
    out = ROOT / "art/sprites/props.png"
    Image.fromarray(strip, "RGBA").save(out)

    big = Image.fromarray(strip, "RGBA").resize((strip.shape[1] * 4, FRAME * 4), Image.NEAREST)
    preview = Image.new("RGBA", big.size, (58, 66, 72, 255))
    preview.alpha_composite(big)
    preview.save(ROOT / "art/source/klad/props@4x.png")
    print("built:", out.name, "frames:", ", ".join(PROPS))


if __name__ == "__main__":
    main()
