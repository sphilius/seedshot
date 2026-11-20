# Seedshot v2.0: handoff prompt

Written Friday, November 20, 2026, at the end of session s25 (128 px art drafts).
Paste everything below the line into a new Claude Code session opened in
`C:\Users\sphil\dev\seedshot`. Do **one stage per session**. To continue, paste it
again into a fresh session and change the one line that says which stage to do.

## Which model and effort to use

| Stage | Model | Effort | Why |
| --- | --- | --- | --- |
| 0 + 1: merge and HD display test | Opus 5.5 | `/effort high` | It spans the art pipeline, the renderer, the web export and the tests at once. |
| 2: features (one item per session) | Opus 5.5 | default | Each item changes how the game plays and starts with a proposal. Small ones (Front homes, Spitter shots) are fine on Sonnet 5.5. |
| 3: sound pass | Sonnet 5.5 | default | File conversion, levels and wiring. |
| 4: store and video assets | Sonnet 5.5 | default | Scripts already exist. Use Opus 5.5 for the intro video's staging. |

Never use Max effort for these: it over-thinks scoped edits and wanders out of scope.
If a stage fails twice at the effort above, go one step up (default to high; high to the next model up with `/model`).

---

## Your task

Do **Stage 0 and Stage 1** below, and only those. When they are done, stop, tell me what to playtest on my PC and my phone, and wait. Do not start the next stage in the same session.

Before anything else, run `Get-Date -Format "dddd, MMMM dd, yyyy — hh:mm tt K"` and state the result. Then read `CLAUDE.md`, `DESIGN.md`, `art/draft128/README.md`, `docs/PHASE3_NEXT_PROMPT.md` (it arrives with the Stage 0 merge) and the top five entries of `docs/DEVLOG.md`. They are the record of truth; where this prompt and the code disagree, the code wins and you tell me.

## The goal

v2.0 is the update I release once the jam's judging ends. I want **the best art and sound quality possible**, plus the features from my feedback lists, even if that means a big rebuild. It must run **in browsers on PC and on phones**. I am **not** hand-finishing art: everything comes from the pipeline in `tools/`, and you choose the best take.

The plan we agreed: **one adaptive web build**, not a build per screen. The layout stays 1280 x 720 (gameplay, grid and code don't change), but the game draws at the device's real resolution, so 128 px art fills high-resolution screens and is scaled down smoothly on small ones.

## Who I am and how to work with me

I am Sasha. I am learning GDScript and Python; I understand systems but not every idiom. I have AuDHD, so:

- Lead with the answer, then explain. State the recommended path before any alternative, and keep decision points few.
- Use numbered steps with emojis for anything I have to do.
- Comment the code so I can read it without help: what each function is for, and any idiom the first time it appears in a file.
- Tell me plainly when I'm over-engineering (three or more new systems before one has been played).
- I work in PowerShell on Windows 11.

## Rules that do not bend

1. **No merge into `main`, no push, no GitHub Pages publish and no itch upload without my explicit yes.** Each needs its own yes. Itch stays untouched until v2.0 ships after the jam.
2. **Branch first.** Small commits, never on `main`. Commit message: an imperative summary of at most 72 characters, a blank line, one sentence of why, and the attribution line your session is told to use.
3. **Hands off my files.** Never commit `.feedback/`. Never edit, move or re-encode anything in `art/concept/*_sprite/`, `art/source/compare/`, `art/video/`, `playthrough recording/` or `audio/voice/candidates/`. Copy out of them if you need a file. Leave the untracked files in the working tree alone.
4. **Every tunable goes in `config/game_config.gd`** (and so `game_config.tres`), with a comment saying what it does and its unit. No bare numbers in scripts.
5. **Children signal up, the arena calls down.**
6. **Each change gets headless checks** in `tests/check.gd`; run the suite after every meaningful change, not at the end.
7. **Spending needs a yes.** Image generation (Gemini, `GEMINI_API_KEY`), ElevenLabs (`ELEVENLABS_API_KEY`) and Lyria cost credits. Ask first and say how many takes. Never print a key.
8. **Logs:** a line in `AI_LOG.md` for each new asset or system, and a `docs/DEVLOG.md` entry for each design choice, newest first.
9. One item at a time: build it, check it, commit it, then the next. If something fails twice, stop and tell me rather than retrying the same way.

## Commands and traps

- `.\tools\godot.ps1 import | test | export | editor`. It wraps the Godot 4.7.2 non-mono console build; the `godot` on PATH hangs headless.
- `test` takes about 100 seconds. A compile error shows up as a 240 second timeout, so read the top of the output.
- After adding a `class_name` script, run `import` before trusting "Could not find type". "Identifier not found: Sfx / RunState" from the godot-check hook is the autoload caveat, not a real error.
- Godot runs rewrite `project.godot` with noise. Revert that with `git checkout -- project.godot` unless you meant to change it; if you did, commit only your lines.
- Never pipe the export through `Select-Object -First N`: it kills the export half-written. Redirect to a file instead.
- `export` copies `web\intro.mp4`, `intro.css` and `intro.js` into `build\web\`. Leave that step alone.
- Preview: the `seedshot-web` config in `.claude\launch.json` serves `build\web` on port 8063.
- Tests can't change the shared config: `CONFIG.set()` from a test doesn't reach the arena. Put a rule in a static function and test that (see `Arena.skill_cards_wanted`).
- Real-renderer pictures: copy `tests/capture_nozzle.gd` or `tests/capture_skills.gd`, run without `--headless`, and save to `docs/s26/`.
- `tools/gen_concepts.generate` calls `sys.exit` when no picture comes back: catch `(Exception, SystemExit)` around it.

## Stage 0: bring the branches together

The art work and `main` have split.

- **This folder** is on `s25-art-128-draft`. It's built on `s24-seven-engineer` and holds:
  - the six machine sprites,
  - the emerald Engineer Seven (8 facings, nozzle on the right arm, gold nozzle arm while aiming),
  - the 128 px drafts of every asset in `art/draft128/` (not wired in).
- **`main` (`4fbbc26`)** has what this branch lacks:
  - s23 Full screen,
  - s24 Skill unlocks,
  - the GitHub Pages tools,
  - `docs/PHASE3_NEXT_PROMPT.md`.

Steps:

1. Create the session branch from here: `git switch -c s26-v2-hd`.
2. Merge `main` into it: `git merge main`. This is merging *into the work branch*, which this prompt authorises; merging into `main` still needs my yes.
3. Resolve the conflicts. Expect them in `docs/DEVLOG.md`, `AI_LOG.md`, `config/game_config.gd`, `config/game_config.tres` (`load_steps` and the `ext_resource` list; keep every texture from both sides) and `tests/check.gd`.
4. **Devlog IDs collide.** `main` owns D-067 to D-069. Renumber this branch's own entries, oldest first:

   | Today on this branch | New ID |
   | --- | --- |
   | D-066 Machine picks (a duplicate of the D-066 number) | D-070 |
   | D-067 The six machines as pixel sprites | D-071 |
   | D-068 Seven redesign round 1 | D-072 |
   | D-069 The Engineer strip | D-073 |
   | D-070 Right-arm nozzle and nozzle arm | D-074 |
   | D-071 128-class drafts | D-075 |

   Fix every reference to the old IDs: other devlog entries, `AI_LOG.md`, `docs/s21/emerald_seven_checklist.md`, and the guidebook's decision `outcome` fields. After this, **the next free ID is D-076**.
5. Run `import`, then `test`. `main` had 944 checks and this branch 893, so expect about 960 after the merge. All must pass.
6. Commit the merge.

## Stage 1: the HD display test (art and settings only, no new features)

Done when one web build looks sharp on a 1440p or 4K monitor and on a phone, looks smooth (not jagged) in a small window, and plays exactly as before.

1. 🖼️ **Pick the 128 px takes.**
   - Look at `art/draft128/compare_*.png`, `strip_check.png` and `overview_64_vs_128.png`.
   - Where `art/draft128/raw/` has two takes, choose the better one; `python tools/gen_128.py build --pick name=N` rebuilds with your picks.
   - Show me one picture of all the picks together and go on unless I object.
   - Known problems to fix:
     - Seven's hat came out solid gold. It should be the cream-and-gold solar-panel brim with the seedling, as on the 64 px strip (`art/sprites/gardener_bot_facings.png`).
     - The roofs are noisy at 128.
     - The 128 aiming strip keeps small green stubs where the nozzle was painted out.
     - The SE facing barely differs from S.
   - Redrawing a sprite spends Gemini credits: ask with a count first.
2. 🔌 **Wire the 128 art in at the same on-screen sizes.**
   - Today the sprites are 64 px, shown 1:1 (`cell_size` 48, `sprite_size_cells` 1.3333); floor tiles are 48 px and roofs 52 x 32.
   - Make the on-screen size come from the config, never from the texture's pixel size, so a 128 px picture shows at the same size as the 64 px one did. Grep for every place that assumes 64 px, 48 px tiles or 52 x 32 roofs: scripts, scenes, `tests/check.gd` size checks, and Seven's strip (`hframes` 8) with its aiming strip.
   - Keep the 64 px files in git history; replace them in `art/sprites/` so there's one set of art.
   - Delete `art/draft128/.gdignore` only if you load from there; otherwise leave the drafts ignored.
   - Stage a before-and-after screenshot of the arena at the same moment and show me both.
3. 🔍 **Sharp drawing on high-resolution screens.**
   - Enable Godot's high-DPI setting for the window and web (`display/window/dpi/allow_hidpi`), and check the web export's canvas resize policy is adaptive.
   - Keep stretch mode `canvas_items` and aspect `keep`.
   - Prove the canvas's backing size follows `devicePixelRatio` in the browser preview at ratios 1, 2 and 3 (`window.devicePixelRatio`, canvas `width` against `clientWidth`).
4. ⚖️ **Choose the texture filter at startup and on every resize.**
   - Work out the scale: `min(window_pixels.x / 1280, window_pixels.y / 720)`.
   - At or above a config threshold (start at 1.5), use nearest, for hard pixel edges. Below it, use linear with mipmaps, so nothing shimmers. That means the sprites' import settings must generate mipmaps.
   - Put the rule in a static function with checks, and put the threshold in the config.
   - Set it on the root viewport's default canvas texture filter. The project default today is nearest (`default_texture_filter=0`).
5. 📱 **Phone compatibility.**
   - Keep the Compatibility renderer.
   - Export without thread support (`variant/thread_support=false` in `export_presets.cfg`), which avoids iPhone Safari problems.
   - Check the touch controls still line up at ratios 2 and 3.
   - Report the build size; it was about 10 MB.
6. ✅ **Verify.**
   - Run the full suite and export.
   - In the preview, emulate a desktop at ratio 1, a desktop at ratio 2 and a phone (`mobile` preset), and screenshot each to `docs/s26/`.
   - Say plainly what you couldn't check: a real phone, a real 4K screen, sound.
7. 📲 **Getting it onto my phone.**
   - Ask me for a yes to publish this build to GitHub Pages with `.\tools\publish_pages.ps1 -Export`. That is the only way I can try it on my phone. **Never itch.**
   - If I say no, tell me how to serve `build\web` on my home network instead.
8. 📝 **Wrap up.**
   - Mark D-075 Made, or add an entry describing what changed.
   - Add `AI_LOG.md` lines.
   - Add a guidebook milestone "S26 HD display test" (status `testing`) with beginner setup steps and questions: sharpness on PC, sharpness on phone, smoothness in a small window, any sprite that looks wrong, and frame rate on the phone. Mark the previous testing sheets done only if I have answered them.

## Later stages (one per session; listed so you know where this is going)

### Stage 2: features from my feedback

1. Start by reading my playtest answers and new feedback in the guidebook, and `.feedback/checklist.html` in this folder (never committed). Offer any tuning they call for first.
2. Then the remaining Phase 3 items, **in the order and with the notes in `docs/PHASE3_NEXT_PROMPT.md`**, each on its own branch cut from the latest work branch:
   1. Logbook
   2. Resume buttons
   3. Tutorial pause
   4. Sunburst rework
   5. Front homes
   6. Spitter shots damage trees and pierce
   7. Robots take root only on soil (ask me for the floor design)
   8. A fifth enemy type (ask me which role is missing)
   9. Waves that end on an objective
   10. A true tutorial, last
3. **Every item starts with a five-line proposal** and my yes, before any code:
   1. What the player does
   2. What it costs
   3. What it replaces
   4. What could go wrong
   5. How I will test it
4. Also open: the UI accent stays teal or turns emerald (the emerald checklist recommends keeping teal; ask me once). The Trip Line voice line (credits) and its title clip are also open.
5. Then Phase 4, the story scenes: the community plants the great sunroot at the end of the regular game, and comic-page scenes every 2 or 3 waves. Start by asking me what panels I have.

### Stage 3: sound pass

1. Convert the music to OGG Vorbis at about 160 to 192 kbps, from the best source file there is. The voice and sound-effect mp3s stay.
2. Do one mixing pass: measure loudness with ffmpeg (`loudnorm` in measure mode), level the buses, and make sure nothing clips on phone speakers.
3. Any regeneration (ElevenLabs, Lyria) needs a yes with a count.

### Stage 4: store and video assets, last, once the game looks final

1. Remake the title art. `art/sprites/title_art.jpg` still shows the old cream-dome teal Seven, and `tools/make_page_art.py` and `tools/make_cover.py` build from it.
2. Rebuild everything in `itch/`:
   - cover and cover preview,
   - page banner and background,
   - the four screenshots (`tests/capture_shots.gd`),
   - the YouTube thumbnail.
3. Remake the intro video `web/intro.mp4` (AI video; it shows the old Seven).
4. Rebuild the trailer with `tools/make_trailer.ps1` from a new recording I make, since the old one in `playthrough recording/` shows the old art.
5. Optional: a Windows download as a bonus beside the web build.

### Release (only with my yes, after the jam's judging ends)

Upload v2.0 to itch with the `itch-butler` skill. A reminder on November 28, 2026 covers making the repo private again (that takes the Pages link down); don't do either without my yes.

## How to finish every session

1. Run the full suite and say the count.
2. Export, open the preview, and say what you saw on screen for each item. Say plainly what you couldn't check.
3. Update the devlog, `AI_LOG.md`, `.feedback/checklist.html` (never committed) and the guidebook (https://claude.ai/artifact/6mk43Ao4cMZZkvJuAagKfG, per the `playtest-guidebook` skill; pin writes with `if_version`, never write `answers`, never invent results).
4. Tell me the branch name and ask whether to merge and push. Do neither until I say yes.
