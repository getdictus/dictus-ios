# Dictation inside the app

- **ID:** `dictation.in-app`
- **Tier:** Gratuit (Free)
- **Targets:** DictusApp
- **Screens:** `app.home`, `app.recording` (not captured) — see [screens.md](screens.md)

## Sub-features

- `dictation.start-in-app`: « Nouvelle dictée » on Home opens a full-screen recording.
- `dictation.copy-last`: The last transcription card copies its text on tap.
- `dictation.download-prompt`: Without a model, Home asks to download one instead of offering a dictation.
- `dictation.from-widget`: A dictation started from the widget opens the same in-app recording.

## How to get to it (user POV)

1. Open Dictus, tab Accueil.
2. Tap « Nouvelle dictée », speak, tap the stop button.
3. Tap the "Last transcription" card to copy the text.

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/launch.sh --skip-onboarding
.claude/skills/verify-dictus-ios/scripts/drive.sh tab Accueil
argent run describe --udid <udid>      # without a model: « Télécharger un modèle pour commencer »
```

With a model installed (see `models.transcription`), `.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Nouvelle dictée"` opens the recording screen and `.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Arrêter l'enregistrement"` stops it — only when the task accepts recording the Mac's microphone.

## Gotchas

- **Not drivable in the simulator without recording the room:** the dictation itself. Leave it to a physical iPhone unless the task explicitly accepts a Mac-microphone capture.
- `app.home` captured here is the no-model state; the button does not exist until a model is downloaded.
