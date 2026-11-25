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

## 02c — cursor moving freely (three speeds)

Redo of 02b after Pierre's feedback (too slow, the cursor looked like it only went up and
down). Same note, same sheet, same setup as above. The finger traces **one continuous loop**
on the space bar, and the cursor crosses lines and columns at the same time: diagonally and
in a curve, with no stop on any line.

| File | Clip | Gesture (touch → lift) | sha256 |
| --- | --- | --- | --- |
| `02c-cursor-free-fast.mov` | 3.06 s | 2.10 s | `7cdeaf00f67da1cbeacb347eef1c3a77a85a707244b0fc6769cd1f557ee5cecb` |
| `02c-cursor-free-medium.mov` | 3.47 s | 2.52 s | `1830b904a2ec2a3054349cfef668a0d47a8fa9d4174b99cbc5527b7f5a21f0d5` |
| `02c-cursor-free-slow.mov` | 3.95 s | 3.00 s | `ea50e3cc6097ec15dc659fee735b6ae83f93da969dee1d10605b7a97d18d7395` |

Same format as above: 1206 × 2622 px, H.264 (`avc1`), `.mov`, no audio, variable frame rate.
Each clip opens 0.35 s before the finger lands and closes 0.6 s after it lifts.

**What the cursor does** (identical path in all three takes, read frame by frame): from the end
of "Water the plants" it goes up and right to "Call grandma|", then "by |the river", then
"team|". Then it sweeps left along "Lunch with the team" ("te\|am", "the\| team", "w\|ith",
"Lunch\|"), goes down and left through "Su\|nday" and "Ca\|ll", and comes back down and right
along "Water the plants" ("Wa\|ter", "the", "p\|lants"). The finger lifts with the cursor in
**"pla\|nts"**, where it stays. The loop spans four lines (2 to 5) and runs from the start of
the lines to the middle of "Sunday: long walk by the river".

**How.** Build, simulator, language, status bar, Full Access and the Reminders sheet are as in
*Setup* above. This run used a new simulator built the same way, with the Release build of this
branch at `166b174b`: its code is still `256a030d`, and both bundles' build-info plists read
`166b174b`. The gesture is one `axe draw` stroke (AXe v2.0.4), one finger, about 145 to 215
points:

- **Hold.** `axe draw` spreads its duration along the path's length, so repeated points take
  no time. The hold is therefore a 2 pt vertical jitter on the space bar, well under the
  trackpad's 10 pt slop, whose length buys about 0.5 s. The keys blank 0.35 to 0.37 s after
  touch-down.
- **Loop.** An ellipse of 74 × 30 pt of finger travel (148 pt across, 60 pt up), which comes
  to about 3 lines once the trackpad's speed gain (about 1.15× at these speeds) is applied.
  The finger lands at 20° past the bottom of the ellipse, already heading up and right, and
  runs 345° of it, so it lifts just before closing the loop. From the end of the last line, a
  start at the bottom would first spend about 0.3 s pushing right along that line, with the
  cursor held at its end. A full 360° lifts with the cursor at the end of "plants", not inside
  it.
- **Speed.** AXe adds about 4 ms per point to the requested duration, so the requested
  durations (1.50 / 1.80 / 2.04 s) were set from the measured touch-to-lift time in the
  video, not taken from the command.

Trimmed with AVFoundation passthrough export, at the ends only: nothing cut inside the gesture,
nothing re-encoded or sped up.

**Not exactly as in 02b.** The suggestion bar above the keys shows "and / in / are" (Dictus's
predictions after "plants"), where 02b showed no suggestions. That is the keyboard's own state
once the caret was placed by a tap, and it stays the same through the clip. Between the keys
blanking and the first cursor move there are about 0.4 s: the end of the hold, and the cursor
climbing half a line before it leaves "plants".
