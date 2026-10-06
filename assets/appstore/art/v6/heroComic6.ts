import { Gfx, softBox, tube, turn, type Ctx, type Env, type Medium, type P } from "./core";
import type { Film } from "./film";
import { clipped, fillShape, smooth } from "./gallery";
import * as S from "./heroShapes6";

// DICTUS HERO V6 · marker comic (after koi.ts), the style Pierre chose. Same medium as V5: cel
// fills laid in their shade colour, the lit colour offset toward the light and clipped (one crisp
// terminator), then one heavy navy contour. What changed: the figure stands on a skeleton (arms
// as upper arm + forearm tubes from their own shoulders, a tapered torso), and the voice is three
// hand-drawn marker strokes that travel across the cut into slide 2's recording panel.
// Canvas: 2640 x 2000, transparent, laid over slides 1 and 2 by the screenshot template.

const MARKER: Medium = { nib: 2.4, taper: 0.55, pressure: 0.6, retrace: false, wobble: 0.6, rough: 0.3 };
const LIGHT: P = [-0.6, -0.8];
const sm = (pts: P[], per = 6) => smooth(pts, true, per);

const cel = (g: Gfx, s: P[], lit: string, shade: string, k = 18) => {
  fillShape(g, s, shade);
  clipped(g, s, () => fillShape(g, s.map(([x, y]) => [x + LIGHT[0] * k, y + LIGHT[1] * k] as P), lit));
};
const outline = (g: Gfx, s: P[], w: number, seed: number) =>
  g.pen(s, { w, color: S.C.ink, seed, closed: true, wobble: 0.5, boil: 0, taper: 0.3, opacity: 1, retrace: false });
const stroke = (g: Gfx, pts: P[], w: number, seed: number, color = S.C.ink, taper = 0.9, op = 1) =>
  g.pen(smooth(pts, false, 8), { w, color, seed, closed: false, wobble: 0.5, boil: 0, taper, opacity: op, retrace: false });

// an arm: ONE sleeve along shoulder, elbow and wrist (a bent tube, so a single contour with no
// seam at the elbow), a cuff at the wrist, and a short crease on the inside of the elbow
const arm = (sh: P, el: P, wr: P) => {
  const spine = smooth([sh, el, wr], false, 18);
  const sleeve = tube(spine, 60, 44, true);
  const d = [wr[0] - el[0], wr[1] - el[1]], l = Math.hypot(d[0], d[1]), u = [d[0] / l, d[1] / l];
  const cuff = tube([[wr[0] - u[0] * 34, wr[1] - u[1] * 34], wr], 46, 45, true);
  const n: P = [-u[1], u[0]];
  const crease: P[] = [[el[0] + n[0] * 18 - u[0] * 20, el[1] + n[1] * 18 - u[1] * 20], [el[0] + n[0] * 30, el[1] + n[1] * 30], [el[0] + n[0] * 18 + u[0] * 22, el[1] + n[1] * 18 + u[1] * 22]];
  return { sleeve, cuff, crease };
};
// a sharply bent arm (the phone arm): a tube would fold over itself at the elbow, so the upper
// arm and the forearm are two pieces, the forearm laid over the upper arm as it comes toward us
const bentArm = (sh: P, el: P, wr: P) => {
  const upper = tube([sh, el], 60, 52, true), fore = tube([el, wr], 54, 44, true);
  const d = [wr[0] - el[0], wr[1] - el[1]], l = Math.hypot(d[0], d[1]), u = [d[0] / l, d[1] / l];
  const cuff = tube([[wr[0] - u[0] * 34, wr[1] - u[1] * 34], wr], 46, 45, true);
  return { upper, fore, cuff };
};

// a wavy marker line along a path: the ripple follows the path's normal and grows with distance
const ripple = (pts: P[], amp: number, waves: number): P[] => {
  const s = smooth(pts, false, 14);
  return s.map(([x, y], i) => {
    const a = s[Math.max(0, i - 1)], b = s[Math.min(s.length - 1, i + 1)], dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy) || 1;
    const t = i / (s.length - 1), w = Math.sin(t * Math.PI * waves) * amp * Math.sin(Math.PI * Math.min(1, t * 1.2));
    return [x - (dy / l) * w, y + (dx / l) * w] as P;
  });
};

export const drawHeroComic6 = (ctx: Ctx, _frame: number, env: Env) => {
  const g = new Gfx(ctx, env, 0, MARKER);
  ctx.setTransform(env.scale, 0, 0, env.scale, 0, 0);
  ctx.clearRect(0, 0, S.W, S.H);
  const C = S.C;
  const up = arm(S.SHOULDER_L, S.ELBOW_L, S.WRIST_L), front = bentArm(S.SHOULDER_R, S.ELBOW_R, S.WRIST_R);
  const torso = sm(S.TORSO);

  // the voice: three marker strokes, wavy, fanning from the lips and gathering at the panel
  g.group("plain", () => {
    stroke(g, ripple(S.STROKES[0], 16, 5), 12, 1, C.high, 0.6);
    stroke(g, ripple(S.STROKES[1], 22, 6), 16, 2, C.accent, 0.5);
    stroke(g, ripple(S.STROKES[2], 14, 5), 10, 3, C.accentDeep, 0.6);
    S.SOUND_ARCS.forEach((a, k) => stroke(g, a, 7 - k, 4 + k, C.ink, 0.9, 0.9));
  });

  // the raised arm goes behind the torso: its shoulder disappears under the jumper's edge
  g.group("plain", () => {
    cel(g, sm(S.HAND_UP, 4), C.skin, C.skinShade, 10); outline(g, sm(S.HAND_UP, 4), 5, 12);
    cel(g, up.sleeve, C.jumper, C.jumperShade, 20); outline(g, up.sleeve, 7, 10);
    cel(g, up.cuff, C.collar, C.jumperShade, 6); outline(g, up.cuff, 4, 13);
    cel(g, sm(S.BUN), C.hairLight, C.hair, 14);
    cel(g, torso, C.jumper, C.jumperShade, 46);
    cel(g, sm(S.NECK), C.skin, C.skinShade, 16);
    cel(g, sm(S.COLLAR), C.collar, C.jumperShade, 6);
    cel(g, sm(S.FACE), C.skin, C.skinShade, 26);
    fillShape(g, sm(S.BLUSH_L), C.blush, 0.55); fillShape(g, sm(S.BLUSH_R), C.blush, 0.45);
    cel(g, sm(S.HAIR), C.hairLight, C.hair, 20);
    cel(g, sm(S.EAR), C.skin, C.skinShade, 6);
    fillShape(g, sm(S.MOUTH), C.mouth);
    clipped(g, sm(S.MOUTH), () => { fillShape(g, sm(S.TEETH), C.white); fillShape(g, sm(S.TONGUE), C.tongue); });
    // the front arm, the phone with the dictation arriving, the hand round it
  });
  // the torso and the head get their contours here, before the front arm crosses over them
  g.group("plain", () => {
    outline(g, sm(S.BUN), 6, 14); outline(g, torso, 8, 15); outline(g, sm(S.NECK), 5, 16); outline(g, sm(S.COLLAR), 4, 17);
    outline(g, sm(S.FACE), 6, 18); outline(g, sm(S.HAIR), 7, 19); outline(g, sm(S.EAR), 4, 20);
    stroke(g, S.EYE_L, 6, 21); stroke(g, S.EYE_R, 6, 22); stroke(g, S.BROW_L, 5, 23); stroke(g, S.BROW_R, 4, 24);
    stroke(g, S.NOSE, 4.5, 25); outline(g, sm(S.MOUTH), 4.5, 26);
    stroke(g, [[410, 1300], [440, 1350], [470, 1372]], 3.5, 32); stroke(g, [[690, 1300], [668, 1352], [640, 1374]], 3.5, 33);
  });
  // the front arm, whole (fill and contour), then the phone and the hand over it
  g.group("plain", () => {
    cel(g, front.upper, C.jumper, C.jumperShade, 20); outline(g, front.upper, 7, 27);
    // the shoulder: a round deltoid laid over the sleeve's start, only its outer arc inked,
    // so the arm grows out of the shoulder instead of being stuck on it
    const [sx, sy] = S.SHOULDER_R, ball = Array.from({ length: 28 }, (_, i) => [sx + Math.cos((i / 28) * Math.PI * 2) * 64, sy + Math.sin((i / 28) * Math.PI * 2) * 64] as P);
    cel(g, ball, C.jumper, C.jumperShade, 20);
    stroke(g, Array.from({ length: 10 }, (_, i) => { const a = -1.9 + (i / 9) * 2.3; return [sx + Math.cos(a) * 64, sy + Math.sin(a) * 64] as P; }), 7, 36, C.ink, 0.4);
    cel(g, front.fore, C.jumper, C.jumperShade, 16); outline(g, front.fore, 6.5, 28);
    cel(g, front.cuff, C.collar, C.jumperShade, 6); outline(g, front.cuff, 4, 29);
    const ph = S.PHONE_AT, body = turn(softBox(ph.cx, ph.cy, ph.w, ph.h, 6, 40), ph.cx, ph.cy, ph.deg), screen = turn(softBox(ph.cx, ph.cy, ph.w - 18, ph.h - 18, 6, 40), ph.cx, ph.cy, ph.deg);
    fillShape(g, body, C.phone); fillShape(g, screen, "#E8F0FF");
    [0, 1, 2].forEach((k) => fillShape(g, turn(softBox(ph.cx - 8 + (k === 2 ? -12 : 0), ph.cy - 44 + k * 28, k === 2 ? 46 : 66, 9, 3, 16), ph.cx, ph.cy, ph.deg), C.accent, 0.85));
    outline(g, body, 4, 30);
    cel(g, sm(S.HAND_FRONT, 4), C.skin, C.skinShade, 10); outline(g, sm(S.HAND_FRONT, 4), 5, 31);
  });

  // the crop: the figure fades out below the waist instead of ending on a cut edge
  ctx.save(); ctx.setTransform(env.scale, 0, 0, env.scale, 0, 0);
  ctx.globalCompositeOperation = "destination-out";
  const fade = ctx.createLinearGradient(0, 1480, 0, 1700);
  fade.addColorStop(0, "rgba(0,0,0,0)"); fade.addColorStop(1, "rgba(0,0,0,1)");
  ctx.fillStyle = fade; ctx.fillRect(0, 1480, 1000, 260);
  ctx.restore();
};

export const heroComic6: Film = {
  meta: { title: "Dictus hero V6 · marker comic", W: S.W, H: S.H, fps: 30, bpm: 120, durationFrames: 1 },
  assets: { images: {} },
  shots: [{ id: "heroComic6", start: 0, end: 1, draw: drawHeroComic6 }],
};
