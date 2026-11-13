# Seedshot devlog

The record of design choices, newest first. The design lock itself is [DESIGN.md](../DESIGN.md); this file records what was decided while building, and why.

Statuses: Made, Changed, Removed, Revisited, Parked, Archived, Proposed.

## At a glance

| ID | Date | Status | Choice |
|---|---|---|---|
| D-008 | 2026-11-13 | Proposed | Final sprites from SpriteCook Pixel Engine at one fixed size |
| D-007 | 2026-11-13 | Proposed | Upload the web build to itch as a draft now |
| D-006 | 2026-11-13 | Made | Touch controls: two floating thumb-sticks, tap a tree for the vine |
| D-005 | 2026-11-13 | Made | Placeholder sprites are in the gray box (player and Scrapper) |
| D-004 | 2026-11-13 | Made | Debug respawn: a new Scrapper 2 s after each death |
| D-003 | 2026-11-13 | Made | Seal guard keeps a sapling walk-through for good; an occupied sapling retries |
| D-002 | 2026-11-13 | Made | The vine latches the first tree its ray meets |
| D-001 | 2026-11-13 | Made | Every tunable in one config resource |

## D-008: Final sprites from SpriteCook Pixel Engine (Proposed, 2026-11-13)

The eight placeholders have mixed pixel sizes, which no script can fix. SpriteCook's Pixel Engine makes transparent PNGs at an exact size (16 to 128 px), so a set matches. Cost: 6 credits a sprite, 30 credits in the account. Open in the guidebook as decision `d2-final-art-source`. Do it only after Saturday's gate passes.

## D-007: itch draft now (Proposed, 2026-11-13)

The Friday plan asks for a draft on itch. It is also the only reliable way to test touch with two thumbs on a real phone. Open in the guidebook as decision `d1-itch-draft`.

## D-006: Touch controls (Made, 2026-11-13)

Asked for in chat: touch friendly without changing core gameplay. Left-half slide moves, right-half slide aims and fires while held, a quick tap on a tree is the vine.

- **Why sticks, not tap-to-aim:** a finger on the target hides the target. Seed pods only need a direction.
- **Why tap-versus-slide:** a touch is a tap or a stick, never both, so trees under the thumbs can still be tapped.
- **What stayed the same:** the touch layer presses the normal move actions and calls the same `fire` and `try_vine` code. Speeds, cooldowns, range and stop-short are untouched.
- **What differs:** movement is any angle (keyboard is 8 directions), aim is a direction (mouse is a point), and the tap radius is 1.5 cells (mouse is 0.9).
- **Cut-list note:** DESIGN.md lists touch as the third thing to cut. It is one node, `Hud/TouchControls`; deleting it removes the feature.

## D-005: Placeholder sprites in the gray box (Made, 2026-11-13)

The kickoff said no art, but placeholders were supplied in the same message. Player and Scrapper use them. Clearing the two textures in `config/game_config.tres` brings the rectangles back.

## D-004: Debug respawn (Made, 2026-11-13)

With one Scrapper and no waves there is nothing to do after the first kill. A new one walks in after `debug_respawn_delay` (2 s; 0 turns it off). Real waves replace this.

## D-003: Seal guard behaviour (Made, 2026-11-13)

DESIGN.md says a sapling that would cut the player off from the arena centre stays non-solid. Built as: it stays a sapling permanently (no later retry). Separately, a sapling someone is standing on waits 0.25 s and tries again, so nobody is trapped inside a tree.

## D-002: Vine latches the first tree on the line (Made, 2026-11-13)

If another tree stands between the bot and the clicked tree, the vine grabs the nearer one. A wall in the way means no latch. This keeps the zip an honest straight line.

## D-001: One config resource (Made, 2026-11-13)

From the kickoff. `config/game_config.tres` holds every speed, cooldown and size, so tuning never needs a code edit.
