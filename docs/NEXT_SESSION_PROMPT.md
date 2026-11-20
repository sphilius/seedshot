# Seedshot: prompt for the next implementation sessions

Written Thursday, November 19, 2026, 11:58 PM ET, at the end of session s18.
Paste everything below the line into a new Claude Code session opened in
`C:\Users\sphil\dev\seedshot`. Paste it once per phase and change the one line
that says which phase to do.

---

## Your task

Do **Phase 1** of the Seedshot backlog below, and only Phase 1. When it is done, stop, tell me what to playtest, and wait. Do not start the next phase in the same session.

Before anything else, run `Get-Date -Format "dddd, MMMM dd, yyyy — hh:mm tt K"` and state the result. Then read `CLAUDE.md`, `DESIGN.md` and the top three entries of `docs/DEVLOG.md` (D-055 to D-057). They are short and they are the record of truth; where this prompt and the code disagree, the code wins and you tell me.

## Who I am and how to work with me

I am Sasha. I am learning GDScript; I understand systems but not every language idiom. I have AuDHD, so:

- Lead with the answer, then explain. State the recommended path before any alternatives, and keep decision points few.
- Use numbered steps with emojis for anything I have to do.
- Comment the code so I can read it without help: say what a function is for, and explain any idiom the first time it appears in a file (lambdas, `await`, `static`, setters, `%` formatting).
- Tell me plainly when I am over-engineering. Three or more new systems before one of them has been played is over-engineering. This backlog has that problem built in, which is why it is cut into phases.
- I work in PowerShell on Windows 11.

## Where the project stands

Seedshot is a Godot 4.7.2 top-down arena game, my entry for the Jamference AI Game Jam (Hack 4). Seven, a gardener-bot, shoots seed pods at Helios's machines; each machine that goes down grows into a tree where it fell. Ten waves, then New Game +.

- `main` is at `897c687` and is pushed to GitHub. The working branch from s18, `s18-playtest-fixes`, is merged.
- Itch has build `35d2323` live at kingriot.itch.io/seedshot (channel `html5`). It was uploaded without a human playthrough of the last round.
- The jam's submission window closed Friday, November 20, 2026 at 3:00 AM ET. **I do not know whether the jam allows uploads during judging. Do not upload anything to itch. If a fix seems urgent, ask me, and ask me to check the jam rules first.**
- `tests/check.gd` has 726 headless checks, all passing.

## Rules that do not bend

1. **No merge, no push, no itch upload without my explicit yes.** Each one needs its own yes; an earlier yes does not carry over.
2. **Branch first.** Before the first edit, if you are on `main`, run `git switch -c <short-kebab-name>` (for Phase 1: `s19-phase1-fixes`). Small commits, never straight to `main`. Commit message: an imperative summary of at most 72 characters, a blank line, one sentence of why, and the attribution line your session is told to use.
3. **Never commit `.feedback/`.** Never touch `art/concept/*_sprite/`, `art/source/compare/` or anything inside `art/video/`: those are mine. Copy out of them if you need a file; never move, edit or re-encode in place.
4. **Every tunable goes in `config/game_config.gd`**, with a comment saying what it does and its unit. No bare numbers in scripts.
5. **Children signal up, the arena calls down.** A machine or the player never reaches into the arena; it emits a signal and `scripts/arena.gd` acts on it.
6. **Each change gets headless checks** appended to `tests/check.gd`, and the suite runs after every meaningful change, not at the end.
7. **Spending needs a yes.** The ElevenLabs key is in the `ELEVENLABS_API_KEY` environment variable; never print it. Generating any sound or voice spends credits: ask first, say how many takes.
8. **Add a line to `AI_LOG.md`** for each new asset or system, and a `docs/DEVLOG.md` entry (next ID is D-058) for each design choice, newest first.
9. One item at a time: build it, check it, commit it, then the next. If an item fails twice, stop and tell me rather than retrying the same way.

## Commands and traps

- `.\tools\godot.ps1 import | test | export | editor`. It wraps the right Godot build; the `godot` on PATH hangs headless.
- `test` takes about 100 seconds. A script compile error shows up as a 240 second timeout, so read the top of the output.
- After adding a script with `class_name`, run `import` before trusting a "Could not find type" message.
- The godot-check hook reports `Identifier not found: Sfx` and `RunState` on almost every edit. Those are autoloads and the message is a known false alarm. Real errors are the other lines.
- Never pipe the export through `Select-Object -First N`: it kills the export half-written. Redirect it to a file instead.
- `export` also copies `web\intro.mp4`, `intro.css` and `intro.js` into `build\web\`. Leave that step alone.
- To see the game: the `seedshot-web` preview config in `.claude\launch.json` serves `build\web` on port 8063. For a staged screenshot without playing, `tests/capture_shots.gd` shows how to set up a scene and save a PNG (it overwrites `itch/screenshot_*.png`, so restore those with `git checkout itch/` unless I ask for new ones).
- In `tests/check.gd`, `_fresh_arena()` switches off several things so old checks stay stable: intro clips, the moving cat shop, sapling pausing, radio static, the wave-end slow-down. A new check that needs one of them switches it back on for itself. Slow motion (`Engine.time_scale`) stretches any check that waits on physics frames; if Seven stands still in a check while machines walk in, set `player._invulnerable_left = 999.0` first.
- Values read in `_process` need `_wait_drawn_frames`, not `_wait_frames`.

## The playtest guidebook

https://claude.ai/artifact/6mk43Ao4cMZZkvJuAagKfG, kept up to date with the `playtest-guidebook` skill. When a phase is built: add a new milestone sheet with setup steps and questions about that phase, mark the previous sheet done, add one feedback document per note with its outcome and one changelog document per change. Pin every write with `if_version`. Never write the `answers` collection; never invent playtest results.

## Phase 1: fixes and small changes (no new art, no credits)

Recommended model: Sonnet 5.5. Ten items. Do them in this order; the first three are the ones I care about most.

**1. A restarted wave replays its radio lines.**
Today a restart (Seven down, Heart Tree felled, or "Restart this wave" in the pause menu) re-queues Helios's notice and the wave's own Canopy FM lines, but not the one-time lines: the opening hook (`_hook_shown`) and everything said through `_dj_once` or marked in `_dj_said` (first tree, first Sawbot, tap points, Grove rest, and so on). So a player who restarts by accident can miss them for good. In `scripts/arena.gd`, look at `_on_wave_started`, `_restart_current_wave`, `_dj_once`, `_dj_said`, `_story_queue` and `_is_radio_pending`.
Done when: the one-time lines first said during a wave are said again if that wave is restarted (remember what `_dj_said` and `_hook_shown` were when the wave began, and put them back on a restart); lines from earlier waves are not repeated; a restart clears lines still waiting from the failed attempt so nothing is said twice; checks cover a restart in wave 1 and in a later wave.

**2. Helios's opening line.**
`helios_lines[0]` in `config/game_config.gd` is "Courtesy notice: your account is 90 days past due." Change it to exactly: `Courtesy Notice: This sector's account is 90 minutes past due.` Check that no test or other line quotes the old text.

**3. Robots are solid and hurt on contact.**
Seven can walk over machines, Sawbots especially. The player is on collision layer 2 and every machine on layer 4 (`scenes/*.tscn`). Find out why they do not block each other, make them solid to Seven, and add contact damage: a touch costs `contact_damage` pips, no more often than `contact_damage_cooldown` seconds, using the hit-invulnerability Seven already has (`take_damage` in `scripts/player.gd` returns false while it is blinking). Follow the Scrapper's `struck` signal as the pattern: the machine announces, the arena passes it to the player. Watch for two traps: a machine dropping in or rolling out of a gate (`is_entering`) must not hurt, and Seven must never be pinned between a machine and a tree with no way out. A bound machine does not hurt.
Done when: Seven cannot pass through a machine, touching one hurts on a cooldown, and the vine zip still works past machines.

**4. The forest's vines slow machines but do not stop them shooting.**
In New Game + the great sunroots string vines between themselves (`scripts/great_powers.gd`: `_catch_on` for the canopy lines, `_tick_trellises` for the Vine Trip Line). Both call `Enemy.yank_and_bind`, the same full bind Seven's own vine gives, which freezes the machine and stops it shooting. I want two different things: the forest's vines **snare** (the machine is held or slowed in place but a Spitter can still wind up and fire); only Seven's own vine on a machine fully **binds** it. `Enemy` already has `slow_for(steps)` from the brambles; a new "snared" state beside `is_bound` is probably the clean way, with its own tint so I can tell them apart.
Done when: a Spitter caught on a forest vine still shoots, one bound by Seven does not, and each has a check.

**5. Vines are too effective (tuning, after item 4).**
The forest handles the machines so well that New Game + plays itself. Item 4 already weakens them. Then lower, in the config, how long a snare lasts and how often a line can catch (`canopy_line_bind_seconds`, `trellis_bind_seconds`, and the recharge values next to them). Change numbers only, say what you changed from and to, and leave the feel to my playtest.

**6. Explain why vines appear by themselves in New Game +.**
One Canopy FM line, said once, the first time a canopy line forms between two great sunroots. Put the text in the config. Keep it to one sentence in the DJ's voice.

**7. Show where the bramble will land before it is thrown.**
`throw_bramble` in `scripts/player.gd` lands at `aim_direction * bramble_range_cells`; `spawn_bramble` in the arena clamps that to the floor. Draw a faint ring at that clamped spot while Seven has a charge, on the same overlay the aim line uses (`_aim_overlay`), the size of the patch it will make. On touch, show it while the bramble button is held if that is cheap; otherwise always.

**8. Introduce the Bramble Seed more clearly.**
"Thorns" was unclear and my counter sat at 3 / 3 for most of two runs. The wave 2 Canopy FM lines are `dj_bramble` and `dj_bramble_touch`. Rewrite them to say what it does and when to use it (slows a crowd, good in a gateway), name the key, and add a first-use clip in the style of the machine intros: `start_clip` in `scripts/arena.gd`, titles in `intro_titles`. One clip, the first time a bramble charge is available in wave 2.

**9. Lucky's lines stay up longer, and it is clearer that you tap Lucky.**
Lucky's lines go through `_radio_interrupt(_lucky_says(...))` and use the same hold time as everyone (`story_line_seconds`, now 6 s). Give Lucky's lines their own, longer hold in the config. The shop already draws "E: talk" when Seven is near (`scripts/cat_shop.gd`); on touch it should say "Tap" and the paw should be an obvious button.

**10. Trees are hard to see; make them bigger.**
Make the drawn tree larger without changing what it blocks: the collision square must stay exactly one cell (pods must not slip between neighbours, and the grid's pathfinding assumes it). The tunables are in the config near `tree_grown_texture`; the drawing is in `scripts/forest_tree.gd`. Take a staged screenshot before and after and show me both.

**Also open from the last playtest, fold in if they are quick, otherwise list them for me:**
- "The fuse saved Seven more than once." Not reproduced. The code fits one fuse in `receive_cat_gift` and never refits it. Try to make it happen; if you cannot, say so.
- The in-game mute button and the pause menu's Sound and Music switches. I said the mute button "shouldn't override" the pause menu. Do not guess: show me how the three behave today and ask what I want.
- Arc Spitters "still passive" and a Linebreaker's escorts read as "just more machines". Tuning; needs a play between changes.

## Phase 2: art, sound and words (each needs something from me first)

Recommended model: Sonnet 5.5 for the wiring; ask me before any generation.

- **Seven's sprite turns to face each direction.** My own frames are in `art/concept/gardener_bot_sprite/` (read-only for you). Ask me which frames are final, copy them out, and wire four or eight facings. Seven's damage wear is drawn in code on `_aim_overlay` and must still line up.
- **Lit homes along the top read as plain squares.** The back wall is `scripts/back_wall.gd`. Propose a look in one staged screenshot before building the whole row.
- **ElevenLabs voices for the radio; a longer chainsaw; a Klad icon for "Repairing"; a new look for Lucky's shop.** Voices and the chainsaw spend credits: ask, with a count. `audio/SOUNDS.md` holds the prompts, `tools/gen_sfx.ps1` and `tools/pick_sfx.ps1` make and level the takes. Three ideas for the shop are in the guidebook's Feedback tab (`f-s18c-06-lucky-look`).
- **Rewrite the dialogue: it reads too dry.** I want to use a writing skill that was shared in the jam's Discord. Ask me for it before rewriting anything. Every line lives in `config/game_config.gd` and `scripts/lucky_lines.gd`; several checks quote lines, so run the suite after.
- **Redesign the robots.** Art direction is mine. Ask for it; do not generate machines on your own initiative.

## Phase 3: new systems (one per session, each on its own branch)

Recommended model: Opus 5.5. Each of these changes how the game plays, so each starts with a short written proposal (five lines: what the player does, what it costs, what it replaces, what could go wrong, how I will test it) and my yes, before any code.

- **Reload.** The seed shooter reloads after 10 shots. Reload upgrades stack 5 times for 75% off, ending at a 1 s reload, so the starting reload is 4 s and each stack takes off 15 percentage points. Needs card art (Klad, `tools/klad_art.ps1`).
- **Skill unlocks.** Brambles and the Vine Trip Line become cards on the upgrade screen, not shown until wave 3 is beaten. This touches the wave 2 bramble tutorial, the HUD counter, the touch button and the card pool.
- **Logbook** in the pause menu: every tip from Canopy FM and Lucky, added as it is said.
- **Resume buttons** after Lucky's moment, a fuse revive and each machine intro, instead of returning to the game on a timer.
- **Tutorial pause.** During the tutorial transmissions of the first waves only, the fight slows, darkens and machines and trees stop. Other transmissions never slow the game.
- **Sunburst rework.** A great sunroot that fires goes back to a sapling and regrows 20% slower; a card adds 2 Sunbursts. Each machine a Sunburst hits freezes, crackles with sparks, puffs black smoke, then is removed.
- **Front homes.** Move the bottom row of houses so more of their fronts show, and take the graffiti off their roofs (the four roof tags in `scripts/graffiti.gd` need new places).
- **Spitter shots damage trees and pierce**, so machines can hit each other (`scripts/spit_shot.gd`).
- **Robots only take root on soil.** Changes the core loop; needs a floor design first.
- **A fifth enemy type.** Ask me what role is missing before designing one.
- **Waves that end on an objective**, with machines that keep coming.
- **A true tutorial.** The biggest item. Build it last in this phase, on top of the tutorial pause and the Resume buttons.

## Phase 4: story scenes

Recommended model: Opus 5.5 for the staging; the art is mine.

- **The community plants the great sunroot** at the end of the regular game.
- **Comic-page scenes every 2 or 3 waves:** the community building things and repairing Seven, with captions and the music building.

Both need my panels or an agreed way to make them. Start by asking what I have.

## How to finish a session

1. Run the full suite and say the count.
2. Export, open the preview, and tell me what you saw on screen for each item. Say plainly what you could not check (sound, a real phone, anything that needs a person playing).
3. Update the devlog, `AI_LOG.md`, `.feedback/checklist.html` (never committed) and the guidebook.
4. Tell me the branch name and ask whether to merge and push. Do not do either until I say yes.
