import { Gfx, fractal, rng, softBox, tube, turn, type Ctx, type Env, type P } from "./core";
import type { Film } from "./film";
import { blob, bounds, clipped, fillShape, inside, lerpP, mix, resample, smooth } from "./gallery";
import * as S from "./heroShapes";

// DICTUS HERO V5, style B · cut-paper collage (the medium of fox.ts, its paper kit reused below
// with the shadow tinted navy). Not one drawn line: every form is a piece of coloured paper.
// TORN pieces show the white fibrous core along their edge (hair, jumper, the voice's paler
// strip); SCISSOR-cut pieces are crisp (face, hands, phone, features). Each piece lifts off the
// one below with a soft shadow. Form comes from a darker paper laid into the shade side and a
// lighter one where the light lands (upper left). Transparent background.

// hill, the moon rising to the upper left where the light comes from.

const PAPER_CORE = "#fbfbf8", SHADOW = "#0A1628";
type Piece = { shape: P[]; color: string; torn?: number; seed: number; fibre?: number; lift?: number };

// ---------------------------------------------------------------- paper
const normals = (s: P[]): P[] => s.map((_, i) => { const a = s[(i - 1 + s.length) % s.length], b = s[(i + 1) % s.length], dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy) || 1; return [dy / l, -dx / l]; });
const ringLen = (s: P[]) => s.reduce((a, p, i) => a + Math.hypot(p[0] - s[(i + 1) % s.length][0], p[1] - s[(i + 1) % s.length][1]), 0);
// a torn edge: the outline resampled finely and bitten in and out by high-frequency noise.
// `grow` pushes it outward: the white core of a torn sheet sticks out past its dyed face.
const tear = (shape: P[], amp: number, seed: number, grow = 0): P[] => {
  const closed = [...shape, shape[0]], n = Math.max(24, Math.round(ringLen(shape) / 2.6)), s = resample(closed, n).slice(0, -1), nr = normals(s), r = rng(seed);
  return s.map(([x, y], i) => { const d = (fractal(seed, x, y, 0.09, 0.09, 3) - 0.5) * amp * 2.2 + (r() - 0.5) * amp * 0.6 + grow; return [x + nr[i][0] * d, y + nr[i][1] * d]; });
};
const cut = (shape: P[], seed: number): P[] => { const s = resample([...shape, shape[0]], Math.max(24, Math.round(ringLen(shape) / 4))).slice(0, -1), r = rng(seed); return s.map(([x, y]) => [x + (r() - 0.5) * 0.7, y + (r() - 0.5) * 0.7]); };

// fibres and uneven dye, clipped to the piece
const fibres = (g: Gfx, shape: P[], color: string, seed: number, density: number) => {
  const b = bounds(shape), r = rng(seed), area = (b.x1 - b.x0) * (b.y1 - b.y0), c = g.cur;
  clipped(g, shape, () => {
    for (let i = 0; i < 5; i++) fillShape(g, blob(b.x0 + r() * (b.x1 - b.x0), b.y0 + r() * (b.y1 - b.y0), 30 + r() * 90, 20 + r() * 60, seed + i, 0.4, 12, r() * 3), r() < 0.5 ? mix(color, "#ffffff", 0.18) : mix(color, "#000000", 0.12), 0.25);
    c.lineCap = "round";
    const n = Math.round((area / 900) * density);
    for (let i = 0; i < n; i++) { const x = b.x0 + r() * (b.x1 - b.x0), y = b.y0 + r() * (b.y1 - b.y0), a = r() * Math.PI, l = 3 + r() * 9; c.strokeStyle = r() < 0.55 ? mix(color, "#fff8e8", 0.45) : mix(color, "#1a0e06", 0.3); c.globalAlpha = 0.25 + r() * 0.3; c.lineWidth = 0.6 + r() * 0.7; c.beginPath(); c.moveTo(x, y); c.quadraticCurveTo(x + Math.cos(a) * l * 0.5 + (r() - 0.5) * 3, y + Math.sin(a) * l * 0.5 + (r() - 0.5) * 3, x + Math.cos(a) * l, y + Math.sin(a) * l); c.stroke(); }
    c.globalAlpha = 1;
  });
};

// one layer of paper: every piece's shadow first (soft, down and right), then the pieces
const layer = (g: Gfx, pieces: Piece[]) => {
  const shapes = pieces.map((p) => (p.torn ? tear(p.shape, p.torn, p.seed) : cut(p.shape, p.seed)));
  g.group("plain", () => pieces.forEach((p, i) => { const l = p.lift ?? 1; fillShape(g, shapes[i].map(([x, y]) => [x + 3 * l, y + 5 * l] as P), SHADOW, 0.5); }), { blur: 4, alpha: 0.55 });
  g.group("plain", () => pieces.forEach((p, i) => {
    if (p.torn) fillShape(g, tear(p.shape, p.torn * 0.8, p.seed + 1, p.torn * 0.7), PAPER_CORE);     // the white core where the sheet tore
    fillShape(g, shapes[i], p.color);
    fibres(g, shapes[i], p.color, p.seed + 2, p.fibre ?? 1);
  }));
};

const sm = (pts: P[], per = 6) => smooth(pts, true, per);
const shadeIn = (pts: P[], k: number): P[] => sm(pts).map(([x, y]) => [x + k * 0.7, y + k * 0.9] as P);

export const drawHeroPaper = (ctx: Ctx, _frame: number, env: Env) => {
  const g = new Gfx(ctx, env, 0);
  ctx.setTransform(env.scale, 0, 0, env.scale, 0, 0);
  ctx.clearRect(0, 0, S.W, S.H);
  const C = S.C, voice = smooth(S.VOICE, false, 10);

  // the voice: a torn pale strip under a scissor-cut accent strip, and one thin cut echo
  layer(g, [{ shape: tube(voice, 34, 12, true), color: C.high, torn: 2.4, seed: 1, lift: 0.8, fibre: 0.4 }]);
  layer(g, [{ shape: tube(voice.map(([x, y]) => [x + 10, y + 6] as P), 18, 6, true), color: C.accent, seed: 2, lift: 0.6, fibre: 0.3 }]);
  layer(g, [{ shape: tube(voice.slice(8, 60).map(([x, y]) => [x + 52, y - 6] as P), 5, 3, true), color: C.high, seed: 3, lift: 0.4, fibre: 0.2 }]);

  // the back: bun, raised arm, its hand
  layer(g, [{ shape: sm(S.BUN), color: C.hair, torn: 2.6, seed: 10 }]);
  layer(g, [{ shape: sm(S.ARM_UP), color: C.jumper, torn: 2.2, seed: 11 }, { shape: sm(S.CUFF_UP), color: C.collar, seed: 12, lift: 0.5 }]);
  layer(g, [{ shape: sm(S.HAND_UP, 4), color: C.skin, seed: 13 }]);
  // the jumper, its shade side, the neck and the collar
  layer(g, [{ shape: sm(S.JUMPER), color: C.jumper, torn: 2.8, seed: 14 }]);
  layer(g, [{ shape: sm(S.JUMPER_SHADE), color: C.jumperShade, torn: 2.4, seed: 15, lift: 0.4 }]);
  layer(g, [{ shape: sm(S.NECK), color: C.skin, seed: 16, lift: 0.4 }]);
  layer(g, [{ shape: sm(S.COLLAR), color: C.collar, torn: 1.6, seed: 17, lift: 0.5 }]);
  // the head: face, its shade, blush, hair over it, ear
  layer(g, [{ shape: sm(S.FACE), color: C.skin, seed: 18 }]);
  layer(g, [{ shape: sm(S.FACE_SHADE), color: C.skinShade, seed: 19, lift: 0.3 }, { shape: sm(S.BLUSH_L), color: C.blush, torn: 1.4, seed: 20, lift: 0.2 }, { shape: sm(S.BLUSH_R), color: C.blush, torn: 1.4, seed: 21, lift: 0.2 }]);
  layer(g, [{ shape: sm(S.HAIR), color: C.hair, torn: 2.6, seed: 22 }]);
  layer(g, [{ shape: sm(S.HAIR_LIGHT), color: C.hairLight, torn: 1.8, seed: 23, lift: 0.3 }, { shape: sm(S.EAR), color: C.skin, seed: 24, lift: 0.4 }]);
  // features: thin scissor slivers of navy, the open mouth with teeth and tongue
  const sliver = (pts: P[], w: number) => tube(smooth(pts, false, 6), w, w * 0.6, true);
  layer(g, [
    { shape: sliver(S.EYE_L, 7), color: C.ink, seed: 30, lift: 0.3 }, { shape: sliver(S.EYE_R, 6.5), color: C.ink, seed: 31, lift: 0.3 },
    { shape: sliver(S.BROW_L, 6), color: C.hair, seed: 32, lift: 0.3 }, { shape: sliver(S.BROW_R, 5), color: C.hair, seed: 33, lift: 0.3 },
    { shape: sliver(S.NOSE, 4.5), color: C.skinShade, seed: 34, lift: 0.3 },
    { shape: sm(S.MOUTH), color: C.mouth, seed: 35, lift: 0.4 },
  ]);
  layer(g, [{ shape: sm(S.TEETH, 3), color: C.white, seed: 36, lift: 0.2 }, { shape: sm(S.TONGUE), color: C.tongue, seed: 37, lift: 0.2 }]);
  // the front arm, the phone with the dictation arriving on it, the hand round it
  layer(g, [{ shape: sm(S.ARM_FRONT), color: C.jumper, torn: 2.2, seed: 40 }]);
  const ph = S.PHONE_AT, phoneBody = turn(softBox(ph.cx, ph.cy, ph.w, ph.h, 6, 40), ph.cx, ph.cy, ph.deg), screen = turn(softBox(ph.cx, ph.cy, ph.w - 18, ph.h - 18, 6, 40), ph.cx, ph.cy, ph.deg);
  layer(g, [{ shape: phoneBody, color: C.phone, seed: 41 }]);
  layer(g, [{ shape: screen, color: "#E8F0FF", seed: 42, lift: 0.3 }]);
  layer(g, [0, 1, 2].map((k) => ({ shape: turn(softBox(ph.cx - 8 + (k === 2 ? -12 : 0), ph.cy - 40 + k * 28, k === 2 ? 46 : 66, 10, 3, 16), ph.cx, ph.cy, ph.deg), color: C.accent, seed: 43 + k, lift: 0.2 })));
  layer(g, [{ shape: sm(S.HAND_FRONT, 4), color: C.skin, seed: 47 }]);
};

export const heroPaper: Film = {
  meta: { title: "Dictus hero V5 · cut-paper collage", W: S.W, H: S.H, fps: 30, bpm: 120, durationFrames: 1 },
  assets: { images: {} },
  shots: [{ id: "heroPaper", start: 0, end: 1, draw: drawHeroPaper }],
};
