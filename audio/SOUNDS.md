# Seedshot: sound list for ElevenLabs

**How it works:** save each sound into `audio/sfx/` under the exact file name below (`.mp3` is fine). The game picks it up by name and stops using the beep. No code changes. A sound you skip keeps its beep.

**Where:** elevenlabs.io > Sound Effects. For every sound: set the **Duration** shown, **Prompt influence** about 70%, looping off. It makes four takes per prompt: keep the shortest, cleanest one.

**Style line (already written into every prompt):** small, soft, organic sounds for the garden; dry, metallic sounds for the machines. No voices, no music, no reverb tail.

| # | File name | Plays when | Duration | Prompt |
|---|---|---|---|---|
| 1 | `fire.mp3` | You shoot a seed pod (up to 4 times a second) | 0.5 s | `Soft airy "thwip" of a small seed shot from a spring-loaded tube, light and plucky, very short, dry, no reverb` |
| 2 | `thunk.mp3` | A pod or spit shot hits a wall or tree | 0.5 s | `Small hollow metallic plink, a seed pinging off a thin empty tin can, bright short clink, dry, no reverb` |
| 3 | `enemy_down.mp3` | A machine is destroyed | 1.0 s | `Small machine winding down, an electric motor spinning down to a stop with a falling pitch and one last metal clunk, short, dry, no explosion` |
| 4 | `grow.mp3` | A sapling becomes a tree; a pod lands on the hidden shop | 1.0 s | `Quick leafy rustle with a rising wooden creak, a plant sprouting fast, gentle and bright, no reverb` |
| 5 | `zip.mp3` | The vine pulls you to a tree | 0.6 s | `Fast whoosh of a rope pulling taut with a leafy swish, rising in pitch, short, dry` |
| 6 | `bind.mp3` | The vine yanks and ties up a machine | 0.8 s | `Sharp whip crack of a vine, then a fast rising ratchet as it winds tight around metal with a creak, ending in a hard clamp, short, dry` |
| 7 | `windup.mp3` | A Scrapper or Spitter is about to hit you (the warning) | 0.5 s | `Short rising mechanical whine, a servo charging up, tense warning tone, dry, no reverb` |
| 8 | `spit.mp3` | A Spitter fires | 0.5 s | `Single small-calibre gunshot from a little cap pistol, a tight sharp crack with a short punchy snap, small and light, very short, dry, no reverb, no echo` |
| 9 | `saw.mp3` | A Sawbot cuts a tree (repeats twice a second) | 0.6 s | `Short aggressive burst of a small chainsaw revving and biting into wood, raspy two-stroke engine buzz, instantly recognisable, dry, cut off cleanly` |
| 10 | `hurt.mp3` | You take a hit | 0.5 s | `Sharp electric zap with a glitchy digital stutter, a small robot short-circuiting for an instant, bright and painful, dry` |
| 11 | `player_down.mp3` | You are defeated | 1.5 s | `Small friendly robot powering down, a descending electric hum that fades out, sad but soft` |
| 12 | `wave_clear.mp3` | A wave is cleared | 1.5 s | `Bright triumphant four-note rising fanfare on marimba and small bells, clear, loud and joyful, short, clean ending` |
| 13 | `cat.mp3` | The hidden shop opens | 2.0 s | `A small brass bell rings twice, then a happy short cat meow, bright and lucky, clean` |
| 14 | `unlock.mp3` | Your very first click (proves sound is on) | 0.5 s | `Two quick soft plastic clicks, a small switch being flicked on, gentle interface sound, dry` |

**Do these first if time is short:** 1, 3, 4, 7, 13. They are heard most, or matter most (7 is the "dodge now" warning, 13 is the jam's hidden cat).

**Not on the list yet:** background music and a looping garden ambience. The game has no music player yet; say the word and that becomes its own small step.

**After saving files:** run `.\tools\godot.ps1 import`, then `.\tools\godot.ps1 test`, and add one line per sound to `AI_LOG.md` (tool: ElevenLabs Sound Effects).
