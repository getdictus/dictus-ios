# #1066 captures: the keyboard obeys the spatial autocorrect and delete-swipe switches

Simulator proof for PR #1066 (`fix/experiments-wired`).

## How they were taken

- 2026-11-25, Xcode 27.2, Debug builds, simulator « iPhone 17 » on the iOS 26.5 runtime, slimmed with simslim, French device. Each build ran on its own simulator, created for the run and deleted after it.
- Driven with AXe 2.1.1 (the signed release binary, used from a scratch folder and deleted afterwards). Full Access granted through Réglages → Apps → Dictus → Claviers; Dictus keyboard selected in Safari.
- Screenshots are resized to 874 px high. Keyboard lines come from the App Group's `dictus_debug.log`; times are UTC.
- The backspace slide is the same everywhere: press backspace at (371, 720), slide to (250, 720) in 0.8 s, lift, in Safari's address field. The finger lifts over the `b` key.

## Spatial autocorrect (head `faace78f`)

Réglages → Clavier → Expériences → « Correction spatiale ». The proof is the log line each keyboard appearance writes, in `keyboard-log.txt`.

| File | Shows | Keyboard log at that appearance |
| --- | --- | --- |
| `01-spatial-off-switch.png` | The switch off (its default) | — |
| `02-spatial-off-keyboard.png` | The keyboard shown in Safari right after | `spatialAutocorrectConfigured on=false channel=debug` (13:52:46) |
| `03-spatial-on-switch.png` | The switch turned on in the app | — |
| `04-spatial-on-keyboard.png` | The keyboard shown in Safari right after | `spatialAutocorrectConfigured on=true channel=debug` (13:52:58) |

## Delete swipe

Réglages → Clavier → « Effacer en glissant ».

### Head `faace78f`, setting on (default)

| File | Shows |
| --- | --- |
| `05-delete-on-setting.png` | The setting on |
| `06-delete-on-before.png` | Field before: `un un deux trois quatre ` (an earlier aborted attempt in that run had left `un `) |
| `07-delete-on-after.png` | Field after: `un un `; log `deleteSwipeEnded words=3 frozen=false` |
| `08-delete-off-setting.png` | The setting switched off (the page is the same on `5f2a9786`) |

### Why the slide typed a `b` with the setting off on `faace78f`, and the fix

On `faace78f` with the setting off, the same slide gave `un un deux trois quatre ` → `un un deux trois quatreb`. Those two captures are replaced below. The same gesture on three builds:

| Build | Field before → after | Keyboard log after the press | Files |
| --- | --- | --- | --- |
| `d727fd82`: develop just before #1047 was merged | `un deux trois quatre ` → `un deux trois quatreb` | nothing | `13-pre1047-before.png`, `14-pre1047-after.png` |
| `2746316d`: develop today, delete swipe always on | `un deux trois quatre ` → `un ` | `deleteSwipeEnded words=3 frozen=false` | `15-develop-before.png`, `16-develop-after.png` |
| `5f2a9786`: the fixed PR head, setting **off** | `un deux trois quatre ` → `un deux trois qu` | `keyRepeatStarted`, `keyRepeatStopped ticks=4 reason=touch` | `09-delete-off-before.png`, `10-delete-off-after.png` |
| `5f2a9786`: the fixed PR head, setting **on** | `un deux trois quatre ` → `un ` | `deleteSwipeEnded words=3 frozen=false` | `11-delete-on-new-head-before.png`, `12-delete-on-new-head-after.png` |

- **Cause.** This was a defect already present before #1047, in the vendored keyboard: a touch that moves retargets the active key to the key under the finger, and the lift types that key. A slide that begins on backspace and ends over `b` therefore types `b`. #1047 avoided it by keeping the backspace finger on backspace for the whole touch. `faace78f` released that finger when the setting was off, which brought the old behaviour back.
- **Not a simulator artefact.** On `2746316d` the identical AXe gesture types nothing, and its log shows the slide receiving the moves. A second touch landing on `b` would have typed `b` there too.
- **Fix (`5f2a9786`).** The view keeps the backspace finger whatever the setting. With the setting off, no slide starts, so the moves delete nothing and the repeat keeps running. The result is a plain held backspace: one character on touch-down (the space), then four repeat ticks during the 0.8 s hold (`atre`), and nothing typed on lift.

## The text files

- `keyboard-log.txt`: every `spatialAutocorrectConfigured` and `deleteSwipeEnded` line the keyboard wrote during the `faace78f` sequence (captures 01–08), in order.
- `steps.txt`: that sequence's transcript, with each switch's state read from the accessibility tree (last column: `0` off, `1` on), the field before and after each slide, and the log lines. Its last block, setting off, is the `faace78f` behaviour that `5f2a9786` fixes.
- `backspace-slide.txt`: the four runs in the table above, each with its commit, simulator, field before and after, and the keyboard log after the press.
