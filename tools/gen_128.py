"""gen_128.py - DRAFT 128-class versions of every art asset (everything doubled: 2x the pixels).

WHY
    Sasha asked for 128 px drafts of all the art, to see whether finer pixel art is worth moving to.
    "128-class" means every asset is exactly TWICE its current size so proportions never change:
    64 px characters and icons become 128 px, 48 px floor tiles 96 px, 52 x 32 roofs 104 x 64.
    The drafts live in art/draft128/ and are NOT wired into the game.

HOW (the same idea as tools/gen_sprites.py, but starting from a finished sprite, not a concept)
    1. DRAW   Show the Gemini image model the current sprite enlarged on a magenta background (the
              "reference") and ask for the SAME sprite redrawn with twice the pixel detail.
              Seven's seven non-front frames also get Seven's finished front view as a second
              reference, so all eight facings share one hat, one size and one pixel style.
    2. SNAP   Key out the magenta, then shrink the drawing to EXACTLY twice the size of the original
              sprite's artwork (same position in the frame), letting each target pixel take the
              commonest colour of its patch (a "vote"), after every pixel has been moved to the
              nearest colour of that sprite's own palette (its colours plus a lighter and a darker
              step of each, so the extra detail has shading tones to use).
    3. BUILD  Put the pieces back together as the same sheets and strips the game loads today.

USAGE (from the project root; drawing needs the GEMINI_API_KEY user environment variable)
    python tools/gen_128.py draw  [--only seven_s lucky_cat] [--takes 2] [--workers 4]
    python tools/gen_128.py snap
    python tools/gen_128.py build [--pick lucky_cat=2 seven_e=1]    (default: take 1 of each)
    python tools/gen_128.py compare                                  side-by-side check sheets

OUT
    art/draft128/raw/<name>_<take>.png     what the model drew (magenta background)
    art/draft128/parts/<name>_<take>.png   the snapped piece
    art/draft128/sprites/...               the sheets and strips, named like art/sprites/ (swap-in ready)
    art/draft128/compare_<group>.png       the 64 px original (doubled) beside the 128 px draft
"""
import argparse
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_concepts as concepts  # noqa: E402  (the shared image-model plumbing)
import gen_sprites as sprites  # noqa: E402  (its `despeckle` is reused)

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "art/sprites"
OUT = ROOT / "art/draft128"
MAGENTA = np.array([255, 0, 255])
CANVAS = 1024  # the size of every picture we send to / get from the model


# ---- The list of assets ------------------------------------------------------------------
def asset(name, path, box=None, mode="sprite", group="misc", note="", anchor=None, aspect="1:1"):
    """One asset: where its 64-class picture is (`path`, optionally only the `box` = (x0, y0, x1, y1)
    cut out of a sheet), how to treat it (`mode` "sprite" = see-through background, "tile" = opaque
    picture that fills its frame, "roof" = opaque with a few see-through corners), a `note` telling
    the model what it is, and an optional `anchor` = another asset whose finished drawing is shown
    as a second reference (so a set of views stays consistent). Returns a dict."""
    return dict(name=name, path=path, box=box, mode=mode, group=group, note=note, anchor=anchor, aspect=aspect)


def build_assets() -> list:
    """Make the whole list. A `list` is built up with .append (add one) and .extend (add many)."""
    items = []
    # Seven: the eight facings (strip frames, 64 px each, order E SE S SW W NW N NE).
    facings = [
        ("e", "facing EAST (to the right of the picture) in profile, the gold nozzle arm on the near side"),
        ("se", "turned three-quarters toward the viewer and to the RIGHT; the nozzle arm is on the picture's left"),
        ("s", "facing the viewer (SOUTH), the gold nozzle arm on the picture's left, the plain hand on the right"),
        ("sw", "turned three-quarters toward the viewer and to the LEFT; the nozzle arm is on the picture's left, far side"),
        ("w", "facing WEST (to the left of the picture) in profile, the plain hand on the near side"),
        ("nw", "seen from behind and turned to the LEFT; the nozzle arm is on the picture's right, far side"),
        ("n", "seen from BEHIND, the gold nozzle arm on the picture's right"),
        ("ne", "seen from behind and turned to the RIGHT; the nozzle arm is on the picture's right, near side"),
    ]
    for index, (suffix, words) in enumerate(facings):
        items.append(asset(
            "seven_" + suffix, SRC / "gardener_bot_facings.png", (index * 64, 0, index * 64 + 64, 64), group="seven",
            note="Seven, a small emerald gardener robot with a wide solar-panel sun hat, a seedling on its crown, "
                 "a cream face window, a tool belt, a gold watering-spout nozzle on its right arm and cream boots, "
                 "seen " + words + ".",
            anchor=None if suffix == "s" else "seven_s"))
    # The six Helios machines: top-down, front pointing UP.
    machines = {
        "scrapper": "the Scrapper, a crab-like machine", "sawbot": "the Sawbot, a small wheeled tree-cutter",
        "spitter": "the Spitter, a tall slim sentry with a barrel", "linebreaker": "the Linebreaker, a wide plough machine",
        "ripsaw": "the Ripsaw, a machine with a long arm and a big flat round saw blade",
        "arc_spitter": "the Arc Spitter, a squat bunker with three fanned emitter barrels",
    }
    for key, words in machines.items():
        items.append(asset(key, SRC / (key + ".png"), group="machines",
                           note=words.capitalize() + ", seen straight down from above (plan view) with its front pointing UP. "
                                "It has a smiling face plate with solid black eyes and a black mouth line."))
    # Lucky the shop cat, icons, trees.
    items.append(asset("lucky_cat", SRC / "lucky_cat.png", group="misc", note="Lucky, a friendly shop cat sitting, seen from the front."))
    items.append(asset("lucky_cat_wave", SRC / "lucky_cat_wave.png", group="misc", note="Lucky the shop cat sitting with one paw raised, waving."))
    items.append(asset("repair_icon", SRC / "repair_icon.png", group="misc", note="A small repair icon (a wrench or tool badge)."))
    for stage, words in {"sapling": "a young tree sapling", "grown": "a grown glowing tree", "cut": "a tree that has been bitten and cut by a saw"}.items():
        items.append(asset("tree_" + stage, SRC / f"tree_{stage}.png", group="trees", note=words.capitalize() + ", seen from a high angle, game sprite."))
    items.append(asset("tree_big", SRC / "tree_big.png", group="trees", note="A huge ancient sunroot tree, game sprite, seen from a high angle."))
    for name in ("hardwood", "heavy_seeds", "long_trellis", "quick_reload", "quick_roots", "seed_pouch", "thick_plating"):
        items.append(asset("upgrade_" + name, SRC / "upgrades" / (name + ".png"), group="upgrades",
                           note="An upgrade-card icon called '" + name.replace("_", " ") + "'."))
    # Props: nine 64 px frames in one sheet.
    for index, name in enumerate(["meter", "notice", "notice_x", "planter", "barrel", "cable", "panel", "bike", "chair"]):
        items.append(asset("prop_" + name, SRC / "props.png", (index * 64, 0, index * 64 + 64, 64), group="props",
                           note="A street prop for a solarpunk city block, called '" + name.replace("_", " ") + "', seen from a high angle."))
    # Floor: nine 48 px tiles, the soil tap point, six 52 x 32 home roofs.
    for index in range(9):
        items.append(asset(f"floor_{index}", SRC / "floor_tiles.png", (index * 48, 0, index * 48 + 48, 48), mode="tile", group="floor",
                           note="A cracked dark paving tile for the floor of a city block, seen from directly above."))
    items.append(asset("tap_point", SRC / "tap_point.png", mode="tile", group="floor",
                       note="A patch of soil with a gold ring on the paving, seen from directly above."))
    for index in range(6):
        items.append(asset(f"roof_{index}", SRC / "home_roofs.png", (index * 52, 0, index * 52 + 52, 32), mode="roof", group="roofs",
                           aspect="16:9", note="The flat roof of a home seen from above, with rooftop details."))
    return items


# ---- Small helpers ------------------------------------------------------------------------
def load_source(a: dict) -> Image.Image:
    """The asset's 64-class picture as RGBA (cut out of its sheet if it has a `box`)."""
    image = Image.open(a["path"]).convert("RGBA")
    return image.crop(a["box"]) if a["box"] else image


def make_reference(a: dict) -> Path:
    """Enlarge the source with hard edges (no smoothing) and put it on a 1024 px picture: on magenta for
    a sprite, filling the picture for a tile or roof. Saves it and returns the path."""
    source = load_source(a)
    width, height = source.size
    scale = CANVAS // max(width, height)  # a whole-number enlargement keeps every art pixel a crisp block
    big = source.resize((width * scale, height * scale), Image.NEAREST)
    if a["mode"] == "sprite":
        picture = Image.new("RGB", (CANVAS, CANVAS), tuple(MAGENTA))
        picture.paste(big, ((CANVAS - big.width) // 2, (CANVAS - big.height) // 2), big)
    else:
        picture = Image.new("RGB", big.size, (0, 0, 0))
        picture.paste(big, (0, 0), big)
    path = OUT / "refs" / (a["name"] + ".png")
    picture.save(path)
    return path


def prompt_for(a: dict, has_anchor: bool) -> str:
    """The text sent with the pictures."""
    common = (
        "The FIRST reference picture is a 64-pixel pixel-art game sprite shown enlarged. " + a["note"] + " "
        "REDRAW it as a higher-resolution version of the SAME sprite: identical design, silhouette, pose, "
        "proportions, colours and viewpoint; nothing added and nothing removed; but with TWICE the pixel "
        "detail: every art pixel of the reference becomes about 2 x 2 pixels, so edges are smoother and "
        "small features (eyes, rivets, leaves, trim, panel lines, cracks) are sharper, and shading can use "
        "3 or 4 tones per colour. STYLE: crisp pixel art on a 128 x 128 grid, drawn large so each art pixel "
        "is a crisp 8 x 8 block of the picture. Hard edges only: no anti-aliasing, no blur, no gradients, "
        "no glow, no ground shadow. Light from the top left. ")
    if a["mode"] == "sprite":
        common += ("Keep the 1-pixel dark outline. BACKGROUND: one flat solid magenta (#ff00ff), nothing else on it. "
                   "FRAMING: exactly the same position and size in the picture as in the reference, nothing cropped.")
    else:
        common += ("The picture is a flat game texture: it fills the WHOLE picture edge to edge with no magenta, no border, "
                   "no frame. Keep exactly the same layout and colours as the reference.")
        if a["mode"] == "tile":
            common += " It must tile seamlessly: what leaves one edge re-enters at the opposite edge."
    if has_anchor:
        common += (" The SECOND reference picture is the finished high-resolution FRONT view of the same character: "
                   "draw the same character at the same size, with the same hat, proportions and pixel style, just "
                   "turned as described.")
    return common


def draw_one(a: dict, take: int, key: str, anchors: dict) -> str:
    """Ask the model for one drawing (retrying a few times, because it sometimes returns no picture)."""
    raw_path = OUT / "raw" / f"{a['name']}_{take}.png"
    if raw_path.exists():
        return f"have {raw_path.name}"
    references = [OUT / "refs" / (a["name"] + ".png")]
    anchor_raw = anchors.get(a["anchor"]) if a["anchor"] else None
    if anchor_raw is not None:
        references.append(anchor_raw)
    for attempt in range(4):
        try:
            data = concepts.generate(prompt_for(a, anchor_raw is not None), key, references=tuple(references), aspect=a["aspect"])
        except (Exception, SystemExit) as problem:  # the shared plumbing calls sys.exit when no picture comes back: treat that as a retry too
            data = None
            print("  retry", a["name"], problem)
        if data:
            raw_path.write_bytes(data)
            return f"drew {raw_path.name}"
        time.sleep(2 + attempt * 3)
    return f"FAILED {raw_path.name}"


def command_draw(args) -> None:
    """Make references, then draw. Anchors (Seven's front view) first, so the rest can use them."""
    for folder in ("refs", "raw", "parts", "sprites"):
        (OUT / folder).mkdir(parents=True, exist_ok=True)
    assets = [a for a in build_assets() if not args.only or a["name"] in args.only]
    for a in assets:
        make_reference(a)
    key = concepts.get_key()
    anchors = {}
    # Phase 1: assets that are anchors for others (here: seven_s). Phase 2: everything else, in parallel.
    anchor_names = {a["anchor"] for a in assets if a["anchor"]}
    first = [a for a in assets if a["name"] in anchor_names]
    rest = [a for a in assets if a["name"] not in anchor_names]
    for batch in (first, rest):
        with ThreadPoolExecutor(max_workers=args.workers) as pool:  # `with` closes the pool tidily when done
            jobs = [(a, take) for a in batch for take in range(1, args.takes + 1)]
            for message in pool.map(lambda job: draw_one(job[0], job[1], key, anchors), jobs):
                print(message)
        for a in first:
            anchors[a["name"]] = OUT / "raw" / f"{a['name']}_1.png"


# ---- Snapping -----------------------------------------------------------------------------
def palette_of(source: Image.Image) -> np.ndarray:
    """The colours of the 64 px source plus a lighter and a darker step of each (not of the darkest
    one: the outline stays a single colour). Sorted dark to light so entries 0 and 1 are the darkest."""
    pixels = np.array(source.convert("RGBA")).reshape(-1, 4)
    colours = np.unique(pixels[pixels[:, 3] > 0][:, :3], axis=0).astype(float)
    shades = [colours]
    for factor in (0.8, 1.2):
        shades.append(np.clip(colours * factor, 0, 255))
    everything = np.unique(np.round(np.concatenate(shades)), axis=0)
    luminance = everything @ np.array([0.3, 0.59, 0.11])
    return everything[np.argsort(luminance)]


def nearest_index(pixels: np.ndarray, palette: np.ndarray) -> np.ndarray:
    """For every pixel, the number of the nearest palette colour (green counts most, then red, then
    blue). Done a band of rows at a time so a 1024 x 1024 picture does not eat all the memory."""
    weights = np.array([3.0, 4.0, 2.0], dtype=np.float32)
    result = np.zeros(pixels.shape[:2], dtype=np.int32)
    flat_palette = palette.astype(np.float32)
    for top in range(0, pixels.shape[0], 64):
        band = pixels[top:top + 64].astype(np.float32)
        distance = (((band[:, :, None, :] - flat_palette[None, None, :, :]) ** 2) * weights).sum(axis=3)
        result[top:top + 64] = distance.argmin(axis=2)
    return result


def vote_resize(index: np.ndarray, mask: np.ndarray, target_h: int, target_w: int, colours: int) -> tuple:
    """Shrink a picture of palette numbers to target_w x target_h: each target pixel takes the commonest
    colour among the source pixels it covers (the outline colour, number 0, counts 1.5 times so thin
    outlines survive). A target pixel that is mostly background (mask False) stays empty."""
    scale_y, scale_x = index.shape[0] / target_h, index.shape[1] / target_w
    out = np.zeros((target_h, target_w), dtype=np.int32)
    filled = np.zeros((target_h, target_w), dtype=bool)
    for ty in range(target_h):
        y0 = int(ty * scale_y)
        y1 = max(int((ty + 1) * scale_y), y0 + 1)
        for tx in range(target_w):
            x0 = int(tx * scale_x)
            x1 = max(int((tx + 1) * scale_x), x0 + 1)
            cell_mask = mask[y0:y1, x0:x1]
            if cell_mask.mean() < 0.5:
                continue
            votes = np.bincount(index[y0:y1, x0:x1][cell_mask], minlength=colours).astype(float)
            votes[0] *= 1.5
            out[ty, tx] = int(votes.argmax())
            filled[ty, tx] = True
    return out, filled


def snap(a: dict, raw_path: Path) -> Image.Image:
    """Turn one raw drawing into the final 2x-size piece (RGBA)."""
    source = load_source(a)
    width, height = source.size
    palette = palette_of(source)
    pixels = np.array(Image.open(raw_path).convert("RGB")).astype(int)
    if a["mode"] == "sprite":
        # Where was the source's artwork? We reproduce it at twice the size in the same place.
        alpha = np.array(source)[..., 3] > 0
        ys, xs = np.where(alpha)
        box_h, box_w = ys.max() - ys.min() + 1, xs.max() - xs.min() + 1
        # Key out the magenta: flood from the picture's edges so magenta inside the art is kept.
        background = np.abs(pixels - MAGENTA).sum(axis=2) < 200
        labelled, _ = ndimage.label(background)
        edge = set(labelled[0, :]) | set(labelled[-1, :]) | set(labelled[:, 0]) | set(labelled[:, -1])
        edge.discard(0)
        solid = ~np.isin(labelled, list(edge))
        labelled, count = ndimage.label(solid)
        if count > 1:  # keep only the biggest piece (drop stray specks)
            sizes = ndimage.sum(solid, labelled, range(1, count + 1))
            solid = labelled == (int(np.argmax(sizes)) + 1)
        sy, sx = np.where(solid)
        crop = pixels[sy.min():sy.max() + 1, sx.min():sx.max() + 1]
        mask = solid[sy.min():sy.max() + 1, sx.min():sx.max() + 1]
        index = nearest_index(crop, palette)
        out, filled = vote_resize(index, mask, box_h * 2, box_w * 2, len(palette))
        out = sprites.despeckle(out, filled)
        canvas = np.zeros((height * 2, width * 2, 4), dtype=np.uint8)
        y0, x0 = ys.min() * 2, xs.min() * 2
        canvas[y0:y0 + out.shape[0], x0:x0 + out.shape[1], :3] = palette.astype(np.uint8)[out]
        canvas[y0:y0 + out.shape[0], x0:x0 + out.shape[1], 3] = filled * 255
        return Image.fromarray(canvas, "RGBA")
    # A tile or roof: the whole picture is the artwork.
    index = nearest_index(pixels, palette)
    out, _ = vote_resize(index, np.ones(index.shape, dtype=bool), height * 2, width * 2, len(palette))
    rgba = np.zeros((height * 2, width * 2, 4), dtype=np.uint8)
    rgba[..., :3] = palette.astype(np.uint8)[out]
    rgba[..., 3] = 255
    if a["mode"] == "roof":  # keep the source's see-through corners, doubled
        keep = np.array(source)[..., 3] > 0
        rgba[..., 3] = np.kron(keep, np.ones((2, 2))) * 255
    return Image.fromarray(rgba, "RGBA")


def command_snap(args) -> None:
    """Snap every raw drawing."""
    (OUT / "parts").mkdir(parents=True, exist_ok=True)
    by_name = {a["name"]: a for a in build_assets()}
    for raw in sorted((OUT / "raw").glob("*.png")):
        name, take = raw.stem.rsplit("_", 1)
        if name not in by_name or (args.only and name not in args.only):
            continue
        snap(by_name[name], raw).save(OUT / "parts" / f"{name}_{take}.png")
        print("snapped", raw.stem)


# ---- Building the sheets ------------------------------------------------------------------
def strip_nozzle(frame: Image.Image) -> Image.Image:
    """A copy of one Seven frame with the resting gold nozzle painted out (the game draws its own gold
    nozzle arm while aiming; see scripts/player.gd). Gold-looking clumps of 16+ pixels whose middle sits
    between the hat and the boots are replaced by the nearest non-gold colour around them."""
    pixels = np.array(frame.convert("RGBA"))
    r, g, b = (pixels[..., i].astype(int) for i in range(3))
    # "Gold-looking": clearly redder and greener than blue. (The darker gold of the nozzle's shadow
    # side is only about (148, 107, 16), so the test compares channels instead of using a high floor.)
    goldish = (pixels[..., 3] > 0) & (r > 120) & (r > b + 80) & (g > b + 50)
    # The nozzle is split into a few small gold pieces by its outline, so first GROW the gold mask
    # by 2 pixels to join neighbouring pieces into one group, then judge each group.
    groups, count = ndimage.label(ndimage.binary_dilation(goldish, iterations=2), structure=np.ones((3, 3)))
    remove = np.zeros(goldish.shape, dtype=bool)
    for number in range(1, count + 1):
        ys, _ = np.where((groups == number) & goldish)
        if len(ys) >= 20 and 56 <= ys.mean() <= 104:
            remove |= (groups == number) & goldish
    if remove.any():
        # distance_transform_edt with return_indices tells, for each removed pixel, where the nearest
        # pixel that is NOT removed is; we copy that pixel's colour.
        # Only pixels that are solid, not removed and not dark (so not the outline) may be copied from:
        # that way the hand is filled with body-green, not black.
        brightness = pixels[..., :3].astype(int).sum(axis=2)
        donors = (pixels[..., 3] > 0) & ~remove & (brightness > 200)
        _, (near_y, near_x) = ndimage.distance_transform_edt(~donors, return_indices=True)
        pixels[remove] = pixels[near_y[remove], near_x[remove]]
    return Image.fromarray(pixels, "RGBA")


def command_build(args) -> None:
    """Assemble the sheets using the picked take of every piece (take 1 unless --pick says otherwise)."""
    picks = {pair.split("=")[0]: int(pair.split("=")[1]) for pair in args.pick}
    assets = build_assets()
    pieces = {}
    for a in assets:
        take = picks.get(a["name"], 1)
        path = OUT / "parts" / f"{a['name']}_{take}.png"
        if not path.exists():  # fall back to any take that exists
            options = sorted((OUT / "parts").glob(f"{a['name']}_*.png"))
            path = options[0] if options else None
        if path is not None:
            pieces[a["name"]] = Image.open(path).convert("RGBA")
    target = OUT / "sprites"
    (target / "upgrades").mkdir(parents=True, exist_ok=True)

    def sheet(names: list, cell_w: int, cell_h: int, filename: str) -> None:
        """Paste the named pieces left to right into one strip (a missing piece leaves a gap)."""
        strip = Image.new("RGBA", (cell_w * len(names), cell_h), (0, 0, 0, 0))
        for i, name in enumerate(names):
            if name in pieces:
                strip.paste(pieces[name], (i * cell_w, 0))
        strip.save(target / filename)
        print("built", filename)

    seven = ["seven_" + s for s in ("e", "se", "s", "sw", "w", "nw", "n", "ne")]
    sheet(seven, 128, 128, "gardener_bot_facings.png")
    if "seven_s" in pieces:
        pieces["seven_s"].save(target / "gardener_bot.png")
    aiming = Image.new("RGBA", (128 * 8, 128), (0, 0, 0, 0))
    for i, name in enumerate(seven):
        if name in pieces:
            aiming.paste(strip_nozzle(pieces[name]), (i * 128, 0))
    aiming.save(target / "gardener_bot_facings_aiming.png")
    for name in ("scrapper", "sawbot", "spitter", "linebreaker", "ripsaw", "arc_spitter", "lucky_cat", "lucky_cat_wave", "repair_icon"):
        if name in pieces:
            pieces[name].save(target / (name + ".png"))
    for name in ("tree_sapling", "tree_grown", "tree_cut", "tree_big"):
        if name in pieces:
            pieces[name].save(target / (name + ".png"))
    for name in ("hardwood", "heavy_seeds", "long_trellis", "quick_reload", "quick_roots", "seed_pouch", "thick_plating"):
        if "upgrade_" + name in pieces:
            pieces["upgrade_" + name].save(target / "upgrades" / (name + ".png"))
    sheet(["prop_" + n for n in ("meter", "notice", "notice_x", "planter", "barrel", "cable", "panel", "bike", "chair")], 128, 128, "props.png")
    sheet([f"floor_{i}" for i in range(9)], 96, 96, "floor_tiles.png")
    if "floor_0" in pieces:
        pieces["floor_0"].save(target / "floor_tile.png")
    if "tap_point" in pieces:
        pieces["tap_point"].save(target / "tap_point.png")
    sheet([f"roof_{i}" for i in range(6)], 104, 64, "home_roofs.png")


# ---- Side-by-side check sheets ------------------------------------------------------------
def command_compare(args) -> None:
    """For each group: a row per asset with the 64-class original doubled (hard edges) on the left and the
    128-class draft on the right, on the dark floor colour, so the two can be judged at the SAME size."""
    floor = (58, 66, 72, 255)
    groups = {}
    for a in build_assets():
        groups.setdefault(a["group"], []).append(a)
    for group, members in groups.items():
        cells = []
        for a in members:
            draft = OUT / "sprites"
            parts = sorted((OUT / "parts").glob(f"{a['name']}_*.png"))
            if not parts:
                continue
            old = load_source(a)
            old = old.resize((old.width * 2, old.height * 2), Image.NEAREST)
            cells.append((a["name"], old, [Image.open(p).convert("RGBA") for p in parts]))
        if not cells:
            continue
        pad, label = 8, 14
        col_w = max(max(old.width, *(p.width for p in new)) for _, old, new in cells)
        col_h = max(max(old.height, *(p.height for p in new)) for _, old, new in cells)
        per_row = 1 + max(len(new) for _, _, new in cells)
        columns = 2 if group in ("seven", "floor", "props", "upgrades", "roofs") else 1  # group items in pairs of columns
        rows = (len(cells) + columns - 1) // columns
        width = columns * per_row * (col_w + pad) + pad
        sheet = Image.new("RGBA", (width, rows * (col_h + label + pad) + pad), floor)
        pen = ImageDraw.Draw(sheet)
        for n, (name, old, new) in enumerate(cells):
            base_x = (n % columns) * per_row * (col_w + pad) + pad
            y = (n // columns) * (col_h + label + pad) + pad
            pen.text((base_x, y), name + "  (64-class x2 | 128 draft takes)", fill=(235, 235, 225, 255))
            for i, picture in enumerate([old] + new):
                sheet.alpha_composite(picture, (base_x + i * (col_w + pad), y + label))
        sheet.save(OUT / f"compare_{group}.png")
        print("saved", f"compare_{group}.png")


def main() -> None:
    """Read the command line and run draw / snap / build / compare."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=["draw", "snap", "build", "compare"])
    parser.add_argument("--only", nargs="+", default=[], help="asset names to limit the run to")
    parser.add_argument("--takes", type=int, default=2)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--pick", nargs="+", default=[], help="name=take pairs for build")
    args = parser.parse_args()
    {"draw": command_draw, "snap": command_snap, "build": command_build, "compare": command_compare}[args.command](args)


if __name__ == "__main__":
    main()
