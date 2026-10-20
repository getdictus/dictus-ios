# History of transcriptions

- **ID:** `history`
- **Tier:** Pro
- **Targets:** DictusApp + DictusCore
- **Screens:** `app.history`, `app.pro.history`, `app.history.detail` (not captured) — see [screens.md](screens.md)

## Sub-features

- List of the last 200 dictations, stored on the phone only; search « Rechercher dans les transcriptions ».
- Swipe or context menu to delete; tap for detail with Copy, Share, add a word to the vocabulary.
- « Effacer l'historique » in Réglages → Transcription; on/off switch in Pro hub → Historique.
- Home entry: a « Historique » button (swipe up) when entitled; locked or hidden otherwise.
- Files: `DictusApp/Views/HistoryView.swift`, `TranscriptionDetailView.swift`, `DictusCore/Sources/DictusCore/History/`.

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
