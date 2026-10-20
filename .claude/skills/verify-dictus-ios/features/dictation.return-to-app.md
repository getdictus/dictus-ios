# Return to the app you were typing in

- **ID:** `dictation.return-to-app`
- **Tier:** Gratuit (Free)
- **Targets:** DictusApp + DictusKeyboard
- **Screens:** none of its own (overlay over `app.home`, not captured) — see [screens.md](screens.md)

## Sub-features

- `return.swipe-back`: After a cold start from the keyboard, an overlay tells the user to swipe back to the app they were typing in.
- `return.auto-return`: Where the host app is recognised, Dictus returns to it by itself after the dictation.

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
