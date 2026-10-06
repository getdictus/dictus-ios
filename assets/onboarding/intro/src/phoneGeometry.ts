import type { P } from "./core";

// The giant iPhone of the App Store hero V10-A (branch chore/643-hero-a,
// assets/appstore/art/v10-A/heroSpeak10.ts), lying screen-up in perspective. Shared by scene B,
// which places the woman and aims her voice by it although the phone itself is not drawn there,
// and scene C, which draws it. V10-A's numbers, unchanged.
//
// An iPhone 17 Pro Max-shaped slab (163 x 78 mm, display corners ~12 mm), top end away from us,
// seen from above in true perspective: a homography from the phone's millimetres to the strip.

// Top-face corners in strip pixels: (0,0) top-left, (1,0) top-right, (1,1) bottom-right, (0,1)
// bottom-left in the phone's own (across, along) unit square.
export const QUAD: P[] = [[40, 1560], [740, 1330], [1260, 2330], [450, 2650]];
export const MM = { w: 78, h: 163, r: 12.5, thick: 9 };
const homography = (q: P[]) => {
  const [[x0, y0], [x1, y1], [x2, y2], [x3, y3]] = q;
  const dx1 = x1 - x2, dx2 = x3 - x2, dx3 = x0 - x1 + x2 - x3, dy1 = y1 - y2, dy2 = y3 - y2, dy3 = y0 - y1 + y2 - y3;
  const den = dx1 * dy2 - dx2 * dy1, g = (dx3 * dy2 - dx2 * dy3) / den, h = (dx1 * dy3 - dx3 * dy1) / den;
  const a = x1 - x0 + g * x1, b = x3 - x0 + h * x3, d = y1 - y0 + g * y1, e = y3 - y0 + h * y3;
  return (u: number, v: number): P => { const z = g * u + h * v + 1; return [(a * u + b * v + x0) / z, (d * u + e * v + y0) / z]; };
};
const toUnit = homography(QUAD);
/** phone millimetres (x across from the left side, y along from the top end) -> strip pixels */
export const mm = (x: number, y: number): P => toUnit(x / MM.w, y / MM.h);
export const mmPts = (pts: P[]) => pts.map(([x, y]) => mm(x, y));
// pixels per millimetre at a point, measured across the phone (sets the extrusion depth)
export const ppm = (x: number, y: number) => { const a = mm(x, y), b = mm(x + 1, y); return Math.hypot(b[0] - a[0], b[1] - a[1]); };
// a rounded rectangle in phone millimetres, sampled densely so it bends with the perspective
export const rrect = (x0: number, y0: number, x1: number, y1: number, r: number, n = 10): P[] => {
  const out: P[] = [];
  const corner = (cx: number, cy: number, a0: number) => { for (let i = 0; i <= n; i++) { const a = a0 + (i / n) * (Math.PI / 2); out.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]); } };
  corner(x1 - r, y0 + r, -Math.PI / 2); corner(x1 - r, y1 - r, 0); corner(x0 + r, y1 - r, Math.PI / 2); corner(x0 + r, y0 + r, Math.PI);
  const dense: P[] = [];
  out.forEach((p, i) => { const q = out[(i + 1) % out.length], l = Math.hypot(q[0] - p[0], q[1] - p[1]), k = Math.max(1, Math.ceil(l / 4)); for (let j = 0; j < k; j++) dense.push([p[0] + ((q[0] - p[0]) * j) / k, p[1] + ((q[1] - p[1]) * j) / k]); });
  return dense;
};
// the drop of the slab's thickness, straight down the page, scaled by the local size (the view
// is about 50 degrees above the ground, so a vertical edge reads at ~0.75 of its length)
export const drop = (x: number, y: number) => MM.thick * ppm(x, y) * 0.75;

// the keyboard's waveform, in phone millimetres: its centre is where scene B's voice is aimed
export const WAVE = { x0: 7, x1: 71, cy: 123, h: 25, w: 2.7 };
export const WAVE_MM: P = [39, WAVE.cy];
