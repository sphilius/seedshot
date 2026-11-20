"""gen_seven_sprites.py - turn the locked Engineer concept of Seven into the 8-direction pixel strip.

WHY
    Sasha picked "Engineer take 1" (art/concept/seven_redesign/seven_engineer_1.png): an emerald
    gardener robot with a solar-panel sun hat, a seedling on the crown, a watering-can nozzle arm,
    a tool belt and cream boots. The game shows Seven turned to one of EIGHT facings (a strip of
    64 x 64 frames, order East, SouthEast, South, SouthWest, West, NorthWest, North, NorthEast;
    see scripts/player.gd `facing_frame`), so we need that strip redrawn for the new design.

HOW
    1. DRAW   Seven only has to be drawn from FIVE angles, because the other three facings are
              mirror images: front (South), three-quarter front facing right (SouthEast), side
              facing right (East), three-quarter back facing right (NorthEast) and back (North).
              West, SouthWest and NorthWest are those views flipped left to right. The Gemini image
              model draws each angle as chunky pixel art on a magenta background, using the concept
              sheet as a reference (and, for every angle after the front, the finished front drawing,
              so the proportions and the pixel style match).
    2. SNAP   tools/gen_sprites.py already knows how to turn such a drawing into a true 64 px
              sprite (find the block grid, one colour per block, nearest palette colour, despeckle).
              We borrow it, but swap in SEVEN's own palette (emerald, cream, gold, leaf greens)
              instead of the Helios machines' blue palette.
    3. PLACE  Every frame is lined up the same way: feet on the same row, body centred, so Seven
              does not jump about when the aim sweeps round.
    4. STRIP  Eight frames side by side = art/sprites/gardener_bot_facings.png (512 x 64); the
              South frame alone is art/sprites/gardener_bot.png (the fallback / title picture).

USAGE (from the project root; drawing needs the GEMINI_API_KEY user environment variable)
    python tools/gen_seven_sprites.py draw --view front --takes 3        draw the front view
    python tools/gen_seven_sprites.py draw --views side three_front three_back back --takes 2
    python tools/gen_seven_sprites.py snap                               snap every raw drawing
    python tools/gen_seven_sprites.py build --pick front=2 side=1 ...    assemble the strip

OUT
    art/source/seven_pixel/<view>_raw_<take>.png   what the model drew (magenta background)
    art/source/seven_pixel/<view>_<take>.png       the snapped 64 x 64 frame (and @6x preview)
    art/source/seven_pixel/sheet.png               every snapped take side by side
    art/sprites/gardener_bot_facings.png, art/sprites/gardener_bot.png       (build only)
    art/source/seven_pixel/strip@4x.png            the finished strip at 4x, for looking

Needs: Pillow, numpy, scipy
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_concepts as concepts  # noqa: E402  (the shared image-model plumbing)
import gen_sprites as sprites  # noqa: E402  (the pixel-snapping code, reused)

ROOT = Path(__file__).resolve().parent.parent
CONCEPT = ROOT / "art/concept/seven_redesign/seven_engineer_1.png"
OUT = ROOT / "art/source/seven_pixel"
SIZE = 64
FEET_ROW = 59  # the bottom row of every frame's boots (the outline sits on it)

# Seven's palette: every drawn pixel is moved to the NEAREST of these. The first two entries must
# stay the darkest ones (outline, panel): the despeckle step leaves dark pixels alone because a
# lone dark pixel is usually an eye or a rivet, not noise.
PALETTE = [
    ("outline", "#1b1f1d"), ("panel", "#14403a"),
    ("emerald-dark", "#075f3c"), ("emerald", "#0b8f5c"), ("emerald-light", "#1fae78"),
    ("cream", "#efe6c8"), ("cream-dark", "#c9be9c"),
    ("gold", "#e8b93a"), ("gold-dark", "#b98614"),
    ("leaf-light", "#7fc45a"), ("leaf-dark", "#2f6b3a"), ("lime", "#c2e84f"),
    ("steel-dark", "#4a5257"), ("white", "#fffaea"),
]

# ---- What every drawing shares ----------------------------------------------------------
BASE = (
    "Redraw the gardener robot Seven from the model sheet (the reference picture) as a PIXEL-ART GAME "
    "SPRITE for a top-down arena game. Keep EXACTLY the same design: the wide round solar-panel sun hat "
    "(cream and gold rim, the panel glass a very dark green-black with thin cream grid lines) with a "
    "small green dome on top and the bright yellow-green seedling sprouting from the dome; the cream "
    "round face window with two small dark eyes; the deep EMERALD green barrel body with a cream chest "
    "panel, gold rivets and a dark tool belt with two pouches; emerald arms, one ending in a short gold "
    "watering-spout nozzle, the other in a small hand; short emerald legs and chunky CREAM boots. "
    "No blue anywhere. "
    "CAMERA: the same slightly raised eye-level view as the model sheet (we see the hat's top surface a "
    "little), NOT straight down. "
    "STYLE: 16-bit pixel art on a 64 x 64 grid, drawn large so each art pixel is a crisp 16 x 16 block. "
    "Hard edges only: no anti-aliasing, no blur, no gradients, no glow, no ground shadow. A 1-pixel "
    "dark outline. Flat shading with 2 or 3 tones per colour, light from the top left. VERY SIMPLE: big "
    "chunky shapes and large flat areas of colour, about twelve colours in total, no texture and no "
    "fine detail (the hat's grid is just a few pale lines). It must read clearly when shrunk to 64 "
    "pixels. BACKGROUND: one flat solid magenta (#ff00ff), nothing else on it: no panel, no text, no "
    "border. FRAMING: one robot, centred, standing with its boots near the bottom, filling about 90 "
    "percent of the canvas height, nothing cropped."
)

# ---- The five angles --------------------------------------------------------------------
# (the view's note, the frames it makes: (frame number, mirrored?)). Frame numbers follow the game's
# order: 0 East, 1 SouthEast, 2 South, 3 SouthWest, 4 West, 5 NorthWest, 6 North, 7 NorthEast.
VIEWS = {
    "front": (
        "THIS VIEW: the FRONT, exactly the 'FRONT' picture of the model sheet. Seven faces the viewer, "
        "the gold nozzle arm on the left of the picture, the plain hand on the right.",
        [(2, False)],
    ),
    "three_front": (
        "THIS VIEW: a THREE-QUARTER FRONT view. Seven is turned 45 degrees so it faces toward the "
        "viewer AND toward the RIGHT of the picture: we see the face window turned to the right, the "
        "front of the body and the near side of the body. The nozzle arm is on the far side.",
        [(1, False), (3, True)],
    ),
    "side": (
        "THIS VIEW: the SIDE view, exactly the 'SIDE' picture of the model sheet. Seven faces the RIGHT "
        "of the picture in profile, the face window at the right edge of the head, the boots pointing "
        "right.",
        [(0, False), (4, True)],
    ),
    "three_back": (
        "THIS VIEW: a THREE-QUARTER BACK view. Seven is turned so it faces away from the viewer AND "
        "toward the RIGHT of the picture: we see the back of the body and the back of the hat, and just "
        "a sliver of the face window at the right edge of the head. The gold nozzle arm is on the near "
        "side.",
        [(7, False), (5, True)],
    ),
    "back": (
        "THIS VIEW: the BACK, exactly the 'BACK' picture of the model sheet. Seven faces away from the "
        "viewer: we see the back of the hat with its panel, the plain emerald back with the belt, and "
        "the gold nozzle arm on the right of the picture.",
        [(6, False)],
    ),
}


def draw(view: str, take: int, key: str, front_raw: Path = None) -> Path:
    """Ask the model for one drawing of `view`; return the raw file's path. Every angle after the
    front also receives the finished front drawing (`front_raw`) as a second reference."""
    OUT.mkdir(parents=True, exist_ok=True)
    references = [CONCEPT]
    note = ""
    if front_raw is not None and view != "front":
        references.append(front_raw)
        note = (" The SECOND reference picture is the finished pixel sprite of the FRONT view: draw the "
                "same character at the same size and in the same pixel style, just turned.")
    prompt = BASE + note + "\n\n" + VIEWS[view][0]
    raw_path = OUT / f"{view}_raw_{take}.png"
    raw_path.write_bytes(concepts.generate(prompt, key, references=tuple(references), aspect="1:1"))
    return raw_path


PALETTE_RGB = np.array([[int(code[i:i + 2], 16) for i in (1, 3, 5)] for _, code in PALETTE], dtype=float)
CHANNEL_WEIGHTS = np.array([3.0, 4.0, 2.0])  # the eye notices green most, then red, then blue
MAGENTA = np.array([255, 0, 255])
HEIGHT = 56  # every view is shrunk so the whole figure (seedling to boots) is this many pixels tall


def snap_height(raw_path: Path, height: int = HEIGHT) -> np.ndarray:
    """Turn one big drawing into a 64 x 64 RGBA sprite whose figure is `height` pixels tall.
    The model drew on a finer grid than the 64 px game grid, so instead of hunting for its blocks
    we shrink by VOTING: 1. key out the magenta (flood from the picture's edges) and crop;
    2. give every source pixel its nearest palette colour; 3. cut the figure into target-pixel
    cells, and each cell takes the commonest colour inside it (the dark outline counts double so
    the thin outline survives); 4. a cell that is mostly background stays empty."""
    pixels = np.array(Image.open(raw_path).convert("RGB")).astype(int)
    background = np.abs(pixels - MAGENTA).sum(axis=2) < 200
    labelled, _ = ndimage.label(background)
    edge_labels = set(labelled[0, :]) | set(labelled[-1, :]) | set(labelled[:, 0]) | set(labelled[:, -1])
    edge_labels.discard(0)
    solid = ~np.isin(labelled, list(edge_labels))
    labelled, count = ndimage.label(solid)
    if count > 1:  # keep only the biggest piece: the robot, not specks
        sizes = ndimage.sum(solid, labelled, range(1, count + 1))
        solid = labelled == (int(np.argmax(sizes)) + 1)
    ys, xs = np.where(solid)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    crop, mask = pixels[y0:y1, x0:x1], solid[y0:y1, x0:x1]
    # Nearest palette colour for every source pixel.
    distances = (((crop[:, :, None, :] - PALETTE_RGB[None, None, :, :]) ** 2) * CHANNEL_WEIGHTS).sum(axis=3)
    index = distances.argmin(axis=2)
    # Eyes and glints are tiny dark specks inside a big pale area. Left alone, the vote would
    # paint over them, so any outline-coloured source pixel whose surroundings are mostly cream
    # is counted four times instead of twice.
    cream_ids = [i for i, (name, _) in enumerate(PALETTE) if name in ("cream", "white")]
    pale = np.isin(index, cream_ids).astype(float)
    eye_spot = (index == 0) & (ndimage.uniform_filter(pale, size=41) > 0.45)
    # Shrink: `scale` source pixels per target pixel.
    scale = (y1 - y0) / height
    width = max(1, int(round((x1 - x0) / scale)))
    out_index = np.zeros((height, width), dtype=int)
    out_filled = np.zeros((height, width), dtype=bool)
    for ty in range(height):
        sy0, sy1 = int(ty * scale), max(int((ty + 1) * scale), int(ty * scale) + 1)
        for tx in range(width):
            sx0, sx1 = int(tx * scale), max(int((tx + 1) * scale), int(tx * scale) + 1)
            cell_mask = mask[sy0:sy1, sx0:sx1]
            if cell_mask.size == 0 or cell_mask.mean() < 0.5:
                continue
            votes = np.bincount(index[sy0:sy1, sx0:sx1][cell_mask], minlength=len(PALETTE)).astype(float)
            # The outline colour counts double; an "eye" pixel (see above) counts four times.
            plain = ((index[sy0:sy1, sx0:sx1] == 0) & cell_mask & ~eye_spot[sy0:sy1, sx0:sx1]).sum()
            eyes = (eye_spot[sy0:sy1, sx0:sx1] & cell_mask).sum()
            votes[0] = plain * 2.0 + eyes * 4.0
            out_index[ty, tx] = int(votes.argmax())
            out_filled[ty, tx] = True
    out_index = sprites.despeckle(out_index, out_filled)
    canvas = np.zeros((SIZE, SIZE, 4), dtype=np.uint8)
    top, left = max(0, (SIZE - height) // 2), max(0, (SIZE - width) // 2)
    h, w = min(height, SIZE - top), min(width, SIZE - left)
    canvas[top:top + h, left:left + w, :3] = PALETTE_RGB.astype(np.uint8)[out_index[:h, :w]]
    canvas[top:top + h, left:left + w, 3] = out_filled[:h, :w] * 255
    return canvas


def place(canvas: np.ndarray) -> np.ndarray:
    """Slide one snapped frame so its boots end on FEET_ROW and its body is centred.
    The centre is the middle of the character's widest dark-outlined column range in the lower
    half (boots and body), so the wide hat or the nozzle sticking out does not drag it sideways."""
    solid = canvas[..., 3] > 0
    ys, xs = np.where(solid)
    top, bottom = ys.min(), ys.max()
    lower = solid[(top + bottom) // 2:, :]  # the lower half: body, legs, boots
    lower_xs = np.where(lower.any(axis=0))[0]
    centre_x = (lower_xs.min() + lower_xs.max()) / 2.0
    shift_y = FEET_ROW - bottom
    shift_x = int(round(31.5 - centre_x))
    placed = np.zeros_like(canvas)
    for y, x in zip(ys, xs):
        ny, nx = y + shift_y, x + shift_x
        if 0 <= ny < SIZE and 0 <= nx < SIZE:
            placed[ny, nx] = canvas[y, x]
    return placed


def snap_all() -> None:
    """Snap every raw drawing to a 64 px frame; write it and a 6x preview; rebuild the sheet."""
    for raw in sorted(OUT.glob("*_raw_*.png")):
        view, take = raw.stem.split("_raw_")
        frame = place(snap_height(raw))
        sprites.OUT = OUT  # save_sprite writes next to the raw drawings
        sprites.save_sprite(frame, view, int(take))
        print(f"snapped {view}_{take}")
    build_sheet()


def build_sheet() -> None:
    """Every snapped take on one sheet: a row per view, a column per take, at 4x."""
    rows = {}
    for path in sorted(OUT.glob("*_[0-9].png")):
        rows.setdefault(path.stem.rsplit("_", 1)[0], []).append(path)
    if not rows:
        return
    cell = SIZE * 4 + 12
    sheet = Image.new("RGBA", (max(len(v) for v in rows.values()) * cell + 12, len(rows) * (cell + 16) + 12), (58, 66, 72, 255))
    pen = ImageDraw.Draw(sheet)
    for r, view in enumerate(sorted(rows)):
        for c, path in enumerate(rows[view]):
            x, y = 12 + c * cell, 12 + r * (cell + 16)
            pen.text((x, y), path.stem, fill=(235, 235, 225, 255))
            sheet.alpha_composite(Image.open(path).convert("RGBA").resize((SIZE * 4, SIZE * 4), Image.NEAREST), (x, y + 14))
    sheet.save(OUT / "sheet.png")
    print("saved sheet.png")


def build_strip(picks: dict) -> None:
    """Assemble the 8-frame strip from the chosen take of each view (mirroring where needed)."""
    frames = [None] * 8
    for view, (_, targets) in VIEWS.items():
        frame = Image.open(OUT / f"{view}_{picks[view]}.png").convert("RGBA")
        for index, mirrored in targets:
            frames[index] = frame.transpose(Image.FLIP_LEFT_RIGHT) if mirrored else frame
    strip = Image.new("RGBA", (SIZE * 8, SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.paste(frame, (index * SIZE, 0))
    strip.save(ROOT / "art/sprites/gardener_bot_facings.png")
    frames[2].save(ROOT / "art/sprites/gardener_bot.png")
    big = strip.resize((SIZE * 8 * 4, SIZE * 4), Image.NEAREST)
    preview = Image.new("RGBA", big.size, (58, 66, 72, 255))
    preview.alpha_composite(big)
    preview.save(OUT / "strip@4x.png")
    print("built the strip and gardener_bot.png")


def main() -> None:
    """Command line: draw / snap / build (see the module docstring)."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=["draw", "snap", "build"])
    parser.add_argument("--views", nargs="+", choices=list(VIEWS), default=list(VIEWS))
    parser.add_argument("--view", choices=list(VIEWS), help="shorthand for --views with one view")
    parser.add_argument("--takes", type=int, default=2)
    parser.add_argument("--front-take", type=int, default=1, help="which front drawing to show as the second reference")
    parser.add_argument("--pick", nargs="+", default=[], help="view=take pairs, e.g. front=2 side=1")
    args = parser.parse_args()
    if args.command == "draw":
        key = concepts.get_key()
        front_raw = OUT / f"front_raw_{args.front_take}.png"
        for view in ([args.view] if args.view else args.views):
            for take in range(1, args.takes + 1):
                if (OUT / f"{view}_raw_{take}.png").exists():
                    continue
                draw(view, take, key, front_raw if front_raw.exists() else None)
                print(f"drew {view}_raw_{take}")
    elif args.command == "snap":
        snap_all()
    else:
        build_strip({pair.split("=")[0]: int(pair.split("=")[1]) for pair in args.pick})


if __name__ == "__main__":
    main()
