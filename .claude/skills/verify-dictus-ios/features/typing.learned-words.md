# Learned words

- **ID:** `typing.learned-words`
- **Tier:** Gratuit (Free)
- **Targets:** DictusKeyboard + DictusCore + DictusApp
- **Screens:** `app.settings` — see [screens.md](screens.md)

## Sub-features

- The keyboard learns a correction the user rejected and an unknown word typed repeatedly, and stops correcting it.
- « Reset learned words » in Réglages → Clavier clears them.
- Files: `DictusCore/Sources/DictusCore/UserDictionary.swift`, `DictusApp/Views/SettingsView.swift`.

## How to get to it (user POV)

1. Undo an autocorrection twice on the same word: Dictus stops correcting it.
2. To start over: Dictus → Réglages → « Reset learned words ».

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/launch.sh --skip-onboarding
.claude/skills/verify-dictus-ios/scripts/drive.sh tab Réglages
axe swipe --start-x 201 --start-y 700 --end-x 201 --end-y 200 --duration 0.4 --udid <udid>
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Reset learned words"
```

## Gotchas

- Learning needs typed words in a correcting host field, key by coordinate; slow but drivable.
- The row is English on a French device (missing translation).
