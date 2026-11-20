# make_upgrade_icons.py - draw the six upgrade-card icons for Seedshot.
#
# WHY: each icon is a 64 x 64 pixel picture on a transparent background. Drawing every
# pixel by hand is slow, so this script describes each icon as simple shapes (rectangles,
# ellipses, polygons, lines), fills a 64 x 64 grid with them, adds a dark outline, and then
# asks the Klad tool to paint that grid. The grid is written out as a Klad "pixel" op, so
# the same colour names as the game's shared palette are used.
#
# HOW IT RUNS (for each icon):
#   1. Build a grid of single characters, one per pixel ('.' means empty).
#   2. Write it as a Klad op file (<name>.ops.jsonl) next to this script.
#   3. Make a fresh Klad bundle (<name>.klad), apply the shared palette, then the icon op.
#   4. Export the bundle as a 64 x 64 PNG into art/sprites/upgrades/.
# After all six, it tiles them into contact_sheet.png at 6x with no smoothing.
#
# USE:  python C:/Users/sphil/dev/seedshot/art/source/klad/upgrades/make_upgrade_icons.py
#
# TUNING: each icon has its own function below (draw_seed_pouch, draw_heavy_seeds, ...).
# Change its shapes and run the script again. Everything is regenerated from scratch.

import json
import shutil
import subprocess
from pathlib import Path

from PIL import Image

# ---- Paths --------------------------------------------------------------------------
KLAD = Path("C:/Users/sphil/dev/klad-dist/klad-windows/klad.exe")
HERE = Path(__file__).resolve().parent                       # the upgrades source folder
PALETTE_OPS = HERE.parent / "palette.ops.jsonl"              # the game's shared 12 colours
SPRITE_OUT = Path("C:/Users/sphil/dev/seedshot/art/sprites/upgrades")
CONTACT_OUT = HERE / "contact_sheet.png"

SIZE = 64  # every icon is 64 x 64 pixels

# ---- Colour names and their one-letter codes -----------------------------------------
# These names are the palette names in palette.ops.jsonl. Each one-letter code is used
# only inside the script's grids; '.' is always "empty, see-through".
CODE = {
    "outline": "o",      # #1b1f1d, the dark outline
    "teal": "t",         # #2f8f8a
    "cream": "c",        # #efe6c8, the lightest neutral
    "leaf-dark": "d",    # #2f6b3a
    "leaf-light": "l",   # #7fc45a
    "gold": "g",         # #e8b93a
    "rust-dark": "r",    # #6b3a24
    "rust-mid": "m",     # #a65a2e
    "rust-light": "h",   # #d08a4a
    "steel-dark": "s",   # #4a5257
    "steel-light": "S",  # #9aa5a8
    "enemy-red": "e",    # #e0412f
}


# ---- Shape helpers -------------------------------------------------------------------
# A "predicate" is a function (x, y) -> True when pixel (x, y) is inside a shape. We test
# the CENTRE of each pixel (x + 0.5, y + 0.5) so shapes look even on the pixel grid.

def ellipse(cx, cy, rx, ry):
    """True inside an ellipse centred at (cx, cy) with radii rx, ry."""
    def inside(x, y):
        px, py = x + 0.5, y + 0.5
        return ((px - cx) / rx) ** 2 + ((py - cy) / ry) ** 2 <= 1.0
    return inside


def polygon(points):
    """True inside a closed polygon (list of (x, y) corners). Uses the ray-casting test."""
    def inside(x, y):
        px, py = x + 0.5, y + 0.5
        hit = False
        n = len(points)
        for i in range(n):
            x1, y1 = points[i]
            x2, y2 = points[(i + 1) % n]
            # Does a ray going right from (px, py) cross this edge?
            if (y1 > py) != (y2 > py):
                x_cross = x1 + (py - y1) * (x2 - x1) / (y2 - y1)
                if px < x_cross:
                    hit = not hit
        return hit
    return inside


def box(x, y, w, h):
    """True inside a rectangle whose top-left pixel is (x, y), w pixels wide, h tall."""
    def inside(px, py):
        return x <= px < x + w and y <= py < y + h
    return inside


def both(a, b):
    """True where shape a AND shape b overlap."""
    return lambda x, y: a(x, y) and b(x, y)


def not_(a):
    """True where shape a is NOT present."""
    return lambda x, y: not a(x, y)


def line_points(x0, y0, x1, y1):
    """Pixel cells along a straight line from (x0, y0) to (x1, y1), rounded to whole pixels."""
    steps = max(abs(x1 - x0), abs(y1 - y0)) * 2 + 1
    cells = []
    for i in range(steps + 1):
        t = i / steps
        cells.append((round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t)))
    return cells


def curve_points(p0, p1, p2, steps=60):
    """Points along a quadratic curve (a simple bend) from p0 to p2, with control point p1."""
    pts = []
    for i in range(steps + 1):
        t = i / steps
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1]
        pts.append((round(x), round(y)))
    return pts


class Grid:
    """A 64 x 64 canvas. Each cell holds a colour name, or None for empty."""

    def __init__(self):
        self.cells = [[None] * SIZE for _ in range(SIZE)]

    def fill(self, shape, colour):
        """Paint every pixel inside `shape` with `colour`. Later calls paint over earlier ones."""
        for y in range(SIZE):
            for x in range(SIZE):
                if shape(x, y):
                    self.cells[y][x] = colour

    def dot(self, x, y, colour, size=1):
        """Paint a small square of `size` x `size` pixels with its top-left at (x, y)."""
        self.fill(box(x, y, size, size), colour)

    def stroke(self, points, colour, thick=1):
        """Paint a line through a list of (x, y) cells, `thick` pixels wide."""
        for (x, y) in points:
            self.dot(x - (thick - 1) // 2, y - (thick - 1) // 2, colour, thick)

    def outline(self, colour="outline"):
        """Add a closed dark outline: every empty pixel that touches the picture (up, down,
        left or right) becomes the outline colour. Done last, so it wraps the whole icon."""
        filled = [[self.cells[y][x] is not None for x in range(SIZE)] for y in range(SIZE)]
        for y in range(SIZE):
            for x in range(SIZE):
                if filled[y][x]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < SIZE and 0 <= ny < SIZE and filled[ny][nx]:
                        self.cells[y][x] = colour
                        break

    def rows(self):
        """Turn the grid into text rows: one character per pixel, '.' for empty."""
        out = []
        for y in range(SIZE):
            row = ""
            for x in range(SIZE):
                name = self.cells[y][x]
                row += "." if name is None else CODE[name]
            out.append(row)
        return out


# ---- The six icons -------------------------------------------------------------------
# Each function paints one icon and returns its Grid. Read them top to bottom: the first
# shapes are the back, later shapes sit on top. The outline is added at the end.

def draw_seed_pouch():
    """Seed Pouch: a tied canvas bag with green seed pods spilling out, and speed streaks."""
    g = Grid()
    # Speed streaks on the left, drawn first so the bag covers their ends.
    g.fill(box(3, 30, 9, 2), "cream")
    g.fill(box(1, 38, 10, 2), "cream")
    g.fill(box(4, 46, 8, 2), "cream")
    # The bag: a rounded body that narrows into a neck at the top.
    bag = [(24, 26), (40, 26), (46, 34), (51, 46), (48, 57), (16, 57), (13, 46), (18, 34)]
    g.fill(polygon(bag), "rust-mid")
    # Shade the right side of the bag (light comes from the top left).
    g.fill(polygon([(38, 28), (46, 34), (51, 46), (48, 57), (36, 57), (42, 44)]), "rust-dark")
    # A highlight on the left side.
    g.fill(polygon([(18, 38), (22, 34), (24, 40), (22, 52), (17, 50), (16, 44)]), "rust-light")
    # The tie band around the neck.
    g.fill(box(22, 25, 20, 3), "gold")
    g.fill(box(22, 27, 20, 1), "rust-dark")
    # Seed pods spilling out of the top: a dark base with a light front.
    # Bigger pods, so they read at 72 px on a card. Each is a dark base with a light top.
    for (cx, cy) in [(33, 15), (44, 19), (23, 19)]:
        g.fill(ellipse(cx, cy, 5.5, 4.2), "leaf-dark")
        g.fill(ellipse(cx - 1, cy - 1, 3.4, 2.6), "leaf-light")
    # A seed spilling down the front of the bag, below the tie.
    g.fill(ellipse(40, 33, 2.2, 2.6), "leaf-dark")
    g.fill(ellipse(39, 32, 1.2, 1.4), "leaf-light")
    return g


def draw_heavy_seeds():
    """Heavy Seeds: one big seed pod with a metal band, and impact cracks below it."""
    g = Grid()
    pod = ellipse(32, 29, 15, 19)
    # The stalk on top of the pod, then the pod body and a lighter front.
    g.fill(box(31, 8, 2, 4), "leaf-dark")
    g.fill(pod, "leaf-dark")
    g.fill(ellipse(29, 26, 9, 13), "leaf-light")
    g.fill(ellipse(25, 21, 2.5, 3.5), "cream")          # a glint
    # Ground under the pod: a dark patch where it hit.
    g.fill(ellipse(32, 53, 20, 4), "steel-dark")
    # Impact cracks and sparks at the bottom.
    g.stroke(line_points(32, 49, 27, 53), "cream")
    g.stroke(line_points(27, 53, 29, 58), "cream")
    g.stroke(line_points(32, 49, 37, 53), "cream")
    g.stroke(line_points(37, 53, 35, 58), "cream")
    g.stroke(line_points(26, 53, 19, 56), "cream")
    g.stroke(line_points(38, 53, 45, 56), "cream")
    g.dot(15, 43, "gold", 2)                            # sparks
    g.dot(47, 42, "gold", 2)
    g.dot(49, 49, "gold", 2)
    # The metal band that wraps the pod, with a light top edge.
    g.fill(both(box(14, 33, 36, 5), pod), "steel-dark")
    g.fill(both(box(14, 33, 36, 1), pod), "steel-light")
    # Two rivets on the band.
    g.dot(20, 35, "steel-light", 2)
    g.dot(42, 35, "steel-light", 2)
    return g


def draw_thick_plating():
    """Thick Plating: a cream chest plate with rivets and two green health pips."""
    g = Grid()
    plate = polygon([(12, 12), (52, 12), (52, 40), (44, 52), (32, 58), (20, 52), (12, 40)])
    g.fill(plate, "cream")
    # Shade the right and bottom edges with cool grey.
    g.fill(both(polygon([(44, 12), (52, 12), (52, 40), (44, 52), (38, 48), (42, 40)]), plate),
           "steel-light")
    # A top highlight strip.
    g.fill(both(box(14, 13, 36, 2), plate), "cream")
    # Four rivets, one in each corner of the plate.
    for (rx, ry) in [(16, 16), (44, 16), (16, 40), (44, 40)]:
        g.dot(rx, ry, "steel-dark", 2)
        g.dot(rx, ry, "steel-light", 1)
    # Two health pips (the +2 max health): a dark square with a bright green centre.
    for px in (20, 36):
        g.dot(px, 24, "leaf-dark", 8)
        g.dot(px + 1, 25, "leaf-light", 6)
    return g


def draw_hardwood():
    """Hardwood: a thick stump seen from the side, with its cut top showing growth rings."""
    g = Grid()
    # The bottom rim (a dark curve showing the stump's underside).
    g.fill(ellipse(32, 46, 21, 8), "rust-dark")
    # The side of the stump.
    g.fill(box(11, 24, 42, 22), "rust-mid")
    g.fill(box(45, 26, 8, 20), "rust-dark")             # shaded right side
    # Bark texture: short dark strokes down the side.
    for (bx, by, bh) in [(15, 30, 8), (23, 36, 6), (33, 33, 7), (40, 40, 5), (27, 27, 4)]:
        g.dot(bx, by, "rust-dark", 2)
        g.dot(bx, by + bh, "rust-dark", 2)
    # The cut top: a light face with growth rings.
    g.fill(ellipse(32, 24, 21, 10), "rust-dark")         # bark edge around the top
    g.fill(ellipse(32, 24, 19, 8.5), "rust-light")       # the wood
    # Growth rings: rings are thin ellipses, each one smaller than the last.
    for (rx, ry) in [(15, 6.5), (10, 4.5), (5, 2.5)]:
        ring = both(ellipse(32, 24, rx, ry), not_(ellipse(32, 24, rx - 1.2, ry - 1.0)))
        g.fill(ring, "rust-mid")
    g.dot(31, 23, "rust-dark", 2)                        # the heart of the tree
    return g


def draw_quick_roots():
    """Quick Roots: a small sapling with two leaves above the soil and glowing roots below."""
    g = Grid()
    # The soil the sapling grows out of: a low rounded mound, not a flat bar.
    soil = polygon([(8, 44), (12, 37), (22, 33), (42, 33), (52, 37), (56, 44)])
    g.fill(soil, "rust-mid")
    g.fill(both(box(8, 43, 48, 1), soil), "rust-dark")   # dark lower edge of the mound
    # The stem.
    g.fill(box(30, 20, 4, 14), "leaf-dark")
    # The left leaf, with a dark midrib.
    left = polygon([(30, 24), (24, 16), (15, 15), (18, 21), (26, 27)])
    g.fill(left, "leaf-light")
    g.stroke(line_points(28, 24, 18, 17), "leaf-dark")
    # The right leaf, mirrored.
    right = polygon([(34, 21), (40, 12), (49, 11), (46, 17), (38, 24)])
    g.fill(right, "leaf-light")
    g.stroke(line_points(36, 21, 46, 13), "leaf-dark")
    # Roots below the soil line, drawn as glowing green threads with cream tips.
    roots = [
        [(32, 36), (26, 42), (20, 46), (12, 58)],
        [(32, 36), (30, 44), (30, 52), (28, 60)],
        [(32, 36), (38, 42), (44, 48), (52, 58)],
    ]
    for r in roots:
        for i in range(len(r) - 1):
            g.stroke(line_points(r[i][0], r[i][1], r[i + 1][0], r[i + 1][1]), "leaf-light", 2)
        g.dot(r[-1][0], r[-1][1], "cream", 1)
    return g


def draw_long_trellis():
    """Long Trellis: a green vine stretched between two short wooden posts, with leaves."""
    g = Grid()
    # The two posts: a mid-brown body, a dark side, and a dark cap on top.
    # Shorter posts (they stand 22 px tall, from y 32 to the bottom of the icon).
    for px in (7, 50):
        g.fill(box(px, 32, 7, 25), "rust-mid")
        g.fill(box(px + 5, 32, 2, 25), "rust-dark")      # shaded side
        g.fill(box(px, 32, 1, 25), "rust-light")         # lit edge
        g.fill(box(px - 1, 29, 9, 3), "rust-dark")       # post cap
    # The vine: a sagging curve from the left post to the right post.
    vine = curve_points((12, 36), (32, 60), (52, 36), steps=80)
    g.stroke(vine, "leaf-dark", 2)
    g.stroke(vine, "leaf-light", 1)
    # Bigger leaves along the vine, alternating above and below it.
    leaf_spots = [(18, 41, -1), (25, 47, 1), (32, 50, -1), (39, 47, 1), (46, 41, -1)]
    for (lx, ly, side) in leaf_spots:
        cy = ly - 3 * side
        g.fill(polygon([(lx - 5, cy), (lx, cy - 3), (lx + 5, cy), (lx, cy + 3)]), "leaf-light")
        g.stroke(line_points(lx - 4, cy, lx + 4, cy), "leaf-dark")  # midrib
    return g


def draw_repair():
    """Repairing: a steel spanner with a green sprout (the grove mending Seven).
    Not an upgrade card: it sits beside the "Repairing" words under Seven (player.gd)."""
    g = Grid()
    # The handle: a fat diagonal bar from the lower left up to the head, shaded on the
    # lower right (light comes from the top left, like every other icon).
    handle = line_points(14, 50, 38, 26)
    g.stroke(handle, "steel-dark", 9)
    g.stroke([(x - 1, y - 1) for (x, y) in handle], "steel-light", 6)
    # The ring at the handle's end, with a hole through it.
    g.fill(ellipse(12, 52, 7.5, 7.5), "steel-dark")
    g.fill(ellipse(11.5, 51.5, 6.5, 6.5), "steel-light")
    g.fill(ellipse(12, 52, 2.6, 2.6), None)
    # The head: a round jaw with a wedge cut out of its upper right.
    g.fill(ellipse(43, 21, 12.5, 12.5), "steel-dark")
    g.fill(ellipse(42, 20, 11, 11), "steel-light")
    g.fill(polygon([(43, 21), (53, 3), (62, 3), (62, 14)]), None)
    g.fill(polygon([(43, 21), (53, 3), (55, 3), (45, 23)]), None)
    # A gold glint on the head and two bolt dots on the handle.
    g.dot(34, 13, "cream", 3)
    g.dot(24, 38, "steel-dark", 2)
    g.dot(29, 33, "steel-dark", 2)
    # The sprout: two leaves on a short stem, rising from the lower right.
    g.fill(box(49, 46, 2, 10), "leaf-dark")
    g.fill(polygon([(50, 47), (58, 42), (60, 48), (53, 52)]), "leaf-light")
    g.fill(polygon([(50, 51), (42, 46), (40, 52), (47, 56)]), "leaf-dark")
    g.fill(polygon([(50, 51), (43, 47), (42, 51), (47, 54)]), "leaf-light")
    return g


ICONS = [
    ("seed_pouch", draw_seed_pouch),
    ("heavy_seeds", draw_heavy_seeds),
    ("thick_plating", draw_thick_plating),
    ("hardwood", draw_hardwood),
    ("quick_roots", draw_quick_roots),
    ("long_trellis", draw_long_trellis),
]


# Icons that are NOT upgrade cards: (name, draw function, folder the PNG goes to).
EXTRA_ICONS = [
    ("repair", draw_repair, Path("C:/Users/sphil/dev/seedshot/art/sprites")),
]


# ---- Writing the Klad files and running the tool ----------------------------------------

def klad(*args, stdin_file=None):
    """Run klad.exe with the given arguments and stop with a clear error if it fails."""
    cmd = [str(KLAD), *[str(a) for a in args]]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"klad failed: {' '.join(cmd)}\n{result.stderr or result.stdout}")
    return result.stdout


def write_icon_ops(name, grid):
    """Write the icon as Klad ops: one pixel op whose rows are the grid, plus the legend
    that says which palette name each letter stands for."""
    legend = {code: name_ for name_, code in CODE.items()}
    op = {
        "op": "pixel",
        "layer": "l1",
        "rows": grid.rows(),
        "legend": legend,
        "at": [0, 0],
    }
    path = HERE / f"{name}.ops.jsonl"
    path.write_text(json.dumps(op) + "\n", encoding="utf-8")
    return path


def build_icon(name, bundle_dir, png_path):
    """Make one bundle from scratch, paint the palette and icon, export a 64 x 64 PNG."""
    if bundle_dir.exists():
        shutil.rmtree(bundle_dir)
    klad("new", bundle_dir, "--pixel", f"{SIZE}x{SIZE}")
    klad("apply", bundle_dir, "--file", PALETTE_OPS)
    klad("apply", bundle_dir, "--file", write_icon_ops(name, grid_for[name]))
    klad("export", bundle_dir, "--scale", "1", "-o", png_path)


grid_for = {}  # filled in main(), so build_icon can read the grid it needs


def contact_sheet(paths, out_path, scale=6, gap=24):
    """Put the six icons side by side at `scale` times, nearest-neighbour, on #0d1217."""
    width = len(paths) * SIZE * scale + (len(paths) + 1) * gap
    height = SIZE * scale + 2 * gap
    sheet = Image.new("RGBA", (width, height), (0x0D, 0x12, 0x17, 255))
    for i, p in enumerate(paths):
        icon = Image.open(p).convert("RGBA")
        icon = icon.resize((SIZE * scale, SIZE * scale), Image.NEAREST)  # NEAREST = hard pixels
        sheet.alpha_composite(icon, (gap + i * (SIZE * scale + gap), gap))
    sheet.save(out_path)


# main() is the top-level "do everything" function. It runs when the script is started
# from the command line (see the `if __name__ == "__main__":` line at the very bottom).
def main():
    # mkdir makes the output folder if it is missing. parents=True also creates folders
    # above it, and exist_ok=True means "do not complain if it is already there".
    SPRITE_OUT.mkdir(parents=True, exist_ok=True)
    # A list starts empty here and gets one PNG path per icon added to it in the loop.
    # The loop unpacks each (name, draw) pair from ICONS, so `draw` is the function to call.
    png_paths = []
    for name, draw in ICONS:
        grid = draw()
        grid.outline()                       # close the dark outline around the icon
        grid_for[name] = grid
        bundle = HERE / f"{name}.klad"       # the Klad bundle, kept for regenerating
        png = SPRITE_OUT / f"{name}.png"
        build_icon(name, bundle, png)
        png_paths.append(png)
        print(f"wrote {png}")
    contact_sheet(png_paths, CONTACT_OUT)
    # The extra icons use the same pipeline but stay out of the six-card contact sheet.
    for name, draw, folder in EXTRA_ICONS:
        grid = draw()
        grid.outline()
        grid_for[name] = grid
        png = folder / f"{name}_icon.png"
        build_icon(name, HERE / f"{name}.klad", png)
        print(f"wrote {png}")
    print(f"wrote {CONTACT_OUT}")


if __name__ == "__main__":
    main()
