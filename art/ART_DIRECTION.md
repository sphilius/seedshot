# Seedshot art direction (concept picks)

What Sasha has chosen from the concept art in `art/concept/`, and what is still open. When a tile, wall piece or prop
is rebuilt at game size in Klad, it follows this page. Prompts for the open items are in `CONCEPT_PROMPTS.md`
("Round 2").

**View for everything in the game:** high top-down. The camera is almost straight overhead, so the floor is flat and
you mostly see the tops of things, with a sliver of their front faces. 04_sunroot_b and 04_sunroot_c have the right
view; their designs don't.

## Locked

| Part | Pick | Notes |
|---|---|---|
| Lot layout and graffiti | `01_screen_mockup_c` | Its side-wall lettering reads as real spray paint. 01_screen_mockup_a's lettering looks pasted on, so it is out. |
| Floor | `02_floor_sheet_final.png` | Sheet b, with the moss tile (row 2, column 1) and the soil patch (row 3, column 4) taken from sheet a. The two borrowed tiles have no bevelled edge; that gets evened out when the tiles are rebuilt. Row 4 (lit tiles) is not needed: the game lights the floor with glow sprites. |
| Homes and side wall | `03_wall_and_homes_b` | Dark strip, lit strip and the side wall. |
| Seven (the gardener bot) | `art/concept/seven_redesign/seven_engineer_1.png` (redesign, s24; replaces the cream-dome robot in `07_key_art_b`) | A gardener-engineer in **emerald** green (`#0b8f5c`, shade `#075f3c`): a wide solar-panel sun hat (cream and gold rim, dark glass, thin grid lines) with a small dome and a glowing seedling sprouting from the crown; a cream round face window with two small dark eyes; a barrel body with a cream chest panel, gold rivets and a dark tool belt with two pouches; one arm ends in a short gold watering-spout nozzle; **short stumpy legs and chunky cream boots** (no tracks, no wheels). Pixel strip made by `tools/gen_seven_sprites.py`. |
| Helios on the key art | the far-off tower with a cold white sign | Far away, but looming over the block. |
| Trees | `04_sunroot_f` | Built into the game by `tools/tree_sprites.py` (sapling, grown, cut, big). |
| Light stages | `06_light_progression_h` | The middle stage is darker because fewer lights are on, not because of a tint. |
| Key art (itch banner) | `07_key_art_g` | Sasha's pick; `07_key_art_k` is the close-up alternative. |
| Graffiti line 1 | "KEEP THE LIGHTS ON!" | Replaces "LIGHTS ON" in the game and on the key art. |

## Open

Nothing from round 2 is open: trees, light stages and key art are picked (above). Next candidates: the side and
top walls (still plain grey), props from `05_props_b` along the walls, and Seven's sprite in the locked design.
## Not used
`01_screen_mockup_a` (apart from its trees), `01_screen_mockup_b` (too detailed to build from; kept as a mood
target), `01_screen_mockup_d`, `01_screen_mockup_e`, `03_wall_and_homes_a/c/d`, `04_sunroot_b/c` (view only),
`05_props_a/c`, `07_key_art_a` (good pixel art, but darker and grittier than the rest), and `07_key_art_d`.
`05_props_b` is still the props pick: floor-standing props get redrawn from above.
