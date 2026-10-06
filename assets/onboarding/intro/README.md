# Onboarding intro scenes

The three looping videos of the onboarding's intro carousel (issue #667, decision 15 of #649).
They replace the static Welcome screen. Each one plays in place, muted and looping, until the
user swipes or taps **Commencer**. The three scenes tell one story: **the voice goes into the
phone and comes out as text.** The headline and subtitle are SwiftUI text under the video. The
art contains no readable words: every line of "text" is a marker scribble, so one render serves
every language.

| File | Scene (headline) | What it shows | Drawn from |
|---|---|---|---|
| `intro-a-{light,dark}.mp4` | A, walking ("Parlez. Dictus écrit.") | She walks and talks into her phone. The blue strokes leave her lips and go into it, and a scribbled line writes itself on its screen. 5.5 s. | `assets/appstore/art/v15-B/heroWalk15.ts` |
| `intro-b-{light,dark}.mp4` | B, the metro ("Même sans réseau.") | The same woman stands in a metro carriage, one hand on the pole, before a window where the tunnel's lights streak past. Her phone shows no network (struck-through bars), and the text still writes itself. 5.5 s. | Her: V15-B. The carriage: new, same style. |
| `intro-c-{light,dark}.mp4` | C, the keyboard ("Dans votre clavier.") | The drawn iPhone, a note above the Dictus keyboard, through one whole dictation: a few keys typed, the blue mic tapped, recording (waveform, timer, ✕ and ✓), ✓ tapped, transcribing (the sweep), the text lands, then the note clears. 9 s. | `assets/appstore/art/v10-A/heroSpeak10.ts`, the phone (branch `chore/643-hero-a`) |

Every video is 1000 × 1440 px (the 330 × 476 pt art area at 3×), 30 fps, HEVC Main, 4:2:0,
BT.709, tagged `hvc1`. There is no audio track and one keyframe per loop. The light page is
`#FFFFFF` and the dark page `#0A1628`, exact to the code value after decoding, so the video's
edge does not show against the screen behind it.

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

- **The anidoodle engine**, installed at `~/.claude/skills/anidoodle` (https://github.com/alexgreensh/anidoodle). Set `ANIDOODLE=/path/to/anidoodle` to use another copy. The art imports the engine's `core`, `film` and `gallery` modules; the script uses its `scaffold`, `detect` and `build-page` tools and its Playwright adapter. The committed videos were rendered with engine revision `9a1a762`. The script prints the revision it is using and warns when it differs, because a newer engine may move pixels.
- **Node.js 20 or later**, plus network access on the first run for `npm install` (esbuild, playwright-core, typescript). The engine's optional Remotion packages are skipped.
- **A Chromium for Playwright.** If none is cached, the script runs `npx playwright-core install chromium`. Rendering is headless: no window opens.
- **ffmpeg built with libx265**, and ffprobe. Set `FFMPEG` and `FFPROBE` to use binaries that are not on the PATH.

### Determinism

A frame is a pure function of its number and appearance: no clock, no `Math.random`, no assets.
Two renders on the same machine and engine give byte-identical frames and byte-identical
videos. The frame one loop after frame 0 renders to the same PNG as frame 0, so every loop closes exactly. Another
Chromium build may antialias some pixels differently.

## Sources

- `src/theme.ts`: the frame, the three loops, and the two appearances.
- `src/woman.ts`: her, posed by the scenes (V15-B's lines and colours), with:
  - the walk rig: a leg is its hip, its foot and two bones, and the knee is solved. The walk's contact position is V15-B's pose;
  - the phone in her hand, now facing us;
  - her voice going into the phone;
  - the scribbled text that writes on its screen.
- `src/scribble.ts`: handwriting that spells nothing, the timer's digits, and the no-network icon.
- `src/introWalk.ts`: scene A, the pavement sliding back one slab joint per step.
- `src/introMetro.ts`: scene B. The carriage (wall, bench, tunnel window, rail, pole), the lights streaking past, the carriage rocking and her swaying with it.
- `src/introKeyboard.ts`: scene C, driven by one cue table (taps, mic, check, landing, clearing) that is checked against the 5-frame grid when the module loads.
- `src/phoneGeometry.ts`: V10-A's phone in perspective.

The App Store art files are untouched: these sources are copies, adapted.

## Decisions

- **Framing.** The art of the #649 mock-ups (`designs/onboarding-649-png/01{A,B,C}-intro-*.png`, local to the maintainer) is the App Store renders cropped to the drawing.
  - A fills the 330 × 476 pt frame (strip x 0–1466, y 750–2861).
  - B uses the same frame and the same placement as A, so she stands where she walked and the carousel does not jump.
  - C places the phone where its mock-up does: 300 pt wide, at (15, 83) pt.
- **Her phone faces us** in A and B. V15-B showed its back, which kept the screen out of sight. Her hand is the same pieces, laid behind the phone: the fingertips show past its left edge and the thumb comes over its right edge.
- **Scene C follows the real keyboard.** Recording draws the bars on a voice (`.micLevels`), with the ✕ and ✓ pills and the timer. Transcribing draws `.sweep`, the code's `0.2 + 0.25 (sin(2π (i/(n−1) + phase)) + 1)`, with an empty top bar of the same height, so the waveform does not move. The brief's "bright band" rides the sine's crest. The layout is read off the captures, in the phone's millimetres.
- **No readable text.** The keys are blank caps with their icons only: shift, delete, emoji, return, globe, mic. The suggestions, the caption and the note are scribbles, and the no-network signal is the struck-through bars icon. The one exception is the timer's digits, `00:00` to `00:03`: numerals, the same in every language the app ships, and a timer is what the brief asks for.
- **Scene B leaves out the optional noise** (a neighbour). At this size a second figure takes the eye away from her phone, which is the point of the scene. The carriage's rocking stays.
- **Dark.** The art's ink is `#0A1628`, which is the dark page's colour. In dark, the contours turn to `#9FB0D0`, while the marks on skin and cloth (eyes, brows, mouth, pupils, lenses) stay navy. The ground, the carriage and the phones get dark tones of their own. The phones' screens and the keyboard follow the system's dark appearance. The tunnel is dark in both appearances.
- **No HEVC with alpha.** On this machine, only VideoToolbox (`hevc_videotoolbox`, `-alpha_quality`) writes it. Measured on the first version of scene A light:

  | Encode | Luma PSNR | Size |
  |---|---|---|
  | Opaque VideoToolbox, `-q:v 40` | 38.8 dB | 510 KB |
  | Opaque VideoToolbox, `-q:v 55` | 43.6 dB | 1.11 MB |
  | Alpha VideoToolbox, `-q:v 40` (`-alpha_quality 0.6`) | | 1.21 MB |
  | Alpha VideoToolbox, `-q:v 55` | | 1.93 MB |
  | Opaque x265, CRF 26 (used) | 43.3 dB | about 0.9 MB |

  At equal quality, alpha costs about twice the bytes and goes over the 1.5 MB budget. The videos are therefore opaque, and each one carries the page colour of its appearance.

Wiring the videos into the onboarding is #649's PR B, not this folder.
