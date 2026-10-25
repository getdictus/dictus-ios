# Learned words

- **ID:** `typing.learned-words`
- **Tier:** Gratuit (Free)
- **Targets:** DictusKeyboard + DictusCore + DictusApp
- **Screens:** `app.settings` — see [screens.md](screens.md)

## Sub-features

- `learned-words.learn`: A rejected correction or a word typed repeatedly is learned and no longer corrected.
- `learned-words.reset`: « Reset learned words » in Réglages → Clavier.

## How to get to it (user POV)

1. Undo an autocorrection twice on the same word: Dictus stops correcting it.
2. To start over: Dictus → Réglages → « Reset learned words ».

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/launch.sh --skip-onboarding
.claude/skills/verify-dictus-ios/scripts/drive.sh tab Réglages
axe swipe --start-x 201 --start-y 700 --end-x 201 --end-y 450 --duration 0.4 --udid <udid>
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Réinitialiser les mots appris"   # asks for confirmation (« Oublier N mots appris »)
```

## Gotchas

- Learning needs typed words in a correcting host field, key by coordinate; slow but drivable.
- A longer swipe carries the row under the navigation bar, and drive.sh then refuses it as off screen.
