# Dictation inside the app

- **ID:** `dictation.in-app`
- **Tier:** Gratuit (Free)
- **Targets:** DictusApp
- **Screens:** `app.home`, `app.recording` (not captured) — see [screens.md](screens.md)

## Sub-features

- `dictation.start-in-app`: The round mic at the bottom of Home (VoiceOver « Nouvelle dictée », #788) opens a full-screen recording.
- `dictation.copy-last`: The last transcription card copies its text on tap.
- `dictation.download-prompt`: Without a model, Home asks to download one instead of offering a dictation.
- `dictation.from-widget`: A dictation started from the widget opens the same in-app recording.

## How to get to it (user POV)

1. Open Dictus, tab Accueil.
2. Tap the round mic above « Balayez pour l'historique », speak, tap the stop button.
3. Tap the "Last transcription" card to copy the text.

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/launch.sh --skip-onboarding
.claude/skills/verify-dictus-ios/scripts/drive.sh tab Accueil
argent run describe --udid <udid>      # without a model: « Télécharger un modèle pour commencer »
```

With a model installed (see `models.transcription`), `.claude/skills/verify-dictus-ios/scripts/drive.sh tap-id home.newDictation` (or `tap-label "Nouvelle dictée"`) opens the recording screen and `.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Arrêter l'enregistrement"` stops it — only when the task accepts recording the Mac's microphone.

## Gotchas

- **Not drivable in the simulator without recording the room:** the dictation itself. Leave it to a physical iPhone unless the task explicitly accepts a Mac-microphone capture.
- `app.home` captured here is the no-model state; the mic does not exist until a model is downloaded. With a model, the mic and the history hint stay pinned at the bottom and the cards above them scroll when they do not fit (short screen, the iPhone layout an iPad runs in, large Dynamic Type); while they scroll, a swipe up that starts on the cards scrolls them instead of opening the history.
