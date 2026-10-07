import { type Gfx, type P } from "./core";
import { fillShape } from "./gallery";
import { drawScribble, scribbleLine } from "./scribble";
import type { Loop, Theme } from "./theme";
import { clamp, sm, stroke } from "./woman";

// THE TEXT COMING OUT (issue #667, scenes A and B). Her phone is seen from the back, so the
// writing the headline promises ("Parlez. Dictus écrit.") cannot be on its screen: it comes out
// of the phone instead, on a small note card that springs from the phone's edge and settles in
// the empty part of the frame. Scribbled lines (scribble.ts: handwriting that spells nothing)
// write on it while her voice goes into the phone, a row of dots runs from the phone to the card,
// and the card fades away before the loop starts again on its own.
//
// The chain to read at phone size: mouth, blue strokes, phone, card filling with lines.
//
// Timing, in loop time (0..1): the card springs out between 2 % and 10 %, its four lines write
// between 12 % and 82 % (at a speed that wavers with her speech and never goes back), it fades
// between 88 % and 97 %. Hidden at both ends, so the seam is clean.

export type Card = { c: P; w: number; h: number; deg: number };
const LINES = [0, 1, 2, 3].map((i) => scribbleLine([0.8, 0.86, 0.74, 0.46][i], 0.05, 900 + i * 13));
const ease = (t: number) => { const x = clamp(t); return x * x * (3 - 2 * x); };
const rrect = (w: number, h: number, r: number): P[] => {
  const out: P[] = [], c = (cx: number, cy: number, a0: number) => { for (let i = 0; i <= 6; i++) { const a = a0 + (i / 6) * (Math.PI / 2); out.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]); } };
  c(w / 2 - r, -h / 2 + r, -Math.PI / 2); c(w / 2 - r, h / 2 - r, 0); c(-w / 2 + r, h / 2 - r, Math.PI / 2); c(-w / 2 + r, -h / 2 + r, Math.PI);
  return out;
};

/** the card, in canvas pixels: `from` is the point on the phone's edge it springs from */
export const drawNoteCard = (g: Gfx, t: Theme, lp: Loop, frame: number, card: Card, from: P) => {
  const tau = lp.tau(frame);
  const out = ease((tau - 0.02) / 0.08), gone = ease((tau - 0.88) / 0.09), alpha = out * (1 - gone);
  if (alpha <= 0.001) return;
  // springing out: from the phone's edge, small, to its place, with a little overshoot
  const k = 0.3 + 0.7 * out + 0.06 * Math.sin(Math.PI * out), lift = -18 * gone;
  const c: P = [from[0] + (card.c[0] - from[0]) * out, from[1] + (card.c[1] - from[1]) * out + lift];
  const a = (card.deg * Math.PI) / 180, cos = Math.cos(a), sin = Math.sin(a);
  const map = ([x, y]: P): P => [c[0] + (x * cos - y * sin) * k, c[1] + (x * sin + y * cos) * k];
  const W = card.w, H = card.h;

  // the trail of dots from the phone to the card: light runs along it toward the card
  const end = map([-W / 2, H * 0.1]);
  for (let i = 0; i < 5; i++) {
    const s = (i + 1) / 6, p: P = [from[0] + (end[0] - from[0]) * s, from[1] + (end[1] - from[1]) * s - Math.sin(Math.PI * s) * 40];
    const glow = 0.35 + 0.65 * Math.max(0, Math.sin(2 * Math.PI * (s - lp.tau(frame) * 11)));
    fillShape(g, Array.from({ length: 12 }, (_, j) => [p[0] + Math.cos(j * 0.5236) * 9, p[1] + Math.sin(j * 0.5236) * 9] as P), "#3D7EFF", alpha * glow);
  }
  // the card: a paper with soft corners, its shadow, its contour, a short accent at its head
  const body = sm(rrect(W, H, 30).map(map), 3);
  fillShape(g, sm(rrect(W, H, 30).map(([x, y]) => map([x + 14, y + 16])), 3), t.shadow, t.shadowA * alpha);
  fillShape(g, body, t.badge, alpha);
  g.pen(body, { w: 5.5, color: t.line, seed: 960, closed: true, wobble: 0.15, boil: 0, taper: 0.3, opacity: alpha, retrace: false });
  stroke(g, [map([-W / 2 + 36, -H / 2 + 40]), map([-W / 2 + 110, -H / 2 + 40])], 7, 961, t.notesAccent, 0.2, alpha);
  // the lines writing themselves
  const written = 4 * clamp((tau - 0.12) / 0.7 + 0.012 * Math.sin(2 * Math.PI * 11 * tau));
  LINES.forEach((words, i) => {
    const y = -H / 2 + 92 + i * ((H - 120) / 4);
    drawScribble(g, words, clamp(written - i), ([x, yy]) => map([-W / 2 + 36 + x * W, y + yy * W]), { w: 4, color: t.screenInk, seed: 970 + i * 7, opacity: alpha });
  });
};
