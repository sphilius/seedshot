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

ROUND 2: TWO HYBRIDS (python tools/gen_concepts.py --set hybrid)
    A hybrid is not a ratio typed into a prompt. Each art direction was broken into the
    separate things a picture is made of: FORM, SURFACE, PALETTE, FACE, MARKINGS, WEAR.
    Each hybrid then says, for every one of those, which direction supplies it and how much
    of the other is allowed in, in physical terms (which panels, which edges):
      hybrid_brutal  "company livery on industrial hardware": brutalist form, surface and
                     wear; the cheerful side shows up only as factory paint (a blue panel,
                     hazard stripes) and a peeling smiley decal.
      hybrid_cheer   "a cute mascot, up-armoured": cheerful form, glossy shell and smiling
                     face; the brutalist side shows up as bolted steel plates, exhausts,
                     scuffs, soot and one red status light.
    The prompts never contain the numbers 70 or 30.

USAGE (from the project root; needs the GEMINI_API_KEY user environment variable)
    python tools/gen_concepts.py                       all machines, both directions, 2 takes
    python tools/gen_concepts.py --set hybrid          the two hybrid directions (round 2)
    python tools/gen_concepts.py --machine ripsaw      one machine
    python tools/gen_concepts.py --direction brutalist one direction
    python tools/gen_concepts.py --takes 3 --force     more takes / redo existing files
    python tools/gen_concepts.py --sheet               only rebuild the contact sheet

OUT
    art/concept/robot_redesign_v2/<machine>_<direction>_<take>.png          (--set pure, the default)
    art/concept/robot_redesign_v3_hybrid/<machine>_<direction>_<take>.png   (--set hybrid)
    ...and a contact_sheet.png beside each set

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
OUT_HYBRID = ROOT / "art/concept/robot_redesign_v3_hybrid"
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

# ---- Round 2: the two hybrids, written element by element ----------------------------------
HYBRID_DIRECTIONS = {
    "hybrid_brutal": (
        "ART DIRECTION: COMPANY LIVERY ON INDUSTRIAL HARDWARE. This is heavy, brutal "
        "hardware that a cheerful company has repainted and branded. Describe it exactly like this:\n"
        "- FORM: hard blocky slabs, wedges and cylinders, with only the outer corners of the armour "
        "chamfered or slightly rounded. A strong silhouette with parts sticking out of it.\n"
        "- SURFACE: matte, weathered gunmetal and concrete-grey steel, scuffed, with orange rust "
        "streaks and soot. No glossy toy plastic anywhere.\n"
        "- COLOUR: the machine is mostly grey and rust. The ONLY bright company colour is Helios "
        "blue (about #3f7cb8) factory paint on one or two large armour panels, and it is chipped, "
        "scratched and rusted through at the edges. Yellow-and-white hazard stripes appear only on "
        "the leading edges and guards.\n"
        "- FACE: the machine has NO face of its own, only a black slot or lens. The only cheerful "
        "touch is one small sticker-like smiley decal and a tiny sun badge on a panel, half peeled "
        "and scratched.\n"
        "- DETAIL: visible bolts, vents, seams and a few tiny red status lights."
    ),
    "hybrid_cheer": (
        "ART DIRECTION: UP-ARMOURED MASCOT. This is a cute company mascot machine that has been "
        "bolted up with extra armour to go to war. Describe it exactly like this:\n"
        "- FORM: chubby, rounded, toy-like main body with smooth soft curves and friendly "
        "proportions. A clean, simple, strong silhouette. Added on top of the soft body are one "
        "or two heavy, angular, bolted steel plates.\n"
        "- SURFACE: glossy painted enamel on the main shell, like a plastic toy, worn only at the "
        "edges and seams with scuffs, scratches and a little soot. Bare dull steel shows only on "
        "the added plates, vents and exhausts.\n"
        "- COLOUR: the machine is mostly Helios blue (about #3f7cb8), white and sunny yellow "
        "(#f2c230) uniform stripes. Grey steel and orange rust are limited to the added armour "
        "plates and the worn edges.\n"
        "- FACE: it keeps a smiling face plate with two dot eyes and a smile, but the plate is "
        "scratched and has a hairline crack, and its mouth is a dark vent-slot smile.\n"
        "- DETAIL: large rivets on the added plates, an exhaust stack or vent grille, and exactly "
        "one small red status light."
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
        "hybrid_brutal": (
            "SHAPE: the squat tripod battery. A heavy square bunker body with chamfered corners, "
            "low on three short splayed legs, with three thick corrugated emitter barrels fanning "
            "outward from the top. The front slab is one big chipped Helios-blue panel with a "
            "half-peeled sun badge and a scratched smiley decal. The barrel tips glow electric "
            "blue. Rust and soot around the barrels, one small red light, no face."
        ),
        "hybrid_cheer": (
            "SHAPE: the round bobbing pod. A plump glossy blue-and-white spherical body hovering on "
            "a short stalk and three little feet. Instead of soft petals, three short, squared "
            "gunmetal emitter barrels fan out from the top, each tip glowing electric blue. A "
            "bolted grey armour ring runs round the sphere's middle. The smiling face plate on the "
            "front has a crack and a vent-slot mouth."
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
        "hybrid_brutal": (
            "SHAPE: the battering-ram plough. A very wide, low wedge of grey armour with a thick "
            "angled plough blade across the front, two piston arms, and heavy tracks. The plough "
            "blade carries chipped yellow-and-white hazard stripes. One big side armour panel is "
            "chipped Helios blue with a peeling sun badge and a scratched smiley decal. A narrow "
            "black viewing slot, tiny red lights, rust and soot, no face."
        ),
        "hybrid_cheer": (
            "SHAPE: the giant round mascot. A tall, chubby, glossy blue-and-white barrel body on "
            "four fat wheels. The soft front bumper is replaced by a heavy dented steel plough "
            "blade with yellow-and-white hazard stripes. Bolted gunmetal armour plates cover the "
            "shoulders and the wheel arches, with rust at the arches and an exhaust stack at the "
            "back. A smiling face plate sits high on the body, scratched, with a vent-slot mouth."
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
        "hybrid_brutal": (
            "SHAPE: the rolling blade. A long, low, aggressive grey body built behind ONE huge "
            "vertical circular saw blade taller than the body, with big jagged steel teeth, rust "
            "and scuffs. The blade guard is red with chipped paint. The engine cowling carries a "
            "chipped Helios-blue panel with a white stripe, a half-peeled sun badge and a "
            "scratched smiley decal. Twin exhaust stacks, tracks, tiny red lights, no face."
        ),
        "hybrid_cheer": (
            "SHAPE: the smiling sunburst blade. A big round saw blade like a sun, rolling on a "
            "compact glossy blue-and-white body with two stubby legs that wear grey bolted knee "
            "plates. The blade's teeth are real chipped bare steel with red-and-yellow painted "
            "stripes worn away at the tips. The hub is a scratched smiling face with a vent-slot "
            "mouth. A small exhaust stack on the body, one red light."
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


def split_name(stem: str) -> tuple:
    """Split 'arc_spitter_hybrid_brutal_1' into ('arc_spitter', 'hybrid_brutal', '1').
    A direction name is found inside the file name, the take is the last piece, and
    whatever comes before the direction is the machine."""
    for direction in list(DIRECTIONS) + list(HYBRID_DIRECTIONS):
        marker = f"_{direction}_"
        if marker in stem:
            machine, take = stem.split(marker)
            return machine, direction, take
    raise ValueError("unknown picture name: " + stem)


# build_sheet (below) makes the contact sheet for one folder of pictures. It takes the folder
# as a parameter, `out`, so the same function serves both the pure and the hybrid sets.
def build_sheet(out: Path) -> None:
    """Tile every picture in folder `out` into one labelled contact sheet: a row per
    machine, and the first direction's takes then the second's across."""
    out.mkdir(parents=True, exist_ok=True)
    tile_w, tile_h, label_h, gap = 420, 315, 18, 10
    files = {}
    for path in sorted(out.glob("*_*_*.png")):
        if path.stem == "contact_sheet":
            continue
        machine, direction, take = split_name(path.stem)
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
    sheet.save(out / "contact_sheet.png")
    print("saved contact_sheet.png")


def main() -> None:
    """Read the command-line choices, then make one picture per machine, art direction
    and take. The nested for-loops walk machine -> direction -> take; `continue` skips an
    entry that was not asked for (--machine / --direction), and an existing file is skipped
    unless --force is given, so a stopped run can be started again without paying twice.
    `"\\n\\n".join([...])` glues the four prompt parts together with a blank line between."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--machine", choices=list(MACHINES))
    parser.add_argument("--set", choices=["pure", "hybrid"], default="pure", help="pure = round 1, hybrid = round 2")
    parser.add_argument("--direction", choices=list(DIRECTIONS) + list(HYBRID_DIRECTIONS))
    parser.add_argument("--takes", type=int, default=2)
    parser.add_argument("--force", action="store_true", help="redo pictures that already exist")
    parser.add_argument("--sheet", action="store_true", help="only rebuild the contact sheet")
    args = parser.parse_args()
    # Pick the set: which art directions, and which folder the pictures go to.
    directions = HYBRID_DIRECTIONS if args.set == "hybrid" else DIRECTIONS
    out = OUT_HYBRID if args.set == "hybrid" else OUT
    if args.sheet:
        build_sheet(out)
        return
    out.mkdir(parents=True, exist_ok=True)
    key = get_key()
    for machine, brief in MACHINES.items():
        if args.machine and machine != args.machine:
            continue
        for direction, look in directions.items():
            if args.direction and direction != args.direction:
                continue
            prompt = "\n\n".join([STYLE, look, brief["job"], brief[direction]])
            for take in range(1, args.takes + 1):
                file = out / f"{machine}_{direction}_{take}.png"
                if file.exists() and not args.force:
                    print(f"skip {file.name} (exists)")
                    continue
                file.write_bytes(generate(prompt, key))
                print(f"made {file.name}")
    build_sheet(out)


if __name__ == "__main__":
    main()
