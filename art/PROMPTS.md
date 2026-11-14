# Seedshot art test: SpriteCook vs ChatGPT Images vs Klad

**Goal:** find which tool gives sprites the game can use with the least clean-up. The baseline is the current Nano Banana placeholders in `art/placeholder/` (painted checkerboard backgrounds, mixed pixel sizes, front views instead of top-down).

**Test set:** three sprites per tool, the same three each time: the gardener-bot, the Scrapper, the lucky cat. Do not generate the full set until one tool has won.

**Save results as:** `art/source/compare/<tool>/gardener_bot.png`, `scrapper.png`, `lucky_cat.png` (tool = `spritecook`, `chatgpt` or `klad`). Save exactly what the tool gives you, with no edits.

## The shared spec (already written into every prompt below)

| Thing | Value | Why |
|---|---|---|
| Size | 64 x 64 pixels | One grid cell is 48 px; sprites are drawn a little bigger than a cell |
| Background | Transparent | The whole reason for this test |
| View | Straight down from above, front of the machine at the TOP | The game rotates the sprite to face where it aims or walks |
| Cat view | Front | The cat sits in a shop window and never rotates |
| Style | 16-bit pixel art, 1 px dark outline, flat shading | Reads clearly at small size |
| Red | Enemies only | Red is the "this will hurt you" colour |

Palette (12 colours):

```
#1b1f1d outline      #2f8f8a teal         #efe6c8 cream
#2f6b3a leaf dark    #7fc45a leaf light   #e8b93a solar gold
#6b3a24 rust dark    #a65a2e rust mid     #d08a4a rust light
#4a5257 steel dark   #9aa5a8 steel light  #e0412f enemy red
```

## 1. SpriteCook

Settings (spritecook.ai, Generate):

- **Model:** Pixel Engine Image
- **Size:** 64 x 64
- **Pixel art:** on
- **Background:** transparent
- **Variations:** 1
- **Cost:** 6 credits each, 18 for the three (you have 30)

If the page has separate Style and Theme boxes, use these. If not, skip them: each prompt already says the same thing.

```
Style: 16-bit pixel art, 1 px dark outline, flat shading, no gradients
```

```
Theme: solarpunk scrapyard, overgrown machines
```

Pixel Engine allows 100 words in total, so these are short on purpose.

**gardener_bot**

```
Top-down view from directly above, front facing up. Small round gardener robot. Teal dome body with a bright green seedling sprouting from its centre. Two cream seed tanks, one on the left side and one on the right. One short brass cannon barrel at the front, pointing up. Dark outline, flat shading, limited palette. Single sprite, centred.
```

**scrapper**

```
Top-down view from directly above, front facing up. Crab-shaped scrap robot. Rusty brown armoured shell made of riveted plates. Two big pincer claws at the front, pointing up. Six short metal legs, three on each side. One glowing red eye in the middle of the shell. Dark outline, flat shading, limited palette. Single sprite, centred.
```

**lucky_cat**

```
Front view. Maneki-neko lucky cat statue, sitting, left paw raised and waving. Cream ceramic body with patches of green moss. A small blue solar panel on its belly. A green leaf sprout on top of its head. Gold collar with a bell. Dark outline, flat shading, limited palette. Single sprite, centred.
```

## 2. ChatGPT Images

Use one chat for all three so the style carries over. Send the first prompt, download the PNG, then send each follow-up.

**First message (gardener_bot)**

```
Create one pixel-art game sprite as a PNG with a fully transparent background. Real transparency: no checkerboard pattern, no backdrop colour.

Canvas: 1024 x 1024 px. Draw it as a 64 x 64 grid of big square pixels, so every art pixel is exactly 16 x 16 px and lines up with that grid. Hard edges only: no anti-aliasing, no blur, no gradients, no glow, no drop shadow, no text, no border.

Style: 16-bit top-down arcade game sprite. 1-pixel dark outline. Flat shading with 2 or 3 tones per colour. Light from the top left.

Use only these colours: #1b1f1d (outline), #2f8f8a (teal), #efe6c8 (cream), #2f6b3a and #7fc45a (leaf greens), #e8b93a (gold), #6b3a24, #a65a2e and #d08a4a (rust), #4a5257 and #9aa5a8 (steel), #e0412f (red, enemies only).

Framing: one object, centred, filling about 85% of the canvas, nothing cropped.

Subject: a small round gardener robot seen from directly above, with its front at the top of the image. Teal dome body with a bright green seedling sprouting from its centre. Two cream seed tanks, one on the left side and one on the right. One short gold cannon barrel at the front, pointing up. No red anywhere.
```

**Follow-up (scrapper)**

```
Same canvas, pixel grid, style, palette, framing and transparent background as the last image. New subject: a crab-shaped scrap robot seen from directly above, with its front at the top of the image. Rusty armoured shell made of riveted plates, using the three rust colours and the steel colours. Two big pincer claws at the front, pointing up. Six short metal legs, three on each side. One glowing red eye in the middle of the shell.
```

**Follow-up (lucky_cat)**

```
Same canvas, pixel grid, style, palette and transparent background as the last image. New subject, this time a front view: a maneki-neko lucky cat statue, sitting, left paw raised and waving. Cream ceramic body with patches of green moss. A small teal solar panel on its belly. A green leaf sprout on top of its head. Gold collar with a bell. No red anywhere.
```

The PNGs will be 1024 px. Leave them that size; Claude shrinks them to 64 px for the comparison.

## 3. Klad

Klad is not an image generator. It is a drawing app that a coding agent drives stroke by stroke, so the "prompt" goes to Claude Code, not to a website.

**Before you can run it:** Klad has no installer yet. It is built from source with Rust (`rustup`) and `just`, and neither is installed on this laptop. The build is heavy for 8 GB of RAM. Do the other two tools first.

Once `klad` runs in a terminal, open Claude Code in the `seedshot` folder and paste:

```
Run `klad skill` and `klad skill drawing` and read what they print before doing anything else. Use only commands those two print. If a step below is not supported, stop and tell me instead of working around it.

Work in art/source/compare/klad/. Make three 64 x 64 pixel-art sprites: gardener_bot, scrapper and lucky_cat. For each one:

1. Create the drawing: klad new <name>.klad --pixel 64x64
2. Set its palette to exactly these 12 colours: #1b1f1d #2f8f8a #efe6c8 #2f6b3a #7fc45a #e8b93a #6b3a24 #a65a2e #d08a4a #4a5257 #9aa5a8 #e0412f
3. Paint the sprite. Leave every pixel outside the sprite empty (transparent). 1-pixel #1b1f1d outline. Flat shading with 2 or 3 tones per colour, light from the top left. The sprite fills about 85% of the canvas and is centred.
4. Run: klad check <name>.klad   and fix whatever it flags.
5. Export a PNG at 1x scale as <name>.png in the same folder.

Subjects:
- gardener_bot: a small round gardener robot seen from directly above, front at the top of the image. Teal dome body, bright green seedling sprouting from its centre, two cream seed tanks (left and right), one short gold cannon barrel at the front pointing up. No red.
- scrapper: a crab-shaped scrap robot seen from directly above, front at the top. Rusty riveted shell, two big pincer claws at the front pointing up, six short legs (three per side), one red eye in the middle of the shell.
- lucky_cat: front view of a sitting maneki-neko statue, left paw raised. Cream body with patches of green moss, a small teal solar panel on its belly, a leaf sprout on its head, gold collar with a bell. No red.

When all three are done, show me the PNGs and tell me: how long each took, whether the export background is really transparent, and anything Klad could not do.
```

## Scorecard

Fill this in after each tool (yes / partly / no, and minutes).

| Check | Baseline (Nano Banana) | SpriteCook | ChatGPT | Klad |
|---|---|---|---|---|
| Real transparent background | no | | | |
| Exactly 64 px, pixels on one grid | no | | | |
| Stayed inside the 12 colours | no | | | |
| Correct view (top-down, front up) | no | | | |
| Still readable at game size | partly | | | |
| The three look like one set | no | | | |
| Minutes of your time for three sprites | not timed | | | |

**Decision rule:** the winner is the tool with the most "yes" answers. On a tie, the one that took fewer minutes.

## After a tool wins: the other five sprites

Same wrapper as above, new subject line.

- **spitter:** a tripod gun turret seen from directly above, front at the top. Three thin steel legs spread evenly around a small round body, one long narrow barrel pointing up, one red sensor light on the body.
- **sawbot:** a round tracked robot seen from directly above, front at the top. Steel body, rust-coloured caterpillar tracks down the left and right sides, a large circular saw blade sticking out at the front, one red eye.
- **tree:** a round leafy tree canopy seen from above, two greens, a few gold solar-leaf highlights, a hint of dark trunk at the centre.
- **sapling:** a tiny green sprout with two leaves seen from above, on a small mound of dark soil.
- **shop:** front view of a small shuttered shop front, steel roller shutter down, a paw print painted in cream on the wall beside it. 128 x 64 pixels.
