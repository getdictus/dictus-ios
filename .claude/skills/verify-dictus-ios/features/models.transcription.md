# Transcription models

- **ID:** `models.transcription`
- **Tier:** Gratuit (Free)
- **Targets:** DictusApp + DictusCore
- **Screens:** `app.models`, `app.models.languages`, `app.models.loading` — see [screens.md](screens.md)

## Sub-features

- `models.catalogue`: Downloaded and available models, each with size, precision and speed.
- `models.recommended`: One model is marked « Recommandé » for the device.
- `models.download`: Tap an available model to download it.
- `models.select`: Tap a downloaded model to make it the active one.
- `models.delete`: Delete a downloaded model (« Model options »).
- `models.retry`: Retry a failed download, or delete a partial one.
- `models.languages`: ⓘ shows the languages a model supports.
- `models.preparation`: A full-screen overlay while a model is prepared for on-device acceleration.
- `models.device-gating`: Models too heavy for the device are refused (memory, chip).

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

The smallest model that downloads and transcribes is **Small (quantifié)**, `openai_whisper-small_216MB`, ~217 Mo. Download it the way a user does (only when the task needs a model):

```bash
.claude/skills/verify-dictus-ios/scripts/drive.sh tab Modèles
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Small (quantifié)"    # the title; the whole-card label does not match
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-log '<APP> modelLoadStateChanged from=loading to=ready' 300
```

`app.models.loading` (« On prépare votre modèle ») covers the screen until the model is ready. Measured on 2026-10-20: `modelDownloadStarted size=217MB` → `modelDownloadCompleted` 14 s, `modelCompilationCompleted duration=7658ms`, ready 24 s after the tap.

## Gotchas

- A download is real network traffic (217 MB to 1.5 GB). Do it only when the task needs a model.
- **Not drivable in the simulator:** the `>= 6 GB` Turbo gate and `insufficientMemory` (the simulator reports the Mac's RAM), compile times and Neural Engine behaviour (Mac silicon), the Core ML cache surviving an install.
- Identifier-based gating (A12/A13) does render on a device created with that device type (`docs/agents/simulator.md` §1).
