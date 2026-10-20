# Return to the app you were typing in

- **ID:** `dictation.return-to-app`
- **Tier:** Gratuit (Free)
- **Targets:** DictusApp + DictusKeyboard
- **Screens:** none of its own (overlay over `app.home`, not captured) — see [screens.md](screens.md)

## Sub-features

- After a cold start from the keyboard, DictusApp shows a « swipe back » overlay telling the user to go back to the host app.
- Auto-return to the host app after dictation where the host is detected (`docs/auto-return-catalogue.md`).
- Files: `DictusApp/Views/SwipeBackOverlayView.swift`, `DictusApp/DictusApp.swift` (`returnToHostApp`).

## How to get to it (user POV)

1. With Dictus closed, tap the mic in the Dictus keyboard.
2. Dictus opens; swipe back (or wait for auto-return) to the app you were typing in.

## Driving it with axe + Argent

The cold start is reachable: run the `dictation.keyboard` recipe and capture the screen after `kbd mic` (`evidence.sh after-mic`). Without a model the app answers with the failure before any overlay, so only the hand-off half is shown.

```bash
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-log '<APP> coldStartURLReceived isColdStart=true' 20 "$M"
```

## Gotchas

- **Not drivable in the simulator:** whether the return lands in the right host app, and the Spotlight/arbiter cases (#23). Device only; the simulator's host detection is not the phone's.
- The overlay needs a successful dictation start, i.e. a model.
