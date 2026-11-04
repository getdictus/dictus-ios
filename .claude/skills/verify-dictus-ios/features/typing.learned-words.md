# Learned words

- **ID:** `typing.learned-words`
- **Tier:** Gratuit (Free)
- **Targets:** DictusKeyboard + DictusCore + DictusApp
- **Screens:** `app.settings` — see [screens.md](screens.md)

## Sub-features

- `learned-words.learn`: A word kept where the user refused a correction (one refusal is enough, #872), or an unknown word typed twice, is learned and no longer corrected.
- `learned-words.reset`: « Reset learned words » in Réglages → Clavier.

## How to get to it (user POV)

1. Refuse an autocorrection once (erase it and retype, Undo then move on, or tap the quoted typed word): the word you commit at that place is learned. After Undo, the word learned is the one you finally commit there, not the restored typo.
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
