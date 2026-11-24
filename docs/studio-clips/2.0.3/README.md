# Dictus 2.0.3 — keyboard clips for the X thread

Silent simulator clips of the keyboard features shipped in 2.0.2 and 2.0.3. Fictional text only;
no contact, notification, account or personal history on screen.

| File | Duration | Shows |
| --- | --- | --- |
| `01-keys.mov` | 5.76 s | Redesigned keys (Apple layout) in Reminders: "See you at 8 tonight", key previews, 123 layer, suggestions |
| `02-cursor.mov` | 5.20 s | Long press on the space bar (keys blank into a trackpad), cursor glides from the end to the start of "Dinner is at the new place downtown" |
| `03-emoji.mov` | 5.86 s | Emoji panel → search "pizza" → 🍕, then long press 👍 → skin-tone picker → medium-light 👍🏼 |
| `04-return-go.mov` | 5.37 s | Safari address bar: typing "example.com/menu", the return key is the blue *go* key (→) |
| `04-return-search-spotlight.mov` | 3.88 s | Spotlight: the *search* key (🔍) is grey while empty and turns blue on the first letter ("calendar") |
| `05-paste.mov` | 4.00 s | One tap on the Paste pill in the toolbar pastes "Meet at the north entrance at 7:30" (no "Allow Paste" banner) |
| `06-autocorrect-fr.mov` | 5.89 s | French: "il ma dit" + space → "Il m'a dit", "a la maison" + space → "à la maison" |

All clips: 1206 × 2622 px (native, portrait), H.264 (`avc1`), QuickTime `.mov`, no audio,
variable frame rate (the simulator recorder writes a frame only when the screen changes).

## Setup

- Build: Dictus 2.0.3 (45), commit `256a030d` (tag `build/45`), **Release** configuration for the
  simulator (no debug overlays). The build-info plist in both bundles was checked against the sha.
- Simulator: iPhone 17 Pro, iOS 26.5 (23F77), Xcode 27.2, light mode, slimmed with `simslim`
  (search, messaging and pim kept).
- Language: device and Dictus keyboard in English (US) for clips 1–5; device and Dictus keyboard in
  French for clip 6 (the status bar then reads 09:41).
- Status bar: `simctl status_bar override --time 9:41 --batteryState charged --batteryLevel 100
  --cellularBars 4 --wifiBars 3` (the *charged* state draws the bolt).
- Dictus enabled with Full Access through Settings › Apps › Dictus › Keyboards.
- Safari: search-engine suggestions, Safari suggestions, recent searches and preload top hit turned
  off, because live suggestions showed places near the recording Mac's location.

## How they were driven and edited

Gestures were driven with [AXe](https://github.com/cameroncooke/AXe) v2.0.4 (official signed release
binary, run from a scratch folder) and recorded with `xcrun simctl io <udid> recordVideo --codec h264`.

On this Mac AXe needs about 0.7 s per tap (each touch waits for the simulator's acknowledgement), which
is too slow for a natural typing pace. In the typing clips (01, 03, 04, 06) the **idle frames
between two taps were removed**: each keystroke and the ~0.2 s that follows it play at 1×, and the
static wait before the next keystroke is dropped. Nothing is sped up, reordered or re-rendered.
Gestures are never cut: the space-bar trackpad drag (02) and the 👍 long press (03) play whole.
Clips 02 and 05 are single uncut takes, only trimmed at both ends.

## Not filmed, and why

- **`04-return-search-safari`**: Safari's address bar always asks for the *go* key, even for plain
  words, so Dictus shows → there, never 🔍. Searching is shown in Spotlight instead.
- **`04-return-send`**: in an empty new iMessage the message field asks for a plain return key
  (↵), before and after typing; Messages sends with its own ↑ button. The *send* key does not
  appear there on the simulator. Skipped.
- Spotlight clip starts with Spotlight already open: on the slimmed simulator the Home Screen behind
  it has a black wallpaper and blank widgets, which would look broken in a swipe-down.
- The copy step of clip 05 happened off camera (the fictional text was put on the simulator
  clipboard before recording).
- A Settings search take was dropped: the slimmed simulator's Settings index returns "No Results".
