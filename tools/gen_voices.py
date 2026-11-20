"""gen_voices.py - design the radio voices and speak Seedshot's Helios and Canopy FM lines.

WHY
    Helios (the company, heard as customer service) and Canopy FM (the block's pirate
    radio, run by two young DJs) only existed as typed text. This makes their voices
    with ElevenLabs and saves one MP3 per line, so the radio can play them.

THE LINES ARE NOT COPIED HERE. They are read straight out of config/game_config.gd
    (the same file the game reads), so the audio always matches the words. If a line
    is rewritten, run `speak` again with --force for that line.

USAGE (from the project root; needs the ELEVENLABS_API_KEY user environment variable)
    python tools/gen_voices.py design              make the 3 voices (Voice Design; the API key
                                                   needs the "voice_generation" permission)
    python tools/gen_voices.py use                 OR: cast 3 voices already in the account as
                                                   stand-ins (needs no extra permission)
    python tools/gen_voices.py design --only helios   (or canopy_girl, canopy_boy)
    python tools/gen_voices.py speak               speak every line that has no file yet
    python tools/gen_voices.py speak --only helios (or canopy)
    python tools/gen_voices.py previews --only helios --round 2   make 3 NEW previews and keep
                                                   them (and their ids) without saving a voice
    python tools/gen_voices.py save helios 2 1     save preview 1 of round 2 as the voice
    python tools/gen_voices.py swap helios 2       replace a designed voice with a clone of its
                                                   candidate preview N (see the note on `swap`)
    python tools/gen_voices.py level               even out every line's loudness (run after speak)
    python tools/gen_voices.py count               how many characters speak would use

OUT
    audio/voice/voices.json         the saved voice ids (not secret: only usable with the key)
    audio/voice/candidates/*.mp3    every Voice Design preview, to listen to
    audio/voice/<line id>.mp3       one file per line, e.g. helios_lines_0.mp3, dj_intro_1.mp3
    audio/voice/manifest.json       line id -> speaker, text spoken, file (for wiring it up)

COST
    Voice Design and speech spend ElevenLabs credits. The model is eleven_flash_v2_5,
    which costs half a credit per character. `count` shows the total before spending.
"""
import argparse
import base64
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "config/game_config.gd"
OUT = ROOT / "audio/voice"
API = "https://api.elevenlabs.io"
MODEL = "eleven_flash_v2_5"  # half price per character, plenty for a muffled radio

# ---- Who says what: which config variables belong to whom ------------------------------
HELIOS_VARS = ["helios_lines", "helios_end_line"]
# Canopy FM, in the order the game first uses them. Each variable is one "cue": the lines
# said together. The two DJs trade lines inside a cue, and take turns starting cues.
CANOPY_VARS = [
    "dj_intro", "dj_intro_touch", "dj_first_tree", "dj_first_tree_touch",
    "dj_bramble", "dj_bramble_touch", "dj_first_sawbot", "dj_first_ripsaw",
    "dj_first_linebreaker", "dj_first_arc_spitter", "dj_tap_points", "heart_intro_line",
    "heart_alarm_line", "canopy_line_intro_line", "sunburst_intro_line", "grove_rest_line",
    "dj_music_hint", "ng_plus_wakeup_line", "ng_plus_threat_line", "dj_ng_plus_intro",
    "dj_cat_hints",
]

# ---- The three voices ---------------------------------------------------------------------
# `description` is what Voice Design reads (20 to 1000 characters). `sample` is the text
# the previews speak (100 to 1000 characters); it is a real line in that voice's style.
VOICES = {
    "helios": {
        "name": "Seedshot Helios",
        "description": (
            "A warm, polished woman in her thirties, like a recorded airline announcement or a "
            "customer service hotline. Smooth, bright and a little too cheerful, with an even, "
            "unhurried pace. Perfectly polite, with a faint chill underneath. Clean studio "
            "quality, standard American accent."
        ),
        "sample": (
            "Good evening, valued customer. Your sector's account is ninety minutes past due, and "
            "we hate to bring it up. Good news: a technician is on the way to help you. Please "
            "stay exactly where you are."
        ),
        "settings": {"stability": 0.65, "similarity_boost": 0.75, "style": 0.15},
    },
    "canopy_girl": {
        "name": "Seedshot Canopy Girl",
        "description": (
            "A young woman, about twenty, hosting a pirate radio show from a bedroom studio. "
            "Youthful, fast, fun, a little breathless, quick to laugh. American accent with a light "
            "bilingual Spanish-English lilt. Energetic and warm, like a friend whispering a secret."
            # (ElevenLabs blocks descriptions of minors, so the voice is a young adult; the
            # character can still be written as a teen.)
        ),
        "sample": (
            "Okay, new toy: press Q or Space to throw a Bramble Seed. Thorns grow where it lands, "
            "and every machine inside slows down and takes damage. Lob it at a crowd, or into a "
            "gateway they all have to squeeze through."
        ),
        "settings": {"stability": 0.35, "similarity_boost": 0.75, "style": 0.45},
    },
    "canopy_boy": {
        "name": "Seedshot Canopy Boy",
        "description": (
            "A young man, about nineteen, the laid-back co-host of a pirate radio show. Warm, "
            "relaxed, slightly husky voice with a smooth, easy cadence and dry humour. American "
            "accent. Sounds like he is leaning back in a chair, grinning, finishing his friend's "
            "sentence."
        ),
        "sample": (
            "Sawbot on the lot! It's not after you, it's after the trees. Drop it first. It'll "
            "head straight for the Heart, the big old tree in the middle. Lose the Heart, lose "
            "the wave. No pressure."
        ),
        "settings": {"stability": 0.4, "similarity_boost": 0.75, "style": 0.35},
    },
}


# ---- Reading the lines out of the config --------------------------------------------------
STRING_LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')  # a "quoted string", escapes allowed


def read_strings(variable: str) -> list:
    """Return the string(s) a config variable is set to, as a list.
    It finds the line `var <variable>: ... = <value>`; if the value starts with `[` it is a
    list, which runs until the line that holds the closing `]`. Then every "quoted string" in
    that stretch is decoded. (Only the text after the `=` is searched, so a default written
    in a comment cannot leak in.)"""
    lines = CONFIG.read_text(encoding="utf-8").splitlines()
    for number, line in enumerate(lines):
        if re.search(rf"\bvar {variable}\b", line):
            value = line.split("=", 1)[1]
            chunk = [value]
            if value.strip().startswith("[") and "]" not in value.split("[", 1)[1].rsplit("]", 1)[-1] and not value.rstrip().endswith("]"):
                # A multi-line list: keep reading lines until one ends the list.
                for later in lines[number + 1:]:
                    chunk.append(later)
                    if later.strip().startswith("]"):
                        break
            text = "\n".join(chunk)
            # json.loads understands \" and \n; GDScript's \' is not JSON, so drop it first.
            return [json.loads('"' + m.replace("\\'", "'") + '"') for m in STRING_LITERAL.findall(text)]
    sys.exit(f"variable not found in the config: {variable}")


def sunburst_charges() -> int:
    """The number the Sunburst line says (its %d): charges per wave, from the config."""
    match = re.search(r"var sunburst_charges_per_wave\b[^=]*=\s*(\d+)", CONFIG.read_text(encoding="utf-8"))
    return int(match.group(1)) if match else 2


def spoken(text: str) -> str:
    """Rewrite a typed line for a voice to read: spell out what a voice would mangle.
    The typed line on screen is unchanged; only the audio is told to say it this way."""
    text = text.replace("%d", str(sunburst_charges()))
    text = text.replace("WASD", "W, A, S, D").replace("MR-7", "M R seven")
    text = text.replace("...", "... ").replace("  ", " ")
    return text.strip()


def build_lines() -> list:
    """Every line to speak, as dictionaries: id, speaker (a VOICES key), typed text, spoken text."""
    lines = []
    for variable in HELIOS_VARS:
        for index, text in enumerate(read_strings(variable)):
            lines.append({"id": f"{variable}_{index}", "speaker": "helios", "text": text, "spoken": spoken(text)})
    for cue_number, variable in enumerate(CANOPY_VARS):
        for index, text in enumerate(read_strings(variable)):
            # Even cues start with the girl, odd ones with the boy; lines inside a cue alternate.
            girl = (cue_number + index) % 2 == 0
            lines.append({
                "id": f"{variable}_{index}",
                "speaker": "canopy_girl" if girl else "canopy_boy",
                "text": text,
                "spoken": spoken(text),
            })
    return lines


# ---- Talking to ElevenLabs -----------------------------------------------------------------
def call(path: str, body: dict, expect_json: bool = True):
    """POST `body` as JSON to the API and return the reply (parsed JSON, or raw bytes).
    The key is read from the environment and only ever sent as a header; it is never
    printed or written to a file."""
    key = os.environ.get("ELEVENLABS_API_KEY")
    if not key:
        sys.exit("ELEVENLABS_API_KEY is not set.")
    request = urllib.request.Request(
        API + path, data=json.dumps(body).encode("utf-8"),
        headers={"xi-api-key": key, "Content-Type": "application/json"}, method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=180) as reply:
            data = reply.read()
    except urllib.error.HTTPError as error:  # an HTTP error carries the server's explanation
        sys.exit(f"ElevenLabs refused ({error.code}): {error.read().decode('utf-8', 'replace')[:400]}")
    return json.loads(data) if expect_json else data


def credits_used() -> int:
    """Characters used so far this billing period (to show what a step cost)."""
    request = urllib.request.Request(API + "/v1/user/subscription", headers={"xi-api-key": os.environ["ELEVENLABS_API_KEY"]})
    with urllib.request.urlopen(request, timeout=30) as reply:
        return json.load(reply)["character_count"]


def load_voices() -> dict:
    """Return the saved voice ids (speaker name -> ElevenLabs voice id), or an empty
    dictionary if `design` has not run yet. `design` writes this file, and `speak` reads
    it, so the two steps can run on different days. `A if test else B` below is Python's
    one-line "conditional expression": it picks the file's contents or an empty dict."""
    path = OUT / "voices.json"
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def design(only) -> None:
    """Make the voices with Voice Design: ask for previews, keep them all to listen to,
    then save the first preview of each as a real voice in the account."""
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "candidates").mkdir(exist_ok=True)
    saved = load_voices()
    for key, voice in VOICES.items():
        if only and key != only:
            continue
        if key in saved:
            print(f"skip {key} (already designed: {saved[key]})")
            continue
        before = credits_used()
        reply = call("/v1/text-to-voice/design", {
            "voice_description": voice["description"], "text": voice["sample"],
        })
        previews = reply["previews"]
        # Keep every preview's id: a preview can only be saved as a voice through its id,
        # and the reply is the only place that id is ever shown.
        ids_file = OUT / "preview_ids.json"
        known = json.loads(ids_file.read_text(encoding="utf-8")) if ids_file.exists() else {}
        known[key] = [p["generated_voice_id"] for p in previews]
        ids_file.write_text(json.dumps(known, indent=2), encoding="utf-8")
        for number, preview in enumerate(previews):
            (OUT / "candidates" / f"{key}_preview{number}.mp3").write_bytes(base64.b64decode(preview["audio_base_64"]))
        created = call("/v1/text-to-voice", {
            "voice_name": voice["name"], "voice_description": voice["description"],
            "generated_voice_id": previews[0]["generated_voice_id"],
        })
        saved[key] = created["voice_id"]
        (OUT / "voices.json").write_text(json.dumps(saved, indent=2), encoding="utf-8")
        print(f"designed {key}: {len(previews)} previews, saved preview 0; cost {credits_used() - before} credits")


# Stand-in casting from voices already in Sasha's ElevenLabs account, used when Voice Design is
# not available. Each value is the START of a voice's name, matched against the account's list.
# Chosen from the voices' labels only (nobody has listened): swap any of them freely.
LIBRARY_CAST = {
    "helios": "Natasha",         # female, american, calm, smooth: the polished announcer
    "canopy_girl": "Ember",      # female, young, american, hyped: the energetic host
    "canopy_boy": "Fietroy",     # male, young, american, chill: the laid-back co-host
}


def use_library() -> None:
    """Fill voices.json from voices that already exist, instead of designing new ones.
    It asks the account for its voices (a GET request, which costs nothing), then, for each
    speaker, takes the first voice whose name starts with the chosen name."""
    request = urllib.request.Request(API + "/v2/voices?page_size=100", headers={"xi-api-key": os.environ["ELEVENLABS_API_KEY"]})
    with urllib.request.urlopen(request, timeout=30) as reply:
        available = json.load(reply)["voices"]
    OUT.mkdir(parents=True, exist_ok=True)
    saved = load_voices()
    for speaker, prefix in LIBRARY_CAST.items():
        # next(...) takes the first match from a generator; the second argument is the
        # default if nothing matches, so a missing name gives None instead of an error.
        found = next((v for v in available if v["name"].startswith(prefix)), None)
        if found is None:
            sys.exit(f"no voice in the account starts with {prefix!r}")
        saved[speaker] = found["voice_id"]
        print(f"{speaker}: {found['name']}")
    (OUT / "voices.json").write_text(json.dumps(saved, indent=2), encoding="utf-8")


def speak(only, force: bool) -> None:
    """Speak every line that has no MP3 yet (or all, with --force) and write the manifest."""
    OUT.mkdir(parents=True, exist_ok=True)
    voices = load_voices()
    manifest = {}
    spent_before = credits_used()
    for line in build_lines():
        if only and not line["speaker"].startswith(only):
            continue
        file = OUT / f"{line['id']}.mp3"
        manifest[line["id"]] = {"speaker": line["speaker"], "text": line["text"], "spoken": line["spoken"], "file": f"audio/voice/{file.name}"}
        if file.exists() and not force:
            continue
        voice_id = voices.get(line["speaker"])
        if not voice_id:
            sys.exit(f"no voice yet for {line['speaker']}: run `design` first")
        audio = call(f"/v1/text-to-speech/{voice_id}?output_format=mp3_44100_64", {
            "text": line["spoken"], "model_id": MODEL, "voice_settings": VOICES[line["speaker"]]["settings"],
        }, expect_json=False)
        file.write_bytes(audio)
        print(f"spoke {line['id']} ({line['speaker']}, {len(line['spoken'])} chars)")
    # Merge with any manifest already on disk, so a partial run keeps the other entries.
    path = OUT / "manifest.json"
    old = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    old.update(manifest)
    path.write_text(json.dumps(old, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"done; this run cost {credits_used() - spent_before} credits")


def api(method: str, path: str, body=None, raw_body=None, content_type="application/json"):
    """One call to the API with any HTTP method (GET, DELETE, POST). Returns parsed JSON.
    `body` is a dictionary sent as JSON; `raw_body` is ready-made bytes (a file upload)."""
    data = raw_body if raw_body is not None else (json.dumps(body).encode("utf-8") if body is not None else None)
    request = urllib.request.Request(
        API + path, data=data, method=method,
        headers={"xi-api-key": os.environ["ELEVENLABS_API_KEY"], "Content-Type": content_type},
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as reply:
            return json.load(reply)
    except urllib.error.HTTPError as error:
        sys.exit(f"ElevenLabs refused ({error.code}): {error.read().decode('utf-8', 'replace')[:400]}")


def previews(only, round_number: int) -> None:
    """Make a new set of 3 previews for a voice and keep them, WITHOUT saving a voice.
    The audio goes to candidates/<voice>_r<round>_preview<N>.mp3 and the ids to
    preview_ids.json (key "<voice>_r<round>"), so Sasha can listen and pick; `save` then
    turns the chosen one into a real voice. Previews are only valid for a limited time."""
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "candidates").mkdir(exist_ok=True)
    ids_file = OUT / "preview_ids.json"
    known = json.loads(ids_file.read_text(encoding="utf-8")) if ids_file.exists() else {}
    for key, voice in VOICES.items():
        if only and key != only:
            continue
        reply = call("/v1/text-to-voice/design", {"voice_description": voice["description"], "text": voice["sample"]})
        for number, preview in enumerate(reply["previews"]):
            (OUT / "candidates" / f"{key}_r{round_number}_preview{number}.mp3").write_bytes(base64.b64decode(preview["audio_base_64"]))
        known[f"{key}_r{round_number}"] = [p["generated_voice_id"] for p in reply["previews"]]
        ids_file.write_text(json.dumps(known, indent=2), encoding="utf-8")
        print(f"{key}: {len(reply['previews'])} previews saved as {key}_r{round_number}_preview0..2")


def save(speaker: str, round_number: int, number: int) -> None:
    """Save the chosen preview as the speaker's real voice (needs a free custom-voice slot)
    and point voices.json at it. The id comes from preview_ids.json, written by `previews`."""
    known = json.loads((OUT / "preview_ids.json").read_text(encoding="utf-8"))
    generated_id = known[f"{speaker}_r{round_number}"][number]
    created = call("/v1/text-to-voice", {
        "voice_name": VOICES[speaker]["name"], "voice_description": VOICES[speaker]["description"],
        "generated_voice_id": generated_id,
    })
    saved = load_voices()
    saved[speaker] = created["voice_id"]
    (OUT / "voices.json").write_text(json.dumps(saved, indent=2), encoding="utf-8")
    print(f"saved {speaker} from round {round_number} preview {number}")


def swap(speaker: str, preview: int) -> None:
    """Replace a designed voice with a CLONE of one of its candidate previews.
    WHY: a preview can only be saved as a voice using the id it was given when it was made,
    and for the first previews that id was not kept. A clone made from the preview's audio
    sounds close to it, but it is a new voice, not the preview itself.
    WARNING (tried 2026-11-20): ElevenLabs flagged both clones as needing "voice
    verification" (a captcha you must pass by recording your own voice), and refused to
    speak with them. A synthetic voice cannot pass that, so this command does not give a
    usable voice. Prefer `design` (which now keeps preview ids in preview_ids.json) and
    save the preview you choose.
    Steps: check the old voice is one of ours ("Seedshot ..."), delete it (this also frees a
    slot in the account's custom-voice limit), clone the preview's MP3 into a new voice,
    and point voices.json at it. The file upload is "multipart/form-data": a body made of
    named parts separated by a boundary line, built by hand here with plain bytes."""
    saved = load_voices()
    old_id = saved.get(speaker)
    sample = OUT / "candidates" / f"{speaker}_preview{preview}.mp3"
    if not old_id or not sample.exists():
        sys.exit("need a saved voice for that speaker and a candidate preview file")
    old = api("GET", f"/v1/voices/{old_id}")
    if not old.get("name", "").startswith("Seedshot"):
        sys.exit(f"refusing to delete a voice that is not ours: {old.get('name')}")
    api("DELETE", f"/v1/voices/{old_id}")
    print(f"deleted {old['name']}")
    boundary = "----seedshot" + os.urandom(8).hex()
    crlf = b"\r\n"  # multipart lines end with a carriage return and a line feed
    parts = []
    for name, value in (("name", f"{VOICES[speaker]['name']} (preview {preview})"),
                        ("description", VOICES[speaker]["description"]),
                        ("remove_background_noise", "false")):
        header = f'--{boundary}'.encode() + crlf + f'Content-Disposition: form-data; name="{name}"'.encode() + crlf + crlf
        parts.append(header + value.encode("utf-8") + crlf)
    header = (f'--{boundary}'.encode() + crlf
              + f'Content-Disposition: form-data; name="files"; filename="{sample.name}"'.encode() + crlf
              + b"Content-Type: audio/mpeg" + crlf + crlf)
    parts.append(header + sample.read_bytes() + crlf)
    parts.append(f"--{boundary}--".encode() + crlf)
    created = api("POST", "/v1/voices/add", raw_body=b"".join(parts), content_type=f"multipart/form-data; boundary={boundary}")
    saved[speaker] = created["voice_id"]
    (OUT / "voices.json").write_text(json.dumps(saved, indent=2), encoding="utf-8")
    print(f"cloned preview {preview} as the new {speaker} voice")


def level() -> None:
    """Even out the loudness of every spoken file with ffmpeg's `loudnorm` filter, so the
    two DJs and Helios sit at the same volume. Each file is processed into a temporary
    file, then moved over the original. Needs ffmpeg on the PATH. Run it once after
    `speak`; running it again is harmless (a levelled file stays levelled).
    subprocess.run starts another program and waits for it; check=True raises an error
    if that program fails, so a broken file is never quietly kept."""
    import subprocess
    for file in sorted(OUT.glob("*.mp3")):
        temporary = file.with_suffix(".tmp.mp3")
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(file),
             "-af", "loudnorm=I=-18:TP=-2:LRA=9", "-ar", "44100", "-b:a", "64k", str(temporary)],
            check=True,
        )
        temporary.replace(file)  # replace() overwrites the original with the new file
        print(f"levelled {file.name}")


def count() -> None:
    """Show how many characters `speak` would send, per speaker, and the credit estimate."""
    totals = {}
    for line in build_lines():
        totals[line["speaker"]] = totals.get(line["speaker"], 0) + len(line["spoken"])
    for speaker, chars in totals.items():
        print(f"{speaker}: {chars} characters")
    print(f"total: {sum(totals.values())} characters = about {sum(totals.values()) // 2} credits on {MODEL}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=["design", "use", "speak", "level", "swap", "previews", "save", "count"])
    parser.add_argument("extra", nargs="*", help="swap: <speaker> <preview number>")
    parser.add_argument("--round", type=int, default=2, help="previews: which round number to label the set")
    parser.add_argument("--only", help="design: helios|canopy_girl|canopy_boy; speak: helios|canopy")
    parser.add_argument("--force", action="store_true", help="speak again even if the file exists")
    args = parser.parse_args()
    if args.command == "design":
        design(args.only)
    elif args.command == "previews":
        previews(args.only, args.round)
    elif args.command == "save":
        save(args.extra[0], int(args.extra[1]), int(args.extra[2]))
    elif args.command == "swap":
        swap(args.extra[0], int(args.extra[1]))
    elif args.command == "level":
        level()
    elif args.command == "use":
        use_library()
    elif args.command == "speak":
        speak(args.only, args.force)
    else:
        count()
