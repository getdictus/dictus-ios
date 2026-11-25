# #1066 captures: the keyboard obeys the spatial autocorrect and delete-swipe switches

Simulator proof for PR #1066 (`fix/experiments-wired`), taken on the PR head **`faace78f`**, without changing it.

## How they were taken

- 2026-11-25, Xcode 27.2, Debug build of `faace78f`, simulator « iPhone 17 » on the iOS 26.5 runtime, slimmed with simslim, French device. It was created for the run (`Dictus Verify 20261125-144601-faace78f`) and deleted after it.
- Driven with AXe 2.1.1 (the signed release binary, used from a scratch folder and deleted afterwards). Full Access granted through Réglages → Apps → Dictus → Claviers; Dictus keyboard selected in Safari.
- Screenshots are resized to 874 px high. The keyboard's lines come from the App Group's `dictus_debug.log`.

## What each file shows

**Spatial autocorrect** (Réglages → Clavier → Expériences → « Correction spatiale »). The proof is the log line each keyboard appearance writes, in `keyboard-log.txt`.

| File | Shows | Keyboard log at that appearance |
| --- | --- | --- |
| `01-spatial-off-switch.png` | The switch off (its default) | — |
| `02-spatial-off-keyboard.png` | The keyboard shown in Safari right after | `spatialAutocorrectConfigured on=false channel=debug` (13:52:46) |
| `03-spatial-on-switch.png` | The switch turned on in the app | — |
| `04-spatial-on-keyboard.png` | The keyboard shown in Safari right after | `spatialAutocorrectConfigured on=true channel=debug` (13:52:58) |

**Delete swipe** (Réglages → Clavier → « Effacer en glissant »). Same gesture both times: press backspace and slide 120 pt left in 0.8 s, in Safari's address field.

| File | Shows |
| --- | --- |
| `05-delete-on-setting.png` | The setting on (its default) |
| `06-delete-on-before.png` | Field before the slide: `un un deux trois quatre ` |
| `07-delete-on-after.png` | Field after: `un un `. Three words deleted; log `deleteSwipeEnded words=3 frozen=false` (13:54:12) |
| `08-delete-off-setting.png` | The setting switched off |
| `09-delete-off-before.png` | Field before the slide: `un un deux trois quatre ` |
| `10-delete-off-after.png` | Field after: `un un deux trois quatreb`. No slide and no `deleteSwipeEnded` line. Backspace acted as the plain key it was before #1047: the touch-down deleted one character (the space), and the finger, lifted over `b`, typed it |

The field starts with `un un` because an earlier attempt in the same run left `un ` in it. That attempt is not shown here: the script never reached the switches, so it proves nothing.

## The text files

- `keyboard-log.txt`: every `spatialAutocorrectConfigured` and `deleteSwipeEnded` line the keyboard wrote during the captured sequence, in order. The lines at 13:53:11 and 13:54:23 are the keyboard coming back for the two slides, with spatial autocorrect still on.
- `steps.txt`: the run's transcript: each switch's state read from the accessibility tree (last column, `0` off / `1` on), the field's value before and after each slide, and the log lines that followed each step.
