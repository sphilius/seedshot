"""gen_sprites.py - turn the locked robot concepts into 64 x 64 top-down pixel sprites.

WHY
    The six machines were designed as three-quarter concept pictures (art/concept/robot_final).
    But the game ROTATES every machine to face the way it walks (scripts/enemy.gd turns the sprite
    to velocity + 90 degrees), so a game sprite must be a view straight DOWN from above, with the
    machine's FRONT pointing UP in the picture. This tool redraws each concept that way.

HOW (two steps per machine)
    1. DRAW   Ask the Gemini image model for a pixel-art top-down version, giving it the locked
              concept as a reference picture and a note about that machine's top view. The model
              paints on a flat magenta background, which is easy to remove.
    2. SNAP   Remove the magenta, crop to the machine, shrink it to fit a 64 x 64 canvas, reduce it
              to a small palette, make every pixel fully solid or fully empty, and add the 1 px dark
              outline the other sprites have. (A chunky 1024 px picture does not sit exactly on a
              64 px grid, so this step is what makes it a real 64 px sprite.)

USAGE (from the project root; needs the GEMINI_API_KEY user environment variable)
    python tools/gen_sprites.py                      draw + snap all six, 2 takes each
    python tools/gen_sprites.py --machine scrapper   one machine
    python tools/gen_sprites.py --snap-only          redo only the snapping of existing drawings

OUT
    art/source/robot_pixel/<machine>_raw_<take>.png    what the model drew (1024 px, magenta background)
    art/source/robot_pixel/<machine>_<take>.png        the 64 x 64 sprite
    art/source/robot_pixel/<machine>_<take>@6x.png     the same at 6x on the floor colour, for looking
    art/source/robot_pixel/sheet.png                   every sprite side by side

Needs: Pillow, numpy, scipy
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

# The image-model plumbing (key, request, reply parsing) already lives in gen_concepts.py.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_concepts as concepts  # noqa: E402  (imported after the path line on purpose)

ROOT = Path(__file__).resolve().parent.parent
CONCEPTS = ROOT / "art/concept/robot_final"
OUT = ROOT / "art/source/robot_pixel"
SIZE = 64
OUTLINE = (0x1B, 0x1F, 0x1D)  # the game's dark outline colour
MAGENTA = (255, 0, 255)

# The Helios machines' palette: 24 fixed colours. Every drawn pixel is moved to the NEAREST of
# these, so the sprites share one consistent, limited set of colours (like the game's other
# sprites) instead of each inventing its own muddy shades. Names are for reading only.
PALETTE = [
    ("outline", "#1b1f1d"), ("soot", "#2f3437"),
    ("blue-dark", "#1f4d7a"), ("blue", "#3f7cb8"), ("blue-light", "#7fb4e8"), ("blue-pale", "#b9d8f2"),
    ("white", "#eef3f6"), ("white-shade", "#c4d0d8"),
    ("yellow", "#f2c230"), ("yellow-dark", "#b98614"),
    ("steel-dark", "#4a5257"), ("steel", "#727d83"), ("steel-light", "#9aa5a8"),
    ("rust-dark", "#6b3a24"), ("rust", "#a65a2e"), ("rust-light", "#d08a4a"),
    ("red", "#e0412f"), ("red-dark", "#9c2a20"),
    ("glow", "#8fe8ff"), ("glow-deep", "#2f9fd0"),
    ("orange", "#f08a2a"), ("tan", "#cdbb92"), ("smoke", "#6b7075"), ("green", "#5aa84a"),
]
PALETTE_RGB = np.array([[int(code[i:i + 2], 16) for i in (1, 3, 5)] for _, code in PALETTE], dtype=float)
# Red, green and blue differences are not equally visible to the eye: weight them 3 : 4 : 2.
CHANNEL_WEIGHTS = np.array([3.0, 4.0, 2.0])

# ---- What every drawing shares ----------------------------------------------------------
BASE = (
    "Redraw the machine in the reference picture as a PIXEL-ART GAME SPRITE for a top-down arena "
    "game. VIEW: straight down from directly above, like a map view, NOT three-quarter. The FRONT "
    "of the machine points UP in the picture (the game rotates it to face where it walks). Keep the "
    "same design, colours (Helios blue, white, sunny yellow trim, hazard stripes, rust chips, soot) "
    "and the smiling face plate with solid BLACK eyes and a solid BLACK mouth line; because we look "
    "from above, the face plate sits on the machine's TOP surface and reads as a small friendly face. "
    "STYLE: 16-bit pixel art on a 64 x 64 grid, drawn large so each art pixel is a crisp 16 x 16 "
    "block. Hard edges only: no anti-aliasing, no blur, no gradients, no glow, no ground shadow. "
    "A 1-pixel dark outline. Flat shading with 2 or 3 tones per colour, light from the top left. "
    "VERY SIMPLE: big chunky shapes and large flat areas of colour, about ten colours in total, no "
    "texture, no scratches, no soot smudges and no fine detail; rust is only 3 to 5 small orange chips. "
    "It must read clearly when shrunk to 64 pixels. BACKGROUND: one flat solid magenta (#ff00ff), "
    "nothing else on it: no silhouette panel, no text, no border. FRAMING: one machine, centred, "
    "filling about 90 percent of the canvas, nothing cropped."
)

# ---- Each machine's top view -----------------------------------------------------------
MACHINES = {
    "arc_spitter": (
        "THIS MACHINE: the Arc Spitter. IMPORTANT: this must be a true PLAN VIEW, like a blueprint or a "
        "map icon: we see ONLY the flat top of the machine, NO side walls, NO front face and NO "
        "perspective at all, as if the camera were a satellite straight overhead. Top view: a squat square bunker body in the middle with its "
        "smiling face plate on top. The three thick corrugated emitter barrels fan out from the "
        "front edge toward the TOP of the picture (one straight, two angled outward), their tips "
        "glowing electric blue. The splayed armoured legs stick out at the corners."
    ),
    "linebreaker": (
        "THIS MACHINE: the Linebreaker. Top view: a very wide plough blade across the TOP of the "
        "picture with hazard stripes, two piston arms running back from it, a cab with the smiling "
        "face plate on top in the middle, and long tracks along the left and right sides running "
        "up and down."
    ),
    "ripsaw": (
        "THIS MACHINE: the Ripsaw. IMPORTANT: the whole machine is perfectly VERTICAL and symmetric "
        "left to right: the body at the bottom centre, the saw arm running straight up the middle "
        "of the picture to the blade at the top centre. Nothing is diagonal or rotated. "
        "Top view: a compact tracked body at the bottom half with the smiling "
        "face plate on its top and two small exhaust stacks at the back (bottom). A long saw arm "
        "extends forward toward the TOP of the picture, and at its tip a big round saw blade is "
        "seen flat from above, with teeth striped red and yellow. The blade is bigger than the body."
    ),
    "scrapper": (
        "THIS MACHINE: the Scrapper (a crab). Top view: a flat oval armoured carapace in the middle "
        "with the smiling face plate on it, six short bent legs sticking out at the left and right "
        "sides, and two big hydraulic pincer claws reaching forward toward the TOP of the picture, "
        "open and ready to grab."
    ),
    "sawbot": (
        "THIS MACHINE: the Sawbot (a small tree-cutter). Top view: a small engine block in the "
        "middle with the smiling face plate on its cowling and a round exhaust stack, two big chunky "
        "wheels seen from above at the left and right sides, and a short saw arm reaching forward "
        "toward the TOP of the picture with a modest round saw blade seen flat from above, teeth "
        "striped red and yellow."
    ),
    "spitter": (
        "THIS MACHINE: the Spitter (a tall slim sentry). Top view: the top of a narrow rectangular "
        "armoured tower in the middle, with the smiling face plate on its top and a tiny antenna dot, "
        "one long barrel pointing forward toward the TOP of the picture, and just a sliver of the "
        "round roller foot visible under the back edge."
    ),
}


def draw(machine: str, take: int, key: str, use_reference: bool = True) -> Path:
    """Ask the model for one top-down drawing of `machine`; return the raw file's path.
    With use_reference=False the concept picture is NOT sent: a reference tends to drag the
    model back to the concept's three-quarter angle, so a text-only description is the way to
    get a true plan view for a machine that keeps refusing (the Arc Spitter)."""
    OUT.mkdir(parents=True, exist_ok=True)
    references = (CONCEPTS / f"{machine}.png",) if use_reference else ()
    prompt = BASE + "\n\n" + MACHINES[machine]
    raw_path = OUT / f"{machine}_raw_{take}.png"
    raw_path.write_bytes(concepts.generate(prompt, key, references=references))
    return raw_path


def find_grid(block_source: np.ndarray, axis: int) -> tuple:
    """Find the size and offset of the pixel blocks along one axis of a drawing.
    The model paints in chunky square blocks. Where one block ends and the next begins, the
    colour changes, so summing how much the colour changes in each column (axis 1) or row
    (axis 0) gives a profile with a spike at every block edge. The spikes repeat every
    `period` pixels: we find that period by trying lags and keeping the one where the
    profile best matches itself (autocorrelation), then the offset where the spikes sit."""
    difference = np.abs(np.diff(block_source.astype(int), axis=axis)).sum(axis=2)
    profile = difference.sum(axis=1 - axis).astype(float)
    profile -= profile.mean()
    # Score every lag. A grid that repeats every 14 pixels also repeats every 28, 42 ...,
    # so the biggest score alone could pick a multiple. We want the FUNDAMENTAL period: the
    # smallest lag that is a local peak and scores nearly as well as the best of all.
    lags = list(range(8, 60))
    scores = {lag: float((profile[:-lag] * profile[lag:]).sum()) / (len(profile) - lag) for lag in lags}
    top_score = max(scores.values())
    best_lag = next(
        lag for lag in lags
        if scores[lag] >= 0.6 * top_score
        and scores[lag] >= scores.get(lag - 1, -1e18) and scores[lag] >= scores.get(lag + 1, -1e18)
    )
    # Refine to a fraction of a pixel: test periods around the whole-number lag.
    best_period, best_offset, best_total = float(best_lag), 0.0, -1e18
    for period in np.arange(best_lag - 0.6, best_lag + 0.61, 0.05):
        for offset in np.arange(0.0, period, 0.5):
            positions = np.round(np.arange(offset, len(profile), period)).astype(int)
            positions = positions[positions < len(profile)]
            total = float(profile[positions].sum()) / len(positions)
            if total > best_total:
                best_period, best_offset, best_total = float(period), float(offset), total
    return best_period, best_offset


def despeckle(index_image: np.ndarray, filled: np.ndarray) -> np.ndarray:
    """Remove lone stray pixels: a pixel none of whose four neighbours shares its colour takes
    the commonest colour among those neighbours. The dark colours (outline, soot) are left alone,
    because a lone dark pixel is usually a deliberate eye or rivet, not noise."""
    result = index_image.copy()
    dark = {0, 1}
    for y in range(1, index_image.shape[0] - 1):
        for x in range(1, index_image.shape[1] - 1):
            if not filled[y, x] or int(index_image[y, x]) in dark:
                continue
            neighbours = [int(index_image[y + dy, x + dx]) for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1))
                          if filled[y + dy, x + dx]]
            if len(neighbours) >= 3 and int(index_image[y, x]) not in neighbours:
                result[y, x] = max(set(neighbours), key=neighbours.count)
    return result


def snap(raw_path: Path) -> np.ndarray:
    """Turn a big pixel-look drawing into a true 64 x 64 RGBA sprite (a numpy array).
    Steps: key out the magenta and crop to the machine; find the drawing's own block grid and
    take ONE colour per block (no averaging, so no muddy blends and no magenta fringes);
    shrink if it is still bigger than the canvas; reduce the colours a little; add an outline
    only if the drawing does not already have one."""
    pixels = np.array(Image.open(raw_path).convert("RGB")).astype(int)
    # 1. The magenta background: flood from the picture's edges so magenta-ish pixels INSIDE the
    #    machine are never removed by accident. Keep only the biggest piece, then crop to it.
    background = np.abs(pixels - np.array(MAGENTA)).sum(axis=2) < 200
    labelled, _ = ndimage.label(background)
    edge_labels = set(labelled[0, :]) | set(labelled[-1, :]) | set(labelled[:, 0]) | set(labelled[:, -1])
    edge_labels.discard(0)
    solid = ~np.isin(labelled, list(edge_labels))
    labelled, count = ndimage.label(solid)
    if count > 1:
        sizes = ndimage.sum(solid, labelled, range(1, count + 1))
        solid = labelled == (int(np.argmax(sizes)) + 1)
    ys, xs = np.where(solid)
    cropped = pixels[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    # 2. Find the block grid, then sample the middle of every block. The median of a small
    #    3 x 3 patch at the block centre ignores a stray noisy pixel.
    period_x, offset_x = find_grid(cropped, axis=1)
    period_y, offset_y = find_grid(cropped, axis=0)
    columns = int((cropped.shape[1] - offset_x) / period_x)
    rows = int((cropped.shape[0] - offset_y) / period_y)
    blocks = np.zeros((rows, columns, 3), dtype=np.uint8)
    for row in range(rows):
        for column in range(columns):
            cy = int(offset_y + (row + 0.5) * period_y)
            cx = int(offset_x + (column + 0.5) * period_x)
            patch = cropped[max(cy - 1, 0):cy + 2, max(cx - 1, 0):cx + 2].reshape(-1, 3)
            blocks[row, column] = np.median(patch, axis=0)
    # 3. Which blocks are background (magenta)? Trim the empty border off.
    empty = np.abs(blocks.astype(int) - np.array(MAGENTA)).sum(axis=2) < 150
    filled = ~empty
    ys, xs = np.where(filled)
    blocks = blocks[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    filled = filled[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    print(f"  block grid {period_x:.1f} x {period_y:.1f} px, machine is {blocks.shape[1]} x {blocks.shape[0]} blocks")
    # 4. Move every block to the nearest colour of the fixed palette. Empty blocks are painted
    #    with the outline colour first, so magenta can never be matched.
    tidy = blocks.copy()
    tidy[~filled] = OUTLINE
    # For every block, the distance to every palette colour; argmin picks the nearest one.
    distances = (((tidy[:, :, None, :].astype(float) - PALETTE_RGB[None, None, :, :]) ** 2) * CHANNEL_WEIGHTS).sum(axis=3)
    index_image = distances.argmin(axis=2)  # one palette number per block
    palette = PALETTE_RGB.astype(np.uint8)
    # 5. Too big for the canvas? Shrink by MAJORITY VOTE: each target pixel looks at the source
    #    blocks it covers and takes the commonest colour. Averaging would blend colours into mud;
    #    nearest-neighbour would pick one block at random and make edges noisy. The dark outline
    #    colour counts 1.5 times, so thin outline lines are not voted away.
    biggest = max(index_image.shape)
    limit = SIZE - 2
    if biggest > limit:
        scale = biggest / limit  # source blocks per target pixel (more than 1)
        height, width = max(1, round(index_image.shape[0] / scale)), max(1, round(index_image.shape[1] / scale))
        dark_ids = {i for i in range(len(palette)) if int(palette[i].astype(int).sum()) < 150}
        shrunk = np.zeros((height, width), dtype=int)
        shrunk_filled = np.zeros((height, width), dtype=bool)
        for ty in range(height):
            y0, y1 = int(ty * index_image.shape[0] / height), max(int((ty + 1) * index_image.shape[0] / height), int(ty * index_image.shape[0] / height) + 1)
            for tx in range(width):
                x0, x1 = int(tx * index_image.shape[1] / width), max(int((tx + 1) * index_image.shape[1] / width), int(tx * index_image.shape[1] / width) + 1)
                cell_filled = filled[y0:y1, x0:x1]
                if cell_filled.mean() < 0.5:
                    continue  # mostly empty: leave transparent
                votes = {}
                for colour in index_image[y0:y1, x0:x1][cell_filled]:
                    votes[int(colour)] = votes.get(int(colour), 0.0) + (1.5 if int(colour) in dark_ids else 1.0)
                shrunk[ty, tx] = max(votes, key=votes.get)  # the colour with the most votes
                shrunk_filled[ty, tx] = True
        index_image, filled = shrunk, shrunk_filled
    height, width = filled.shape
    index_image = despeckle(index_image, filled)
    tidy = palette[index_image]
    # 6. Put it on the 64 x 64 canvas, centred.
    canvas = np.zeros((SIZE, SIZE, 4), dtype=np.uint8)
    top, left = (SIZE - height) // 2, (SIZE - width) // 2
    canvas[top:top + height, left:left + width, :3] = tidy
    canvas[top:top + height, left:left + width, 3] = filled * 255
    # 7. The dark outline, only if the drawing lacks one: look at the machine's edge pixels.
    solid_px = canvas[..., 3] > 0
    edge = solid_px & ~ndimage.binary_erosion(solid_px)
    dark = (canvas[..., :3].astype(int).sum(axis=2) < 150) & edge
    if edge.sum() and dark.sum() / edge.sum() < 0.6 and top > 0 and left > 0:
        ring = ndimage.binary_dilation(solid_px) & ~solid_px
        canvas[ring] = (*OUTLINE, 255)
    return canvas


def save_sprite(canvas: np.ndarray, machine: str, take: int) -> None:
    """Write the 64 px sprite and a 6x preview on the dark floor colour."""
    sprite = Image.fromarray(canvas, "RGBA")
    sprite.save(OUT / f"{machine}_{take}.png")
    big = sprite.resize((SIZE * 6, SIZE * 6), Image.NEAREST)
    preview = Image.new("RGBA", big.size, (58, 66, 72, 255))
    preview.alpha_composite(big)
    preview.save(OUT / f"{machine}_{take}@6x.png")


def build_sheet() -> None:
    """Every sprite on one sheet: a row per machine, a column per take, at 4x."""
    files = [p for p in sorted(OUT.glob("*_[0-9].png")) if "_raw_" not in p.name]
    rows = {}
    for path in files:
        machine = path.stem.rsplit("_", 1)[0]
        rows.setdefault(machine, []).append(path)
    if not rows:
        return
    cell = SIZE * 4 + 12
    sheet = Image.new("RGBA", (max(len(v) for v in rows.values()) * cell + 12, len(rows) * (cell + 16) + 12), (58, 66, 72, 255))
    draw_ = ImageDraw.Draw(sheet)
    for r, machine in enumerate(sorted(rows)):
        for c, path in enumerate(rows[machine]):
            tile = Image.open(path).convert("RGBA").resize((SIZE * 4, SIZE * 4), Image.NEAREST)
            x, y = 12 + c * cell, 12 + r * (cell + 16)
            draw_.text((x, y), path.stem, fill=(235, 235, 225, 255))
            sheet.alpha_composite(tile, (x, y + 14))
    sheet.save(OUT / "sheet.png")
    print("saved sheet.png")


def main() -> None:
    """Read the command line, then for every machine and take: draw it (unless the raw drawing
    already exists, so a stopped run never pays twice), snap it to 64 px, and save it.
    `args.machine` is None when --machine was not given; `if args.machine and ...: continue`
    then skips every machine except the one asked for. Finally rebuild the overview sheet."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--machine", choices=list(MACHINES))
    parser.add_argument("--takes", type=int, default=2)
    parser.add_argument("--no-reference", action="store_true", help="draw from the text description only")
    parser.add_argument("--snap-only", action="store_true", help="redo the snapping of drawings already made")
    args = parser.parse_args()
    key = None if args.snap_only else concepts.get_key()
    for machine in MACHINES:
        if args.machine and machine != args.machine:
            continue
        for take in range(1, args.takes + 1):
            raw_path = OUT / f"{machine}_raw_{take}.png"
            if not args.snap_only and not raw_path.exists():
                raw_path = draw(machine, take, key, use_reference=not args.no_reference)
                print(f"drew {raw_path.name}")
            if raw_path.exists():
                save_sprite(snap(raw_path), machine, take)
                print(f"snapped {machine}_{take}")
    build_sheet()


if __name__ == "__main__":
    main()
