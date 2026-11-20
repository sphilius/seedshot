"""gen_concepts.py - generate concept art for Seedshot's machine redesigns with Gemini.

WHY
    Sasha asked for proper redesigns of all six Helios machines, with NEW SHAPES, in two
    art directions: Brutalist utility and Corporate cheerful. Concept art comes first; the
    game sprites are rebuilt from the chosen pictures later (as pixel art, with Klad).

THE SIX MACHINES (this file holds the first three; the rest come after Sasha reacts)
    Arc Spitter   ranged escort: fires a fan of three bolts, guards the Sawbots
    Linebreaker   heavy repo unit: shielded, slow, hits twice as hard, brings three Spitters
    Ripsaw        a big, fast Sawbot: cuts trees twice as fast, hunts the Heart Tree
    (later) Scrapper, Sawbot, Spitter

HOW IT WORKS
    Each picture is ONE request to the Gemini image model: a shared style block, the art
    direction's look, and the machine's own brief (its job and its new SHAPE). Every prompt
    also asks for a small pure-black silhouette beside the machine, so shapes can be
    compared at a glance (a game sprite is judged by its silhouette first).

USAGE (from the project root; needs the GEMINI_API_KEY user environment variable)
    python tools/gen_concepts.py                       all machines, both directions, 2 takes
    python tools/gen_concepts.py --machine ripsaw      one machine
    python tools/gen_concepts.py --direction brutalist one direction
    python tools/gen_concepts.py --takes 3 --force     more takes / redo existing files
    python tools/gen_concepts.py --sheet               only rebuild the contact sheet

OUT
    art/concept/robot_redesign_v2/<machine>_<direction>_<take>.png
    art/concept/robot_redesign_v2/contact_sheet.png

COST
    Each picture is one image request, a few cents at most. The default is 3 x 2 x 2 = 12.
"""
import argparse
import base64
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art/concept/robot_redesign_v2"
MODEL = "gemini-nano-banana-2.1"  # the "Nano Banana 2.1" image model the first art used
ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

# ---- What every picture shares ------------------------------------------------------------
STYLE = (
    "Concept art for a top-down arena game, seen from a high three-quarter angle (looking down "
    "at the machine from above and a little in front). ONE enemy machine, large and centred, "
    "on a plain flat light-grey background. Clean stylised illustration with bold readable shapes "
    "and flat shading, designed to still read when shrunk to 64 pixels, so keep the form simple "
    "and chunky with a strong, unique silhouette. Beside the machine, add one small panel "
    "showing that same machine as a pure solid black silhouette from the same angle. "
    "No text, no labels, no logos with words, no human characters, no scenery, no extra machines. "
    "The world: a solarpunk block fighting Helios Clean Energy, a company that owns the sun and "
    "sends repossession machines; its machines are cold company hardware."
)

# ---- The two art directions ---------------------------------------------------------------
DIRECTIONS = {
    "brutalist": (
        "ART DIRECTION: BRUTALIST UTILITY. Faceless hardware following orders. Heavy, blocky, "
        "hard-edged slabs and wedges; matte concrete and gunmetal greys with orange rust "
        "streaks and scuffs; bolts, vents and seams; black slots instead of eyes; only a few "
        "tiny red status lights. Menacing, industrial, built not designed. No smiles, no faces."
    ),
    "cheerful": (
        "ART DIRECTION: CORPORATE CHEERFUL. A friendly toy-like company mascot whose "
        "friendliness is the menace. Smooth rounded forms like a glossy plastic toy; "
        "Helios blue (about #3f7cb8) and white with sunny yellow (#f2c230) uniform stripes "
        "and trim; a simple smiling face plate (two dot eyes and a smile) where a head or "
        "sensor would be; tidy bolts and a small sun badge without words. Cute but "
        "quietly wrong."
    ),
}

# ---- The machines: job, and the NEW SHAPE for each art direction ---------------------------
MACHINES = {
    "arc_spitter": {
        "job": (
            "MACHINE: the ARC SPITTER, a ranged escort unit. It stands back and fires a FAN of "
            "three electric bolts, and it guards the Sawbots. Its current game sprite is a "
            "tall bottle-shape on spider legs: do NOT repeat that shape."
        ),
        "brutalist": (
            "NEW SHAPE: a squat tripod battery. A heavy square bunker body sitting low on three "
            "short splayed legs, with three fat coil emitters on top, angled outward in a fan, "
            "like a three-barrel mortar. Wide and low, nothing tall. Rust and soot around the "
            "barrels. One small red light on the front slab."
        ),
        "cheerful": (
            "NEW SHAPE: a round bobbing pod. A plump spherical body hovering just above the "
            "floor on a short stalk and three little feet, with three small petal-shaped "
            "emitter fins fanning out from the top like a flower or a sunburst, each tip "
            "glowing electric blue. A big smiling face plate on the front of the sphere."
        ),
    },
    "linebreaker": {
        "job": (
            "MACHINE: the LINEBREAKER, Helios's heavy repossession unit. Slow, shielded, hits "
            "twice as hard as anything else, and brings three small escorts. It is the biggest "
            "machine in the game. Its current sprite is a small claw-armed barrel: do NOT "
            "repeat that shape."
        ),
        "brutalist": (
            "NEW SHAPE: a battering-ram plough. A very wide, low wedge of armour with a thick "
            "angled blast-shield slab across the front, two short piston arms behind it, and "
            "heavy chunky tracks or rollers underneath. Like a bulldozer made of a bunker. "
            "A single narrow black viewing slot and one small red light."
        ),
        "cheerful": (
            "NEW SHAPE: a giant round bumper-car mascot. A big, tall rounded barrel body on "
            "four fat wheels, with a huge soft rounded bumper at the front in yellow-and-white "
            "safety stripes, a smiling face plate high on the body and a small sun badge. "
            "Huge and friendly, like an oversized toy steamroller."
        ),
    },
    "ripsaw": {
        "job": (
            "MACHINE: the RIPSAW, a big, fast, upgraded Sawbot that cuts trees twice as fast "
            "and goes straight for the Heart Tree. It must read as DANGEROUS and use RED "
            "prominently (red is the colour of enemies that will hurt you). Its current sprite "
            "is a boxy body with a small round saw on top: do NOT repeat that shape."
        ),
        "brutalist": (
            "NEW SHAPE: a rolling blade. A long, low, aggressive body built behind ONE huge "
            "vertical circular saw blade at the front, taller than the body, with big jagged "
            "teeth, like a giant sawblade wheel with an engine strapped behind it. Twin "
            "exhaust stacks at the back, red warning paint on the blade guard, rust streaks."
        ),
        "cheerful": (
            "NEW SHAPE: a smiling sunburst blade. A big round saw blade shaped like a daisy "
            "or sun, with a smiling face on its hub, rolling on a small compact body with two "
            "stubby legs. Blade teeth are alternating red and yellow stripes like candy; "
            "the body is blue and white. Cute, but the red blade says danger."
        ),
    },
}


def get_key() -> str:
    """The Gemini key: from this program's environment, else fresh from Windows' user-level
    variables (a shell started before the key was set would not have it). Never printed."""
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        key = subprocess.run(
            ["pwsh", "-NoProfile", "-Command", "[Environment]::GetEnvironmentVariable('GEMINI_API_KEY','User')"],
            capture_output=True, text=True,
        ).stdout.strip()
    if not key:
        sys.exit("GEMINI_API_KEY is not set.")
    return key


def generate(prompt: str, key: str) -> bytes:
    """Ask the model for one picture and return its PNG/JPEG bytes.
    The reply holds a list of "parts"; a picture part carries its data base64-encoded
    under `inlineData`, so we look for the first part that has it."""
    body = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"responseModalities": ["TEXT", "IMAGE"], "imageConfig": {"aspectRatio": "4:3"}},
    }
    request = urllib.request.Request(
        ENDPOINT.format(model=MODEL), data=json.dumps(body).encode("utf-8"), method="POST",
        headers={"x-goog-api-key": key, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=180) as reply:
            data = json.load(reply)
    except urllib.error.HTTPError as error:
        sys.exit(f"Gemini refused ({error.code}): {error.read().decode('utf-8', 'replace')[:500]}")
    for candidate in data.get("candidates", []):
        for part in candidate.get("content", {}).get("parts", []):
            if "inlineData" in part:
                return base64.b64decode(part["inlineData"]["data"])
    # No picture came back: show what the model said instead (often a refusal reason).
    texts = [p.get("text", "") for c in data.get("candidates", []) for p in c.get("content", {}).get("parts", [])]
    sys.exit("no picture returned: " + " ".join(texts)[:400] + " " + json.dumps(data.get("promptFeedback", {}))[:300])


def build_sheet() -> None:
    """Tile every picture into one labelled contact sheet: a row per machine, and the
    brutalist takes then the cheerful takes across."""
    OUT.mkdir(parents=True, exist_ok=True)
    tile_w, tile_h, label_h, gap = 420, 315, 18, 10
    files = {}
    for path in sorted(OUT.glob("*_*_*.png")):
        machine, direction, take = path.stem.rsplit("_", 2)
        files.setdefault(machine, []).append((direction, take, path))
    if not files:
        print("no pictures to sheet")
        return
    columns = max(len(v) for v in files.values())
    sheet = Image.new("RGB", (columns * (tile_w + gap) + gap, len(files) * (tile_h + label_h + gap) + gap), (40, 44, 48))
    draw = ImageDraw.Draw(sheet)
    for row, machine in enumerate(sorted(files)):
        for column, (direction, take, path) in enumerate(sorted(files[machine])):
            picture = Image.open(path).convert("RGB")
            picture.thumbnail((tile_w, tile_h))  # shrinks in place, keeping the proportions
            x = gap + column * (tile_w + gap)
            y = gap + row * (tile_h + label_h + gap)
            draw.text((x, y), f"{machine}  {direction}  take {take}", fill=(235, 235, 225))
            sheet.paste(picture, (x, y + label_h))
    sheet.save(OUT / "contact_sheet.png")
    print("saved contact_sheet.png")


def main() -> None:
    """Read the command-line choices, then make one picture per machine, art direction
    and take. The nested for-loops walk machine -> direction -> take; `continue` skips an
    entry that was not asked for (--machine / --direction), and an existing file is skipped
    unless --force is given, so a stopped run can be started again without paying twice.
    `"\\n\\n".join([...])` glues the four prompt parts together with a blank line between."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--machine", choices=list(MACHINES))
    parser.add_argument("--direction", choices=list(DIRECTIONS))
    parser.add_argument("--takes", type=int, default=2)
    parser.add_argument("--force", action="store_true", help="redo pictures that already exist")
    parser.add_argument("--sheet", action="store_true", help="only rebuild the contact sheet")
    args = parser.parse_args()
    if args.sheet:
        build_sheet()
        return
    OUT.mkdir(parents=True, exist_ok=True)
    key = get_key()
    for machine, brief in MACHINES.items():
        if args.machine and machine != args.machine:
            continue
        for direction, look in DIRECTIONS.items():
            if args.direction and direction != args.direction:
                continue
            prompt = "\n\n".join([STYLE, look, brief["job"], brief[direction]])
            for take in range(1, args.takes + 1):
                file = OUT / f"{machine}_{direction}_{take}.png"
                if file.exists() and not args.force:
                    print(f"skip {file.name} (exists)")
                    continue
                file.write_bytes(generate(prompt, key))
                print(f"made {file.name}")
    build_sheet()


if __name__ == "__main__":
    main()
