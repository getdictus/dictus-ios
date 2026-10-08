# Onboarding intro scenes

These are the three looping videos of the onboarding's intro carousel (issue #667, decision 15 of
#649). They replace the static Welcome screen. Each video plays in place, muted and looping, until
the user swipes or taps **Commencer**.

The three scenes tell one story: **the voice goes into the phone and comes out as text.** The
headline and subtitle are SwiftUI text under the video, localized. The text inside the art is
short everyday English, hand-lettered in the marker line, which reads naturally under every
locale's headline.

| File | Scene (headline) | What it shows | Loop |
|---|---|---|---|
| `intro-a-{light,dark}.mp4` | A, walking ("Parlez. Dictus écrit.") | She walks, a tote held by its handles in one hand. With the other she holds her phone out in front of her, between chin and collarbone, seen from the back. Her voice crosses the gap to the phone as small blue bars of the Dictus waveform. A dotted trail leads from the phone to a chat thread: under a grey "Where are you?", her blue reply writes itself and grows a line at a time: "On my way, I'll be there in ten minutes. Can you order me a coffee?" | 5.5 s |
| `intro-b-{light,dark}.mp4` | B, the metro ("Même sans réseau.") | The same woman stands in a rocking metro carriage, one hand on the vertical pole at shoulder height. Tunnel lights streak past the window and sweep over her, the grab handles swing, and a badge in the top-right corner says no network (signal bars struck through in red). Her voice still goes into the phone, and a mail draft writes itself: "Notes from today", then "Great meeting this morning. Next steps for the launch below." | 5.5 s |
| `intro-c-{light,dark}.mp4` | C, the keyboard ("Dans votre clavier.") | The drawn iPhone shows a note above the Dictus keyboard (QWERTY keys) through one whole dictation: "Hi" is typed (touch indicators on h, then i), the blue mic is tapped, the recording overlay runs (waveform on the voice, timer, ✕ and ✓), ✓ is tapped, transcribing runs (the sweep), and the paragraph lands: "Sam, quick reminder: dinner at eight tonight. I'll bring dessert, can you pick up the bread?" Then the note clears. | 6.5 s |

Format of every video:
- 1000 × 1440 px (the 330 × 476 pt art area at 3×), 30 fps;
- HEVC Main 10, 4:2:0, BT.709, tagged `hvc1`;
- no audio track, one keyframe per loop.

The light page is `#F2F2F7` and the dark page `#0A1628`, exact to the code value in the decoded corners of every frame, so the video's edge does not show against the screen behind it.

## Re-rendering

```sh
node assets/onboarding/intro/render.mjs                 # all six
node assets/onboarding/intro/render.mjs --only b-dark   # some of them, comma-separated
node assets/onboarding/intro/render.mjs --frames 0,90   # a few frames as PNG, into .build/frames/, no video
```

No manual step is needed. The script:
1. scaffolds the anidoodle engine into `.build/` (git ignores it);
2. installs its npm dependencies the first time;
3. copies `src/` next to the engine's core;
4. draws every frame in headless Chromium through the engine's Playwright adapter, in a single page and in order;
5. encodes each video with ffmpeg, then prints its size, its ffprobe line and a hash of its frames.

To render from a clean state, delete `.build/` first.

### What it depends on

The script reads nothing outside this folder except the following:

- **The anidoodle engine**, installed at `~/.claude/skills/anidoodle` (https://github.com/alexgreensh/anidoodle). Set `ANIDOODLE=/path/to/anidoodle` to use another copy.
  - The art imports the engine's `core`, `film` and `gallery` modules.
  - The script uses its `scaffold`, `detect` and `build-page` tools and its Playwright adapter.
  - The committed videos were rendered with engine revision `9a1a762`. The script prints the revision it is using and warns when it differs, because a newer engine may move pixels.
- **Node.js 20 or later**, plus network access on the first run for `npm install` (esbuild, playwright-core, typescript). The engine's optional Remotion packages are skipped.
- **A Chromium for Playwright.** If none is cached, the script runs `npx playwright-core install chromium`. Rendering is headless: no window opens.
- **ffmpeg built with libx265**, and ffprobe. Set `FFMPEG` and `FFPROBE` to use binaries that are not on the PATH.

### Determinism

A frame is a pure function of its number and appearance: no clock, no `Math.random`, no assets. Two renders on the same machine and engine give byte-identical frames and byte-identical videos. The frame one loop after frame 0 renders to the same PNG as frame 0, so every loop closes exactly. Another Chromium build may antialias some pixels differently.

## Sources

- `src/theme.ts`: the frame, the three loops, and the two appearances.
- `src/woman.ts`: the woman, posed by scenes A and B. She keeps the App Store hero V15-B's face, top, colours and line (`assets/appstore/art/v15-B/heroWalk15.ts`, untouched); the hair, the hands and the trousers' seat are redrawn (see Decisions). The file contains:
  - the walk rig: a leg is its hip, its foot and two bones, and the knee is solved;
  - the trousers' seat, one fixed shape on the torso over the legs' tops;
  - the jaw-length bob;
  - the hand on the tote's handles, the hand holding the phone, the hand on the metro pole;
  - her voice as waveform bars.
- `src/handLettering.ts`: the hand-lettered alphabet, punctuation and timer digits, and how text is written letter by letter.
- `src/noteCard.ts`: where the text comes out: a chat thread in A, a mail draft in B.
- `src/edges.ts`: the clean band round every frame.
- `src/introWalk.ts`: scene A, with the pavement sliding back one slab joint per step.
- `src/introMetro.ts`: scene B, with:
  - the carriage: wall, bench, tunnel window, high rail and its grab handles, pole;
  - the lights streaking past and sweeping through;
  - the rocking;
  - the no-network badge.
- `src/introKeyboard.ts`: scene C, driven by one cue table (taps, mic, check, landing, clearing) checked against the 5-frame grid when the module loads.
- `src/phoneGeometry.ts`: the App Store hero V10-A's phone in perspective (from `heroSpeak10.ts`, branch `chore/643-hero-a`).

The App Store art files are untouched: these sources are adapted copies. The changes to the character (hair, phone held out, hands) were accepted by Pierre; the App Store screenshots will be redone from them later.

## Decisions

### Light page `#F2F2F7`, not the issue's `#FFFFFF`

The #649 mock-ups' page measures `#F2F2F7` (the onboarding's grouped background). A white video shows as a white box on it.

- In 8-bit video no colour code decodes back to `#F2F2F7` exactly; the nearest gives `#F2F2F6`. The videos are therefore 10-bit (HEVC Main 10, decoded in hardware by every iPhone that runs iOS 17), for about 4 % more bytes.
- After a scene is drawn, a band round the frame is cleared (`edges.ts`).
- x265's sample adaptive offset is off.
- C is encoded at CRF 24 instead of 26, since its large flat page otherwise rounded one corner one code value off.

The decoded corners were checked on every frame of all six videos.

### Framing

The art of the #649 mock-ups (local to the maintainer) is the App Store renders cropped to the drawing.

- A and B use A's scale. Each starts a little lower than the mock-up's crop, so her head clears the top edge.
- C places the phone where its mock-up does: 300 pt wide, at (15, 83) pt.
- In B, her head, the badge and the mail draft stay out of the frame's bottom tenth, which mock-up 01b's three-line subtitle crowds.

### Her phone is seen from the back, the text comes out beside it

People talk into the back of a phone they hold out, not into a screen they show. The writing therefore appears beside the phone, in shapes that evoke the apps people write in: a chat thread in A, a mail draft in B. They are generic: no second phone, no logo, no colours but Dictus's.

A dotted trail leads from the phone to the card. The card fades before the seam.

### The character

- **Hair:** a jaw-length bob with a swept fringe, chosen over a ponytail and long loose hair. It replaces V15-B's roll on top and stiff ponytail.
- **Phone hand:** four fingers side by side across the phone's back, curling onto its far edge, with one knuckle line each. The thumb is on the screen side, out of sight. Only a sliver of palm shows at the bottom of the near edge.
- **Bag hand:** she holds the tote by its handles, the fingers curled together under a row of knuckles, the thumb along the index, the handles taut. One hand is busy, which is why she dictates.
- **Trousers:** the seat is one fixed shape on the torso, flat at the front and gently rounded at the back, with the legs drawn under it.
  - Under the buttock it eases into the back of the near thigh, so no corner shows when the leg swings back.
  - The seat takes the legs' own tone and shading.
  - The walk rises over the supporting leg at the passing position, so no frame shows both knees bent.
- **Voice:** small rounded bars of the Dictus waveform, straight from her lips to the phone, swelling with her speech. This ties A and B to the keyboard of scene C.

### Scene B

The carriage rocks and she sways with it, her hair swinging. Bands of the tunnel's light sweep through the carriage and over her. They are screen-blended, so they brighten what they cross.

- **Her hand on the pole:** at shoulder height, the upper arm down along her side, a rounded elbow, the forearm rising to the pole, the wrist straight, the knuckles on the near side of the pole.
- **Rail and handles:** the rail runs above the frame, and the handles' loops hang above her head, so she reads as a woman of normal height.
- **Pole:** a plain round tube with two parallel contours, so it has no pointed ends.
- **No-network badge:** it sits in the frame's top-right corner, about 48 pt on the device, on its own disc so it reads in both appearances. The signal bars are struck through in the recording red `#EF4444`. It swells a little twice a loop.
- **No neighbour:** the optional noise of the brief is left out, because at this size a second figure takes the eye from her phone.

### Scene C

- **No hand:** two drawn hands were rejected. Each tap is a touch indicator: an accent disc spreading into a fading ring, with the key's own flash.
- **The states follow the real keyboard** (`KeyboardWaveformView.resolvedAnimation(for:)`, `RecordingOverlay`):
  - recording draws the bars on a voice, with the ✕ and ✓ pills, the timer and "Listening...";
  - transcribing draws the code's sine sweep, a bright band on its crest, with "Transcribing..." and no pills.
- **Suggestions:** the bar suggests "Hi", "Hey" and "Hello" after the typed word.

### Dark appearance

The art's ink is `#0A1628`, which is the dark page's colour. In dark, the contours turn to `#9FB0D0`, while the marks on skin and cloth stay navy. The ground, the carriage and the phones have dark tones of their own. Scene C's screen and keyboard follow the system's dark appearance.

### No HEVC with alpha

On this machine, only VideoToolbox (`hevc_videotoolbox`, `-alpha_quality`) writes it. Measured on the first version of scene A light:

| Encode | Luma PSNR | Size |
|---|---|---|
| Opaque VideoToolbox, `-q:v 40` | 38.8 dB | 510 KB |
| Opaque VideoToolbox, `-q:v 55` | 43.6 dB | 1.11 MB |
| Alpha VideoToolbox, `-q:v 40` (`-alpha_quality 0.6`) | | 1.21 MB |
| Alpha VideoToolbox, `-q:v 55` | | 1.93 MB |
| Opaque x265, CRF 26 (used) | 43.3 dB | about 0.9 MB |

At equal quality, alpha costs about twice the bytes. The videos are opaque, and each one carries its appearance's page colour.

Wiring the videos into the onboarding is #649's PR B, not this folder.
