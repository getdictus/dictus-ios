# Emoji

- **ID:** `keyboard.emoji`
- **Tier:** Gratuit (Free)
- **Targets:** DictusKeyboard
- **Screens:** `kbd.emoji` — see [screens.md](screens.md)

## Sub-features

- Emoji picker with categories, recents, search (« Rechercher des Emoji », French keywords), ABC key back to letters.
- Files: `DictusKeyboard/Views/EmojiPickerView.swift`, `EmojiCategoryBar.swift`, `DictusKeyboard/Models/EmojiData.swift`.

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
