# Seedshot concept art prompts (Gemini Nano Banana)

**What these are for:** pictures to steer by, not game assets. Once you pick the ones you like, the floor tiles, wall
and home pieces and background props are rebuilt from them at game size with Klad, so they stay pixel-exact and match
the sprites already in the game.

**How to run them**

1. Open Gemini and choose the Nano Banana image model (whichever version you have).
2. Paste the **Style block** below, then one prompt under it, as a single message.
3. Set the aspect ratio the prompt names. If Gemini has no ratio setting, the prompt's first line already asks for it.
4. Save what comes back, unedited, to `art/source/concept/` under the file name the prompt gives.
5. Run each prompt two or three times and keep the takes you like. Numbering them `_a`, `_b` is fine.

**Run order:** prompts 1, 2 and 3 first. They decide the floor, the walls and the homes, which is where the game looks
barest. Prompts 4 to 7 are only worth running once those three have a direction you like.

**Tip for prompt 1:** attach `docs/playtest/shots/s12-after-wave-8.jpg` with it, so the layout matches the real screen.

---

## Style block (paste above every prompt)

```
Style: 16-bit pixel art, crisp square pixels, no blur, no anti-aliasing, 1-pixel dark outlines, flat shading with
two or three tones per surface. Night scene. The base of the picture is dark, cool blue-grey concrete and steel.
Light comes only from warm amber windows, soft green-glowing plants, and a few small neon signs in teal and pink.
Mood: a lived-in back lot in a dense, stacked city at night. Patched, repaired and hand-made, not shiny. Hopeful,
not bleak: people live here and look after it. No people or animals visible. No text except where the prompt gives
exact words. No logos, no watermark, no border, no user interface.
Palette, use these and darker or lighter steps of them only:
#1b1f1d outline, #4a5257 steel dark, #9aa5a8 steel light, #2f8f8a teal, #2f6b3a leaf dark, #7fc45a leaf light,
#e8b93a solar gold, #efe6c8 cream, #6b3a24 rust dark, #a65a2e rust mid, #d08a4a rust light, #e0412f red (machines only).
```

---

## 1. The game screen, as it should look  →  `01_screen_mockup.png`

Aspect ratio 16:9. **The most useful picture of the set.**

```
Aspect ratio 16:9. A single screen of a top-down 2D arcade game, seen from straight above with no perspective at all.
A rectangular back lot of cracked concrete slabs, enclosed on all four sides by the flat rooftops and wall-tops of
the buildings around it. The lot floor fills most of the picture. The surrounding rooftops form a border about one
twelfth of the picture's height thick.
On the floor: shallow puddles that reflect amber and teal light, weeds and moss growing in the cracks between slabs,
a rusted drain grate, faded yellow parking lines, two thick power cables snaking across the ground.
Scattered on the floor: about eight small glowing trees, each grown up through the wreck of a small robot, with
luminous green leaves that light the concrete around them.
Along the bottom border: ten small homes seen from above, each with two or three lit amber windows throwing warm
light onto the lot floor. Along the left and right borders: spray-painted words on the wall-tops.
In the top border, right of centre: a small shuttered kiosk with a tiny pink neon sign.
The centre of the lot is left clear and readable, because that is where the action happens.
```

**Taking from it:** how busy the floor can get before sprites stop reading, and how the border is built.
**Watch for:** any slant or perspective (it must be flat, straight down); clutter in the middle of the lot.

---

## 2. Floor materials  →  `02_floor_sheet.png`

Aspect ratio 1:1.

```
Aspect ratio 1:1. A reference sheet for a top-down game floor, seen from straight above with no perspective.
A grid of 4 columns and 4 rows, sixteen equal square tiles, each with a thin dark gap around it.
Every tile is one square of night-time back-lot ground:
Row 1: four variations of plain cracked concrete slab, quiet and low-contrast, meant to repeat across a large floor.
Row 2: concrete with moss and weeds in the cracks; concrete with a shallow puddle reflecting amber light; concrete
with an oil stain; concrete with a faded yellow painted line.
Row 3: a rusted drain grate; a metal access hatch; a thick black power cable crossing the tile; a patch of bare soil
where the concrete has broken open, with a small green shoot.
Row 4: the same four as row 1, each lit by warm amber light falling from the bottom edge of the tile.
Keep every tile dark and calm enough that bright characters standing on it stay easy to see.
```

**Taking from it:** three or four floor slabs to replace the one repeating slab, plus the soil patch for tap points.
**Watch for:** tiles that are too bright or too detailed; tiles drawn at an angle.

---

## 3. Walls and homes from above  →  `03_wall_and_homes.png`

Aspect ratio 21:9, or 16:9 if that is not offered.

```
Aspect ratio 21:9. Three long horizontal strips stacked one above another, each seen from straight above with no
perspective, for the border of a top-down game.
Strip 1, "homes, dark": a row of small flat rooftops packed side by side: corrugated metal, tar paper, patched
panels, a water tank, an air-conditioning box, a satellite dish, a washing line, potted plants. Along the bottom edge
of each roof, two or three small dark windows. No lights on.
Strip 2, "homes, lit": exactly the same rooftops, but the windows glow warm amber, strings of small lanterns hang
between roofs, and warm light spills onto the ground below the strip.
Strip 3, "side wall": a plain weathered concrete wall-top with pipes and cable runs along it, bare enough to carry
spray-painted words. On it, in loose spray paint, the words "LIGHTS ON" in teal and "THE SUN IS FREE" in pink.
```

**Taking from it:** what a home looks like dark and lit, and what sits on the side walls behind the graffiti.
**Watch for:** misspelled paint words (re-run if so); roofs drawn in perspective.

---

## 4. Sunroot trees  →  `04_sunroot.png`

Aspect ratio 16:9.

```
Aspect ratio 16:9. A reference sheet on a plain dark blue-grey background, four subjects in a row with space between
them, each seen from straight above with no perspective.
1. A sapling: a small green shoot pushing up through the cracked shell of a scrapped robot.
2. A grown tree: a round canopy of luminous green leaves with thin gold veins like solar cells, roots gripping rusted
machine parts, glowing softly and lighting the ground around it.
3. The same grown tree, damaged: half its leaves gone, a saw cut in the trunk, glowing weakly.
4. A larger, brighter tree: the same kind, with gold-tipped leaves and a thick cable running from its roots.
```

**Taking from it:** the tree, which is still a plain green square with a circle in the game.
**Watch for:** side views. Trees are the easiest thing for the model to draw from the side.

---

## 5. Props  →  `05_props.png`

Aspect ratio 16:9.

```
Aspect ratio 16:9. A reference sheet of small props on a plain dark blue-grey background, arranged in two rows with
space between them, each seen from straight above with no perspective.
Row 1: a wall-mounted electricity meter box with a red seal on it; a bundle of spliced cables with tape; a wooden
crate of seedlings; an oil drum planter; a string of small paper lanterns; a folding chair beside a small table.
Row 2: a paper notice pasted on a wall with the single word "HELIOS" at the top and lines of unreadable small print;
the same notice torn and spray-painted over with a pink X; a small roller-shuttered kiosk with a tiny pink neon sign
of a waving cat; a hand-painted arrow in teal spray paint; a rooftop solar panel with one cracked cell; a bicycle.
```

**Taking from it:** small things to scatter along the walls so the lot looks lived in.
**Watch for:** the word HELIOS spelled wrong; props drawn from the side.

---

## 6. The lot coming to light  →  `06_light_progression.png`

Aspect ratio 21:9, or 16:9 if that is not offered.

```
Aspect ratio 21:9. Three panels side by side showing the same top-down back lot at three moments, seen from straight
above with no perspective. The layout is identical in all three: a concrete lot with homes along the bottom edge.
Panel 1: almost dark. Deep blue. One home has two faint amber windows. Three small green-glowing trees.
Panel 2: most homes lit. The blue has warmed. Amber light pools on the concrete below the windows. About fifteen
glowing trees. Two homes still dark.
Panel 3: every home lit at full strength, lantern strings glowing, the whole lot warm amber and green, around
thirty glowing trees, and lights coming on in the buildings beyond the far wall.
```

**Taking from it:** the dark and lit tint colours, which are two numbers in the game's config.
**Watch for:** panels that change the layout between them.

---

## 7. Mood piece  →  `07_key_art.png`

Aspect ratio 16:9. Optional. This one may use perspective: it is for the itch page, not for building tiles.

```
Aspect ratio 16:9. Looking down at an angle into a narrow back lot between tall, stacked, patched-together apartment
blocks at night. A small rounded maintenance robot, teal and cream, stands in the middle of the lot holding a
glowing green seed. Around it, young trees with luminous leaves grow up through wrecked machines. High above, on the
tallest tower, a huge cold white sign reads "HELIOS". Down in the lot the light is all warm: amber windows, paper
lanterns, a little pink neon sign. On a wall in pink spray paint: "LIGHTS ON".
```

**Taking from it:** the itch page banner and cover.
**Watch for:** misspelled sign text; a robot that does not match the game's (teal body, cream trim, seen in the game
from above).
