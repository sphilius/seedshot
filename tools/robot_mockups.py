"""robot_mockups.py - mock up three art directions for Helios's machines (s21).

WHY
    Sasha asked to see the first three redesign options for the Scrapper, the Sawbot and
    the Spitter before choosing one:
        1. "Same family, more story": industrial yellow-grey work-crew plating and a
           Helios sun-logo stamp on every machine, so the cast reads as one company.
        2. "Corporate cheerful": friendly blue-and-white machines with smiley face
           plates and a sunny uniform stripe. The menace comes from the contrast.
        3. "Brutalist utility": faceless, concrete-grey, rust-streaked, with small red
           status lights. Hardware following orders.
    These are MOCKUPS: the real sprites in art/sprites/ are not touched.

HOW
    Each mockup starts from the machine's current 64 x 64 sprite. Two steps:
      a) RECOLOUR: swap each palette colour for a new one (a dictionary "old -> new").
      b) DRAW OVER: paint a few details (a logo, a smiley, rust streaks) at coordinates
         that were read off the current sprites. Pixels are only changed where the
         sprite is already solid, so the silhouette stays exactly the same.
    Silhouettes are unchanged on purpose: it keeps the comparison about the paint job.
    A new silhouette (rounded for 2, blockier for 3) would be the next step once Sasha
    picks a direction.

USAGE (from the project root)
    python tools/robot_mockups.py

OUT
    art/concept/robot_redesign/<machine>_<option>.png   64 x 64 each
    art/concept/robot_redesign/contact_sheet.png        all twelve, 5x, labelled

Needs: Pillow, numpy
"""
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/concept/robot_redesign"
MACHINES = ("scrapper", "sawbot", "spitter")


def rgb(hex_text: str) -> tuple:
    """'#e0412f' -> (224, 65, 47). int(x, 16) reads a base-16 (hex) number."""
    hex_text = hex_text.lstrip("#")
    return tuple(int(hex_text[i:i + 2], 16) for i in (0, 2, 4))


# The colours the current sprites use (the game palette).
OUTLINE = rgb("#1b1f1d")
RUST_DARK, RUST_MID, RUST_LIGHT = rgb("#6b3a24"), rgb("#a65a2e"), rgb("#d08a4a")
STEEL_DARK, STEEL_LIGHT = rgb("#4a5257"), rgb("#9aa5a8")
RED, GOLD, CREAM = rgb("#e0412f"), rgb("#e8b93a"), rgb("#efe6c8")


def recolour(image: np.ndarray, swaps: dict) -> np.ndarray:
    """Return a copy of `image` with every pixel of a key colour turned into its value.
    np.all(..., axis=-1) asks "do all three colour numbers match?" per pixel, giving a
    True/False mask; writing through the mask changes exactly those pixels. We test
    against the ORIGINAL image so one swap cannot be swapped again by the next."""
    result = image.copy()
    for old, new in swaps.items():
        mask = np.all(image[..., :3] == old, axis=-1) & (image[..., 3] > 0)
        result[mask, :3] = new
    return result


def put(image: np.ndarray, points, colour) -> None:
    """Paint single pixels, but only where the sprite is already solid (alpha > 0), so
    details never spill outside the machine's outline."""
    for x, y in points:
        if image[y, x, 3] > 0:
            image[y, x, :3] = colour


def box(x0: int, y0: int, x1: int, y1: int):
    """Every (x, y) inside a rectangle, corners included. A "generator expression"
    inside a list: loops over y and x and collects the pairs."""
    return [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)]


# Where things are on each current sprite, read off the 64 x 64 pictures:
#   visor   = the red face panel on the body (x0, y0, x1, y1), None if it has none
#   stamp   = where the centre of a logo stamp can go
#   stripe  = the rows a uniform stripe can cross the body on
#   lens    = the Sawbot's round eye centre; muzzle = the Spitter's barrel tip
SPOTS = {
    "scrapper": {"visor": (27, 26, 36, 30), "stamp": (32, 40), "stripe": (36, 37)},
    "sawbot": {"visor": (25, 36, 38, 39), "stamp": (32, 45), "stripe": (31, 32), "lens": (29, 13, 34, 18)},
    "spitter": {"visor": (26, 39, 37, 52), "stamp": (32, 31), "stripe": (34, 35), "muzzle": (30, 3, 33, 5)},
}


def sun_stamp(image: np.ndarray, cx: int, cy: int) -> None:
    """The Helios logo: a dark sun (a 3 x 3 disc with eight rays) on a cream 9 x 9 plate."""
    put(image, box(cx - 4, cy - 4, cx + 4, cy + 4), CREAM)
    put(image, box(cx - 1, cy - 1, cx + 1, cy + 1), OUTLINE)  # the sun's disc
    # The eight rays: up, down, left, right and the four diagonals, 2 pixels out.
    for dx, dy in ((0, -3), (0, 3), (-3, 0), (3, 0), (-2, -2), (2, -2), (-2, 2), (2, 2)):
        put(image, [(cx + dx, cy + dy)], OUTLINE)


def option_1(name: str, base: np.ndarray) -> np.ndarray:
    """Same family, more story: mustard-grey work-crew plating and the sun stamp."""
    image = recolour(base, {
        RUST_DARK: rgb("#5b5532"), RUST_MID: rgb("#a89c46"), RUST_LIGHT: rgb("#d3c867"),
        STEEL_DARK: rgb("#3d4346"), STEEL_LIGHT: rgb("#8a9498"),
    })
    spots = SPOTS[name]
    # A hazard edge: dark dashes every 3rd pixel along the stripe rows, over plating only.
    for y in spots["stripe"]:
        put(image, [(x, y) for x in range(0, 64) if x % 4 < 2], rgb("#3a3720"))
    sun_stamp(image, *spots["stamp"])
    return image


def smiley(image: np.ndarray, visor: tuple, big: bool) -> None:
    """A friendly face on a cream plate: two eyes and a smile that curls up at the ends.
    `big` is for the tall Spitter plate, which has room for rounder eyes and a wide smile."""
    x0, y0, x1, y1 = visor
    put(image, box(x0, y0, x1, y1), rgb("#f6f3e4"))  # the face plate
    mid_x = (x0 + x1) // 2
    if big:
        put(image, box(mid_x - 4, y0 + 4, mid_x - 3, y0 + 5), OUTLINE)  # left eye, 2 x 2
        put(image, box(mid_x + 2, y0 + 4, mid_x + 3, y0 + 5), OUTLINE)  # right eye
        put(image, [(mid_x - 4, y0 + 8), (mid_x + 3, y0 + 8)], OUTLINE)  # the smile's ends
        put(image, box(mid_x - 3, y0 + 9, mid_x + 2, y0 + 9), OUTLINE)  # and its middle
    else:
        # A shallow plate (4 or 5 rows): single-pixel eyes on the top row, a flat smile below.
        put(image, [(x0 + 2, y0 + 1), (x1 - 2, y0 + 1)], OUTLINE)
        put(image, [(x0 + 1, y1 - 1), (x1 - 1, y1 - 1)], OUTLINE)
        put(image, [(x, y1) for x in range(x0 + 2, x1 - 1)], OUTLINE)


def option_2(name: str, base: np.ndarray) -> np.ndarray:
    """Corporate cheerful: Helios blue and white, a smiley plate, a sunny uniform stripe."""
    image = recolour(base, {
        RUST_DARK: rgb("#2b4d7a"), RUST_MID: rgb("#3f7cb8"), RUST_LIGHT: rgb("#8cc1ee"),
        STEEL_DARK: rgb("#9fb1c2"), STEEL_LIGHT: rgb("#f2f2ee"),
        RED: rgb("#f2c230"),  # claws, muzzle and lamp become a cheerful yellow
        GOLD: rgb("#ffffff"),
    })
    spots = SPOTS[name]
    # The uniform stripe: a 2-row sunny band, only over the blue body colours.
    blues = (rgb("#2b4d7a"), rgb("#3f7cb8"), rgb("#8cc1ee"))
    for y in spots["stripe"]:
        for x in range(64):
            if tuple(image[y, x, :3]) in blues and image[y, x, 3] > 0:
                image[y, x, :3] = rgb("#f2c230")
    smiley(image, spots["visor"], big=(name == "spitter"))
    return image


def option_3(name: str, base: np.ndarray, seed: int) -> np.ndarray:
    """Brutalist utility: concrete greys, no face, rust streaks, tiny red status lights."""
    image = recolour(base, {
        RUST_DARK: rgb("#26292b"), RUST_MID: rgb("#45494b"), RUST_LIGHT: rgb("#5d6264"),
        STEEL_DARK: rgb("#32373a"), STEEL_LIGHT: rgb("#6c777b"),
        RED: rgb("#7a3f22"),  # claws and muzzle become rusted metal, not warning red
        GOLD: rgb("#26292b"),
    })
    spots = SPOTS[name]
    # The face becomes a blank black slot with ONE small red light, bottom left.
    x0, y0, x1, y1 = spots["visor"]
    put(image, box(x0, y0, x1, y1), rgb("#0f1112"))
    put(image, box(x0 + 1, y1 - 1, x0 + 2, y1 - 1), RED)
    # The Sawbot's lens: a dark disc with one red dot, instead of a red target.
    if "lens" in spots:
        lx0, ly0, lx1, ly1 = spots["lens"]
        put(image, box(lx0, ly0, lx1, ly1), rgb("#0f1112"))
        put(image, box(lx0 + 2, ly0 + 2, lx0 + 3, ly0 + 3), RED)
    # Rust streaks: short vertical runs of orange-brown on the plating. `random.Random(seed)`
    # makes a private random-number maker; the same seed gives the same streaks every run.
    rng = random.Random(seed)
    greys = (rgb("#26292b"), rgb("#45494b"), rgb("#5d6264"))
    candidates = [(x, y) for y in range(64) for x in range(64)
                  if tuple(image[y, x, :3]) in greys and image[y, x, 3] > 0]
    for x, y in rng.sample(candidates, k=min(7, len(candidates))):
        for run in range(rng.randint(2, 5)):  # a streak runs downward
            put(image, [(x, y + run)], rgb("#8a4a22") if run % 2 == 0 else rgb("#6d3a1b"))
    # Two rivets and a status light: bolts on the plate, a green-less, red-only light.
    sx, sy = spots["stamp"]
    put(image, [(sx - 5, sy - 3), (sx + 5, sy - 3), (sx - 5, sy + 3), (sx + 5, sy + 3)], rgb("#9aa5a8"))
    put(image, [(sx, sy)], RED)
    return image


def main() -> None:
    """Build the nine mockups, then a labelled contact sheet with the current art first."""
    OUT.mkdir(parents=True, exist_ok=True)
    scale = 5
    # A row per machine; a column per version: current, then options 1, 2, 3.
    titles = ["current", "1 same family", "2 corporate cheerful", "3 brutalist"]
    sheet = Image.new("RGBA", (4 * 64 * scale + 5 * 12, 3 * (64 * scale + 22) + 12), (58, 66, 72, 255))
    draw = ImageDraw.Draw(sheet)
    for row, name in enumerate(MACHINES):
        base = np.array(Image.open(ROOT / f"art/sprites/{name}.png").convert("RGBA"))
        versions = [base, option_1(name, base), option_2(name, base), option_3(name, base, seed=7 + row)]
        for column, version in enumerate(versions):
            picture = Image.fromarray(version, "RGBA")
            if column > 0:  # the three options are saved on their own too
                picture.save(OUT / f"{name}_{column}.png")
            big = picture.resize((64 * scale, 64 * scale), Image.NEAREST)  # NEAREST = hard pixels
            left = 12 + column * (64 * scale + 12)
            top = 12 + row * (64 * scale + 22)
            sheet.alpha_composite(big, (left, top + 14))
            draw.text((left, top), f"{name}: {titles[column]}", fill=(235, 235, 225, 255))
    sheet.save(OUT / "contact_sheet.png")
    print("saved", OUT / "contact_sheet.png")


if __name__ == "__main__":
    main()
