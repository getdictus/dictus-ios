import type { Gfx, P } from "./core";

// FAKE TEXT (issue #667, round 10, approved by Pierre). Every line of "text" in the intro reads as
// writing at a glance, in real Latin letter shapes, hand-lettered in the marker line, and says
// nothing in any language: the words are made up, checked against French, English, German and
// Spanish so none is a real word (WORDS below). A capital opens a sentence, a comma or a period
// falls here and there. The keyboard's keys in scene C carry real QWERTY letters.
//
// Glyphs are single marker strokes in a unit box: x from 0 to the glyph's width, y UP from the
// baseline, x-height 1, ascenders and capitals 1.6, descenders to -0.6. drawText maps them through
// the caller's `map` (local x right, local y DOWN), so the same text lies flat on a card or in
// perspective on the giant phone.

type Glyph = { w: number; s: P[][] };
const ell = (cx: number, cy: number, rx: number, ry: number, a0 = 0, a1 = Math.PI * 2, n = 14): P[] =>
  Array.from({ length: n + 1 }, (_, i) => { const a = a0 + ((a1 - a0) * i) / n; return [cx + Math.cos(a) * rx, cy + Math.sin(a) * ry] as P; });
const bowl = (cx: number) => ell(cx, 0.5, 0.36, 0.5);
const G: Record<string, Glyph> = {
  a: { w: 0.86, s: [bowl(0.4), [[0.8, 1], [0.8, 0]]] },
  b: { w: 0.86, s: [[[0.08, 1.6], [0.08, 0]], bowl(0.46)] },
  c: { w: 0.76, s: [ell(0.42, 0.5, 0.38, 0.5, 0.7, Math.PI * 2 - 0.7)] },
  d: { w: 0.86, s: [bowl(0.4), [[0.8, 1.6], [0.8, 0]]] },
  e: { w: 0.82, s: [[[0.06, 0.5], [0.8, 0.5], ...ell(0.43, 0.5, 0.37, 0.5, 0, Math.PI * 2 - 0.75).slice(1)]] },
  f: { w: 0.62, s: [[[0.62, 1.52], [0.42, 1.62], [0.28, 1.46], [0.26, 0]], [[0.04, 1], [0.56, 1]]] },
  g: { w: 0.86, s: [bowl(0.4), [[0.8, 1], [0.8, -0.32], [0.62, -0.58], [0.3, -0.6], [0.1, -0.45]]] },
  h: { w: 0.88, s: [[[0.08, 1.6], [0.08, 0]], [[0.08, 0.62], [0.3, 0.95], [0.58, 0.98], [0.8, 0.72], [0.8, 0]]] },
  i: { w: 0.3, s: [[[0.15, 1], [0.15, 0]], [[0.14, 1.42], [0.16, 1.46]]] },
  j: { w: 0.42, s: [[[0.32, 1], [0.32, -0.38], [0.2, -0.58], [0.0, -0.55]], [[0.31, 1.42], [0.33, 1.46]]] },
  k: { w: 0.8, s: [[[0.08, 1.6], [0.08, 0]], [[0.7, 1], [0.1, 0.42]], [[0.32, 0.62], [0.76, 0]]] },
  l: { w: 0.28, s: [[[0.14, 1.6], [0.14, 0]]] },
  m: { w: 1.24, s: [[[0.08, 1], [0.08, 0]], [[0.08, 0.66], [0.3, 0.98], [0.56, 0.86], [0.62, 0]], [[0.62, 0.66], [0.86, 0.98], [1.1, 0.86], [1.16, 0]]] },
  n: { w: 0.88, s: [[[0.08, 1], [0.08, 0]], [[0.08, 0.66], [0.32, 0.98], [0.62, 0.95], [0.8, 0.7], [0.8, 0]]] },
  o: { w: 0.86, s: [ell(0.43, 0.5, 0.39, 0.5)] },
  p: { w: 0.86, s: [[[0.08, 1], [0.08, -0.6]], bowl(0.46)] },
  q: { w: 0.86, s: [bowl(0.4), [[0.8, 1], [0.8, -0.6]]] },
  r: { w: 0.64, s: [[[0.08, 1], [0.08, 0]], [[0.08, 0.6], [0.28, 0.94], [0.62, 0.96]]] },
  s: { w: 0.74, s: [[[0.68, 0.86], [0.46, 1], [0.16, 0.9], [0.14, 0.66], [0.4, 0.5], [0.64, 0.34], [0.64, 0.12], [0.36, 0], [0.06, 0.14]]] },
  t: { w: 0.64, s: [[[0.28, 1.4], [0.28, 0.16], [0.42, 0], [0.62, 0.04]], [[0.04, 1], [0.6, 1]]] },
  u: { w: 0.86, s: [[[0.08, 1], [0.08, 0.34], [0.26, 0.02], [0.52, 0.0], [0.78, 0.3]], [[0.8, 1], [0.8, 0]]] },
  v: { w: 0.82, s: [[[0, 1], [0.41, 0], [0.82, 1]]] },
  w: { w: 1.18, s: [[[0, 1], [0.28, 0], [0.59, 0.78], [0.9, 0], [1.18, 1]]] },
  x: { w: 0.78, s: [[[0.02, 1], [0.76, 0]], [[0.76, 1], [0.02, 0]]] },
  y: { w: 0.82, s: [[[0, 1], [0.42, 0.06]], [[0.82, 1], [0.26, -0.6]]] },
  z: { w: 0.78, s: [[[0.06, 1], [0.74, 1], [0.04, 0], [0.76, 0]]] },
  D: { w: 0.92, s: [[[0.06, 0], [0.06, 1.6], [0.42, 1.6], [0.76, 1.36], [0.88, 0.8], [0.76, 0.24], [0.42, 0], [0.06, 0]]] },
  E: { w: 0.78, s: [[[0.74, 1.6], [0.06, 1.6], [0.06, 0], [0.74, 0]], [[0.06, 0.82], [0.6, 0.82]]] },
  H: { w: 0.92, s: [[[0.06, 1.6], [0.06, 0]], [[0.86, 1.6], [0.86, 0]], [[0.06, 0.82], [0.86, 0.82]]] },
  K: { w: 0.86, s: [[[0.06, 1.6], [0.06, 0]], [[0.8, 1.6], [0.08, 0.72]], [[0.32, 0.98], [0.84, 0]]] },
  L: { w: 0.72, s: [[[0.06, 1.6], [0.06, 0], [0.7, 0]]] },
  N: { w: 0.94, s: [[[0.06, 0], [0.06, 1.6], [0.88, 0], [0.88, 1.6]]] },
  T: { w: 0.92, s: [[[0, 1.6], [0.92, 1.6]], [[0.46, 1.6], [0.46, 0]]] },
  V: { w: 0.94, s: [[[0, 1.6], [0.47, 0], [0.94, 1.6]]] },
  ".": { w: 0.24, s: [[[0.1, 0.04], [0.14, 0.08], [0.1, 0.12], [0.06, 0.08], [0.1, 0.04]]] },
  ",": { w: 0.26, s: [[[0.14, 0.12], [0.12, -0.04], [0.02, -0.28]]] },
};
const TRACK = 0.2, SPACE = 0.55;

// The made-up words, each checked not to be a word in French, English, German or Spanish.
export const WORDS = ["Lorvem", "tasini", "obrelk", "denuva", "miscor", "faltin", "trivo", "sapnel", "cundra", "moreti", "vilsan", "plodri",
  "Esnaru", "gelvo", "nustri", "borkam", "ilvane", "Tarsiv", "quelbo", "venusk", "olmabi", "skirel", "Dapor", "unvel", "hoskim", "Ke"];

/** the width of a text at letter size `h` (its x-height), in local units */
export const textWidth = (text: string, h: number) => [...text].reduce((x, ch) => x + (ch === " " ? SPACE : (G[ch]?.w ?? 0.6) + TRACK), 0) * h;

/**
 * Draw `text` with its baseline at local (0, 0), x-height `h`, up to `progress` (0..1 of its
 * characters, the one being written drawn stroke by stroke), mapped by `map` (local y down).
 */
export const drawText = (g: Gfx, text: string, progress: number, map: (p: P) => P, o: { h: number; w: number; color: string; seed: number; opacity?: number }) => {
  if (progress <= 0) return;
  const chars = [...text], upTo = progress * chars.length;
  let x = 0;
  chars.forEach((ch, i) => {
    const glyph = G[ch];
    if (i >= upTo) return;
    if (ch === " " || !glyph) { x += (ch === " " ? SPACE : 0.6) * o.h; return; }
    const p = Math.min(1, upTo - i);
    glyph.s.forEach((st, k) => {
      const share = Math.min(1, Math.max(0, p * glyph.s.length - k));
      if (share <= 0) return;
      g.pen(st.map(([u, v]) => map([x + u * o.h, -v * o.h])), { w: o.w, color: o.color, seed: o.seed + i * 5 + k, closed: false, wobble: 0.12, boil: 0, taper: 0.25, opacity: o.opacity ?? 1, retrace: false, progress: share });
    });
    x += (glyph.w + TRACK) * o.h;
  });
};
