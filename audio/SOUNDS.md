# Seedshot: sound list for ElevenLabs

**How it works:** save each sound into `audio/sfx/` under the exact file name below (`.mp3` is fine). The game picks it up by name and stops using the beep. No code changes. A sound you skip keeps its beep.

**Where:** elevenlabs.io > Sound Effects. For every sound: set the **Duration** shown, **Prompt influence** about 70%, looping off. It makes four takes per prompt: keep the shortest, cleanest one.

**Style line (already written into every prompt):** small, soft, organic sounds for the garden; dry, metallic sounds for the machines. No voices, no music, no reverb tail.

| # | File name | Plays when | Duration | Prompt |
|---|---|---|---|---|
| 1 | `fire.mp3` | You shoot a seed pod (up to 4 times a second) | 0.5 s | `Soft airy "thwip" of a small seed shot from a spring-loaded tube, light and plucky, very short, dry, no reverb` |
| 2 | `thunk.mp3` | A pod or spit shot hits a wall or tree | 0.5 s | `Small dull wooden thunk, a seed hitting a tree trunk, short, dry, no reverb` |
| 3 | `enemy_down.mp3` | A machine is destroyed | 0.8 s | `Small robot breaking apart, a metallic crunch with a short electric fizzle, cartoonish, dry, no explosion boom` |
| 4 | `grow.mp3` | A sapling becomes a tree; a pod lands on the hidden shop | 1.0 s | `Quick leafy rustle with a rising wooden creak, a plant sprouting fast, gentle and bright, no reverb` |
| 5 | `zip.mp3` | The vine pulls you to a tree | 0.6 s | `Fast whoosh of a rope pulling taut with a leafy swish, rising in pitch, short, dry` |
| 6 | `bind.mp3` | The vine yanks and ties up a machine | 0.8 s | `Whip crack of a vine followed by a tight creaking wrap around metal, short, dry` |
| 7 | `windup.mp3` | A Scrapper or Spitter is about to hit you (the warning) | 0.5 s | `Short rising mechanical whine, a servo charging up, tense warning tone, dry, no reverb` |
| 8 | `spit.mp3` | A Spitter fires | 0.5 s | `Wet pneumatic spit of thick oil from a metal nozzle, short, dry` |
| 9 | `saw.mp3` | A Sawbot cuts a tree (repeats twice a second) | 0.5 s | `Short burst of a small circular saw biting into wood, gritty, dry, cut off cleanly` |
| 10 | `hurt.mp3` | You take a hit | 0.5 s | `Metallic clank with a short low electric buzz, a small robot taking a hit, dry` |
| 11 | `player_down.mp3` | You are defeated | 1.5 s | `Small friendly robot powering down, a descending electric hum that fades out, sad but soft` |
| 12 | `wave_clear.mp3` | A wave is cleared | 1.5 s | `Warm three-note rising chime on a wooden kalimba with a soft leafy shimmer, hopeful, short` |
| 13 | `cat.mp3` | The hidden shop opens | 2.0 s | `A small brass bell rings twice, then a happy short cat meow, bright and lucky, clean` |
| 14 | `unlock.mp3` | Your very first click (proves sound is on) | 0.5 s | `Single soft wooden click with a tiny bright chime, friendly interface sound, dry` |

**Do these first if time is short:** 1, 3, 4, 7, 13. They are heard most, or matter most (7 is the "dodge now" warning, 13 is the jam's hidden cat).

**Not on the list yet:** background music and a looping garden ambience. The game has no music player yet; say the word and that becomes its own small step.

**After saving files:** run `.\tools\godot.ps1 import`, then `.\tools\godot.ps1 test`, and add one line per sound to `AI_LOG.md` (tool: ElevenLabs Sound Effects).
