# Evidence for #1094 (refs #1090): swipe typing reads the user's own words, in their casing

Simulator `feature/1090-swipe-learned-words` (iPhone 17, iOS 27.2, slimmed, French UI, status bar at 9:41), Debug build of `feature/1090-swipe-learned-words` at 45c19de3 (PR #1094, head fe8c1438 adds only a merge of develop f44c0a98, audio), Full Access on, « Swipe typing » on (Expériences), Dictus keyboard in a `<textarea>` served from the Mac. Strokes drawn with AXe v2.2.0 (official release binary, `axe draw`, one finger through the keycap centres of AZERTY).

| File | What it shows |
|---|---|
| `wisprflow.mp4`, `wisprflow-mid-sentence.png` | « WisprFlow » **learned by tap typing**: typed twice mid-sentence with its capitals (`avec WisprFlow et WisprFlow`), the store then holds `wisprflow = 2` and its casing `WisprFlow`. A swipe w-i-s-p-r-f-l-o-w after « On travaille avec » types « WisprFlow », inner capital kept. |
| `apple-once.mp4`, `apple-learned-once.png` | « Apple » seeded in the store at **one use** (the state one refusal leaves, #872), with its casing `Apple`: the swipe a-p-l-e after « On achete chez » types « aime », and « Apple » is not even in the bar. A word learned once never comes out of a swipe. |
| `apple-adopted.mp4`, `apple-adopted-mid-sentence.png`, `apple-and-wisprflow.png` | The same store with « apple » at **two uses** (adopted): the same swipe types « Apple », capital kept mid-sentence, then « et » and a swipe of « WisprFlow » in the same sentence. |
| `switch-off.png` | « Swipe typing » off: no swipe controller (`swipeTypingConfigured on=false … :off`), the same stroke types the key under the finger on lift, as on develop. |
| `keyboard-log.txt` | The keyboard's lines for the runs above: `swipeTypingConfigured on=true` at each appearance, one `swipeEnded … outcome=word` per swipe (Debug decode 59–76 ms; counts only, never the word). |
| `learned-store.txt` | The App Group store at the end: `dictus.userDictionary`, the new `dictus.userDictionary.casing`, `lastUsed`. |

Why « Apple » is seeded and not typed: the French spellcheck dictionary already has « apple » (`fr_frequency.json`, frequency 50), so tap typing keeps « Apple » mid-sentence but never learns it (#287 decision 2: only words the dictionary lacks are learned). The French swipe model lacks it. Typed « Apple » twice by tap here, the store stayed empty. The seed writes the three keys the app writes, in the App Group plist, and the keyboard reads them on its next appearance.
