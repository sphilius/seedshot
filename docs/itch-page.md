# Seedshot: itch page text (draft for Sasha)

Paste each block into the matching field on https://itch.io/game/edit (kingriot/seedshot). Anything in
**[brackets]** is a choice or a fill-in for you. Lines marked UPDATE change when New Game + ships.

---

## Title

Seedshot

## Short description (the one line under the title)

Helios owns the sun. Your block stopped paying for it. Shoot seeds, grow a forest out of their machines, and keep the lights on.

## Genre / tags

Genre: Action. Tags: solarpunk, top-down-shooter, pixel-art, arcade, short, robots, trees, cats, jam, browser.

## Cover image and banner

- Cover (630 x 500): a crop of `art/concept/07_key_art/07_key_art_g.png` (Sasha's pick).
- Note: don't use a screenshot that shows where Lucky's shop is (it is meant to be found).
- Banner: the same picture, wide crop.
- Screenshots (1280 x 720, in `docs/playtest/shots/`), in this order:
  1. `s17-late-wave.png`: a late-wave fight, Linebreakers and Arc Spitters closing in.
  2. `s17-radio-heart-bramble.png`: Helios on the radio, the Heart Tree, a bramble patch.
  3. `s17-upgrade-cards.png`: the between-wave upgrade pick.
  4. `s17-sunburst.png`: New Game +, Canopy lines and a Sunburst.
  5. `s14-light-3-end.jpg`: the lit block at the end of a run.
  None of them gives away where Lucky's shop is.

---

## Description (main body)

**Helios owns the sun. Your block stopped paying for it.**

The lights are out. Helios Utilities has cut the power to your block and sent its machines to collect. You are
**Seven**, an old Helios meter-reader the neighbourhood kids jailbroke and repainted. You don't fix meters any more.

**Every machine you take down becomes a sunroot tree.** Trees are cover, trees are your grapple points, and every
tree standing helps the block get its light back. Clear a wave and more windows come on. Lose a tree and somewhere
a window flickers.

Ten waves. One night. Keep the lights on.

- Shoot seed pods. A downed machine roots and grows into a tree.
- Zip to any tree on a live vine.
- Guard the Heart Tree: the Sawbots want it, and if it falls the wave starts over.
- Pick an upgrade between waves, because Helios sends heavier machines as the night goes on.
- After wave 3, unlock two new skills: Bramble Seeds (thorn patches that slow machines and chew them up) and the
  Vine Trip Line (zip tree to tree and the vine stays strung as a trap).
- Canopy FM, the block's pirate radio, talks you through it, and gets clearer as the block lights up.

### 🐱 There is a hidden lucky cat in this game

Somewhere in the lot, a shuttered shop hides **Lucky**, a lucky cat who sells to the right customers. It is hidden
for real: keep your eyes open, and listen to Canopy FM. Lucky's gift: **a live clamp that lets your vine yank and
bind machines, and a spare fuse that gets you back up once when you'd go down.** Talk to Lucky as often as you like.

**[Optional, if you want it spoiler-free: replace the last two sentences with "Find it. It's worth it."]**

### Controls

| | Keyboard and mouse | Touch (phone / tablet) |
|---|---|---|
| Move | WASD or arrow keys | slide a thumb on the left half |
| Aim and shoot | mouse; hold left click | slide and hold a thumb on the right half |
| Zip to a tree | right click on the tree | tap the tree |
| Bind a machine (after Lucky) | right click on the machine | tap the machine |
| Reload (it also reloads by itself) | R | (automatic) |
| Throw a Bramble Seed (once unlocked) | Q or Space | the "bramble" button, right side |
| Talk to Lucky | E near the open shop | tap the shop |
| Pick an upgrade (between waves) | 1, 2 or 3, or click a card | tap a card |
| Pause | P or Esc | the pause button, top right |
| Mute | M | the speaker button, top right |
| Restart after the run | R or Enter | tap the end banner |

**Short on time?** After wave 5 the game tells you it's a good place to stop and rate. Play on for the ending.

**New Game +**: beat the game once to unlock it on the title screen: 50% more machines, sent faster, and trees that
survive a whole wave grow into **great sunroots**. Two great sunroots in sight of each other string a **Canopy line**
that tangles machines crossing it, and zipping to one sets off a **Sunburst** that stuns everything around it. You
also get to pick your Canopy FM station (lo-fi, dub, chiptune or drill trap).

### Made for Jamference AI Game Jam Hack 4

Theme: Solarpunk. Restriction: a hidden lucky cat that gives the player a benefit (see above).

---

## AI disclosure (required section; keep it honest and specific)

This game was made with AI tools. What each one did:

- **Claude Code (Anthropic):** wrote the game's code (Godot 4.7, GDScript) and its automated tests from my design,
  story and notes, and built the art pipelines below.
- **Gemini, Nano Banana image model (Google):** concept art from my prompts and direction: the floor, homes,
  sunroot trees, lighting stages, Seven's design and the cover art. I picked and combined the results.
- **Klad + scripts:** turned the chosen concept art into the in-game pixel art (floor tiles, rooftops, trees) at
  game size, in one fixed palette. Seven's sprite was drawn by a script from the locked design.
- **ElevenLabs:** the sound effects and the four Canopy FM songs (lo-fi, dub, chiptune, drill trap).

My part: the concept, story, characters and dialogue direction, every design decision, art direction and picks, and
playtesting. **[Edit this line in your own words.]**

**Before and after** (suggested pictures to attach): concept `01_screen_mockup_c.png` next to an in-game screenshot;
concept `04_sunroot_f.png` next to `art/source/klad/tree_sprites@8x.png`.

## Credits

- Font: Permanent Marker by Font Diner (Apache License 2.0), used for the graffiti.
- Engine: Godot Engine 4.7 (MIT).

---

## Page settings checklist (from the jam host's rulings)

1. ✅ The hidden lucky cat is stated on the page (section above).
2. **[ ]** Kind of project: HTML. "This file will be played in the browser" ticked on the html5 upload.
3. **[ ]** Viewport 1280 x 720, "Mobile friendly" ticked (touch controls exist), fullscreen button on.
4. ✅ A "stop and rate" point inside the first 10 minutes (after wave 5).
5. ✅ The tutorial is in play (wave 1 teaches cover and the vine) and can be skipped by just playing.
6. **[ ]** A short playthrough video (the host rates games he can't run from videos). Record one run, link it here.
7. **[ ]** Visibility: Restricted with password `jamference` for feedback, then Public before the jam closes
   **Fri Nov 20, 2:00 AM ET**.
8. **[ ]** Optional: email a screenshot to the host.
