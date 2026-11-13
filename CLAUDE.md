# Seedshot: notes for Claude

Jam entry (Jamference Hack 4). The design lock is `DESIGN.md`; decisions made while building are in `docs/DEVLOG.md`.

## Commands

- Use `.\tools\godot.ps1 import | test | export | editor`. It wraps the Godot 4.7.2 non-mono console build; the `godot` on PATH hangs headless.
- After adding a `class_name` script, run `import` before trusting "Could not find type" from the godot-check hook. "Identifier not found: Sfx" from that hook is the autoload caveat, not a real error.
- Never pipe the export through `Select-Object -First N`: it kills the export half-written.

## Rules of the build

- Every tunable goes in `config/game_config.gd` (and so `game_config.tres`), never as a number in a script.
- Children signal up, the arena calls down.
- Each feature gets headless checks in `tests/check.gd`; run them after every meaningful change.
- Add a line to `AI_LOG.md` for each new asset or system.

## Playtest guidebook

https://claude.ai/artifact/6mk43Ao4cMZZkvJuAagKfG

Update it per the playtest-guidebook skill. The page source is `docs/playtest/guidebook.html`; its content lives in the artifact's database.
