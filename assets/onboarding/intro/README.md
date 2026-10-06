# Onboarding intro scenes

The three looping videos of the onboarding's intro carousel (issue #667, decision 15 of #649).
They replace the static Welcome screen. Each one plays in place, muted and looping, until the
user swipes or taps **Commencer**. The headline and subtitle are SwiftUI text under the video,
so there is no text in the art.

| File | Scene | Drawn from |
|---|---|---|
| `intro-a-{light,dark}.mp4` | A, walking: she walks, phone up at her chin, and talks; her voice leaves as the three blue strokes and turns into three waveform bars | `assets/appstore/art/v15-B/heroWalk15.ts` |
| `intro-b-{light,dark}.mp4` | B, dictating: seated, she speaks; the strokes flow out of her | `assets/appstore/art/v10-A/heroSpeak10.ts`, the woman (branch `chore/643-hero-a`) |
| `intro-c-{light,dark}.mp4` | C, keyboard: the drawn iPhone with the Dictus keyboard recording; its waveform reacts | `heroSpeak10.ts`, the phone |

Every video is 1000 × 1440 px (the 330 × 476 pt art area at 3×). Each one is a 4.5 s loop at
30 fps (135 frames), HEVC Main, 4:2:0, BT.709, tagged `hvc1`, with no audio track and one
keyframe per loop. The light page is `#FFFFFF` and the dark page `#0A1628`, exact to the code
value after decoding, so the video's edge does not show against the screen behind it.

## Re-rendering

```sh
node assets/onboarding/intro/render.mjs                 # all six
node assets/onboarding/intro/render.mjs --only b-dark   # some of them, comma-separated
node assets/onboarding/intro/render.mjs --frames 0,67   # a few frames as PNG, into .build/frames/, no video
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

- **The anidoodle engine**, installed at `~/.claude/skills/anidoodle` (https://github.com/alexgreensh/anidoodle). Set `ANIDOODLE=/path/to/anidoodle` to use another copy. The art imports the engine's `core`, `film` and `gallery` modules; the script uses its `scaffold`, `detect` and `build-page` tools and its Playwright adapter. The committed videos were rendered with engine revision `9a1a762`. The script prints the revision it is using and warns when it differs, because a newer engine may move pixels.
- **Node.js 20 or later**, plus network access on the first run for `npm install` (esbuild, playwright-core, typescript). The engine's optional Remotion packages are skipped.
- **A Chromium for Playwright.** If none is cached, the script runs `npx playwright-core install chromium`. Rendering is headless: no window opens.
- **ffmpeg built with libx265**, and ffprobe. Set `FFMPEG` and `FFPROBE` to use binaries that are not on the PATH.

### Determinism

A frame is a pure function of its number and appearance: no clock, no `Math.random`, no assets.
Two renders on the same machine and engine give byte-identical frames and byte-identical
videos. Frame 135 renders to the same pixels as frame 0, so every loop closes exactly. Another
Chromium build may antialias some pixels differently.

## Sources

- `src/theme.ts`: the frame, the loop, and the two appearances.
- `src/introWalk.ts`: scene A. V15-B's drawing with a walk rig. A leg is its hip, its foot and two bone lengths, and the knee is solved. Frame 0 is the App Store pose, the walk cycle's contact position. The pavement slides back one slab joint per step at the feet's speed.
- `src/introSpeak.ts`: scene B. V10-A's woman: the mouth talks, the head nods, the sound arcs are emitted, the ripple travels along the strokes, and the open hand gestures.
- `src/introKeyboard.ts`: scene C. V10-A's phone: the waveform follows a speech-like level and the phone hovers.
- `src/phoneGeometry.ts`: V10-A's phone in perspective, shared by B (which is placed and aimed by it) and C (which draws it).

The App Store art files are untouched: these sources are copies, adapted.

## Decisions

- **Framing.** The art of the #649 mock-ups (`designs/onboarding-649-png/01{A,B,C}-intro-*.png`, local to the maintainer) is the App Store renders cropped to the drawing. Each scene sits in the 330 × 476 pt frame where the mock-up puts it:
  - A fills the frame (strip x 0–1466, y 750–2861).
  - B is 289.5 pt wide at (20.5, 34) pt.
  - C is 300 pt wide at (15, 83) pt.
  
  For B and C the frame's top is inferred from the layout, because their two-line headline raises everything by about 55 pt.
- **Dark.** The art's ink is `#0A1628`, which is the dark page's colour. In dark, the contours turn to `#9FB0D0`, while the marks on skin and cloth (eyes, brows, mouth, pupils, lenses) stay navy. The pavement, the shadows and the drawn phone get dark tones of their own. The phone's screen shows the keyboard in the system's dark appearance, since the onboarding follows it.
- **No HEVC with alpha.** On this machine, only VideoToolbox (`hevc_videotoolbox`, `-alpha_quality`) writes it. Measured on scene A light:

  | Encode | Luma PSNR | Size |
  |---|---|---|
  | Opaque VideoToolbox, `-q:v 40` | 38.8 dB | 510 KB |
  | Opaque VideoToolbox, `-q:v 55` | 43.6 dB | 1.11 MB |
  | Alpha VideoToolbox, `-q:v 40` (`-alpha_quality 0.6`) | | 1.21 MB |
  | Alpha VideoToolbox, `-q:v 55` | | 1.93 MB |
  | Opaque x265, CRF 26 (used) | 43.3 dB | about 0.9 MB |

  At equal quality, alpha costs about twice the bytes and goes over the 1.5 MB budget. The videos are therefore opaque, and each one carries the page colour of its appearance.
- **Scene C has no entrance.** A loop that closes on itself cannot show the phone arriving without also showing it leave every 4.5 s, so the phone is there from frame 0 and hovers. If the screen wants an entrance, that is a SwiftUI transition on the video view (#649, PR B).
- **No lettering.** V15-B's "Thanks for the notes" along the strokes is gone.

Wiring the videos into the onboarding is #649's PR B, not this folder.
