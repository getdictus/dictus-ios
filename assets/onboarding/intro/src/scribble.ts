import { rng, type Gfx, type P } from "./core";

// WRITING THAT IS NOT WORDS (issue #667). Every "line of text" in the intro is a marker scribble
// that reads as handwriting and spells nothing, so one render serves French, English, German and
// Spanish: the only real words on the intro screen are the SwiftUI headline and subtitle. Also
// here: the timer's digits (numerals, the same in every language the app ships).
//
// Everything is drawn in a LOCAL frame and mapped by the caller (`map`): x along the line from
// 0, baseline at y = 0, up is -y. That is how the same scribble lies in perspective on scene C's
// giant phone.

export type Map = (p: P) => P;

// one line of handwriting: words of cursive humps, some looped (e, l), some plain arches (m, n),
// the odd tall one (an ascender), seeded so a line is the same scribble in every frame. Returns
// one polyline per word, the pen lifting between words.
export const scribbleLine = (len: number, xh: number, seed: number): P[][] => {
  const r = rng(seed), words: P[][] = [];
  let x = 0;
  while (x < len - xh * 1.2) {
    const wordLen = Math.min(len - x, xh * (2.6 + r() * 4.2)), end = x + wordLen, w: P[] = [[x, 0]];
    let cx = x;
    while (cx < end - xh * 0.4) {
      const hw = xh * (0.55 + r() * 0.35), tall = r() < 0.22, loop = r() < 0.55, h = xh * (tall ? 1.9 : 0.85 + r() * 0.3);
      // a hump: a cycloid, looped when its swing is wide enough to cross back over itself
      const a = loop ? 0.36 : 0.12;
      for (let k = 1; k <= 8; k++) { const s = k / 8; w.push([cx + hw * s - a * hw * Math.sin(2 * Math.PI * s), -h * (1 - Math.cos(2 * Math.PI * s)) / 2]); }
      cx += hw;
    }
    words.push(w);
    x = cx + xh * (0.9 + r() * 0.5);
  }
  return words;
};

/** draw a scribbled line up to `progress` (0..1 of its length, word by word), mapped by `map` */
export const drawScribble = (g: Gfx, words: P[][], progress: number, map: Map, o: { w: number; color: string; seed: number; opacity?: number }) => {
  if (progress <= 0) return;
  const lens = words.map((w) => w.reduce((a, p, i) => (i ? a + Math.hypot(p[0] - w[i - 1][0], p[1] - w[i - 1][1]) : 0), 0));
  const total = lens.reduce((a, b) => a + b, 0);
  let left = progress * total;
  words.forEach((w, i) => {
    if (left <= 0) return;
    const p = Math.min(1, left / lens[i]); left -= lens[i];
    g.pen(w.map(map), { w: o.w, color: o.color, seed: o.seed + i * 13, closed: false, wobble: 0.25, boil: 0, taper: 0.5, opacity: o.opacity ?? 1, retrace: false, progress: p });
  });
};

// ---------------------------------------------------------------- digits, for the recording timer
// Single-stroke numerals in a unit box (x 0..0.6, y 0 at the top, 1 at the baseline), the order
// a hand writes them in
const DIGITS: Record<string, P[][]> = {
  "0": [Array.from({ length: 15 }, (_, i) => { const a = -Math.PI / 2 - (i / 14) * Math.PI * 2; return [0.3 + Math.cos(a) * 0.28, 0.5 + Math.sin(a) * 0.48] as P; })],
  "1": [[[0.12, 0.2], [0.34, 0.02], [0.34, 1]]],
  "2": [[[0.04, 0.24], [0.14, 0.06], [0.32, 0.01], [0.5, 0.08], [0.56, 0.26], [0.46, 0.48], [0.04, 1], [0.58, 1]]],
  "3": [[[0.06, 0.12], [0.24, 0.01], [0.46, 0.06], [0.52, 0.24], [0.3, 0.44], [0.52, 0.6], [0.56, 0.8], [0.42, 0.97], [0.2, 0.99], [0.04, 0.88]]],
  "4": [[[0.44, 1], [0.44, 0.02], [0.02, 0.7], [0.6, 0.7]]],
  "5": [[[0.54, 0.02], [0.12, 0.02], [0.08, 0.44], [0.3, 0.38], [0.52, 0.5], [0.56, 0.74], [0.42, 0.96], [0.18, 0.98], [0.04, 0.86]]],
  ":": [[[0.1, 0.32], [0.12, 0.35]], [[0.1, 0.76], [0.12, 0.79]]],
};
/** a timer like 00:04, `h` tall, its top-left at the local origin; returns its width */
export const drawDigits = (g: Gfx, text: string, h: number, map: Map, o: { w: number; color: string; seed: number }) => {
  let x = 0;
  [...text].forEach((ch, i) => {
    (DIGITS[ch] ?? []).forEach((s, k) => g.pen(s.map(([u, v]) => map([x + u * h, v * h])), { w: o.w * (ch === ":" ? 1.6 : 1), color: o.color, seed: o.seed + i * 7 + k, closed: false, wobble: 0.2, boil: 0, taper: 0.4, opacity: 1, retrace: false }));
    x += h * (ch === ":" ? 0.32 : 0.7);
  });
  return x;
};
