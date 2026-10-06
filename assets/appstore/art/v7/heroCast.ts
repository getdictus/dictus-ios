import { Gfx, softBox, tube, turn, type Ctx, type Env, type Medium, type P } from "./core";
import type { Film } from "./film";
import { clipped, fillShape, smooth } from "./gallery";
import * as V5 from "./heroShapes";

// DICTUS HERO V7 · three characters in the marker comic (the style and colours Pierre validated
// in V6), same composition: a canvas spanning slides 1 and 2, the voice strokes leaving the
// character's mouth and landing at PANEL_IN, the left edge of slide 2's recording panel.
//
// What V7 fixes on every character:
// - FIVE fingers on every visible hand: the raised hand is built finger by finger (four fingers
//   fanned from the knuckles plus a thumb from the side of the palm); the phone hand shows four
//   curled fingertips on one edge of the phone and the thumb on the other.
// - The phone held naturally: low, in front of the waist, a little away from the body, upright
//   with its screen to the viewer; the upper arm hangs from the shoulder, the elbow bends at the
//   side, the forearm comes forward.
// - Anatomy as in V6: each arm from its own shoulder, upper arm and forearm about equal, elbows.
//   Pose reference: a standing adult waving with one hand while holding a phone at waist height
//   in the other, three-quarter view, the usual figure canon with the comic's larger head.
// - Three distinct faces, not one face with three haircuts:
//   WOMAN (V6's character, refitted): rounder face, eyes closed laughing, small hooked nose, bun.
//   MAN: square jaw, open round eyes under heavy straight brows, longer straight nose, short
//   quiff with lighter sides, a light stubble, a wide grin, a buttoned shirt.
//   WOMAN, CURVES: soft oval face, open almond eyes with lashes, small button nose, long wavy hair
//   over one shoulder, a smile with defined lips, a fitted top tucked into high-waisted trousers
//   (waist and hips drawn as the form turns, nothing more).

// Rebuild art/v7/hero-*.png (anidoodle engine; md5 printed as "reproducible"):
//   node ~/.claude/skills/anidoodle/engine/tools/scaffold.mjs /tmp/art --still hero
//   cp assets/appstore/art/v5/heroShapes.ts assets/appstore/art/v7/heroCast.ts /tmp/art/src/canvas-core/
//   for f in heroWoman heroMan heroCurves; do printf 'export { %s } from "./heroCast";\n' $f > /tmp/art/src/canvas-core/$f.ts;
//     printf 'import { %s } from "../canvas-core/heroCast";\nimport { mountFilm } from "./page";\nmountFilm(%s);\n' $f $f > /tmp/art/src/hosts/page-$f.ts; done
//   cd /tmp/art && npm install && npx playwright-core install chromium
//   node tools/still.mjs heroWoman --out out/hero-woman.png   (heroMan, heroCurves likewise)

export const W = 2640, H = 2000;
export const PANEL_IN: P = [1400, 1387];

const MARKER: Medium = { nib: 2.4, taper: 0.55, pressure: 0.6, retrace: false, wobble: 0.6, rough: 0.3 };
const LIGHT: P = [-0.6, -0.8];
const INK = "#0A1628", ACCENT = "#3D7EFF", DEEP = "#2563EB", HIGH = "#6BA3FF", WHITE = "#FFFFFF";
const sm = (pts: P[], per = 6) => smooth(pts, true, per);
const circle = (c: P, r: number, n = 24): P[] => Array.from({ length: n }, (_, i) => [c[0] + Math.cos((i / n) * Math.PI * 2) * r, c[1] + Math.sin((i / n) * Math.PI * 2) * r] as P);

const cel = (g: Gfx, s: P[], lit: string, shade: string, k = 18) => {
  fillShape(g, s, shade);
  clipped(g, s, () => fillShape(g, s.map(([x, y]) => [x + LIGHT[0] * k, y + LIGHT[1] * k] as P), lit));
};
const outline = (g: Gfx, s: P[], w: number, seed: number) =>
  g.pen(s, { w, color: INK, seed, closed: true, wobble: 0.5, boil: 0, taper: 0.3, opacity: 1, retrace: false });
const stroke = (g: Gfx, pts: P[], w: number, seed: number, color = INK, taper = 0.9, op = 1) =>
  g.pen(smooth(pts, false, 8), { w, color, seed, closed: false, wobble: 0.5, boil: 0, taper, opacity: op, retrace: false });
const piece = (g: Gfx, s: P[], lit: string, shade: string, k: number, w: number, seed: number) => { cel(g, s, lit, shade, k); outline(g, s, w, seed); };

// ---------------------------------------------------------------- hands
// The raised hand, palm to the viewer: palm, four fingers fanned from the knuckle line, a thumb
// from the side of the palm. `dir` is the forearm's direction (radians), `s` the scale.
const raisedHand = (wrist: P, dir: number, s: number, thumbSide: 1 | -1 = -1) => {
  const ux = Math.cos(dir), uy = Math.sin(dir), nx = -uy, ny = ux;
  const at = (a: number, b: number): P => [wrist[0] + ux * a * s + nx * b * s, wrist[1] + uy * a * s + ny * b * s];
  const palm = sm([at(0, -34), at(30, -42), at(78, -40), at(84, 0), at(78, 40), at(30, 40), at(0, 32)], 4);
  const fingers = [[-30, 62, -0.16], [-10, 74, -0.05], [10, 70, 0.06], [28, 56, 0.17]].map(([off, len, spread], i) => {
    const base = at(78, off as number), tipDir = dir + (spread as number);
    const tip: P = [base[0] + Math.cos(tipDir) * (len as number) * s, base[1] + Math.sin(tipDir) * (len as number) * s];
    return { shape: tube([base, tip], 12 * s, 10.5 * s, true), seed: 200 + i };
  });
  const tb = at(26, thumbSide * 40), tdir = dir + thumbSide * 0.95;
  const thumb = tube([tb, [tb[0] + Math.cos(tdir) * 58 * s, tb[1] + Math.sin(tdir) * 58 * s]], 13 * s, 11 * s, true);
  return { palm, fingers, thumb };
};

// the phone hand: the palm behind the phone's lower half, four curled fingertips along its right
// edge, the thumb along its left edge, in front
const phoneHand = (ph: { cx: number; cy: number; w: number; h: number; deg: number }) => {
  const rot = (pts: P[]) => turn(pts, ph.cx, ph.cy, ph.deg);
  const x0 = ph.cx - ph.w / 2, x1 = ph.cx + ph.w / 2, yb = ph.cy + ph.h / 2;
  const palm = rot(sm([[x0 - 6, yb - 70], [x1 + 14, yb - 80], [x1 + 30, yb - 10], [x1 + 10, yb + 34], [x0 + 10, yb + 40], [x0 - 14, yb + 6]], 4));
  const tips = [0, 1, 2, 3].map((k) => rot(sm([[x1 - 10, yb - 112 + k * 30], [x1 + 14, yb - 116 + k * 30], [x1 + 22, yb - 98 + k * 30], [x1 + 4, yb - 88 + k * 30], [x1 - 10, yb - 92 + k * 30]], 3)));
  const thumb = rot(tube([[x0 - 4, yb - 10], [x0 + 6, yb - 92]], 14, 12, true));
  return { palm, tips, thumb };
};

// ---------------------------------------------------------------- arms
const sleeveArm = (sh: P, el: P, wr: P) => tube(smooth([sh, el, wr], false, 18), 58, 44, true);
const bentArm = (sh: P, el: P, wr: P) => ({ upper: tube([sh, el], 58, 50, true), fore: tube([el, wr], 52, 44, true) });
const cuffAt = (el: P, wr: P) => { const d = [wr[0] - el[0], wr[1] - el[1]], l = Math.hypot(d[0], d[1]), u = [d[0] / l, d[1] / l]; return tube([[wr[0] - u[0] * 34, wr[1] - u[1] * 34], wr], 46, 45, true); };

// ---------------------------------------------------------------- the voice
const ripple = (pts: P[], amp: number, waves: number): P[] => {
  const s = smooth(pts, false, 14);
  return s.map(([x, y], i) => {
    const a = s[Math.max(0, i - 1)], b = s[Math.min(s.length - 1, i + 1)], dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy) || 1;
    const t = i / (s.length - 1), w = Math.sin(t * Math.PI * waves) * amp * Math.sin(Math.PI * Math.min(1, t * 1.2));
    return [x - (dy / l) * w, y + (dx / l) * w] as P;
  });
};
// three strokes from a mouth to PANEL_IN, fanning out on the way (V6's paths, re-fitted per mouth)
const voiceFrom = (m: P): P[][] => [-24, 0, 24].map((o, k) => {
  const spread = [-46, 0, 46][k];
  return [[m[0] + 14, m[1] + o], [m[0] + 150, m[1] - 30 + o + spread * 0.4], [m[0] + 300, m[1] + 70 + spread], [1130, 920 + spread * 1.2 + (m[1] - 600) * 0.4], [1268, 1250 + spread * 0.8], [PANEL_IN[0], PANEL_IN[1] + o * 1.4]] as P[];
});
const soundArcs = (m: P): P[][] => [0, 1, 2].map((k) => {
  const r = 34 + k * 26;
  return Array.from({ length: 7 }, (_, i) => { const a = -0.75 + (i / 6) * 1.5; return [m[0] - 4 + Math.cos(a) * r, m[1] + 4 + Math.sin(a) * r] as P; });
});

// ---------------------------------------------------------------- characters
type Cast = {
  skin: string; skinShade: string; blush?: string; top: string; topShade: string; cuff: string;
  lower?: { color: string; shade: string; y: number };
  mouth: P; shoulderL: P; elbowL: P; wristL: P; shoulderR: P; elbowR: P; wristR: P;
  phone: { cx: number; cy: number; w: number; h: number; deg: number };
  torso: P[]; torsoShade: P[]; neck: P[]; collar: P[];
  back: (g: Gfx) => void;     // hair behind the head (bun, long hair)
  head: (g: Gfx) => void;     // face, features, hair in front
};

const draw = (c: Cast) => (ctx: Ctx, _frame: number, env: Env) => {
  const g = new Gfx(ctx, env, 0, MARKER);
  ctx.setTransform(env.scale, 0, 0, env.scale, 0, 0);
  ctx.clearRect(0, 0, W, H);
  const torso = sm(c.torso), handUp = raisedHand(c.wristL, Math.atan2(c.wristL[1] - c.elbowL[1], c.wristL[0] - c.elbowL[0]), 1.05);
  const sleeveUp = sleeveArm(c.shoulderL, c.elbowL, c.wristL), front = bentArm(c.shoulderR, c.elbowR, c.wristR), hand = phoneHand(c.phone);

  // the voice first: three marker strokes and the sound arcs at the lips
  g.group("plain", () => {
    const v = voiceFrom(c.mouth);
    stroke(g, ripple(v[0], 16, 5), 12, 1, HIGH, 0.6);
    stroke(g, ripple(v[1], 22, 6), 16, 2, ACCENT, 0.5);
    stroke(g, ripple(v[2], 14, 5), 10, 3, DEEP, 0.6);
    soundArcs(c.mouth).forEach((a, k) => stroke(g, a, 7 - k, 4 + k, INK, 0.9, 0.9));
  });
  g.group("plain", () => {
    // the raised arm behind the torso, its hand with five digits
    piece(g, handUp.palm, c.skin, c.skinShade, 10, 5, 10);
    handUp.fingers.forEach((f) => piece(g, f.shape, c.skin, c.skinShade, 6, 4.5, f.seed));
    piece(g, handUp.thumb, c.skin, c.skinShade, 6, 4.5, 11);
    fillShape(g, handUp.palm, c.skin);                       // the palm over the finger roots
    piece(g, sleeveUp, c.top, c.topShade, 20, 7, 12);
    piece(g, cuffAt(c.elbowL, c.wristL), c.cuff, c.topShade, 6, 4, 13);
    c.back(g);
    // the torso (and trousers for a two-piece outfit), neck, collar
    cel(g, torso, c.top, c.topShade, 46);
    cel(g, sm(c.torsoShade), c.topShade, c.topShade, 0);
    if (c.lower) clipped(g, torso, () => { cel(g, sm([[0, c.lower!.y], [1000, c.lower!.y], [1000, 1800], [0, 1800]]), c.lower!.color, c.lower!.shade, 30); });
    outline(g, torso, 8, 14);
    if (c.lower) clipped(g, torso, () => stroke(g, [[300, c.lower!.y], [820, c.lower!.y]] as P[], 5, 15));
    piece(g, sm(c.neck), c.skin, c.skinShade, 16, 5, 16);
    piece(g, sm(c.collar), c.cuff, c.topShade, 6, 4, 17);
    c.head(g);
  });
  // the phone arm: upper arm hanging, deltoid, forearm forward; then the phone and its hand
  g.group("plain", () => {
    piece(g, front.upper, c.top, c.topShade, 20, 7, 20);
    const ball = circle(c.shoulderR, 62, 28); cel(g, ball, c.top, c.topShade, 20);
    stroke(g, Array.from({ length: 10 }, (_, i) => { const a = -1.9 + (i / 9) * 2.3; return [c.shoulderR[0] + Math.cos(a) * 62, c.shoulderR[1] + Math.sin(a) * 62] as P; }), 7, 21, INK, 0.4);
    piece(g, front.fore, c.top, c.topShade, 16, 6.5, 22);
    piece(g, cuffAt(c.elbowR, c.wristR), c.cuff, c.topShade, 6, 4, 23);
    piece(g, hand.palm, c.skin, c.skinShade, 8, 5, 24);
    const ph = c.phone, rot = (pts: P[]) => turn(pts, ph.cx, ph.cy, ph.deg);
    const body = rot(softBox(ph.cx, ph.cy, ph.w, ph.h, 6, 40)), screen = rot(softBox(ph.cx, ph.cy, ph.w - 18, ph.h - 20, 6, 40));
    fillShape(g, body, INK); fillShape(g, screen, "#E8F0FF");
    [0, 1, 2, 3].forEach((k) => fillShape(g, rot(softBox(ph.cx - 6 + (k === 3 ? -14 : 0), ph.cy - 58 + k * 30, k === 3 ? 48 : 72, 10, 3, 16)), ACCENT, 0.85));
    outline(g, body, 4, 25);
    hand.tips.forEach((t, k) => piece(g, t, c.skin, c.skinShade, 4, 3.5, 26 + k));
    piece(g, hand.thumb, c.skin, c.skinShade, 5, 4, 30);
  });
  // the crop: the figure fades out below the waist
  ctx.save(); ctx.setTransform(env.scale, 0, 0, env.scale, 0, 0);
  ctx.globalCompositeOperation = "destination-out";
  const fade = ctx.createLinearGradient(0, 1480, 0, 1700);
  fade.addColorStop(0, "rgba(0,0,0,0)"); fade.addColorStop(1, "rgba(0,0,0,1)");
  ctx.fillStyle = fade; ctx.fillRect(0, 1480, 1000, 260);
  ctx.restore();
};

// ---------------------------------------------------------------- WOMAN (V6, refitted)
const woman: Cast = {
  skin: "#F3C7A6", skinShade: "#DC9C7E", top: ACCENT, topShade: DEEP, cuff: HIGH,
  mouth: [690, 606],
  shoulderL: [372, 852], elbowL: [246, 690], wristL: [214, 476],
  shoulderR: [728, 856], elbowR: [812, 1074], wristR: [668, 1200],
  phone: { cx: 640, cy: 1104, w: 112, h: 214, deg: -6 },
  torso: [[500, 792], [430, 806], [376, 832], [338, 884], [330, 980], [352, 1120], [386, 1260], [398, 1380], [392, 1520], [386, 1700], [716, 1700], [710, 1520], [704, 1380], [716, 1260], [748, 1120], [770, 980], [764, 884], [728, 834], [672, 806], [600, 792]],
  torsoShade: [[338, 884], [376, 832], [430, 806], [420, 900], [410, 1100], [436, 1300], [446, 1700], [386, 1700], [392, 1520], [398, 1380], [386, 1260], [352, 1120], [330, 980]],
  neck: [[500, 676], [596, 690], [600, 800], [500, 800]],
  collar: [[488, 790], [548, 812], [614, 796], [622, 830], [548, 846], [480, 822]],
  back: (g) => piece(g, sm(V5.BUN), V5.C.hairLight, V5.C.hair, 14, 6, 40),
  head: (g) => {
    piece(g, sm(V5.FACE), V5.C.skin, V5.C.skinShade, 26, 6, 41);
    fillShape(g, sm(V5.BLUSH_L), V5.C.blush, 0.55); fillShape(g, sm(V5.BLUSH_R), V5.C.blush, 0.45);
    piece(g, sm(V5.HAIR), V5.C.hairLight, V5.C.hair, 20, 7, 42);
    piece(g, sm(V5.EAR), V5.C.skin, V5.C.skinShade, 6, 4, 43);
    fillShape(g, sm(V5.MOUTH), INK);
    clipped(g, sm(V5.MOUTH), () => { fillShape(g, sm(V5.TEETH), WHITE); fillShape(g, sm(V5.TONGUE), V5.C.tongue); });
    outline(g, sm(V5.MOUTH), 4.5, 44);
    stroke(g, V5.EYE_L, 6, 45); stroke(g, V5.EYE_R, 6, 46); stroke(g, V5.BROW_L, 5, 47); stroke(g, V5.BROW_R, 4, 48); stroke(g, V5.NOSE, 4.5, 49);
  },
};

// ---------------------------------------------------------------- MAN
const MAN_FACE: P[] = [[446, 362], [520, 330], [604, 336], [660, 378], [690, 438], [702, 500], [700, 556], [692, 616], [676, 668], [636, 712], [566, 730], [500, 716], [460, 690], [428, 630], [410, 540], [414, 446]];
const MAN_HAIR: P[] = [[424, 486], [410, 410], [424, 336], [470, 282], [540, 248], [622, 244], [690, 266], [728, 318], [716, 352], [668, 334], [604, 334], [540, 352], [490, 384], [458, 432], [446, 500], [434, 540]];
const MAN_SIDE: P[] = [[426, 500], [440, 440], [470, 404], [460, 470], [452, 540]];
const man: Cast = {
  skin: "#E2A982", skinShade: "#BE7E5C", top: HIGH, topShade: ACCENT, cuff: WHITE,
  mouth: [694, 612],
  shoulderL: [352, 862], elbowL: [224, 700], wristL: [190, 478],
  shoulderR: [752, 864], elbowR: [836, 1084], wristR: [690, 1210],
  phone: { cx: 662, cy: 1112, w: 116, h: 220, deg: -8 },
  torso: [[492, 806], [410, 818], [346, 846], [306, 902], [298, 1000], [318, 1160], [336, 1320], [340, 1500], [336, 1700], [764, 1700], [760, 1500], [764, 1320], [782, 1160], [804, 1000], [798, 902], [758, 846], [690, 818], [612, 806]],
  torsoShade: [[306, 902], [346, 846], [410, 818], [396, 920], [392, 1160], [404, 1400], [400, 1700], [336, 1700], [340, 1500], [336, 1320], [318, 1160], [298, 1000]],
  neck: [[494, 700], [612, 712], [618, 820], [490, 820]],
  // a shirt collar: two points either side of an open neck
  collar: [[480, 806], [552, 862], [624, 808], [640, 846], [598, 900], [552, 876], [506, 900], [466, 846]],
  back: () => {},
  head: (g) => {
    piece(g, sm(MAN_FACE), "#E2A982", "#BE7E5C", 26, 6, 60);
    // stubble: the jaw a shade darker, a soft band, no line
    clipped(g, sm(MAN_FACE), () => fillShape(g, sm([[440, 610], [500, 640], [580, 660], [650, 640], [700, 600], [700, 740], [420, 740]]), "#A9705A", 0.22));
    piece(g, sm(MAN_HAIR), "#3A3F4A", "#20242C", 18, 7, 61);
    fillShape(g, sm(MAN_SIDE), "#6B7180", 0.55);
    // the hair is hair: a side parting and a few strands swept up into the quiff
    stroke(g, [[520, 356], [560, 300], [620, 262]], 3.5, 69, "#8C93A3", 0.9, 0.9);
    [[[580, 346], [628, 300], [690, 280]], [[628, 336], [672, 304], [716, 316]], [[480, 392], [500, 330], [552, 278]]].forEach((pts, k) => stroke(g, pts as P[], 3, 70 + k, "#12151B", 0.9, 0.7));
    piece(g, sm([[432, 524], [414, 492], [428, 470], [452, 482], [458, 526], [446, 556]]), "#E2A982", "#BE7E5C", 6, 4, 62);
    // heavy straight brows, open round eyes, laugh lines
    stroke(g, [[514, 420], [556, 410], [596, 416]], 9, 63); stroke(g, [[626, 410], [656, 404], [682, 412]], 8, 64);
    fillShape(g, circle([560, 456], 11, 16), INK); fillShape(g, circle([654, 450], 10, 16), INK);
    fillShape(g, circle([563, 452], 3.5, 8), WHITE); fillShape(g, circle([657, 446], 3.2, 8), WHITE);
    stroke(g, [[530, 470], [548, 482], [574, 482]], 3.5, 65, INK, 0.9, 0.7); stroke(g, [[678, 466], [690, 478]], 3, 66, INK, 0.9, 0.6);
    // a longer straight nose
    stroke(g, [[672, 478], [704, 530], [688, 550], [668, 546]], 5, 67);
    // a wide grin, upper teeth and tongue
    const mouth = sm([[578, 600], [640, 594], [694, 590], [692, 624], [672, 654], [632, 668], [598, 660], [580, 632]]);
    fillShape(g, mouth, INK);
    clipped(g, mouth, () => { fillShape(g, sm([[584, 604], [692, 594], [692, 614], [588, 620]], 3), WHITE); fillShape(g, sm([[608, 660], [632, 640], [660, 642], [668, 658], [636, 668]]), "#E7826F"); });
    outline(g, mouth, 4.5, 68);
  },
};

// ---------------------------------------------------------------- WOMAN, CURVES
const C_FACE: P[] = [[455, 366], [530, 336], [608, 346], [662, 396], [688, 460], [694, 522], [682, 582], [656, 634], [612, 674], [556, 690], [500, 678], [456, 642], [428, 586], [418, 516], [426, 440]];
const C_HAIR_BACK: P[] = [[452, 620], [402, 560], [376, 470], [392, 372], [450, 296], [540, 262], [610, 270], [560, 330], [470, 420], [446, 520], [462, 640], [480, 760], [470, 880], [436, 1000], [392, 1070], [340, 1066], [316, 990], [330, 900], [324, 800], [350, 700]];
// side-parted, swept over to the far temple, the forehead left open
const C_HAIR_FRONT: P[] = [[422, 470], [436, 380], [490, 318], [566, 290], [640, 296], [696, 330], [720, 384], [704, 392], [664, 360], [612, 344], [566, 352], [526, 384], [492, 440], [470, 520], [460, 600], [440, 660], [420, 600]];
const curves: Cast = {
  skin: "#F1C09C", skinShade: "#D59674", top: ACCENT, topShade: DEEP, cuff: HIGH,
  lower: { color: "#1E3354", shade: "#0F1E36", y: 1392 },
  mouth: [678, 604],
  shoulderL: [392, 852], elbowL: [270, 700], wristL: [240, 486],
  shoulderR: [716, 854], elbowR: [794, 1070], wristR: [656, 1196],
  phone: { cx: 628, cy: 1100, w: 108, h: 208, deg: -7 },
  // a fitted top: the bust as the form turns, a defined waist, the hips flaring into the trousers
  torso: [[500, 794], [440, 806], [392, 830], [358, 878], [348, 960], [362, 1040], [392, 1140], [420, 1240], [428, 1310], [416, 1390], [392, 1480], [370, 1570], [364, 1700], [744, 1700], [740, 1570], [722, 1480], [698, 1390], [686, 1310], [694, 1240], [722, 1140], [752, 1040], [762, 960], [754, 880], [722, 832], [668, 806], [604, 794]],
  torsoShade: [[358, 878], [392, 830], [440, 806], [430, 900], [436, 1100], [460, 1300], [452, 1392], [416, 1390], [428, 1310], [420, 1240], [392, 1140], [362, 1040], [348, 960]],
  neck: [[506, 670], [596, 684], [600, 798], [506, 798]],
  // a V neckline
  collar: [[488, 792], [552, 880], [616, 794], [628, 812], [552, 912], [476, 812]],
  back: (g) => piece(g, sm(C_HAIR_BACK), "#2C3F66", "#18264A", 18, 7, 80),
  head: (g) => {
    piece(g, sm(C_FACE), "#F1C09C", "#D59674", 26, 6, 81);
    fillShape(g, sm([[514, 540], [544, 526], [568, 538], [554, 560], [524, 562]]), "#EE9D86", 0.45);
    fillShape(g, sm([[650, 524], [672, 516], [684, 532], [670, 548]]), "#EE9D86", 0.4);
    piece(g, sm(C_HAIR_FRONT), "#3A5486", "#1E2F55", 16, 6, 82);
    // almond eyes, open, with lashes; thin arched brows
    const eyeL = sm([[528, 464], [548, 448], [576, 450], [594, 464], [574, 474], [548, 474]], 4), eyeR = sm([[630, 458], [648, 444], [670, 446], [682, 458], [666, 468], [644, 468]], 4);
    fillShape(g, eyeL, WHITE); fillShape(g, eyeR, WHITE);
    fillShape(g, circle([562, 462], 11, 16), "#2F4C7A"); fillShape(g, circle([658, 457], 10, 16), "#2F4C7A");
    fillShape(g, circle([562, 462], 5, 10), INK); fillShape(g, circle([658, 457], 4.5, 10), INK);
    fillShape(g, circle([566, 458], 2.6, 8), WHITE); fillShape(g, circle([661, 453], 2.4, 8), WHITE);
    stroke(g, [[526, 466], [548, 448], [576, 450], [596, 466]], 5.5, 83); stroke(g, [[628, 460], [648, 444], [670, 446], [684, 460]], 5, 84);
    stroke(g, [[596, 466], [606, 456]], 3, 85); stroke(g, [[684, 460], [694, 450]], 3, 86);
    stroke(g, [[528, 424], [556, 410], [588, 416]], 4, 87); stroke(g, [[630, 414], [652, 404], [676, 410]], 3.5, 88);
    // a small button nose
    stroke(g, [[666, 492], [680, 520], [664, 528]], 4, 89);
    // a smile with defined lips
    const mouth = sm([[588, 588], [630, 580], [670, 576], [670, 602], [654, 626], [626, 638], [600, 632], [588, 610]]);
    fillShape(g, mouth, INK);
    clipped(g, mouth, () => { fillShape(g, sm([[592, 592], [668, 580], [668, 598], [596, 604]], 3), WHITE); fillShape(g, sm([[606, 630], [626, 618], [648, 620], [652, 632], [628, 640]]), "#E7826F"); });
    g.pen(smooth([[582, 584], [628, 572], [676, 570]], false, 6), { w: 7, color: "#C9645A", seed: 90, wobble: 0.3, boil: 0, taper: 0.9, opacity: 0.85, retrace: false });
    g.pen(smooth([[594, 640], [628, 646], [658, 630]], false, 6), { w: 6, color: "#C9645A", seed: 91, wobble: 0.3, boil: 0, taper: 0.9, opacity: 0.75, retrace: false });
    outline(g, mouth, 4, 92);
    // a small earring in the Dictus accent
    fillShape(g, circle([436, 560], 9, 14), ACCENT); outline(g, circle([436, 560], 9, 14), 2.5, 93);
  },
};

const film = (id: string, title: string, c: Cast): Film => ({
  meta: { title, W, H, fps: 30, bpm: 120, durationFrames: 1 }, assets: { images: {} },
  shots: [{ id, start: 0, end: 1, draw: draw(c) }],
});
export const heroWoman = film("heroWoman", "Dictus hero V7 · woman", woman);
export const heroMan = film("heroMan", "Dictus hero V7 · man", man);
export const heroCurves = film("heroCurves", "Dictus hero V7 · woman, curves", curves);
