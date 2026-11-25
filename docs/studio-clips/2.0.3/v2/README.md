# Dictus 2.0.3 — keyboard clips, second batch (v2)

Two more silent simulator clips for the 2.0.3 video. Fictional text only; no contact, notification,
account or personal history on screen.

| File | Duration | Shows |
| --- | --- | --- |
| `02b-cursor-multiline.mov` | 7.75 s | A five-line note under the title "Weekend plan". Long press on the space bar (keys blank into a trackpad), the cursor climbs line by line from the end of "Water the plants" to "farme\|rs", then comes back down two lines and stops inside "wa\|lk" |
| `03b-emoji-keyboard.mov` | 7.75 s | Emoji key → panel opens on Frequently Used → swipe through Smileys & People → category bar: Animals & Nature, then Food & Drink → 🍓 inserted → back to Frequently Used → long press 👍 → skin-tone picker → medium 👍🏽 inserted |

Both clips: 1206 × 2622 px (native, portrait), H.264 (`avc1`), QuickTime `.mov`, no audio,
variable frame rate (the simulator recorder writes a frame only when the screen changes).

| File | sha256 |
| --- | --- |
| `02b-cursor-multiline.mov` | `486f7182801fa555a6c6725efb4b17749f4cf46a474c039791cffb9e489f6c33` |
| `03b-emoji-keyboard.mov` | `ed6f8ee40dfd123420fcea52206e57fb0004d597096fd15d487c5704f5eaf8d8` |

## Setup

- Build: Dictus 2.0.3, **Release** configuration for the simulator (no debug overlays), built from
  this branch at `6788798d`, whose code is `256a030d` (release/2.0.3, the build sent to Apple)
  plus only the `docs/studio-clips` commit. Both bundles' build-info plists read `6788798d`.
- Simulator: iPhone 17 Pro, iOS 27.2 (24B8117), the newest runtime installed, Xcode 27.2, light
  mode, portrait, slimmed with `simslim` (Reminders kept).
- Language: device and Dictus keyboard in English (US).
- Status bar: `simctl status_bar override --time 9:41 --batteryState charged --batteryLevel 100
  --cellularBars 4 --wifiBars 3`.
- Dictus enabled with Full Access through Settings › Apps › Dictus › Keyboards.

## How they were driven and edited

Gestures were driven with [AXe](https://github.com/cameroncooke/AXe) v2.0.4 (official signed release
binary, run from a scratch folder) and recorded with `xcrun simctl io <udid> recordVideo --codec h264`.
Trimming and splicing used AVFoundation passthrough export: nothing re-encoded, sped up or reordered.

- **02b** is one uncut take, trimmed only at both ends. The space-bar drag is a single `axe draw`
  stroke (one finger, down → hold → up/down moves with short pauses → lift) at about 20 pt of
  finger travel per line, which is the line height the Dictus trackpad uses for this field.
- **03b**: on this Mac AXe needs about 0.7 s per step, so the take ran 15 s. As in v1, the **static
  frames between two actions were removed**; each action plays whole at 1×, from just before the
  touch to just after the screen settles. The swipe's scroll (with its momentum) and the 👍 long
  press up to the open picker are never cut. The picker stays open after the long press, as on
  Apple's keyboard; the tone is then tapped.

## Not filmed as asked, and why

- **Notes**: the iOS Simulator ships no Notes app (not in the runtime, `simctl launch
  com.apple.mobilenotes` fails). The note is the *New Reminder* sheet of Reminders instead: title
  "Weekend plan" and the lines in its Notes field, in black body text. Calendar was tried too, but
  its *Add* button is disabled on the slimmed simulator.
- **Five lines instead of four**: "Water the plants" was added while I was working out why the
  cursor slipped one line down a moment after the downward move ended. The cause was my stroke:
  at 26 pt of finger travel per line it overshot the top of the text, so the way back down landed
  a line lower than the cursor showed. At 20 pt per line the take is clean. The four-line version
  was not reshot at 20 pt.
- **Emoji, purple avoided**: the swipe stops in the middle of Smileys & People, before 😈/👿; the
  Symbols category is never opened (no ♓). Grapes, eggplant, unicorn and butterfly pass by in the
  Animals and Food grids, never close up.
