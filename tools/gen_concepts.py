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

ROUND 3: AN EVEN SPLIT (python tools/gen_concepts.py --set split)
    With the same six elements (FORM, MARKINGS, CONDITION, SURFACE, COLOUR, FACE) an even
    split gives each art direction exactly three of them. There are two ways to deal them out,
    so the set has two styles, each the other's mirror:
      split_a  "hard shell, happy paint": brutalist FORM, MARKINGS and CONDITION; cheerful
               SURFACE (glossy enamel), COLOUR (Helios blue, white, yellow) and FACE.
      split_b  "soft shell, hard paint": cheerful FORM, MARKINGS and CONDITION; brutalist
               SURFACE (matte raw metal), COLOUR (grey and safety orange) and FACE (none).
    Again no ratio is typed into any prompt.

ROUND 4: THE PICK (Sasha chose Split A, 2026-11-20)
    Chosen: Arc Spitter split_a take 1, Linebreaker split_a take 2, and a Ripsaw built from
    TWO takes: the body, paint and face plate of take 1 with the long extended saw arm and
    blade of take 2 (python tools/gen_concepts.py --merge-ripsaw, which sends both pictures
    to the model as references). The Scrapper, Sawbot and Spitter are added in Split A only,
    with new shapes that differ from every machine above (python tools/gen_concepts.py
    --set split --machine scrapper).

ROUND 5: THE SCRAPPER, NOT HUMANOID (python tools/gen_concepts.py --scrapper-shapes)
    Sasha picked Spitter take 2 and Sawbot take 2, and rejected both humanoid Scrapper takes:
    "it shouldn't be humanoid at all". This makes the Scrapper again in the same Split A style
    with three non-humanoid shapes (a crab crawler, a flail roller, a hammer ram), 2 takes each.

USAGE (from the project root; needs the GEMINI_API_KEY user environment variable)
    python tools/gen_concepts.py                       all machines, both directions, 2 takes
    python tools/gen_concepts.py --set split           the two even-split styles (round 3)
    python tools/gen_concepts.py --set hybrid          the two hybrid directions (round 2)
    python tools/gen_concepts.py --machine ripsaw      one machine
    python tools/gen_concepts.py --direction brutalist one direction
    python tools/gen_concepts.py --takes 3 --force     more takes / redo existing files
    python tools/gen_concepts.py --sheet               only rebuild the contact sheet

OUT
    art/concept/robot_redesign_v2/<machine>_<direction>_<take>.png          (--set pure, the default)
    art/concept/robot_redesign_v3_hybrid/<machine>_<direction>_<take>.png   (--set hybrid)
    art/concept/robot_redesign_v4_split/<machine>_<direction>_<take>.png    (--set split)
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
OUT_SPLIT = ROOT / "art/concept/robot_redesign_v4_split"
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

# ---- Round 3: an even split, dealt out element by element ----------------------------------
SPLIT_DIRECTIONS = {
    "split_a": (
        "ART DIRECTION: HARD SHELL, HAPPY PAINT. Brutal, armoured hardware wearing a cheerful "
        "company paint job and a smiling face. Describe it exactly like this:\n"
        "- FORM: hard blocky slabs, wedges and cylinders with sharp angular edges and parts "
        "sticking out of the silhouette. Nothing soft or toy-like in the shape.\n"
        "- MARKINGS: visible bolts, vents, panel seams, yellow-and-black hazard stripes on the "
        "edges, and a few tiny red status lights.\n"
        "- CONDITION: battle-worn. The paint is chipped, scratched and burnt in places, with "
        "orange rust streaks and soot showing through.\n"
        "- SURFACE: glossy painted enamel, like a plastic toy or a new appliance, wherever the "
        "paint has not worn away.\n"
        "- COLOUR: bright Helios blue (about #3f7cb8) and white, with sunny yellow (#f2c230) trim.\n"
        "- FACE: a friendly smiling face plate with two dot eyes and a smile, set into a flat "
        "armour slab on the front."
    ),
    "split_b": (
        "ART DIRECTION: SOFT SHELL, HARD PAINT. A cute, toy-shaped machine made of cold raw "
        "industrial metal with no face. Describe it exactly like this:\n"
        "- FORM: chubby, rounded, toy-like body with smooth soft curves and friendly proportions. "
        "A clean, simple, strong silhouette with no sharp angular slabs.\n"
        "- MARKINGS: neat, tidy uniform stripe bands, a small sun badge and small tidy rivets, "
        "all placed symmetrically like factory branding.\n"
        "- CONDITION: clean and intact, like it has just left the factory. No rust, no dents, "
        "no soot.\n"
        "- SURFACE: matte, raw, unpainted-looking steel and cast metal. No gloss, no shiny plastic.\n"
        "- COLOUR: concrete grey and gunmetal with safety-orange accents and white stripes. No blue "
        "and no yellow anywhere. Red appears only as warning lights and where the brief says so.\n"
        "- FACE: no face at all. Where a head or sensor would be there is a black slot lens with "
        "one small red light. No smile, no eyes."
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
        "split_a": (
            "SHAPE: the squat tripod battery. A heavy square bunker body low on three short "
            "splayed legs, with three thick corrugated emitter barrels fanning outward from the "
            "top, the tips glowing electric blue. The glossy blue-and-white paint covers the "
            "bunker, chipped at the corners, and the smiling face plate is set in the front slab."
        ),
        "split_b": (
            "SHAPE: the round bobbing pod. A plump spherical body of matte grey metal hovering on "
            "a short stalk and three little feet, with three small petal-shaped emitter fins "
            "fanning from the top, their tips glowing electric blue. Safety-orange and white "
            "stripe bands circle it. A black slot lens with one red light on the front."
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
        "split_a": (
            "SHAPE: the battering-ram plough. A very wide, low wedge of angular armour with a "
            "thick angled plough blade across the front, two piston arms, and heavy tracks. "
            "Glossy blue-and-white paint on the armour with yellow trim, chipped and rusted, and a "
            "smiling face plate set in the front armour slab above the blade."
        ),
        "split_b": (
            "SHAPE: the giant round mascot. A tall, chubby barrel body of matte grey metal on "
            "four fat wheels, with a huge soft rounded bumper at the front striped in safety "
            "orange and white. A small sun badge on the side and a black slot lens with one red "
            "light high on the body."
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
        "split_a": (
            "SHAPE: the rolling blade. A long, low, aggressive body behind ONE huge vertical "
            "circular saw blade taller than the body, with big jagged teeth painted in red and "
            "yellow stripes. The engine body has glossy blue-and-white paint, chipped and rusty, "
            "twin exhaust stacks, and a smiling face plate set in the front of the engine cowling."
        ),
        "split_b": (
            "SHAPE: the sunburst blade. A big round saw blade shaped like a sun, in matte raw "
            "steel, rolling on a compact chubby grey body with two stubby legs. The blade's rim "
            "guard is painted warning red, with safety-orange and white stripe bands on the body "
            "and a small sun badge. The hub is a black slot lens with one red light."
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


# ---- Round 4: the rest of the cast, Split A only -------------------------------------------
# Each shape is NEW and different from the other five machines: the tripod battery (Arc
# Spitter), the plough (Linebreaker) and the rolling blade (Ripsaw) are taken.
MACHINES["scrapper"] = {
    "job": (
        "MACHINE: the SCRAPPER, Helios's basic melee grunt. It walks up to the player's tiny "
        "gardener robot and smashes it with a telegraphed swing. It is the most common machine. "
        "Its current sprite is a rusty barrel with two tall claw arms raised: do NOT repeat that shape."
    ),
    "split_a": (
        "SHAPE: a hunched brawler. An upright, wide-shouldered armoured torso on two thick stumpy "
        "legs with big flat feet, leaning forward. One enormous hydraulic pincer claw hangs from a "
        "heavy arm on one side and a small hooked arm on the other. A flat armour slab for a "
        "head, with the smiling face plate set in it. Glossy blue-and-white paint, chipped and "
        "rusted, hazard stripes on the shoulders, small red lights."
    ),
}
MACHINES["sawbot"] = {
    "job": (
        "MACHINE: the SAWBOT, a small tree-cutter that ignores the player and walks to the "
        "nearest tree to saw it down. It is the little sibling of the RIPSAW (a big, up-armoured "
        "rolling saw with a long saw arm), so it shares that family look in a smaller, "
        "lighter, simpler form. Its current sprite is a boxy body with a small round saw on top."
    ),
    "split_a": (
        "SHAPE: a compact wheeled dolly. A small, low, open frame on two big chunky wheels with a "
        "short forward saw arm carrying one modest circular blade with red-and-yellow striped teeth. "
        "A small engine block with a single exhaust stack, lightly armoured, with the smiling face "
        "plate on the front of the engine. Glossy blue-and-white paint, chipped and rusty, "
        "hazard stripes, tiny red lights."
    ),
}
MACHINES["spitter"] = {
    "job": (
        "MACHINE: the SPITTER, a ranged machine that stands off and fires single small spit shots "
        "at the player. It is not the ARC SPITTER (that one is a squat three-barrel tripod "
        "battery that fires a fan of bolts). Its current sprite is a bottle on spider legs."
    ),
    "split_a": (
        "SHAPE: a tall slim sentry. A narrow, tall rectangular armoured tower balanced on a "
        "single big spherical roller foot, with ONE long barrel pointing forward from the front of "
        "the tower, and a small periscope antenna on top. The smiling face plate is set in the "
        "tower's front slab. Glossy blue-and-white paint, chipped and rusty, hazard stripes at the "
        "base, tiny red lights."
    ),
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


def generate(prompt: str, key: str, references: tuple = (), aspect: str = "4:3") -> bytes:
    """Ask the model for one picture and return its PNG/JPEG bytes.
    The reply holds a list of "parts"; a picture part carries its data base64-encoded
    under `inlineData`, so we look for the first part that has it."""
    # Reference pictures go in as extra "parts" before the text: each is its raw bytes,
    # base64-encoded, labelled with its file type. The prompt can then say "image 1" and "image 2".
    parts = []
    for reference in references:
        data = Path(reference).read_bytes()
        parts.append({"inlineData": {"mimeType": "image/png", "data": base64.b64encode(data).decode("ascii")}})
    parts.append({"text": prompt})
    body = {
        "contents": [{"parts": parts}],
        "generationConfig": {"responseModalities": ["TEXT", "IMAGE"], "imageConfig": {"aspectRatio": aspect}},
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


# The Scrapper's job again, now with the one hard rule Sasha added: nothing humanoid.
SCRAPPER_JOB = (
    "MACHINE: the SCRAPPER, Helios's basic melee grunt. It crawls up to the player's tiny "
    "gardener robot and smashes it with a telegraphed swing. It is the most common machine. "
    "HARD RULE: it must NOT be humanoid in any way: no torso with two arms and two legs, no head "
    "on shoulders, no biped stance, nothing that reads as a robot person or a mech suit. It should "
    "look like a work machine or a creature-like tool. The smiling face plate is a flat plate set "
    "into the front of its body, not a head."
)
SCRAPPER_SHAPES = {
    "crab": (
        "SHAPE: a crab crawler. A low, wide, flat armoured body that sits close to the ground on "
        "six short bent legs, with two big hydraulic pincer claws held out in front like a crab's. "
        "The smiling face plate is set in the front slab of the body between the claws."
    ),
    "flail": (
        "SHAPE: a flail roller. A fat horizontal drum body that rolls on two big wide drum wheels "
        "at its sides, with a long jointed boom arm rising from the top that swings a heavy "
        "wrecking-ball mace on a chain. The smiling face plate is set in the front of the drum."
    ),
    "ram": (
        "SHAPE: a hammer ram. A low, squat slab body on four stubby crawler pods, with one huge "
        "piston hammer head on a thick boom that arches over the body like a stamping press, ready "
        "to smash straight down in front of it. The smiling face plate is set in the front slab."
    ),
}


def make_scrapper_shapes(key: str, takes: int) -> None:
    """Generate the non-humanoid Scrapper: every shape, the Split A look, `takes` pictures each.
    Files: scrapper_split_a_<shape>_<take>.png. Existing files are skipped, so a stopped
    run can be started again without paying twice."""
    for shape, text in SCRAPPER_SHAPES.items():
        prompt = "\n\n".join([STYLE, SPLIT_DIRECTIONS["split_a"], SCRAPPER_JOB, text])
        for take in range(1, takes + 1):
            file = OUT_SPLIT / f"scrapper_split_a_{shape}_{take}.png"
            if file.exists():
                print(f"skip {file.name} (exists)")
                continue
            file.write_bytes(generate(prompt, key))
            print(f"made {file.name}")


MERGE_PROMPT = (
    "You are given two reference concept pictures of the SAME enemy machine, the RIPSAW, made in the "
    "same art style.\n"
    "IMAGE 1 supplies the core: the compact blue-and-white tracked body, the engine cowling, the "
    "twin exhaust stacks, the chipped glossy paint and hazard stripes, and the smiling face plate "
    "on the front of the cowling. Keep all of that exactly as it is.\n"
    "IMAGE 2 supplies the saw: the long extended saw ARM that reaches far out from the body, with the "
    "big joint where it attaches, carrying the huge vertical circular blade with red-and-yellow "
    "striped teeth, taller than the body.\n"
    "Draw ONE new picture of a single machine: the body, paint and face plate of image 1 carrying "
    "the long extended saw arm and blade of image 2, mounted on the body and reaching forward. Same "
    "high three-quarter view, same flat light-grey background, same style. Beside the machine, add one "
    "small panel with that machine as a pure solid black silhouette from the same angle. No text, no "
    "extra machines."
)


def merge_ripsaw(key: str, takes: int) -> None:
    """Make the Ripsaw Sasha asked for by sending split_a take 1 and take 2 together as
    references. The results are named ripsaw_split_a_merged_<n>.png."""
    sources = (OUT_SPLIT / "ripsaw_split_a_1.png", OUT_SPLIT / "ripsaw_split_a_2.png")
    for take in range(1, takes + 1):
        file = OUT_SPLIT / f"ripsaw_split_a_merged_{take}.png"
        file.write_bytes(generate(MERGE_PROMPT, key, references=sources))
        print(f"made {file.name}")


# split_name turns a picture's file name back into (machine, direction, take) so the contact
# sheet can group pictures into rows and columns. It checks the known direction names because
# machine names (arc_spitter) and direction names (split_a) both contain underscores.
def split_name(stem: str) -> tuple:
    """Split 'arc_spitter_hybrid_brutal_1' into ('arc_spitter', 'hybrid_brutal', '1').
    A direction name is found inside the file name, the take is the last piece, and
    whatever comes before the direction is the machine."""
    for direction in list(DIRECTIONS) + list(HYBRID_DIRECTIONS) + list(SPLIT_DIRECTIONS):
        marker = f"_{direction}_"
        if marker in stem:
            machine, take = stem.split(marker)
            return machine, direction, take
    # "ripsaw_split_a_merged_1": the merge results carry a word between direction and take.
    if "_split_a_merged_" in stem:
        machine, take = stem.split("_split_a_merged_")
        return machine, "split_a_merged", take
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
    parser.add_argument("--set", choices=["pure", "hybrid", "split"], default="pure",
                        help="pure = round 1, hybrid = round 2, split = round 3")
    parser.add_argument("--direction", choices=list(DIRECTIONS) + list(HYBRID_DIRECTIONS) + list(SPLIT_DIRECTIONS))
    parser.add_argument("--takes", type=int, default=2)
    parser.add_argument("--force", action="store_true", help="redo pictures that already exist")
    parser.add_argument("--sheet", action="store_true", help="only rebuild the contact sheet")
    parser.add_argument("--merge-ripsaw", action="store_true", help="round 4: merge Ripsaw takes 1 and 2")
    parser.add_argument("--scrapper-shapes", action="store_true", help="round 5: non-humanoid Scrapper, 3 shapes")
    args = parser.parse_args()
    # Pick the set: which art directions, and which folder the pictures go to.
    # A dictionary used as a lookup table: set name -> (its art directions, its folder).
    sets = {"pure": (DIRECTIONS, OUT), "hybrid": (HYBRID_DIRECTIONS, OUT_HYBRID), "split": (SPLIT_DIRECTIONS, OUT_SPLIT)}
    directions, out = sets[args.set]
    if args.sheet:
        build_sheet(out)
        return
    out.mkdir(parents=True, exist_ok=True)
    key = get_key()
    if args.scrapper_shapes:
        make_scrapper_shapes(key, args.takes)
        return
    if args.merge_ripsaw:
        merge_ripsaw(key, args.takes)
        build_sheet(OUT_SPLIT)
        return
    for machine, brief in MACHINES.items():
        if args.machine and machine != args.machine:
            continue
        for direction, look in directions.items():
            if args.direction and direction != args.direction:
                continue
            if direction not in brief:  # this machine was only designed in some directions
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
