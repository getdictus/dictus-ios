# Custom vocabulary

- **ID:** `vocabulary`
- **Tier:** Pro
- **Targets:** DictusApp + DictusCore
- **Screens:** `app.pro.vocabulary`, `app.onboarding.vocabulary-scene` — see [screens.md](screens.md)

## Sub-features

- `vocabulary.add`: « Ajouter un terme »: the correct spelling and, optionally, how Dictus mishears it. A term saved alone lists as « En attente d’erreurs à corriger » and replaces nothing (#819).
- `vocabulary.edit`: Edit a term.
- `vocabulary.delete`: Delete a term.
- `vocabulary.reset`: « Réinitialiser le vocabulaire ».
- `vocabulary.suggestions`: « Suggestions depuis l'historique »: words the user corrected, offered, never imposed.
- `vocabulary.apply`: Terms are applied to every transcription.
- `vocabulary.toggle`: « Vocabulaire » on/off switch.

## How to get to it (user POV)

1. With Pro, Dictus → Réglages → Dictus Pro → Vocabulaire.
2. Tap « Ajouter un terme », type the word and, if known, how it comes out wrong, save.

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/launch.sh --skip-onboarding
.claude/skills/verify-dictus-ios/scripts/drive.sh set-default dictus.debugProEntitlementForced -bool YES
.claude/skills/verify-dictus-ios/scripts/drive.sh tab Réglages
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Dictus Pro, Pro actif"
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Vocabulaire, Apprenez à Dictus vos termes techniques, Activé"
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Ajouter un terme"
.claude/skills/verify-dictus-ios/scripts/evidence.sh vocabulary-term-editor
```

Type into the focused field with `axe type 'Dr Nguyen' --udid <udid>`.

## Gotchas

- **Not drivable in the simulator:** whether a term actually fixes a transcription (needs a recording). FluidAudio's vocabulary boosting is English-only; the French correction path is the post-pass.
- Suggestions stay empty without history.
