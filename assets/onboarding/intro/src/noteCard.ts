import { type Gfx, type P } from "./core";
import { fillShape } from "./gallery";
import { drawText } from "./handLettering";
import type { Loop, Theme } from "./theme";
import { clamp, sm } from "./woman";

// THE TEXT COMING OUT (issue #667, scenes A and B). Her phone is seen from the back, so the
// writing the headline promises ("Parlez. Dictus écrit.") cannot be on its screen: it comes out
// of the phone instead, onto a card that springs from the phone's edge and settles in the empty
// part of the frame. The card evokes the apps people write in every day, as generic shapes only
// (no second phone, no logo, no one's colours but Dictus's):
// - "bubble" (scene A): a sent chat message, the accent blue with its tail, white lines of text,
//   growing a line at a time as she talks, under a small grey message already received;
// - "mail" (scene B): a mail draft, a small sheet with an envelope mark, a subject line, a rule,
//   then the body writing itself.
// The text is short everyday English (handLettering.ts). A row of dots runs from the phone to the
// card.
//
// The chain to read at phone size: mouth, blue strokes, phone, dots, the text appearing.
//
// Timing, in loop time (0..1): the card springs out between 2 % and 10 %, its four lines write
// between 12 % and 82 % (at a speed that wavers with her speech and never goes back), it fades
// between 88 % and 97 %. Hidden at both ends, so the seam is clean.

export type Card = { style: "bubble" | "mail"; c: P; w: number; deg: number };
const ACCENT = "#3D7EFF";
// the text (handLettering.ts), its letter size and pen: a question received and the reply she
// dictates while walking (A); a mail she dictates in the metro (B)
const XH = 15, PEN = 2.8;
const BODY = ["On my way, I'll be", "there in ten minutes.", "Can you order me", "a coffee?"];
const RECEIVED = "Where are you?";
const SUBJECT = "Notes from today";
const MAIL = ["Great meeting this", "morning. Next steps", "for the launch below."];
const ease = (t: number) => { const x = clamp(t); return x * x * (3 - 2 * x); };
// a rounded rectangle from its top-left corner, width and height
const rrect = (x0: number, y0: number, w: number, h: number, r: number): P[] => {
  const out: P[] = [], x1 = x0 + w, y1 = y0 + h, c = (cx: number, cy: number, a0: number) => { for (let i = 0; i <= 6; i++) { const a = a0 + (i / 6) * (Math.PI / 2); out.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]); } };
  c(x1 - r, y0 + r, -Math.PI / 2); c(x1 - r, y1 - r, 0); c(x0 + r, y1 - r, Math.PI / 2); c(x0 + r, y0 + r, Math.PI);
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
  // card space: x across from the card's left edge, y down from its top, centred on `c` across
  const W = card.w, map = ([x, y]: P): P => { const u = x - W / 2; return [c[0] + (u * cos - y * sin) * k, c[1] + (u * sin + y * cos) * k]; };
  const written = 4 * clamp((tau - 0.12) / 0.7 + 0.012 * Math.sin(2 * Math.PI * 11 * tau));
  const pen = (pts: P[], w: number, color: string, seed: number, closed = true, op = 1) =>
    g.pen(pts, { w, color, seed, closed, wobble: 0.15, boil: 0, taper: closed ? 0.3 : 0.6, opacity: alpha * op, retrace: false });
  const shape = (pts: P[], fill: string, seed: number) => {
    const s = sm(pts.map(map), 3);
    fillShape(g, s.map(([x, y]) => [x + 12, y + 14] as P), t.shadow, t.shadowA * alpha);
    fillShape(g, s, fill, alpha);
    pen(s, 5, t.line, seed);
  };
  const lines = (texts: string[], x0: number, y0: number, lead: number, progress: number, color: string, seed: number) =>
    texts.forEach((txt, i) => drawText(g, txt, clamp(progress - i), ([x, y]) => map([x0 + x, y0 + i * lead + y]), { h: XH, w: PEN, color, seed: seed + i * 31, opacity: alpha }));

  // the trail of dots from the phone to the card: light runs along it toward the card
  const end = map([0, 60]);
  for (let i = 0; i < 5; i++) {
    const s = (i + 1) / 6, p: P = [from[0] + (end[0] - from[0]) * s, from[1] + (end[1] - from[1]) * s - Math.sin(Math.PI * s) * 40];
    const glow = 0.35 + 0.65 * Math.max(0, Math.sin(2 * Math.PI * (s - tau * 11)));
    fillShape(g, Array.from({ length: 12 }, (_, j) => [p[0] + Math.cos(j * 0.5236) * 9, p[1] + Math.sin(j * 0.5236) * 9] as P), ACCENT, alpha * glow);
  }

  if (card.style === "bubble") {
    // a small grey message already received, top left
    shape(rrect(0, -118, W * 0.68, 84, 40), t.received, 958);
    lines([RECEIVED], 30, -70, 0, 1, t.screenInk, 959);
    // the sent message, right-aligned: its height grows a line at a time as the lines come
    const lead = 52, pad = 34, n = 1 + [1, 2, 3].reduce((s, i) => s + ease((written - i + 0.2) / 0.35), 0);
    const h = 2 * pad + lead * (n - 1) + 24, x0 = W * 0.06, w = W * 0.94;
    const bubble = rrect(x0, 0, w, h, 42);
    // the tail at the bottom right, curling out of the bubble's corner
    // (it replaces the rounded bottom-right corner: points 7 to 13 of the outline)
    const tail: P[] = [[x0 + w, h - 44], [x0 + w + 4, h - 12], [x0 + w + 18, h + 6], [x0 + w - 24, h - 2], [x0 + w - 64, h]];
    shape([...bubble.slice(0, 7), ...tail, ...bubble.slice(14)], ACCENT, 960);
    lines(BODY, x0 + 32, pad + 18, lead, written, "#FFFFFF", 970);
  } else {
    // a mail draft: the sheet, an envelope mark and the subject on its head, a rule, the body
    const H = 300;
    shape(rrect(0, 0, W, H, 26), t.badge, 960);
    const env = [[28, 26], [76, 26], [76, 60], [28, 60]] as P[];
    pen(env.map(map), 3.6, ACCENT, 961);
    pen(([[28, 26], [52, 46], [76, 26]] as P[]).map(map), 3.2, ACCENT, 962, false);
    drawText(g, SUBJECT, clamp(written * 2), ([x, y]) => map([96 + x, 58 + y]), { h: XH * 1.1, w: PEN * 1.25, color: t.screenInk, seed: 963, opacity: alpha });
    pen(([[24, 86], [W - 24, 86]] as P[]).map(map), 2.4, t.screenFaint, 964, false);
    lines(MAIL, 28, 140, 56, Math.max(0, written - 0.5) * 3 / 3.5, t.screenInk, 970);
  }
};
