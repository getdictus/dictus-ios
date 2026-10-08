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
// each), C carries the keyboard's whole dictation in 6.5 seconds.
export const FPS = 30, BPM = 120;
export const LOOP_A = 165, LOOP_B = 165, LOOP_C = 195;
export type Loop = { frames: number; tau: (frame: number) => number; cyc: (frame: number, n: number, phase?: number) => number };
export const loop = (frames: number): Loop => ({
  frames,
  /** loop time in [0, 1) */
  tau: (frame) => frame / frames,
  /** a sine that turns exactly `n` whole times per loop */
  cyc: (frame, n, phase = 0) => Math.sin((2 * Math.PI * n * frame) / frames + phase),
});

// ---------------------------------------------------------------- the palette
// The App Store art's palette, on the onboarding's page colour: #F2F2F7, the grey the #649
// mock-ups' pages measure (the issue said #FFFFFF; a white video would show as a white box on that
// page). There is one palette: the dark videos show this same art, black outlines and all, in a
// pool of light that fades into the app's dark page (render.mjs, DARK). A drawing in marker keeps
// its black lines; a dark palette with light contours read wrong.
export type Theme = {
  name: "light";
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
  badge: string;          // scene B: the no-network badge's disc, and the mail draft's sheet
  received: string;       // scene A: the grey chat message already received
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
  name: "light", bg: "#F2F2F7", line: "#0A1628", ink: "#0A1628",
  road: "#D9E0EB", pave: "#E4E9F1", kerb: "#C4CEDD", joint: "#0A1628", jointK: 1,
  shadow: "#0A1628", shadowA: 0.16,
  sole: "#C4CEDD", soleShade: "#A9B6CA", shoeShade: "#D3DCEA",
  wall: "#E9EDF4", wallShade: "#D7DDE8", floor: "#DCE2EC", frameFill: "#C9D1DE",
  tunnel: "#1B2538", tunnelLine: "#2C3954", streak: ["#FFD27A", "#EAF1FF"], pole: "#AEB9CB", poleLit: "#E6ECF4", seat: "#9FB3D6", seatShade: "#7F95BD", badge: "#FFFFFF", received: "#E1E3EA",
  titan: "#2B3A5C", titanLit: "#46577D", titanDark: "#1A2642", rim: "#7F92BC", groundShadow: "#C6CFDF",
  screen: "#FFFFFF", screenInk: "#1C2333", screenFaint: "#B4BBC8",
  panel: "#E3E5EB", panelEdge: "#C9CED9", shine: "#EAF1FF", pill: "#FFFFFF", pillGlyph: "#7B8496",
  key: "#FFFFFF", keyShade: "#B9BEC8", keyHit: "#C3C8D3", notesAccent: "#E2A50B",
  barLit: ["#A7ADBB", "#C3C7D1"], barShade: ["#8E95A5", "#AEB3BF"], glyph: "#0A1628",
};


export const THEMES = { light: LIGHT_THEME };
