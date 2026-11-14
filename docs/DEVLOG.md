# Seedshot devlog

The record of design choices, newest first. The design lock itself is [DESIGN.md](../DESIGN.md); this file records what was decided while building, and why.

Statuses: Made, Changed, Removed, Revisited, Parked, Archived, Proposed.

## At a glance

| ID | Date | Status | Choice |
|---|---|---|---|
| D-010 | 2026-11-13 | Made | One art spec for every tool: 64 px, top-down, 12 colours, red for enemies only |
| D-009 | 2026-11-13 | Made | Scrapper melee is a telegraphed swing; 5 hit points; defeat restarts the arena |
| D-008 | 2026-11-13 | Revisited | Final art source: three-way test first (SpriteCook, ChatGPT Images, Klad) |
| D-007 | 2026-11-13 | Made | Upload the web build to itch as a draft (waiting on the game page) |
| D-006 | 2026-11-13 | Made | Touch controls: two floating thumb-sticks, tap a tree for the vine |
| D-005 | 2026-11-13 | Made | Placeholder sprites are in the gray box (player and Scrapper) |
| D-004 | 2026-11-13 | Made | Debug respawn: a new Scrapper 2 s after each death |
| D-003 | 2026-11-13 | Made | Seal guard keeps a sapling walk-through for good; an occupied sapling retries |
| D-002 | 2026-11-13 | Made | The vine latches the first tree its ray meets |
| D-001 | 2026-11-13 | Made | Every tunable in one config resource |

## D-010: One art spec for every tool (Made, 2026-11-13)

Written down in `art/PROMPTS.md` so any generator gets the same brief.

- **64 x 64 pixels.** A cell is 48 px and sprites are drawn slightly larger than a cell. When final art goes in, set `sprite_size_cells` to 1.333 so one art pixel is exactly one screen pixel.
- **Top-down, front at the top.** The game rotates sprites to face their aim or travel. The placeholders are front views, which look wrong when rotated. The cat is the exception: it never rotates.
- **12 colours, red for enemies only.** DESIGN.md asks for one accent colour reserved for enemy tells; the melee windup glow (D-009) already uses red.
- **Differs from DESIGN.md:** the lock says "grayscale kit plus palette-swap shader". The test uses colour so results compare directly with the colour placeholders. Revisit once a tool wins.

## D-009: Telegraphed melee, 5 hit points, restart on defeat (Made, 2026-11-13)

First slice of Saturday's work, pulled forward.

- **The swing:** within 1.0 cells a Scrapper glows red for 0.35 s and stands still, then hits if the bot is still in reach. Leaving its reach makes it miss. A hit you could not have avoided would make trees feel pointless; a hit you can dodge by zipping makes them matter.
- **Health:** 5 hit points, one per swing, 0.8 s of blinking invulnerability after a hit so two enemies landing together cost one point.
- **Defeat:** the whole arena reloads after 1.2 s. This is a stand-in. DESIGN.md says death restarts the current wave with the forest as it stood at wave start; that needs waves first.
- **How it is wired:** the Scrapper emits `struck`, the arena connects it to the player. The Scrapper never touches the player's health directly.

## D-008: Final art source (Revisited, 2026-11-13)

Was: SpriteCook Pixel Engine, proposed. Now: Sasha wants a three-way test first, SpriteCook vs ChatGPT Images vs Klad, against the Nano Banana placeholders as the baseline. Three sprites per tool, scorecard in `art/PROMPTS.md`. Guidebook decision `d2-final-art-source` stays open until the scorecard is filled in.

## D-007: itch draft (Made, 2026-11-13)

Decided in chat: upload now. The first `butler push` to `kingriot/seedshot:html5` was refused because the game page does not exist yet; butler cannot create one. Blocked on Sasha creating the page.

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
