import type { P } from "./core";

// ONBOARDING INTRO (issue #667, sub-issue of #649 decision 15). Shared by the three scenes: the
// two appearances, the frame and the loop.
//
// The frame is the art area of the intro screen, 330 x 476 pt on a 402 x 874 pt iPhone 16 Pro,
// rendered at 3x: 1000 x 1440 px. Every scene draws in its own source coordinates (the App Store
// strip's pixels, 2640 x 2868) and is placed in the frame by a Placement: the source rectangle
// that starts at `o` is scaled by `k` to the frame's pixels. The placements are read off the
// #649 mock-ups (designs/onboarding-649-png/01{A,B,C}-intro-*.png, local to Pierre's machine):
// their art is the App Store renders cropped to the drawing, laid out in the 330 x 476 area.

export const FRAME = { w: 1000, h: 1440 };
const PX_PER_PT = FRAME.w / 330;

export type Placement = { o: P; k: number };
/** the source rectangle at `src`, `srcW` source pixels wide, lands at `at` (pt in the frame), `ptW` pt wide */
export const place = (src: P, srcW: number, at: P, ptW: number): Placement => {
  const k = (ptW * PX_PER_PT) / srcW;
  return { o: [src[0] - (at[0] * PX_PER_PT) / k, src[1] - (at[1] * PX_PER_PT) / k], k };
};

// One loop for all three scenes: 4.5 s at 30 fps. 120 bpm at 30 fps is the engine's 15-frame beat
// grid, and 135 frames is nine beats. Everything that moves is a whole number of cycles over the
// loop, so frame 135 would be frame 0 again and the seam disappears.
export const FPS = 30, BPM = 120, LOOP = 135;
/** loop time in [0, 1) */
export const tau = (frame: number) => frame / LOOP;
/** a sine that turns exactly `n` whole times per loop */
export const cyc = (frame: number, n: number, phase = 0) => Math.sin(2 * Math.PI * n * tau(frame) + phase);

// ---------------------------------------------------------------- the two appearances
// Light is the App Store art's palette, unchanged. Dark is the app's background, #0A1628, which
// is also the art's ink: so in dark the contour (`line`) turns light, while the marks drawn ON
// the skin and the clothes (eyes, brows, mouth, pupils, lenses: `ink`) stay dark navy, as they
// would on paper. The ground and the drawn phone get their own dark tones rather than keeping the
// light greys, which would glow on the dark page.
export type Theme = {
  name: "light" | "dark";
  bg: string;
  line: string;           // contours and construction lines
  ink: string;            // marks on skin and cloth, the mouth, pupils, lenses
  road: string; pave: string; kerb: string;
  joint: string; jointK: number;   // slab joints and kerb edges, and how strong they are
  shadow: string; shadowA: number; // a cast shadow on the ground
  sole: string; soleShade: string; shoeShade: string; tongue: string;
  // the drawn iPhone
  sitShadow: string;      // scene B: her shadow where she sits
  titan: string; titanLit: string; titanDark: string; rim: string; groundShadow: string;
  screen: string; panel: string; panelEdge: string; shine: string; pill: string; pillGlyph: string;
  barLit: [string, string]; barShade: [string, string];   // the grey bars, inner then outer
  glyph: string;          // globe and mic on the keyboard
  voiceEnd: [string, string, string];   // scene A: the three bars the voice turns into
};

export const LIGHT_THEME: Theme = {
  name: "light", bg: "#FFFFFF", line: "#0A1628", ink: "#0A1628",
  road: "#D9E0EB", pave: "#E4E9F1", kerb: "#C4CEDD", joint: "#0A1628", jointK: 1,
  shadow: "#0A1628", shadowA: 0.16,
  sole: "#C4CEDD", soleShade: "#A9B6CA", shoeShade: "#D3DCEA", tongue: "#EEF2F8",
  sitShadow: "#D3D9E4",
  titan: "#2B3A5C", titanLit: "#46577D", titanDark: "#1A2642", rim: "#7F92BC", groundShadow: "#C6CFDF",
  screen: "#FFFFFF", panel: "#E3E5EB", panelEdge: "#C9CED9", shine: "#EAF1FF", pill: "#FFFFFF", pillGlyph: "#7B8496",
  barLit: ["#A7ADBB", "#C3C7D1"], barShade: ["#8E95A5", "#AEB3BF"], glyph: "#0A1628",
  voiceEnd: ["#6E9BEF", "#93AEE6", "#B6C1DD"],
};

export const DARK_THEME: Theme = {
  name: "dark", bg: "#0A1628", line: "#9FB0D0", ink: "#0A1628",
  road: "#16243F", pave: "#1B2B4A", kerb: "#2A3C5E", joint: "#9FB0CF", jointK: 1.25,
  shadow: "#000000", shadowA: 0.4,
  sole: "#AEBBD0", soleShade: "#8D9BB3", shoeShade: "#C9D3E3", tongue: "#E4EAF4",
  sitShadow: "#050C18",
  // the slab one step lighter than the light render's, so its faces separate from the page
  titan: "#34466C", titanLit: "#53668F", titanDark: "#22304F", rim: "#93A6CE", groundShadow: "#050C18",
  // the screen in the system's dark appearance: the onboarding follows it, so does the keyboard
  screen: "#141A26", panel: "#2A2F3A", panelEdge: "#1E222B", shine: "#1B2232", pill: "#3A404D", pillGlyph: "#AEB5C4",
  barLit: ["#8A92A3", "#6C7384"], barShade: ["#6B7283", "#545B6B"], glyph: "#C9D4E8",
  voiceEnd: ["#5B8DF0", "#5F7FC4", "#55678F"],
};

export const THEMES = { light: LIGHT_THEME, dark: DARK_THEME };
