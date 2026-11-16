# Seedshot: story spine ("Lights Out")

Status: DRAFT for Sasha to edit. No code follows this until Sasha approves it.
Names and lines marked (placeholder) are there to be rewritten. The structure is the proposal.

## Hook (the first five seconds)

> **Helios owns the sun. Your block stopped paying for it.**

## The world in three sentences

Helios Clean Energy sells "clean power for all" and has made any unlicensed solar a crime called theft of sunlight.
One block has gone dark rather than pay, and is growing its own power: sunroot (placeholder), a pirate strain that
roots in scrap metal and grows leaves that make electricity. Helios is sending crews to cut it down.

## Central conflict

**Who owns the light?** A block that wants its lights on, against a company that owns the only legal way to have them.

The dark turn: the Helios machines are flown by remote contract pilots, people from blocks just like this one, paid per
disconnection. Winning means beating people who are also losing.

## Characters

| Who | What they are | What they want | How the player meets them |
|---|---|---|---|
| **Nine** (placeholder), the player | A Helios meter-reader bot the block's kids jailbroke and repainted | To keep the lights on | You play it |
| **Helios** | The company, heard only as customer service: polite, cheerful, threatening | The account settled, or the block dark | One line on the banner at the start of each wave |
| **The Block** | The neighbours and their kids | Their own power | Graffiti that appears on the arena walls, answering Helios |
| **Lucky** | A parts dealer behind a shutter in the wall, with a lucky cat on the counter | Customers | The hidden cat: three pods on the shutter opens it, pods fire in pairs |
| **The pilots** | The people flying the machines | To finish the shift | Three "last transmissions", one line each, when a wave ends |

## Three trailer shots (the spectacle the mechanics must deliver)

1. **First light.** The first machine falls, roots, and grows. A dark window on the wall glows.
2. **Blackout.** A disconnection crew saws a tree down. A window goes dark and the music loses its top end.
3. **The block lit.** Wave 10 ends with every window on, the full song playing, and the last Helios notice painted over.

## What each mechanic means now

| Mechanic (already built unless marked NEW) | Meaning in the story |
|---|---|
| A downed machine becomes a tree | Sunroot grows in scrap. Helios's own hardware becomes the block's power plant. |
| Trees block shots | The grid you grow is also your cover. |
| Scrapper | Repossession unit. It comes for you, the stolen meter-reader. |
| Spitter | Enforcement unit. It keeps its distance and fires. |
| Sawbot | Disconnection crew. It ignores you and cuts power, which is why it goes for trees. |
| Vine: zip to a tree, yank and bind a machine | Live cable. You ride your own grid, and you can short a machine with it. |
| Hidden cat shop | Lucky's black-market counter. |
| "Trees" counter | Becomes **Homes powered**. One tree, one home. |
| NEW: windows on the walls | One window per tree standing. They light and go dark as the forest changes. |
| NEW: tap points | A few marked cells per wave. A machine downed on one grows a tap tree: it powers three homes, heals one pip, and is slow to saw. Lure a machine there, or yank it there with the vine. |
| NEW: Canopy FM | The block's pirate station. One song, muffled at first, that opens up as more homes are powered and dulls when trees fall. |
| NEW: graffiti | The Block's lines appear on the walls and stay. By wave 10 the walls are covered. |

## The ten waves (all lines are placeholders)

| Wave | Helios (banner) | The Block (graffiti) | Beat |
|---|---|---|---|
| 1 | "Courtesy notice: your account is 90 days past due." | LIGHTS ON | First light |
| 2 | "A technician is on the way to help you." | NOT YOURS | Enforcement arrives |
| 3 | "Unlicensed generation is theft of sunlight." | THE SUN IS FREE | You start choosing where trees go |
| 4 | "Disconnection crews dispatched. Thank you for your patience." | GUARD THE TREES | First Sawbot, first blackout |
| 5 | "We'd hate to lose you. Ask about our amnesty plan." | NO DEAL | Halfway: stop-and-rate marker |
| 6 | "Your neighbours are paying for your choices." | WE ARE THE NEIGHBOURS | Pilot transmission 1 |
| 7 | "Unit MR-9 is stolen Helios property." | NINE IS OURS | It gets personal |
| 8 | "This call may be recorded. This block may be removed." | STILL HERE | Pilot transmission 2 |
| 9 | "Final notice." | COME AND TAKE IT | Hardest wave before the last |
| 10 | "Please hold." | WE ARE THE GRID | The block lit |

**Pilot transmissions (shown small, for two seconds, when the wave is cleared):**
- After 6: "Pilot 114 signing off. They dock me for the unit."
- After 8: "I grew up on a block like this."
- After 10: "Leave it on. I'm clocking out."

**End screen:** "ACCOUNT CLOSED" painted over with "WE ARE THE GRID", then "Homes powered: N".

## What we expect a playtest to show

By wave 4, players defend trees from Sawbots because watching a window go dark bothers them, not because the game told
them to. If that does not happen, the windows and the music are not doing their job.

## Build order, and what gets cut first

Build in this order, so the game is shippable after every step:

1. Helios banner lines, graffiti on the walls, the end screen, "Homes powered". (Text only.)
2. Windows that light and go dark.
3. Canopy FM: one generated song on its own audio bus, with a filter that opens as homes are powered. The mute key
   already covers it. This is one track made to sound fuller or duller, not separate stacked recordings, because
   generated tracks will not line up in time.
4. Tap points and tap trees.
5. Pilot transmissions.

If time runs out, cut from the bottom: transmissions, then tap points. Steps 1 to 3 are the story.

## Dates

- Build steps 1 to 3: Tuesday, November 17.
- Steps 4 and 5, a blind playtest, the itch page: Wednesday, November 18.
- Jam window closes Friday, November 20 at 2:00 AM ET. Thursday is the spare day.
