# Emoji

- **ID:** `keyboard.emoji`
- **Tier:** Gratuit (Free)
- **Targets:** DictusKeyboard (the panel itself is in DictusCore, `Sources/DictusCore/Emoji`, ported from Hex, #1027)
- **Screens:** `kbd.emoji` — see [screens.md](screens.md)

## Sub-features

- `emoji.picker`: every category in one grid that scrolls sideways (Récents, then Smileys, Personnes, … Drapeaux); the bar under it jumps to a category on a tap and scrubs through them on a slide. Holding an emoji shows it larger.
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
- On an iPhone 17 (402 pt), from the top-left of `inputView` the panel starts under the toolbar: the magnifier is at about (+26, +80) pt, ABC (+26, +256), the categories from (+66, +256) every 30 pt (clock, then the nine categories), delete (+375, +256). Measured 2026-11-22 (#1027); re-read a screenshot if the toolbar changes.
- `axe` taps reach the keyboard, its drags do not (swipe, finer samples, a held swipe and contact-token moves all tried, 2026-11-22): the grid cannot be scrolled from outside and the bar cannot be scrubbed. Debug builds scroll every open panel through the whole grid on `xcrun simctl spawn <udid> notifyutil -p dictus.debug.emojiScrollAll` (`EmojiPanelDebug.swift`), and log `EMOJI_DEBUG panel created/freed` (a leaked panel would show as more than one live panel). A slide onto a skin tone needs a drag too: lift in place and tap the tone instead.
- Memory is a device figure (Physical test shortlist). On the simulator (iPhone 17, iOS 26.5, #1027) the extension went 31 MB at rest, 38 MB open, 42 MB after scrolling every emoji, 34 MB once closed; the old picker reached 110 MB and kept 104 MB after closing.
