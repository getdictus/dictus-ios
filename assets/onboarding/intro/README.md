# Onboarding intro scenes

The three looping videos of the onboarding's intro carousel (issue #667, decision 15 of #649).
They replace the static Welcome screen. Each one plays in place, muted and looping, until the
user swipes or taps **Commencer**. The three scenes tell one story: **the voice goes into the
phone and comes out as text.** The headline and subtitle are SwiftUI text under the video. The
art contains no readable words: every line of "text" is a marker scribble, so one render serves
every language.

| File | Scene (headline) | What it shows | Drawn from |
|---|---|---|---|
| `intro-a-{light,dark}.mp4` | A, walking ("Parlez. Dictus écrit.") | She walks and talks into her phone, held to her mouth and seen from the back, as on the App Store art. The blue strokes leave her lips in the art's big arch and go into the phone. The text comes out of it as a sent chat message: a blue bubble springs from the phone's edge, under a small grey message already received, and grows a scribbled line at a time as she talks, then fades before the loop restarts. 5.5 s. | `assets/appstore/art/v15-B/heroWalk15.ts` |
| `intro-b-{light,dark}.mp4` | B, the metro ("Même sans réseau.") | The same woman stands in a metro carriage, one hand on the pole, before a window where the tunnel's lights streak past. The carriage rocks and she sways, her ponytail swinging; grab handles swing; bands of tunnel light sweep through the carriage and over her. A badge in the top-right corner says no network (signal bars struck through in red). Her voice still goes into the phone, and the text comes out into a mail draft (envelope mark, subject, rule, body). 5.5 s. | Her: V15-B. The carriage: new, same style. |
| `intro-c-{light,dark}.mp4` | C, the keyboard ("Dans votre clavier.") | The drawn iPhone, a note above the Dictus keyboard, through one whole dictation: two keys typed, the blue mic tapped, recording (waveform, timer, ✕ and ✓), ✓ tapped, transcribing (the sweep), the text lands, then the note clears. No hand: each tap is a touch indicator. 6.5 s. | `assets/appstore/art/v10-A/heroSpeak10.ts`, the phone (branch `chore/643-hero-a`) |

Every video is 1000 × 1440 px (the 330 × 476 pt art area at 3×), 30 fps, HEVC Main 10, 4:2:0,
BT.709, tagged `hvc1`. There is no audio track and one keyframe per loop. The light page is
`#F2F2F7` and the dark page `#0A1628`, exact to the code value in the decoded corners, so the
video's edge does not show against the screen behind it.

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
  - V15-B's phone, seen from the back;
  - her voice going into the phone, its strokes ending behind it.
- `src/scribble.ts`: handwriting that spells nothing, and the timer's digits.
- `src/noteCard.ts`: what the text comes out on: a chat message in A, a mail draft in B.
- `src/edges.ts`: the clean band round the frame (A and B).
- `src/introWalk.ts`: scene A, the pavement sliding back one slab joint per step.
- `src/introMetro.ts`: scene B. The carriage (wall, bench, tunnel window, rail and its grab handles, pole), the lights streaking past and sweeping through, the carriage rocking and her swaying with it, and the no-network badge.
- `src/introKeyboard.ts`: scene C with its touch indicators, driven by one cue table (taps, mic, check, landing, clearing) that is checked against the 5-frame grid when the module loads.
- `src/phoneGeometry.ts`: V10-A's phone in perspective.

The App Store art files are untouched: these sources are copies, adapted.

## Decisions

- **Framing.** The art of the #649 mock-ups (`designs/onboarding-649-png/01{A,B,C}-intro-*.png`, local to the maintainer) is the App Store renders cropped to the drawing.
  - A fills the 330 × 476 pt frame (strip x 0–1466, y 750–2861).
  - B uses the same frame and the same placement as A, so she stands where she walked and the carousel does not jump.
  - C places the phone where its mock-up does: 300 pt wide, at (15, 83) pt.
- **The phone is seen from the back** in A and B, as V15-B drew it. People talk into the back of a phone they hold to their mouth, not into a screen they show. The idea rides on the voice's strokes going into the phone; no screen text is drawn.
- **No network is a badge, not a mark on the phone.** It sits in the frame's top-right corner, about 48 pt across on the device, with its own fill and contour so it reads over the wall, the window or the page in both appearances. Inside: the four signal bars (the mobile network is what a tunnel takes away), struck through in the recording red `#EF4444`. It swells a little twice a loop.
- **The light page is `#F2F2F7`, not the issue's `#FFFFFF`.** The #649 mock-ups' page measures `#F2F2F7` (the onboarding's grouped background), and a white video shows as a white box on it. In 8-bit video no colour code decodes back to `#F2F2F7` exactly (the nearest gives `#F2F2F6`), so the videos are 10-bit (HEVC Main 10, decoded in hardware by every iPhone that runs iOS 17), for about 4 % more bytes. After a scene is drawn, a band round the frame is cleared (`edges.ts`) so nothing near the edge disturbs the page colour there. The decoded corners are exact (checked on every 15th frame). B's carriage also fades out well before the frame's right and bottom edges, so the encoder has only flat page to code there.
- **The text comes out of the phone (A and B), into everyday writing.** The headline promises writing and the phone is seen from the back, so the writing appears beside it (`noteCard.ts`). It evokes the apps people write in, as generic shapes only: no second phone, no logo, no one's colours but Dictus's.
  - In A it is a sent chat message: the accent blue, its tail at the bottom right, white scribbled lines, growing a line at a time, under a small grey message already received.
  - In B it is a mail draft: a small sheet with an envelope mark, a subject line, a rule, then the body writing itself. It sits below the window, over the bench, so it does not fight the dark glass.
  - In both, the card springs from the phone's edge, a row of dots runs from the phone to it, and it fades before the seam. The scribbles are thinner than in round 5, so they read lighter at phone size.
  - The voice is the App Store art's big arch, curling back into the phone.
- **Scene B lives.** The carriage rocks and she sways with it, her ponytail swinging. Two grab handles swing from the rail; the right one hangs between the voice's arch and the badge, clear of both. Bands of the tunnel's light sweep through the carriage and over her, screen-blended so they brighten what they cross rather than tint it. The pole is a plain round tube cut by the frame's top, with a round collar at the rail and a round foot; it is drawn with two parallel contours, because a closed outline tapers to points at its ends. The scene sits 75 frame pixels lower than A so her bun clears the top edge. Her head, the badge and the mail draft stay out of the frame's bottom tenth, which the three-line subtitle of mock-up 01b crowds.
- **Scene C has no hand.** Two drawn hands were rejected, the second at real size. Each tap is now a touch indicator, as in screen recordings: an accent disc spreading into a fading ring, in perspective on the glass, together with the key's own flash. The mic and ✓ touches land three frames before the overlay swaps them, so the contact is seen on them. The loop is 6.5 s: two keys, the mic at 1.2 s, three seconds of recording, ✓, one second of transcribing, the text lands, the note clears.
- **No readable text.** The keys are blank caps with their icons only: shift, delete, emoji, return, globe, mic. The suggestions, the caption and the note are scribbles, and scene B's no-network badge is an icon. The one exception is the timer's digits, `00:00` to `00:02`: numerals, the same in every language the app ships, and a timer is what the brief asks for.
- **Scene B leaves out the optional noise** (a neighbour). At this size a second figure takes the eye away from her phone, which is the point of the scene. The carriage's rocking stays.
- **Dark.** The art's ink is `#0A1628`, which is the dark page's colour. In dark, the contours turn to `#9FB0D0`, while the marks on skin and cloth (eyes, brows, mouth, pupils, lenses) stay navy. The ground, the carriage and the phones get dark tones of their own. Scene C's screen and keyboard follow the system's dark appearance. The tunnel is dark in both appearances.
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
