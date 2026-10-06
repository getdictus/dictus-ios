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

// The loops. 120 bpm at 30 fps is the engine's 15-frame beat grid; every loop is a whole number
// of beats, and everything that moves turns a whole number of times over its loop, so frame LOOP
// would be frame 0 again and the seam disappears. A and B are five walk-cycle lengths (1.1 s
// each), C carries the keyboard's whole dictation and needs nine seconds.
export const FPS = 30, BPM = 120;
export const LOOP_A = 165, LOOP_B = 165, LOOP_C = 270;
export type Loop = { frames: number; tau: (frame: number) => number; cyc: (frame: number, n: number, phase?: number) => number };
export const loop = (frames: number): Loop => ({
  frames,
  /** loop time in [0, 1) */
  tau: (frame) => frame / frames,
  /** a sine that turns exactly `n` whole times per loop */
  cyc: (frame, n, phase = 0) => Math.sin((2 * Math.PI * n * frame) / frames + phase),
});

// ---------------------------------------------------------------- the two appearances
// Light is the App Store art's palette, unchanged. Dark is the app's background, #0A1628, which
// is also the art's ink: so in dark the contour (`line`) turns light, while the marks drawn ON
// the skin and the clothes (eyes, brows, mouth, pupils, lenses: `ink`) stay dark navy, as they
// would on paper. The ground, the carriage and the drawn phones get their own dark tones rather
// than keeping the light greys, which would glow on the dark page. A phone's screen follows the
// system appearance, as the onboarding does.
export type Theme = {
  name: "light" | "dark";
  bg: string;
  line: string;           // contours and construction lines
  ink: string;            // marks on skin and cloth, the mouth, pupils, lenses
  road: string; pave: string; kerb: string;
  joint: string; jointK: number;   // slab joints and kerb edges, and how strong they are
  shadow: string; shadowA: number; // a cast shadow on the ground
  sole: string; soleShade: string; shoeShade: string;
  // scene B, the metro carriage: its wall and floor, the window on the tunnel (dark in both
  // appearances: it is a tunnel), the lights streaking past, the steel pole
  wall: string; wallShade: string; floor: string; frameFill: string;
  tunnel: string; tunnelLine: string; streak: [string, string]; pole: string; poleLit: string; seat: string; seatShade: string;
  // the drawn iPhones
  titan: string; titanLit: string; titanDark: string; rim: string; groundShadow: string;
  screen: string; screenInk: string; screenFaint: string;   // a screen, its writing, its quiet marks
  panel: string; panelEdge: string; shine: string; pill: string; pillGlyph: string;
  key: string; keyShade: string; keyHit: string;            // scene C: the keyboard's keys
  notesAccent: string;    // scene C: the note's back chevron and caret, Apple Notes' yellow
  barLit: [string, string]; barShade: [string, string];   // the grey bars, inner then outer
  glyph: string;          // globe and mic on the keyboard, the key icons
};

export const LIGHT_THEME: Theme = {
  name: "light", bg: "#FFFFFF", line: "#0A1628", ink: "#0A1628",
  road: "#D9E0EB", pave: "#E4E9F1", kerb: "#C4CEDD", joint: "#0A1628", jointK: 1,
  shadow: "#0A1628", shadowA: 0.16,
  sole: "#C4CEDD", soleShade: "#A9B6CA", shoeShade: "#D3DCEA",
  wall: "#E9EDF4", wallShade: "#D7DDE8", floor: "#DCE2EC", frameFill: "#C9D1DE",
  tunnel: "#1B2538", tunnelLine: "#2C3954", streak: ["#FFD27A", "#EAF1FF"], pole: "#AEB9CB", poleLit: "#E6ECF4", seat: "#9FB3D6", seatShade: "#7F95BD",
  titan: "#2B3A5C", titanLit: "#46577D", titanDark: "#1A2642", rim: "#7F92BC", groundShadow: "#C6CFDF",
  screen: "#FFFFFF", screenInk: "#1C2333", screenFaint: "#B4BBC8",
  panel: "#E3E5EB", panelEdge: "#C9CED9", shine: "#EAF1FF", pill: "#FFFFFF", pillGlyph: "#7B8496",
  key: "#FFFFFF", keyShade: "#B9BEC8", keyHit: "#C3C8D3", notesAccent: "#E2A50B",
  barLit: ["#A7ADBB", "#C3C7D1"], barShade: ["#8E95A5", "#AEB3BF"], glyph: "#0A1628",
};

export const DARK_THEME: Theme = {
  name: "dark", bg: "#0A1628", line: "#9FB0D0", ink: "#0A1628",
  road: "#16243F", pave: "#1B2B4A", kerb: "#2A3C5E", joint: "#9FB0CF", jointK: 1.25,
  shadow: "#000000", shadowA: 0.4,
  sole: "#AEBBD0", soleShade: "#8D9BB3", shoeShade: "#C9D3E3",
  wall: "#17243E", wallShade: "#111C33", floor: "#1B2A47", frameFill: "#2C3B58",
  tunnel: "#050A14", tunnelLine: "#16213A", streak: ["#FFC861", "#C9D8F5"], pole: "#7D8CA8", poleLit: "#B6C3DB", seat: "#2E416B", seatShade: "#22325A",
  // the slab one step lighter than the light render's, so its faces separate from the page
  titan: "#34466C", titanLit: "#53668F", titanDark: "#22304F", rim: "#93A6CE", groundShadow: "#050C18",
  screen: "#141A26", screenInk: "#E3E8F2", screenFaint: "#4A5366",
  panel: "#2A2F3A", panelEdge: "#1E222B", shine: "#1B2232", pill: "#3A404D", pillGlyph: "#AEB5C4",
  key: "#4A505E", keyShade: "#1C2029", keyHit: "#6E7586", notesAccent: "#E8B23A",
  barLit: ["#8A92A3", "#6C7384"], barShade: ["#6B7283", "#545B6B"], glyph: "#C9D4E8",
};

export const THEMES = { light: LIGHT_THEME, dark: DARK_THEME };
