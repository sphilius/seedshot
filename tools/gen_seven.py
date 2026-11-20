"""gen_seven.py - concept art for the redesign of Seven, the gardener bot (the player).

WHY
    Sasha asked for a redesign of Seven, now in EMERALD GREEN instead of teal. Seven is not like
    the Helios machines: it is the hero, it is not rotated to face its movement (the game picks one
    of eight pre-drawn FACINGS instead), and it has to stay readable beside blue-and-yellow
    machines, glowing emerald-ish trees and vines, and its own bright green seedling.

THE BRIEF EVERY DIRECTION MUST MEET
    - Emerald green is Seven's colour: deep and a little blue (about #0b8f5c, shade #075f3c). It must
      NOT be confused with the light yellow-green of the seedling (#7fc45a) or the glowing trees.
    - Cream (#efe6c8) and solar gold (#e8b93a) carry the read, as the cream dome did before.
    - Friendly and small. It can turn through eight directions, so it needs a design that reads from
      the front, side and back: every direction is drawn as a TURNAROUND SHEET.
    - It plants seeds: it shoots seed pods from a nozzle, throws Bramble Seeds, rides a vine, carries
      a seedling. It is repaired by the grove. It must look NOTHING like the Helios machines
      (no blue, no hazard stripes, no face plate squares).

THREE DIRECTIONS (each 2 takes)
    evolve     the locked design polished: cream dome, emerald barrel body, stumpy legs, seedling
    engineer   a new silhouette: a solar-panel sun hat, a seed-hopper body with a nozzle arm, boots
    sprout     a rounder, smaller seed-pod mascot with leaf ears and the seedling growing from its head

USAGE (from the project root; needs the GEMINI_API_KEY user environment variable)
    python tools/gen_seven.py                  all directions, 2 takes each
    python tools/gen_seven.py --direction engineer --takes 3

OUT
    art/concept/seven_redesign/seven_<direction>_<take>.png and contact_sheet.png
"""
import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_concepts as concepts  # noqa: E402  (the shared image-model plumbing)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/concept/seven_redesign"
CURRENT = ROOT / "art/source/klad/seven@8x.png"  # the locked design, 512 px, as a reference

STYLE = (
    "Character model sheet for the hero of a top-down arena game: ONE small friendly gardener robot "
    "called Seven, drawn THREE times in a row on a plain flat light-grey background: a FRONT view, "
    "a SIDE view facing right, and a BACK view, all the same size and standing on the same line. "
    "Clean stylised illustration with bold readable shapes and flat shading, designed to still read "
    "when shrunk to 64 pixels, so keep the form simple and chunky with a strong, unique silhouette. "
    "No text, no labels, no scenery, no other characters. The world: a solarpunk block fighting "
    "Helios Clean Energy, a company that owns the sun; Seven plants seeds that grow into trees "
    "that power the block's homes."
)

BRIEF = (
    "COLOURS: Seven is EMERALD GREEN: a deep, slightly bluish emerald (about #0b8f5c) with a darker "
    "shade (#075f3c). Cream (#efe6c8) and solar gold (#e8b93a) are the supporting colours. The "
    "seedling Seven carries is a different, much lighter yellow-green (#7fc45a) with a soft glow, so "
    "the emerald and the seedling never look alike. NO blue anywhere, NO hazard stripes. "
    "WHAT SEVEN DOES: it fires seed pods from a small nozzle, it can throw a Bramble Seed, it rides a "
    "grappling vine, and it carries a seedling. It is small, kind and a bit scrappy, repaired by "
    "neighbours. It has small stumpy legs (no tracks, no wheels)."
)

DIRECTIONS = {
    "evolve": (
        "DESIGN: the established Seven, polished. A round cream dome head with a deep emerald stripe "
        "over the top and two small dark rectangular eyes; a barrel-shaped emerald body with a cream "
        "chest patch and a cream band at the waist; round emerald shoulder joints; short cream arms; "
        "small stumpy legs. In its raised hand it holds a glowing seedling. Add a small cream seed tank "
        "on its back with a gold cap (visible in the side and back views), and a short gold nozzle on "
        "its other hand for shooting seed pods. Keep it close to this shape, just cleaner and more "
        "characterful."
    ),
    "engineer": (
        "DESIGN: a NEW silhouette, the gardener-engineer. A small solar-panel sun hat on its head: a "
        "wide round brim made of a tiny cream-and-gold solar panel, with the seedling sprouting from a "
        "little hole in the hat's crown. A round cream face-window under the brim with two small dark "
        "eyes. A seed-hopper body: a short emerald barrel shaped like a watering can or a seed "
        "hopper, with a cream belly band, a gold rivet pattern and a small tool belt. One arm ends in "
        "a short gold seed-pod nozzle like a watering spout; the other is a small three-fingered hand. "
        "Chunky stumpy legs with cream boots."
    ),
    "sprout": (
        "DESIGN: a NEW silhouette, the seed-pod mascot. A rounder, smaller, egg-shaped emerald body, "
        "wider at the bottom, like a big seed pod, with a smooth cream face-dome window on the upper "
        "half showing two small dark eyes. Two leaf-shaped emerald ears or antennae on top, and a "
        "glowing seedling growing from the very top of its head. Short vine-like tendril arms ending in "
        "small cream mitten hands, one holding a gold seed-pod nozzle. Tiny round stumpy feet in cream. "
        "A cream seed-pod belly seam."
    ),
}


def build_sheet(takes_by_direction: dict) -> None:
    """Put every picture on one contact sheet: a row per direction, a column per take."""
    columns = max(len(v) for v in takes_by_direction.values())
    tile_w, tile_h, label, gap = 720, 405, 18, 10
    sheet = Image.new("RGB", (columns * (tile_w + gap) + gap, len(takes_by_direction) * (tile_h + label + gap) + gap), (40, 44, 48))
    draw = ImageDraw.Draw(sheet)
    for row, (direction, files) in enumerate(sorted(takes_by_direction.items())):
        for column, path in enumerate(files):
            picture = Image.open(path).convert("RGB")
            picture.thumbnail((tile_w, tile_h))
            x, y = gap + column * (tile_w + gap), gap + row * (tile_h + label + gap)
            draw.text((x, y), f"seven {direction} take {column + 1}", fill=(235, 235, 225))
            sheet.paste(picture, (x, y + label))
    sheet.save(OUT / "contact_sheet.png")
    print("saved contact_sheet.png")


def main() -> None:
    """Make every direction's takes (skipping files that exist) and build the contact sheet.
    The 'evolve' direction also receives the current Seven as a reference picture, so the polished
    version stays recognisably the same character; the two new silhouettes get no reference, so
    the model is free to invent."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--direction", choices=list(DIRECTIONS))
    parser.add_argument("--takes", type=int, default=2)
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    key = concepts.get_key()
    made = {}
    for direction, design in DIRECTIONS.items():
        if args.direction and direction != args.direction:
            continue
        prompt = "\n\n".join([STYLE, BRIEF, design])
        references = (CURRENT,) if direction == "evolve" else ()
        made[direction] = []
        for take in range(1, args.takes + 1):
            file = OUT / f"seven_{direction}_{take}.png"
            if not file.exists():
                file.write_bytes(concepts.generate(prompt, key, references=references, aspect="16:9"))
                print(f"made {file.name}")
            made[direction].append(file)
    # The sheet covers every picture on disk, not only this run's.
    on_disk = {d: sorted(OUT.glob(f"seven_{d}_*.png")) for d in DIRECTIONS}
    build_sheet({d: f for d, f in on_disk.items() if f})


if __name__ == "__main__":
    main()
