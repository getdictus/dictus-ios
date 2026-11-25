# #1018 — Adaptive touch on its Experiments switch: simulator proof

Build: Debug, PR #1018 head `3b20e02d` (`feature/adaptive-touch`), built for the simulator by
`verify-dictus-ios`'s `launch.sh` (ad-hoc signed, so the App Group container and
`dictus_debug.log` exist).
Simulator: iPhone 17, iOS 26.5, slimmed (simslim), French UI, status bar at 9:41, created for this
run (`Dictus Verify 20261125-200212-3b20e02d`) and deleted after it. Driven with AXe v2.2.0 (the
official notarized release binary), Xcode 27.2. Onboarding skipped, no model downloaded. The
distribution the app recorded is `debug`, so the Experiments switches act (as on TestFlight).

Full Access was granted in Réglages → Apps → Dictus → Claviers. The skill's `full-access` recipe
goes through Réglages → Général → Clavier, which did not reach the keyboard list here. The keyboard
was shown in Safari's address bar (long press on the globe, then Dictus). Switches were flipped on
the Experiments page, or written to the App Group with `drive.sh set-default` (which relaunches the
app). Every keyboard appearance logs the effective values (`newView`, then `viewWillAppear`).

| File | What it shows |
|---|---|
| `00-experiments-adaptive-off.png` | Réglages → Clavier → Expériences: « Correction spatiale » on, « Toucher adaptatif » off, « Réinitialiser le toucher adaptatif » under it |
| `01-experiments-adaptive-on.png` | Step 1: the same page with both switches on, the Reset button visible |
| `02-reset-confirmation.png` | Step 2: Reset tapped, the confirmation « Réinitialiser le toucher adaptatif ? » and its destructive « Oublier ce qu'il a appris » (iOS 26 shows it as a popover; tapping outside cancels) |
| `03-keyboard-adaptive-off.png` | Step 3: spatial on, adaptive off, the Dictus keyboard in Safari. Log: `spatialAutocorrectConfigured on=true`, `adaptiveTouchConfigured on=false` |
| `04-keyboard-adaptive-on.png` | Step 4: spatial on, adaptive on, same keyboard. Log: `adaptiveTouchConfigured on=true` |
| `05-typed-adaptive-on.png` | Step 4, learning: « La maison est belle et grande » typed on the Dictus keys in a Rappels note (autocorrect runs there, unlike Safari's address bar). When the keyboard was dismissed, `AdaptiveTouch/adaptive-touch.bin` (23,588 bytes, the fixed size) appeared in the App Group (`keyboard-log.txt`) |
| `06-keyboard-spatial-off-adaptive-on.png` | Step 5: spatial off with adaptive still stored on (`dictus.keyboard.adaptiveTouch = true` in the group's plist). Log: `spatialAutocorrectConfigured on=false`, `adaptiveTouchConfigured on=false`: the effective rule |
| `07-experiments-spatial-off.png` | The page in that state: adaptive greyed, « Inactif : activez la correction spatiale pour que le toucher adaptatif fonctionne. » |
| `08-experiments-after-reset.png` | After « Oublier ce qu'il a appris »: `AdaptiveTouch/` is empty and `adaptiveTouch.resetAt` is stamped in the App Group |
| `keyboard-log.txt` | The App Group log's relevant lines, in order, with the file checks made from the host. No typed text is logged |

Images are resized to 874 px high, the rule for screenshots in this repository.

Not shown: a profile actually in use (Hex's gate wants 400 labelled taps over 3 sessions, and the
simulator's taps land on key centres, so it has no bias to learn: that is the bench's job, see the
PR), the App Store channel (a Debug build records `debug`; `swift test` covers it with
`testTheAppStoreChannelIgnoresAStoredTrue`), and anything on an iPhone.
