# Seedshot: Phase 3 handoff prompt

Paste everything below the line into a new Claude Code session opened on the Seedshot repo.
Recommended model: Opus 5.5. Written 2026-11-20, after s24 (skill unlocks) was merged.

---

Continue Phase 3 of Seedshot: new systems, **one per session, each on its own branch**.

## Where things stand (2026-11-20)

- `main` is at `208916b` (or later). Phase 3 done so far:
  - s22 Reload (D-066)
  - s23 Full screen button (D-068, an extra I asked for)
  - s24 Skill unlocks (D-069)
- 944 headless checks pass.
- Play link: https://sphilius.github.io/seedshot/ (GitHub Pages, from `gh-pages`). Newest release zip: `web-208916b`.
  - Publish a new build with `.\tools\publish_pages.ps1 -Export`, then make a GitHub release zip named `web-<short sha>`. `gh release create` needs the full SHA as `--target`.
- **Nov 28, 2026:** a reminder fires to make the repo private again and upload the latest build to itch.io. Going private takes the Pages link down. Don't do either without my yes.
- Folders:
  - `C:\Users\sphil\dev\seedshot` is the main folder. Another session uses it for concept art and keeps it on branch `s22-reload`. Don't switch its branch or touch its uncommitted files.
  - `C:\Users\sphil\dev\seedshot-main-wt` is a git worktree where `main` is checked out. Cut new branches from `main` there.
  - `C:\Users\sphil\dev\seedshot-pages` is the `gh-pages` worktree; `publish_pages.ps1` manages it.
  - In a fresh worktree, run `.\tools\godot.ps1 import` once before trusting errors.
- Playtest guidebook: https://claude.ai/artifact/6mk43Ao4cMZZkvJuAagKfG (update it per the playtest-guidebook skill). S22, S23 and S24 are all "testing".
  - **Start by reading my playtest answers there**, especially S24's "waves 2 and 3 without brambles" scale and the wave 3 card questions. If they call for tuning, offer that first.

## Rules (from CLAUDE.md, repeated so nothing is missed)

- Every tunable goes in `config/game_config.gd`, never as a number in a script.
- Children signal up, the arena calls down.
- Explanatory comments throughout. I'm still learning GDScript.
- Each feature gets headless checks in `tests/check.gd`. Run `.\tools\godot.ps1 test` after every meaningful change.
- Small commits on the session branch. Never commit to `main`. Don't merge or push until I say so.
- Add a line to `AI_LOG.md` for each new asset or system.
- Hook noise "Identifier not found: Sfx / RunState" is the autoload caveat, not a real error.
- Tests can't change the shared config: `CONFIG.set()` from a test does not reach the arena. Put the rule in a static function and test that instead (see `Arena.skill_cards_wanted`).
- Pictures from the real renderer: copy `tests/capture_skills.gd` (run without `--headless`) and save them to `docs/sNN/`.
- Card art: add a `draw_<id>()` recipe to `art/source/klad/upgrades/make_upgrade_icons.py` and run it. Afterwards, revert the line-ending-only changes it makes to the other `.ops.jsonl` files.

## How each session starts

Before any code, give me a **five-line proposal**:
1. What the player does
2. What it costs
3. What it replaces
4. What could go wrong
5. How I will test it

Then wait for my yes. If I say "fix the obvious issues you expect", do that and list each fix in the devlog.

## Remaining Phase 3 items, in order

1. **Logbook** in the pause menu: every tip from Canopy FM and Lucky, added as it is said.
   - Radio lines go through the arena's `_radio_line`, `_dj`, `_dj_once` and `_radio_interrupt`.
   - Lucky's lines are in `scripts/lucky_lines.gd`.
   - The pause menu is `scripts/pause_overlay.gd`: 6 buttons, plus THIS RUN and CONTROLS on the right.
   - The skill tips from s24 (`skill_tip_lines`) belong in the Logbook too.
2. **Resume buttons** after Lucky's moment, a fuse revive and each machine intro, instead of going back to the game on a timer.
   - The intro clips are `start_clip` / `clip_left` in `scripts/arena.gd`.
   - The fuse is in `receive_cat_gift` and the player's revive.
3. **Tutorial pause.** During the tutorial transmissions of the first waves only, the fight slows, darkens, and machines and trees stop. Other transmissions never slow the game.
   - `tutorial_on` in `arena.gd`; `scripts/dim_sheet.gd` is the spotlight sheet.
   - Clips already use `Engine.time_scale`.
4. **Sunburst rework.**
   - A great sunroot that fires goes back to a sapling and regrows 20% slower.
   - A card adds 2 Sunbursts.
   - Each machine a Sunburst hits freezes, crackles with sparks, puffs black smoke, then is removed.
   - The code is in `scripts/great_powers.gd`.
5. **Front homes.** Move the bottom row of houses so more of their fronts show, and take the graffiti off their roofs. The four roof tags in `scripts/graffiti.gd` need new places. Show one staged picture before building the whole row.
6. **Spitter shots damage trees and pierce**, so machines can hit each other (`scripts/spit_shot.gd`). Today, trees stop the shot.
7. **Robots only take root on soil.** This changes the core loop and needs a floor design first. Ask me for it.
8. **A fifth enemy type.** Ask me what role is missing before designing one. Machines extend `scripts/enemy.gd`; wave sizes are lists in the config.
9. **Waves that end on an objective**, with machines that keep coming (`scripts/wave_director.gd`).
10. **A true tutorial.** The biggest item. Build it last, on top of the tutorial pause and the Resume buttons. Note: s24 moved the bramble lesson to "the wave after its card", and the Trip Line tip has no voice yet.

## Open follow-ups from s24 (fold in only if quick, otherwise list them)

- The Trip Line tip (`dj_trip_line`) has no voice file. Voices cost ElevenLabs credits, so ask me first, with a count.
- The Trip Line has no title clip like the Bramble Seed's. My guidebook answer (`s24-unlock-moment`) says whether I want one.
- If waves 2 and 3 are too hard without brambles, the knob is `skill_unlock_after_wave`, or wave 3's Spitters (`wave_spitters`).

## How to finish a session

1. Run the full suite and say the count.
2. Export, open the preview, and say what you saw on screen for each item. Say plainly what you couldn't check (sound, a real phone, anything that needs a person playing).
3. Update the devlog (next ID is D-076), `AI_LOG.md`, `.feedback/checklist.html` in the main folder (never committed) and the guidebook.
4. Tell me the branch name and ask whether to merge and push. Do neither until I say yes.
