# Emoji

- **ID:** `keyboard.emoji`
- **Tier:** Gratuit (Free)
- **Targets:** DictusKeyboard (the panel itself is in DictusCore, `Sources/DictusCore/Emoji`, ported from Hex, #1027)
- **Screens:** `kbd.emoji` — see [screens.md](screens.md)

## Sub-features

- `emoji.picker`: the panel takes the whole keyboard: the toolbar (mic, ☰) folds away while it is open and comes back with ABC, as Hex's strip does; the keyboard's height does not move (#166). Every category in one grid of four rows that scrolls sideways (Récents, then Smileys, Personnes, … Drapeaux); the bar under it jumps to a category on a tap and scrubs through them on a slide. Holding an emoji shows it larger.
- `emoji.recents`: « Récents », the grid's first section: the emoji you use most, fading over ten days, filled up with common ones. Read when the panel opens, so a pick does not move them under the finger. Imports the old picker's list once (`recentEmojis` in the App Group).
- `emoji.search`: the magnifier at the top left (the whole band left of the suggestions answers) opens « Rechercher des Emoji » with its own letter keys; results come from Unicode's CLDR names and keywords in the keyboard's language plus English. « coeur » and « cœur » both find ❤️.
- `emoji.back-to-letters`: ABC returns to the letters. The whole band under the grid left of the categories answers, not only the word.
- `emoji.skin-tones` (#1027): holding an emoji that has skin tones opens the tones; slide onto one and lift, or lift in place and tap one. The tone is remembered for that emoji, in the grid and the suggestions.
- `emoji.suggestions` (#1027): the row at the top suggests emoji for the words before the cursor (« pizza » → 🍕), then your favourites.
- `emoji.closed-on-reappearance` (#505): the picker does not survive the keyboard going away. Left open, then the keyboard dismissed (same app) or another app's field focused, the keyboard comes back on the letters, like Apple's. Check: open the picker, dismiss the keyboard, focus the field again → letters; the App Group log's `viewWillAppear_afterHandle` line reads `mode=keys`.

## How to get to it (user POV)

1. In the Dictus keyboard, tap 😀 next to 123.
2. Pick an emoji, or tap a category in the bar, or the magnifier to search; tap ABC to return to the letters.

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/drive.sh full-access && .claude/skills/verify-dictus-ios/scripts/drive.sh select-keyboard
.claude/skills/verify-dictus-ios/scripts/drive.sh kbd emoji
.claude/skills/verify-dictus-ios/scripts/evidence.sh emoji
.claude/skills/verify-dictus-ios/scripts/drive.sh kbd abc
```

## Gotchas

- Emoji cells are inside the keyboard: coordinates only. Recents persist in the App Group across runs on the same device, never across devices (each run's device is new).
- From the top-left of `inputView`, the panel starts at its top (no toolbar in emoji mode): the magnifier at about (+26, +20) pt; ABC at (+26, height − 95), the categories from x +66 every 30 pt on an iPhone 17 (clock, then the nine), delete at (width − 27, height − 95). The emoji key is at (width × 75/402, height − 102). `inputView` is 326 pt tall on an iPhone 17 and 351 pt on a 17 Pro Max, the same in letters and emoji mode. Measured 2026-11-23 (#1027).
- `axe` taps reach the keyboard, its drags do not (swipe, finer samples, a held swipe and contact-token moves all tried, 2026-11-22): the grid cannot be scrolled from outside and the bar cannot be scrubbed. Debug builds scroll every open panel through the whole grid on `xcrun simctl spawn <udid> notifyutil -p dictus.debug.emojiScrollAll` (`EmojiPanelDebug.swift`), and log `EMOJI_DEBUG panel created/freed` (a leaked panel would show as more than one live panel). A slide onto a skin tone needs a drag too: lift in place and tap the tone instead.
- A touch on a clear pixel never reaches a keyboard extension, so the panel's background is an invisible fill (0.1% black, `UIColor.keyboardTouchFill`, Hex pull 2547). Without it ABC's band outside its key and the magnifier's chip corners and margin took no tap (#503: 0 of 5 and 5 of 13 single taps took; with it 16 of 16 and 13 of 13, iPhone 17, iOS 26.5). To re-measure: tap a point, screenshot, and check the grid is gone (ABC → letters, magnifier → search); the panel does not appear in the accessibility tree.
- Memory is a device figure (Physical test shortlist). On the simulator (iPhone 17, iOS 26.5, #1027) the extension went 31 MB at rest, 38 MB open, 42 MB after scrolling every emoji, 34 MB once closed (three-row grid; the four-row grid opens at 39–40 MB); the old picker reached 110 MB and kept 104 MB after closing.
