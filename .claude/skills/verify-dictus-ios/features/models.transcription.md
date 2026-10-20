# Transcription models

- **ID:** `models.transcription`
- **Tier:** Gratuit (Free)
- **Targets:** DictusApp + DictusCore
- **Screens:** `app.models`, `app.models.languages`, `app.models.loading` (not captured) — see [screens.md](screens.md)

## Sub-features

- Catalogue in two sections, « Téléchargés » and « Disponibles »: WhisperKit Tiny, Base, Small, Small (quantifié), Medium, Turbo; Parakeet v3 (recommended), Nemotron 3.5.
- Tap a card to download, tap a downloaded card to select it; « Model options » menu: delete, delete partial download; retry after a failure.
- ⓘ « Langues prises en charge » opens the per-model language sheet.
- Full-screen preparation overlay while a model compiles for the Neural Engine.
- Device gating: Turbo needs ≥ 6 GB RAM; some models are refused on A12/A13.
- Files: `DictusApp/Views/ModelManagerView.swift`, `ModelCardView.swift`, `ModelLanguageDetailView.swift`, `ModelLoadingOverlay.swift`, `DictusCore/Sources/DictusCore/ModelInfo.swift`.

## How to get to it (user POV)

1. Open Dictus, tab Modèles.
2. Tap a model to download it; tap ⓘ to see its languages.

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/launch.sh --skip-onboarding
.claude/skills/verify-dictus-ios/scripts/drive.sh tab Modèles
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Langues prises en charge"     # first ⓘ on screen: Small
.claude/skills/verify-dictus-ios/scripts/evidence.sh models-languages
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label OK
```

Card labels are the whole card, e.g. `Parakeet v3, PK, Recommandé, Rapide et précis (NVIDIA), Précision, Vitesse, ~483 Mo`.

## Gotchas

- A download is real network traffic (217 MB to 1.5 GB). Do it only when the task needs a model.
- **Not drivable in the simulator:** the `>= 6 GB` Turbo gate and `insufficientMemory` (the simulator reports the Mac's RAM), compile times and Neural Engine behaviour (Mac silicon), the Core ML cache surviving an install.
- Identifier-based gating (A12/A13) does render on a device created with that device type (`docs/agents/simulator.md` §1).
