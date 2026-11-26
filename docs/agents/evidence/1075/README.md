# #1075 captures: swipe typing in German

Simulator proof for PR #1075 (`feature/swipe-de`, head `9c3197a4`).

## How they were taken

- 2026-11-25 (23:09–23:16 UTC), Xcode 27.2, Debug build of `9c3197a4`, simulator « iPhone 17 » on the iOS 26.5 runtime, slimmed with simslim, French device. Created for the run by `verify-dictus-ios`'s `launch.sh` and deleted after it.
- App Group switches: `dictus.keyboard.swipeTyping` on, `dictus.language` = `de`. The Dictus keyboard was selected in Safari and shows German's default layout, QWERTZ (keys for ü ö ä, space bar « Leertaste »).
- Full Access could not be granted: Réglages → Général → Clavier stays blank on iOS 26.5 (the map's known gotcha). The bar therefore shows « Accès complet requis » instead of the readings. The swiped words still go in.
- The field is a `<textarea>` on a page served from the Mac (127.0.0.1).
- Strokes were drawn with AXe v2.2.0 (the notarized release binary, used from a scratch folder and deleted afterwards). Each word was one `axe draw` through its keys' centres, at about 0.22 s per key, then a 1.3 s pause. ß was drawn through s, ö through QWERTZ's ö key.

## Files

| File | Shows |
| --- | --- |
| `swipe-de.mp4` | 10.5 s, trimmed from the 28 s recording (from 15.0 s), 440×960. The field reads `… das Haus an der`; then « Straße » (s-t-r-a-s-e), « ist » and « schön » (s-c-h-ö-n) are swiped in. Ends on `… das Haus an der Straße ist schön`. |
| `keyboard-log.txt` | The keyboard's swipe lines: `swipeTypingConfigured on=true channel=debug` at each appearance, then one `swipeEnded … outcome=word` per swipe (counts and decode time only, never the word). |

## What it proves

The second run typed seven swipes, `das haus an der straße ist schön`, and the field got **`das Haus an der Straße ist schön`**:

- ß is read on the s key (« Straße »), and ö on QWERTZ's own ö key (« schön »).
- Nouns take their capital mid-sentence (« Haus », « Straße »), from `de.capitals`. « das », « an », « der », « ist », « schön » stay lowercase.
- « das » is lowercase because nothing before it ends a sentence. In the first attempt, at the start of the field, it came in as « Das ».
- Debug decode times on the simulator: 20–49 ms per swipe (log lines 23:14:57–23:15:18). A Debug build decodes 10–20 times slower than Release (`typing.swipe.md`).

## The first attempt, left in the field

The field starts with `Das Haus der ś`. That was a first attempt with `axe batch`, one `touch --down` step per point. On a loaded Mac each step comes about 0.4 s after the last, so the finger sat on `s` past the 0.5 s hold, and the accent popup typed « ś » instead of a swipe. This is the hold working, as the map's gotcha says. « an » and the words after « ś » were lost the same way. The second run used `axe draw`, one continuous stroke per word. The page did not reload between the two runs, so both are in the field.
