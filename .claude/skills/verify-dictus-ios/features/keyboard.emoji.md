# Emoji

- **ID:** `keyboard.emoji`
- **Tier:** Gratuit (Free)
- **Targets:** DictusKeyboard
- **Screens:** `kbd.emoji` — see [screens.md](screens.md)

## Sub-features

- `emoji.picker`: Emoji by category.
- `emoji.recents`: Recently used emoji.
- `emoji.search`: « Rechercher des Emoji », with French keywords.
- `emoji.back-to-letters`: ABC returns to the letters.
- `emoji.closed-on-reappearance` (#505): the picker does not survive the keyboard going away. Left open, then the keyboard dismissed (same app) or another app's field focused, the keyboard comes back on the letters, like Apple's. Check: open the picker, dismiss the keyboard, focus the field again → letters; the App Group log's `viewWillAppear_afterHandle` line reads `mode=keys`.

## How to get to it (user POV)

1. In the Dictus keyboard, tap 😀 next to 123.
2. Pick an emoji; tap ABC to return to the letters.

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/drive.sh full-access && .claude/skills/verify-dictus-ios/scripts/drive.sh select-keyboard
.claude/skills/verify-dictus-ios/scripts/drive.sh kbd emoji
.claude/skills/verify-dictus-ios/scripts/evidence.sh emoji
.claude/skills/verify-dictus-ios/scripts/drive.sh kbd abc
```

## Gotchas

- Emoji cells are inside the keyboard: coordinates only. Recents persist in the App Group across runs on the same device, never across devices (each run's device is new).
