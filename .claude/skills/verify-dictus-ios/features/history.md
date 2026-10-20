# History of transcriptions

- **ID:** `history`
- **Tier:** Pro
- **Targets:** DictusApp + DictusCore
- **Screens:** `app.history`, `app.pro.history`, `app.history.detail` (not captured) — see [screens.md](screens.md)

## Sub-features

- `history.list`: The last 200 dictations, kept on the phone only.
- `history.search`: « Rechercher dans les transcriptions ».
- `history.delete`: Delete one entry (swipe or context menu).
- `history.detail`: An entry's detail: copy, share, add a word to the vocabulary.
- `history.clear`: « Effacer l'historique » in Réglages → Transcription.
- `history.toggle`: « Historique » on/off switch.
- `history.home-entry`: « Historique » button on Home (swipe up).

## How to get to it (user POV)

1. With Pro, open Dictus → Accueil.
2. Tap « Historique » (or swipe up) to see past dictations; tap one for details.

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/launch.sh --skip-onboarding
.claude/skills/verify-dictus-ios/scripts/drive.sh set-default dictus.debugProEntitlementForced -bool YES
.claude/skills/verify-dictus-ios/scripts/drive.sh tab Accueil
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label Historique
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-label "Aucune transcription pour l’instant"
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label Fermer
```

## Gotchas

- **Not drivable in the simulator without a real dictation:** a non-empty list, the detail screen, search results. Entries come only from a transcription (model + recording). The empty state is what an agent can show.
- `Historique` also labels the Pro hub row and the switch on its page: use the Home tab first so the right one is on top.
