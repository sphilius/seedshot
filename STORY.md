# Seedshot: story spine ("Lights Out")

Status: approved by Sasha on 2026-11-16, and updated since as Sasha changed it. Steps 1 and 2 are built.
Lines marked (placeholder) are there to be rewritten. The structure is the proposal.

## Hook (the first five seconds)

> **Helios owns the sun. Your block stopped paying for it.**

## The world in three sentences

Helios Clean Energy sells "clean power for all" and has made any unlicensed solar a crime called theft of sunlight.
One block has gone dark rather than pay, and is growing its own power: sunroot (placeholder), a pirate strain that
roots in scrap metal, drinks the sun by day and glows with stored power at night. Every night, Helios sends machines
to cut it down.

## Central conflict

**Who owns the light?** A block that wants its lights on, against a company that owns the only legal way to have them.

## Look and mood

Night in a walled-in back lot of a dense, stacked city: dark wet concrete, warm amber windows, neon signs and glowing
graffiti, weathered little robots, one cat. The mood reference is the game Stray (a lived-in neon city, small and
tender against something huge and uncaring). Its mood is the reference, not its art: every sprite, sign and character
here is our own.

What that means for a top-down 2D game:
- The floor goes dark and cool. Light comes from the things that matter: windows, trees, signs, Seven's lamp.
- Sunroot trees glow softly, so the forest is also the lighting.
- Graffiti and Helios notices are drawn as neon and stencil on the walls.
- Lit windows are warm amber. A dark window is nearly invisible.

## Characters

| Who | What they are | What they want | How the player meets them |
|---|---|---|---|
| **Seven**, the player | Helios meter-reader unit MR-7, jailbroken and repainted by the block's kids | To keep the lights on | You play it |
| **Helios** | The company, heard only as customer service: polite, cheerful, threatening | The account settled, or the block dark | One line on the banner at the start of each wave |
| **The Block** | The neighbours and their kids | Their own power | Graffiti that appears on the arena walls, answering Helios |
| **Lucky** | A lucky-cat shopkeeper behind a shutter in the wall, dealing parts off the books | Company, and customers | Hidden. Three pods on the shutter opens it. Then you can talk to it. |

The machines are only machines: Helios hardware following orders.

## Four trailer shots (the spectacle the mechanics must deliver)

1. **First light.** The first machine falls, roots, and grows. A dark window on the wall glows.
2. **Blackout.** A disconnection crew saws a tree down. A lit window flickers dark and the music dulls.
3. **Almost there (after wave 8).** Most of the homes are lit and shining strongly; the lot has warmed from night
   blue toward amber. Two homes are still dark. This is the payoff players reach before the end, with more to come.
4. **The whole block lit (after wave 10).** The last homes come on at full strength, and the light jumps the wall:
   windows come on in the next block over.
## What each mechanic means now

| Mechanic (already built unless marked NEW or CHANGED) | Meaning in the story |
|---|---|
| A downed machine becomes a tree | Sunroot grows in scrap. Helios's own hardware becomes the block's power plant. |
| Trees block shots | The grid you grow is also your cover. |
| Scrapper | Repossession unit. It comes for you, the stolen meter-reader. |
| Spitter | Enforcement unit. It keeps its distance and fires. |
| Sawbot | Disconnection crew. It ignores you and cuts power, which is why it goes for trees. |
| Vine: zip to a tree | Live cable. Seven rides the grid it grows. Seven has this from the start. |
| CHANGED: vine yank and bind a machine | Locked at the start. Lucky sells Seven a live clamp that shorts a machine: this is the first half of the cat's gift. |
| CHANGED: the cat's gift | No longer paired pods. It is the yank-and-bind, plus a spare fuse: the first time Seven would go down, it gets back up instead. A used fuse is replaced only when Seven is really defeated and the wave restarts. Clearing a wave does not replace it. |
| NEW: talking to Lucky | Stand by the open shop and press E (or tap the shop). Lucky says a line. It changes nothing in the game. |
| The corner counter | Shows **Homes lit** (out of ten) and **Trees** standing. |
| NEW: homes and windows | Ten homes along the bottom wall, 24 windows in all (two or three each). Each wave cleared lights more windows and makes every lit window shine stronger. A tree cut down makes one lit window flicker dark for a moment. |
| NEW: the lot's light | Everything in the lot (sprites, floor, walls) is tinted to match: dark and blue when few windows are lit, warm and bright when the block is lit. |
| NEW: Canopy FM | The block's pirate station. One song, muffled at first, that opens up as more homes are powered and dulls when trees fall. |
| NEW: graffiti | The Block's lines appear on the walls and stay. By wave 8 the walls are covered. |
| NEW: tap points | A few marked cells per wave. A machine downed on one grows a tap tree: it powers three homes, heals one pip, and is slow to saw. Lure a machine there, or, once Lucky has sold you the clamp, yank it there. |

**Finding Lucky:** the cat stays hidden for the first two waves, so finding it early is a discovery. From wave 3, if
the shop is still shut, a graffiti arrow points at the shutter ("KNOCK x3"). Nothing a player needs to finish the game
is behind the cat: the zip is theirs from the start.
## Lucky's lines (all placeholders)

Lucky has two kinds of line. Neither changes the game.

**The greeting**, said once when the shutter opens. It depends on the wave you found it in:

| Found in | Lucky says |
|---|---|
| Waves 1 to 3 | "Early. I like early. Take the clamp, kid. And a fuse, on the house." |
| Waves 4 to 7 | "Thought you'd never knock. Clamp. Fuse. Don't tell Helios." |
| Waves 8 to 10 | "The whole block's lit and NOW you find me? Take the clamp anyway." |

**Small talk**, each time you speak to it. It depends on the wave you are on, and cycles through the set:

| On wave | Lucky says (cycles) |
|---|---|
| 1 to 3 | "They used to queue down the alley for me." / "That saw-thing's coming. They always send the saw-thing." / "Seven's a lucky number. I'd know." |
| 4 to 7 | "Watch the trees, not yourself. You, I can fix." / "Hear that? Somebody's got the radio going." / "I've sold fuses to worse causes." |
| 8 (block lit) | "Look at that. Haven't seen my own sign lit in years." / "Don't get soft. They'll want it back." |
| 9 to 10 | "They're not sending notices any more." / "Hold it one more night. Next block's watching." |

## The ten waves (all lines are placeholders)

| Wave | Helios (banner) | The Block (graffiti) | Beat |
|---|---|---|---|
| 1 | "Courtesy notice: your account is 90 days past due." | KEEP THE LIGHTS ON! | First light |
| 2 | "A technician is on the way to help you." | NOT YOURS | Enforcement arrives |
| 3 | "Unlicensed generation is theft of sunlight." | THE SUN IS FREE (and KNOCK x3, if the shop is shut) | You start choosing where trees go |
| 4 | "Disconnection crews dispatched. Thank you for your patience." | GUARD THE TREES | First Sawbot, first blackout |
| 5 | "We'd hate to lose you. Ask about our amnesty plan." | NO DEAL | Halfway: stop-and-rate marker |
| 6 | "Your neighbours are paying for your choices." | WE ARE THE NEIGHBOURS | |
| 7 | "Unit MR-7 is stolen Helios property." | SEVEN IS OURS | It gets personal |
| 8 | "Final notice." | WE ARE THE GRID | Cleared: almost there |
| 9 | "Service area reclassified. Recovering assets." | STILL HERE | Helios comes to take it back |
| 10 | "Please hold." | PASS IT ON | Cleared: the whole block lit, then the next block |

**End screen:** "PASS IT ON", the trees left standing, and Helios's last word: "Account closed."

## What we expect a playtest to show

By wave 4, players defend trees from Sawbots because watching a window go dark bothers them, not because the game told
them to. If that does not happen, the windows and the music are not doing their job.

## Build order, and what gets cut first

Build in this order, so the game is shippable after every step:

1. Words: Helios banner lines, graffiti on the walls, the end screen, "Homes powered", the name Seven.
2. Light: the night look, homes whose windows light wave by wave, the lot's tint following the light, the wave 10 next block.
3. Lucky: the yank-and-bind and the spare fuse replace paired pods; the E key and tap to talk; the lines above; the KNOCK x3 arrow.
4. Canopy FM: one generated song on its own audio bus, with a filter that opens as homes are powered. The mute key
   already covers it. This is one track made to sound fuller or duller, not separate stacked recordings, because
   generated tracks will not line up in time.
5. Tap points and tap trees.

If time runs out, cut from the bottom: tap points first. Steps 1 to 4 are the story.

Sprites are recoloured for night only if time is left after step 5. Until then the night look comes from the floor,
the glow and the windows.

## Dates

- Steps 1 to 3: Tuesday, November 17.
- Steps 4 and 5, a blind playtest, the itch page: Wednesday, November 18.
- Jam window closes Friday, November 20 at 2:00 AM ET. Thursday is the spare day.
