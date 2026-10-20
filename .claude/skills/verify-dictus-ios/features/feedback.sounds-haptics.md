# Sounds and haptics

- **ID:** `feedback.sounds-haptics`
- **Tier:** Gratuit (Free)
- **Targets:** DictusApp + DictusKeyboard
- **Screens:** `app.settings.sounds` — see [screens.md](screens.md)

## Sub-features

- `sounds.toggle`: « Activer les sons ».
- `sounds.volume`: Volume.
- `sounds.per-event`: A sound per event: Début, Fin, Annuler.
- `haptics.toggle`: « Retour haptique » on key presses.

## How to get to it (user POV)

1. Dictus → Réglages → Sons.
2. Turn sounds on, pick a sound for each event.

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/launch.sh --skip-onboarding
.claude/skills/verify-dictus-ios/scripts/drive.sh tab Réglages
axe swipe --start-x 201 --start-y 700 --end-x 201 --end-y 350 --duration 0.4 --udid <udid>
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label Sons
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Activer les sons"
```

## Gotchas

- **Not drivable in the simulator:** hearing a sound or feeling a haptic. Only the preference change can be shown.
