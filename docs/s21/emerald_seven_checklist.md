# Emerald Seven: what needs updating (decided 2026-11-20)

Sasha: "we'll go with an emerald green instead of teal for Seven." Status 2026-11-20: section 1 (sprites, code fallback colour) and the palette and art-direction entries are DONE (D-069); everything from section 4 down is still open.
Seven's current teal is `#2f8f8a` (shade `#1f5f5c`). The hex for the emerald is not chosen yet: see
the readability warning in section 6 before picking it.

## 1. Seven's sprites (the source of truth is code, so this is one change plus two reruns)

| What | Where | Action |
|---|---|---|
| The colour constants | `tools/seven_sprite.py`: `TEAL`, `TEAL_DARK` (body, shoulders, dome stripe) | Change both to the emerald and its shade |
| The 8 facings | `tools/seven_facings.py` imports those constants; also the tank cap | Rerun it (its check that the front frame equals the locked sprite must still say 0 pixels) |
| The files the game loads | `art/sprites/gardener_bot.png`, `art/sprites/gardener_bot_facings.png` | Rebuilt by the two scripts; then `.\tools\godot.ps1 import` |
| Preview pictures | `art/source/klad/seven@8x.png`, `art/source/klad/seven_facings@3x.png` | Rebuilt by the same scripts |
| Code fallback colour | `scripts/player.gd` `FALLBACK_COLOR` (0.30, 0.70, 0.72), used if the texture is missing | Change to the emerald |

## 2. The shared palette

`art/source/klad/palette.ops.jsonl` holds the 12 shared colours, including `teal` `#2f8f8a`. The upgrade
icons, props and Lucky use palette names. Decide: **add** an `emerald` entry (a 13th colour, recommended:
nothing else changes) or **replace** `teal` (changes every sprite that uses it). Also `tools/prop_sprites.py`
(teal for the solar panel glass) and `tools/tree_sprites.py` (draws trees with a palette minus teal, because
teal speckled the leaves: emerald is closer to the leaf greens, so check trees stay clean).

## 3. Documents that describe Seven

`art/ART_DIRECTION.md` (the Seven row), `art/PROMPTS.md` and `art/CONCEPT_PROMPTS.md` (the palette and Seven
descriptions), `STORY.md` / `DESIGN.md` if they say teal. The old compare prompts in `art/source/compare/` are
history: leave them.

## 4. The UI accent is also called "teal" (a separate decision)

`(0.35, 0.90, 0.85)` is the game's UI accent: `scripts/title.gd` `TEAL_COLOR`, the edges in `pause_overlay.gd`,
`tutorial_offer.gd`, `upgrade_picker.gd`, Canopy FM's tag in `scripts/radio.gd`, one spray colour in
`scripts/graffiti.gd`, and the logo colour in `tools/make_page_art.py` and `tools/make_cover.py`. Seven's
colour does not depend on it. Option A (recommended): leave the UI teal. Option B: move the UI accent to emerald
too, then change all of these and remake the itch cover and banner.

## 5. Everything that shows Seven as teal (art made before the change)

Title art `art/sprites/title_art.jpg`; the itch cover, banner, background and screenshots (`itch/*`, regenerate
with `tests/capture_shots.gd` and `tools/make_page_art.py` / `make_cover.py`); the intro clip `web/intro.mp4`
(and its source in `art/video/opening sequence/`); Sasha's playthrough recording and the trailer
(`tools/make_trailer.ps1`); the playtest guidebook screenshots (`docs/playtest/shots/`); the key art concept
`art/concept/07_key_art/`. The video items cannot be recoloured by a script: they need re-capturing or a
colour grade.

## 6. READABILITY WARNING: emerald is close to the forest greens

Seven stands among glowing trees, vines and Grove-rest effects that are already emerald-ish:
`tree_glow_color` (0.35, 0.95, 0.60), `scripts/forest_tree.gd` `CANOPY_COLOR` (0.36, 0.88, 0.56),
`tree_bar_full_color` (0.45, 1.0, 0.55), `trellis_color`, `grove_rest_glow_color`, and the Seedshot leaf greens
`#2f6b3a` / `#7fc45a`. A light, minty emerald (about `#50c878`) would blend into the canopy. Pick a deeper,
slightly bluer emerald (about `#0b8f5c` with a shade near `#075f3c`), keep the cream dome (which carries the
read), and check by rendering Seven among grown trees at night and in the lit block
(`tests/capture_machines.gd` is a starting point). If it still blends, add a rim light or soften the tree glow.

## 7. Things that do NOT need changing

The machines (Helios blue: emerald Seven now contrasts better with them than teal did), the tests (none check a
teal value; the art-size checks stay valid), the seedling and leaf greens, Seven's warm glow
(`player_glow_color`), and the aim line.
