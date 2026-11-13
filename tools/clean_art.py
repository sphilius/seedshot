"""clean_art.py - turn AI-generated "fake transparent" JPGs into real transparent PNGs.

THE PROBLEM THIS FIXES
    Image generators often paint a grey/white checkerboard (or a flat colour) behind a
    sprite instead of giving it real transparency, and then save it as a JPG, which has
    no alpha channel at all. Dropped into a game, the sprite shows up inside a square of
    checkerboard.

HOW IT WORKS (one image at a time)
    1. Look at the outer frame of the picture to learn the 1 or 2 background colours.
    2. Mark every pixel that is close to one of those colours as "background-like".
    3. Flood-fill inwards from the picture's border through background-like pixels.
       The sprite's dark outline stops the flood, so cream/white/grey areas INSIDE the
       sprite survive even when they are the same colour as the background.
    4. Also remove enclosed pockets of background (for example the gap between an arm
       and a body) when the pocket really looks like background.
    5. Shave a couple of pixels off the edge to remove the JPG halo, drop stray specks,
       crop to the sprite, pad to a square, and shrink to a small game-ready PNG.

USAGE (from the project root)
    python tools/clean_art.py                 # cleans every JPG in art/source
    python tools/clean_art.py --size 128      # bigger output sprites
    python tools/clean_art.py --only lucky_cat

Outputs go to art/placeholder/<name>.png, plus art/source/_cleaned_preview.png, which shows
every result on bright magenta so leftover background is easy to spot.

Needs: Pillow, numpy, scipy  (pip install pillow numpy scipy)
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIR = ROOT / "art" / "source"
OUTPUT_DIR = ROOT / "art" / "placeholder"

# How far (in RGB distance, 0-441) a pixel may be from a background colour and still
# count as background. Higher removes more. Dark backgrounds need a tighter value
# because the sprites' black outlines sit close to the dark checker colour.
DEFAULT_TOLERANCE = 34.0
TOLERANCE_OVERRIDES: dict[str, float] = {
    "sawbot_a": 24.0,
    "scrapper_b": 24.0,
    "spitter_a": 24.0,
    "spitter_b": 22.0,
}


def learn_background_colours(rgb: np.ndarray) -> list[np.ndarray]:
    """Return the background colours (1 for a flat backdrop, 2 for a checkerboard).

    We only sample the outer frame of the image, where there is no sprite.
    """
    height, width, _ = rgb.shape
    margin = max(4, width // 40)
    frame = np.concatenate(
        [
            rgb[:margin].reshape(-1, 3),
            rgb[-margin:].reshape(-1, 3),
            rgb[:, :margin].reshape(-1, 3),
            rgb[:, -margin:].reshape(-1, 3),
        ]
    ).astype(np.float32)

    # Split the frame pixels into a darker half and a lighter half by brightness.
    brightness = frame.mean(axis=1)
    threshold = (brightness.min() + brightness.max()) / 2.0
    dark = frame[brightness <= threshold]
    light = frame[brightness > threshold]
    if len(dark) == 0 or len(light) == 0:
        return [frame.mean(axis=0)]

    dark_colour = np.median(dark, axis=0)
    light_colour = np.median(light, axis=0)
    # If the two halves are nearly the same colour, it is a flat backdrop.
    if np.linalg.norm(dark_colour - light_colour) < 14.0:
        return [np.median(frame, axis=0)]
    return [dark_colour, light_colour]


def build_alpha(rgb: np.ndarray, tolerance: float) -> np.ndarray:
    """Return a boolean array: True where the sprite is, False where background was."""
    height, width, _ = rgb.shape
    colours = learn_background_colours(rgb)
    pixels = rgb.astype(np.float32)

    # A flat backdrop has almost no colour variation, so we can be much stricter.
    # Being strict matters: it stops pale parts of the sprite (cream on light grey)
    # from being mistaken for backdrop.
    is_flat = len(colours) == 1
    if is_flat:
        tolerance = min(tolerance, 16.0)

    # distance[i] is how far every pixel is from background colour i (0 = identical).
    # near[i] is True where that distance is inside the tolerance.
    # (The [... for colour in colours] form is a "list comprehension": it builds a
    # list by running the expression once per background colour.)
    distance = [np.linalg.norm(pixels - colour, axis=2) for colour in colours]
    near = [d < tolerance for d in distance]
    background_like = np.logical_or.reduce(near)

    # The seams between checker squares are a blend of the two colours, so they fail
    # the test above. "Closing" fills those hairline gaps (and JPG speckle) so the
    # flood fill can cross from one checker square to the next.
    seam = max(1, width // 500)
    background_like = ndimage.binary_closing(
        background_like, structure=np.ones((3, 3), bool), iterations=seam, border_value=1
    )

    # Group touching background-like pixels into numbered regions.
    labels, count = ndimage.label(background_like)

    # Any region that touches the picture's border is definitely background.
    border_labels = np.unique(
        np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])
    )
    is_background = np.isin(labels, border_labels[border_labels != 0])

    # Enclosed pockets: keep them as sprite unless they convincingly look like backdrop.
    min_pocket_area = (width * height) * 0.0004
    areas = ndimage.sum(background_like, labels, index=np.arange(1, count + 1))
    for label_id in np.nonzero(areas >= min_pocket_area)[0] + 1:
        if label_id in border_labels:
            continue
        region = labels == label_id
        if is_flat:
            # A real flat-backdrop pocket is almost exactly the backdrop colour.
            if distance[0][region].mean() > 6.0:
                continue
        else:
            # A real checkerboard pocket contains a fair share of BOTH colours.
            share_dark = near[0][region].mean()
            share_light = near[1][region].mean()
            if min(share_dark, share_light) < 0.2:
                continue
        is_background |= region

    sprite = ~is_background

    # Shave the fuzzy JPG halo off the sprite's edge.
    shave = max(1, width // 700)
    sprite = ndimage.binary_erosion(sprite, iterations=shave)

    # Drop stray specks: keep only blobs at least 0.5% the size of the biggest blob.
    blobs, blob_count = ndimage.label(sprite)
    if blob_count > 1:
        blob_areas = ndimage.sum(sprite, blobs, index=np.arange(1, blob_count + 1))
        keep = np.nonzero(blob_areas >= blob_areas.max() * 0.005)[0] + 1
        sprite = np.isin(blobs, keep)
    return sprite


def clean_one(source: Path, size: int) -> Image.Image:
    """Clean one JPG and return a square RGBA image of `size` x `size` pixels."""
    rgb = np.asarray(Image.open(source).convert("RGB"))
    tolerance = TOLERANCE_OVERRIDES.get(source.stem, DEFAULT_TOLERANCE)
    sprite = build_alpha(rgb, tolerance)

    alpha = (sprite * 255).astype(np.uint8)
    rgba = Image.fromarray(np.dstack([rgb, alpha]), "RGBA")

    # Crop tightly around the sprite, then centre it on a square canvas with a margin
    # so that rotating the sprite in-game never clips a corner.
    box = rgba.getbbox()
    if box is None:
        raise ValueError(f"{source.name}: everything was removed; raise the tolerance?")
    cropped = rgba.crop(box)
    side = int(max(cropped.size) * 1.06)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(cropped, ((side - cropped.width) // 2, (side - cropped.height) // 2))

    # Shrink using "premultiplied alpha" (the "RGBa" mode) so that the colour of the
    # removed background cannot bleed back into the sprite's edge as a pale fringe.
    small = square.convert("RGBa").resize((size, size), Image.LANCZOS).convert("RGBA")
    return small


def save_preview(results: dict[str, Image.Image], size: int) -> None:
    """Paste every result side by side on magenta, so leftovers are obvious."""
    sheet = Image.new("RGBA", (size * len(results), size), (255, 0, 255, 255))
    for index, image in enumerate(results.values()):
        sheet.alpha_composite(image, (index * size, 0))
    sheet.convert("RGB").save(SOURCE_DIR / "_cleaned_preview.png")


def main() -> None:
    """Read the command-line options, clean each JPG, and write the PNGs + preview.

    Python notes for reading this function:
      * argparse turns `--size 128` on the command line into `args.size == 128`.
      * `dict[str, Image.Image]` is a type hint: a dictionary of name -> image.
      * `f"{source.stem}.png"` is an f-string: the {...} part is replaced by the value.
        `source.stem` is the file name without its extension ("lucky_cat").
    """
    # __doc__ is this file's big docstring at the top; we reuse its first line as help.
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--size", type=int, default=96, help="output width/height in pixels")
    parser.add_argument("--only", help="clean just this one file (name without .jpg)")
    args = parser.parse_args()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    results: dict[str, Image.Image] = {}
    for source in sorted(SOURCE_DIR.glob("*.jpg")):
        if args.only and source.stem != args.only:
            continue
        image = clean_one(source, args.size)
        image.save(OUTPUT_DIR / f"{source.stem}.png")
        results[source.stem] = image
        coverage = (np.asarray(image)[:, :, 3] > 127).mean() * 100.0
        print(f"{source.stem:14s} -> {source.stem}.png  ({coverage:.0f}% of the square is sprite)")

    if results and not args.only:
        save_preview(results, args.size)
        print(f"Preview: {SOURCE_DIR / '_cleaned_preview.png'}  (order: {', '.join(results)})")


if __name__ == "__main__":
    main()
