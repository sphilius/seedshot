# Seedshot — Design Lock (Jamference Hack 4)

- **Jam:** Jamference AI Game Jam Hack 4. Build window Fri Nov 13, 2:00 AM ET to Fri Nov 20, 2:00 AM ET.
- **Own deadline:** submitted Tue Nov 17 night. Budget 20 hrs.
- **Theme:** Solarpunk. **Restriction (mandatory):** Hidden Lucky Cat.
- **Engine:** Godot 4, GDScript, Compatibility renderer, web export without threads.
- **Rule to respect:** no game code or game scenes before the window opens. Generic tooling is fine.

## Pitch

You are a gardener-bot in a scrapyard arena. You fire seed pods at rogue machines. Every machine you down roots where it fell and grows into a tree. Trees block shots, yours and theirs, and your vine can only latch onto trees. By wave 10 the scrapyard is a forest you planted and fight through.

## Two-term v1

- **Prediction (what the build must test):** is fighting inside a forest you created fun by wave 3? Specifically: do players start killing enemies in chosen spots on purpose?
- **Regularizer (anti-failure constraints):** one arena. Two verbs (seed, vine). Three enemy types. Taught by a staged first wave, no text walls. Checkpoint at every wave.
- **Heuristic (cut first, in this order):** Trellis upgrade, between-wave upgrade picks, touch controls, third seed type.

## Verbs

| Input | Verb | Rule |
|---|---|---|
| WASD | Move | 8-direction, no acceleration curve in v1 |
| Mouse | Aim | Reticle follows pointer |
| Left click | Seed pod | Projectile, short cooldown, blocked by trees |
| Right click | Vine lash | On a tree: zip to it in a straight line (replaces dash). On an enemy: yank it toward you and bind it for 1.5 s |

The vine is the Rootline idea folded in. It is a straight-line tween, not swing physics, so it carries none of the platformer risk. It also sharpens the Prediction: more trees means more places to zip, so the forest is mobility as well as cover.

**Trellis (upgrade, cut first):** zipping between two trees leaves a vine line between them for 6 s that snares any enemy crossing it. This is the Overgrowth idea in one rule.

## Trees

- A downed enemy becomes a sapling for 1 s (no collision), then a tree (collision, blocks projectiles).
- Trees snap to a grid cell. Trees have HP and can be destroyed.
- A bloom meter counts living trees. The final screen shows the arena as you left it.

## Enemies

| Type | Behavior | Why it exists |
|---|---|---|
| Scrapper | Rushes to melee | Baseline pressure; easy to place as a tree |
| Spitter | Keeps range, fires slow shots | Makes cover matter |
| Sawbot | Ignores you, cuts down trees | Makes the forest something to defend, and prevents the arena sealing shut |

## Waves

- 10 waves, target run 6 to 8 minutes.
- Wave 1 is staged: one Scrapper walks in, dies in one pod, grows into a tree, and a Spitter's shot visibly stops on that tree. A vine icon pulses on the tree until the player zips once.
- Waves 2 to 4 add Spitters, 5 to 7 add Sawbots, 8 to 10 mix all three.
- Death restarts the current wave with the forest as it stood at wave start.

## Hidden lucky cat

- **Where:** a shuttered shop on the arena's edge, outside the fight's natural center.
- **How:** hit the shop window with three seed pods. Vines grow over the front, the shutter lifts, and a moss-and-solar-panel maneki-neko waves.
- **Benefit:** seed pods fire as a pair for the rest of the run.
- **Hint:** the window glints every few seconds; a paw print is painted on the wall beside it.
- **Page requirement:** the itch description must say the game has a hidden lucky cat. Email a screenshot to dg@jamference.com.

## Technical choices

- **Pathing:** `AStarGrid2D` over the arena grid. When a tree spawns or dies, set that cell solid or clear and let enemies re-path on a timer. Avoids runtime navmesh rebakes on web.
- **Seal guard:** before a sapling becomes solid, check the player still has a path to the arena center; if not, the sapling stays non-solid.
- **Audio:** start the audio bus on first input (browser autoplay rule).
- **Size:** keep the export under 30 MB.
- **Art:** grayscale kit plus palette-swap shader; one accent color reserved for enemy tells.

## 20-hour plan

| When | Hours | Work |
|---|---|---|
| Thu night (pre-window) | not counted | Generic template: export preset, input map, audio unlock, palette shader. Write art prompts. No Seedshot scenes. |
| Fri evening | 3 | Gray-box move, aim, seed, vine zip. Web build running on itch as a draft. |
| Sat | 7 | Kill-to-tree, grid pathing, three enemies, waves 1 to 5, palette lock, art generations |
| Sun | 6 | Vine bind, waves 6 to 10, art and audio in, the cat, staged wave 1 |
| Mon | 2 | Blind playtest, fix the top three problems |
| Tue | 2 | itch page, AI tool list with a before/after image, submit |

**Gate:** if the Prediction fails on Saturday night (trees feel like clutter), raise tree HP and Spitter count before adding anything else.

## AI-use log (start now)

Keep one line per asset or system: tool, date, what it did. Raters scored what they could read on the page last time.

## Claude Code kickoff prompt (paste after 2:00 AM ET Fri)

```
Read DESIGN.md in this repo. We are building Seedshot for a game jam in Godot 4
(GDScript, Compatibility renderer, web export without threads).

Session goal: a gray-box build of the four verbs, running in a browser.
1. Arena scene: one screen, grid-aligned, placeholder rectangles only.
2. Player: WASD move, mouse aim, left click fires a seed pod projectile.
3. Place three static test trees. Seed pods stop on trees.
4. Right click on a tree zips the player to it in a straight-line tween,
   stopping one cell short. Right click on empty space does nothing.
5. One Scrapper enemy that walks at the player using AStarGrid2D and dies in
   one pod. On death it becomes a sapling, then a solid tree after 1 second,
   and the grid cell is marked solid.
6. Export to web and confirm it loads and audio starts on first click.

Constraints: no art, no menus, no upgrades, no waves yet. Keep every tunable
(speeds, cooldowns, tree HP, zip speed) as exported variables in one
config resource. Stop and report when step 6 passes.
```
