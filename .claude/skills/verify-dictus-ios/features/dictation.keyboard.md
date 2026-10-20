# Dictation from the keyboard

- **ID:** `dictation.keyboard`
- **Tier:** Gratuit (Free)
- **Targets:** DictusKeyboard + DictusApp + DictusCore
- **Screens:** `kbd.keys`, `kbd.recording` (not captured) — see [screens.md](screens.md)

## Sub-features

- `dictation.start`: Tap the mic in the keyboard toolbar to start a dictation.
- `dictation.stop`: Stop with ✓: the transcript is inserted at the cursor.
- `dictation.cancel`: Cancel with ✕: nothing is inserted.
- `dictation.status`: Recording overlay states: starting, listening, transcribing, processing.
- `dictation.undo-insert`: An undo chip after insertion removes the inserted text.
- `dictation.handoff`: The keyboard hands the recording to the app (warm through a notification, cold through the `dictus://dictate` URL after 500 ms), because the extension's memory limit keeps audio out of it.
- `dictation.requires-full-access`: Without Full Access the mic is disabled and the bar reads « Accès complet requis ».
- `dictation.device-gating`: Refused on devices too old to transcribe (A12/A13 iPhones: « Dictation unavailable on this device »).

## How to get to it (user POV)

1. Install Dictus, add the keyboard in Réglages → Général → Clavier → Claviers, turn on Accès complet.
2. In any text field, long-press the globe and choose Dictus.
3. Tap the blue mic pill at the top right of the keyboard, speak, tap ✓.

## Driving it with axe + Argent

This is the recipe the skill was proven on (no model installed, so the chain must end in the expected failure):

```bash
.claude/skills/verify-dictus-ios/scripts/drive.sh full-access
.claude/skills/verify-dictus-ios/scripts/drive.sh select-keyboard
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-log '<KBD> .*fullAccess=true' 15
xcrun simctl terminate <udid> com.pivi.dictus   # force the cold-start path
M=$(.claude/skills/verify-dictus-ios/scripts/drive.sh log-mark)
.claude/skills/verify-dictus-ios/scripts/drive.sh kbd mic
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-log '<KBD> keyboardMicTapped' 15 "$M"
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-log '<APP> coldStartURLReceived isColdStart=true' 20 "$M"
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-log '<APP> dictationFailed error=No model downloaded' 20 "$M"
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-log '<KBD> statusChanged from=requested to=failed' 15 "$M"
```

The mic is not in the accessibility tree: `kbd mic` taps `inputView`'s trailing edge, 28 pt below its top. The four log lines are the proof, in that order (except the last, which may be written before `dictationFailed`: two processes, two write queues). `scripts/simulator-smoke-test.sh` runs the same chain as a pass/fail test.

## Gotchas

- **Not drivable in the simulator:** an actual recording and transcript. A simulator records the Mac's microphone (the room), transcription timing is Mac silicon, and a model download is needed first. Do not start one unless the task asks.
- **Not drivable:** the warm hand-off as a deterministic test (it depends on iOS keeping the app alive), auto-return to the host app, the keyboard's memory ceiling and the declared-height constraint (#166). Physical iPhone only.
- The A12/A13 refusal renders on a device created as `iPhone-11` (identifier-based); anything gated on RAM never fires (the simulator reports the Mac's RAM).
- `simctl openurl dictus://dictate…` raises an « Ouvrir dans « Dictus » ? » alert that needs a tap.
- Granting Full Access kills DictusApp (`domain:tcc(11)`); Doctor then warns "DictusApp not running", which is expected.
