import { Gfx, softBox, tube, turn, type Medium, type P } from "./core";
import { clipped, fillShape, smooth } from "./gallery";
import { THEMES, type Loop, type Theme } from "./theme";

// THE WOMAN (issue #667): the App Store hero V15-B's character (assets/appstore/art/v15-B/
// heroWalk15.ts, untouched), drawn once and posed by the scenes. Scene A walks her, scene B
// stands her in a metro carriage holding a pole. Her face, hair, top, trousers, trainers and
// hands are V15-B's lines and colours; what a scene chooses is the pose (legs, the near arm, what
// that hand carries, the body's bob and sway).
//
// One thing differs from V15-B: the trousers are two legs and a seat instead of one silhouette,
// because one outline round both legs cannot survive them crossing in the walk. Her phone is
// V15-B's, seen from the back as she holds it to her mouth (the way anyone talks into a phone);
// her voice goes into it.
//
// The walk (legAt): a leg is its hip, its foot (heel point, sole angle, toe bend) and two bone
// lengths; the knee is solved from them. V15-B's pose is the cycle's CONTACT position (Richard
// Williams, The Animator's Survival Kit, walk chapter): phase 0 is the far leg's heel strike and
// phase 0.5 the near leg's push-off, and the solver gives back V15-B's knees to the pixel. In
// between: down, passing and up, keyed in FOOT.

export const MARKER: Medium = { nib: 2.4, taper: 0.55, pressure: 0.6, retrace: false, wobble: 0.6, rough: 0.3 };
export const LIGHT: P = [-0.6, -0.8];
export const ACCENT = "#3D7EFF", DEEP = "#2563EB", HIGH = "#6BA3FF", WHITE = "#FFFFFF";
export const SKIN = "#F1C09C", SKIN_SH = "#D59674";
const PANTS = "#1E3354", PANTS_SH = "#0F1E36";
export const sm = (pts: P[], per = 6) => smooth(pts, true, per);
export const circle = (c: P, r: number, n = 24): P[] => Array.from({ length: n }, (_, i) => [c[0] + Math.cos((i / n) * Math.PI * 2) * r, c[1] + Math.sin((i / n) * Math.PI * 2) * r] as P);
export const shift = (pts: P[], dx: number, dy: number): P[] => pts.map(([x, y]) => [x + dx, y + dy]);
export const clamp = (v: number, a = 0, b = 1) => Math.max(a, Math.min(b, v));

// line weights are multiplied by LW: the head is drawn at HEAD_S, so its V7 weights are raised to
// match the body's. T is the appearance being drawn. Both are set at the top of every frame and
// read only while it draws, so a frame stays a pure function of (frame, theme).
let LW = 1;
let T: Theme = THEMES.light;
/** set the appearance for a scene's own marks drawn with these helpers (the ground, the carriage) */
export const setTheme = (t: Theme) => { T = t; };
export const cel = (g: Gfx, s: P[], lit: string, shade: string, k = 18) => {
  fillShape(g, s, shade);
  clipped(g, s, () => fillShape(g, s.map(([x, y]) => [x + LIGHT[0] * k, y + LIGHT[1] * k] as P), lit));
};
export const outline = (g: Gfx, s: P[], w: number, seed: number, color = T.line) =>
  g.pen(s, { w: w * LW, color, seed, closed: true, wobble: 0.5, boil: 0, taper: 0.3, opacity: 1, retrace: false });
export const stroke = (g: Gfx, pts: P[], w: number, seed: number, color = T.line, taper = 0.9, op = 1) =>
  g.pen(smooth(pts, false, 8), { w: w * LW, color, seed, closed: false, wobble: 0.5, boil: 0, taper, opacity: op, retrace: false });
export const piece = (g: Gfx, s: P[], lit: string, shade: string, k: number, w: number, seed: number) => { cel(g, s, lit, shade, k); outline(g, s, w, seed); };
// the seat's shading: the shade only down its side away from the light, never along its bottom,
// where a band of shade read as a bulge between the legs
const celAcross = (g: Gfx, s: P[], lit: string, shade: string, k: number) => {
  fillShape(g, s, shade);
  clipped(g, s, () => fillShape(g, s.map(([x, y]) => [x + LIGHT[0] * k, y + 40] as P), lit));
};

// ---------------------------------------------------------------- path utilities (V15-B's)
export type Path = { pts: P[]; len: number[]; total: number };
export const pathOf = (ctrl: P[], per = 24): Path => {
  const pts = smooth(ctrl, false, per), len = [0];
  for (let i = 1; i < pts.length; i++) len.push(len[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]));
  return { pts, len, total: len[len.length - 1] };
};
export const at = (p: Path, s: number): { p: P; t: P } => {
  const v = Math.max(0, Math.min(p.total, s));
  let i = 1; while (i < p.len.length - 1 && p.len[i] < v) i++;
  const a = p.pts[i - 1], b = p.pts[i], f = (v - p.len[i - 1]) / Math.max(1e-6, p.len[i] - p.len[i - 1]);
  const dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy) || 1;
  return { p: [a[0] + dx * f, a[1] + dy * f], t: [dx / l, dy / l] };
};
export const off = (p: Path, s: number, v: number): P => { const { p: c, t } = at(p, s); return [c[0] + t[1] * v, c[1] - t[0] * v]; };
// a limb's two edges from its joints, half-widths at each joint
const limb = (joints: P[], hws: number[], n = 40): { left: P[]; right: P[] } => {
  const c = smooth(joints, false, 14), L: P[] = [], R: P[] = [];
  for (let k = 0; k <= n; k++) {
    const u = k / n, i = Math.min(c.length - 2, Math.floor(u * (c.length - 1))), a = c[i], b = c[i + 1];
    const f = u * (c.length - 1) - i, p: P = [a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f];
    const dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy) || 1;
    const seg = u * (hws.length - 1), j = Math.min(hws.length - 2, Math.floor(seg)), hw = hws[j] + (hws[j + 1] - hws[j]) * (seg - j);
    L.push([p[0] + (dy / l) * hw, p[1] - (dx / l) * hw]); R.push([p[0] - (dy / l) * hw, p[1] + (dx / l) * hw]);
  }
  return { left: L, right: R };
};
// a limb with round ends, both of them: a shoulder is a ball, never a corner
export const limbTube = (joints: P[], r0: number, r1: number): P[] => {
  const c = smooth(joints, false, 14), n = c.length, L: P[] = [], R: P[] = [];
  const dir = (i: number): P => { const a = c[Math.max(0, i - 1)], b = c[Math.min(n - 1, i + 1)], l = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1; return [(b[0] - a[0]) / l, (b[1] - a[1]) / l]; };
  c.forEach((p, i) => { const [dx, dy] = dir(i), r = r0 + ((r1 - r0) * i) / (n - 1); L.push([p[0] - dy * r, p[1] + dx * r]); R.push([p[0] + dy * r, p[1] - dx * r]); });
  const arc = (p: P, r: number, a0: number, sgn: number): P[] => Array.from({ length: 5 }, (_, k) => { const a = a0 + sgn * ((k + 1) / 6) * Math.PI; return [p[0] + Math.cos(a) * r, p[1] + Math.sin(a) * r] as P; });
  const aEnd = Math.atan2(dir(n - 1)[1], dir(n - 1)[0]), aStart = Math.atan2(dir(0)[1], dir(0)[0]);
  return [...L, ...arc(c[n - 1], r1, aEnd + Math.PI / 2, -1), ...R.reverse(), ...arc(c[0], r0, aStart - Math.PI / 2, -1)];
};

// ---------------------------------------------------------------- the figure (V15-B's, figure space)
export const FIG = { at: [4.8, -72] as P, s: 1.06 };
export const fig = ([x, y]: P): P => [FIG.at[0] + x * FIG.s, FIG.at[1] + y * FIG.s];

export const SHADOW: P[] = [[150, 2404], [300, 2436], [450, 2452], [640, 2460], [800, 2456], [930, 2476], [1046, 2508], [1104, 2540], [1044, 2562], [880, 2558], [700, 2534], [520, 2510], [330, 2480], [168, 2432]];

export const HEAD_AT: P = [401, 970], HEAD_S = 0.78;
export const hv = ([x, y]: P): P => [HEAD_AT[0] + (x - 560) * HEAD_S, HEAD_AT[1] + (y - 500) * HEAD_S];
export const MOUTH_F = hv([688, 602]);   // her lips, figure space

// V15-B's limbs at the contact position: hip, knee, ankle; shoulder, elbow, wrist
export const LEG_FAR = [[452, 1680], [566, 2020], [660, 2370]] as P[];    // her left, reaching forward, heel striking
export const LEG_NEAR = [[344, 1690], [350, 2010], [200, 2296]] as P[];   // her right, behind, heel lifted
export const ARM_NEAR = [[298, 1238], [322, 1450], [376, 1650]] as P[];   // her right, swung forward, the tote
export const ARM_FAR = [[500, 1228], [566, 1456], [650, 1278]] as P[];    // her left, the phone up at her chin
export const BAG_D: P = [36, -14];

const TORSO: P[] = [[368, 1160], [330, 1172], [292, 1192], [266, 1226], [262, 1290], [276, 1380], [294, 1468], [300, 1532], [482, 1528], [476, 1478], [492, 1420], [516, 1362], [524, 1300], [520, 1242], [502, 1198], [462, 1174], [428, 1162]];
const TORSO_SH: P[] = [[266, 1226], [292, 1192], [330, 1174], [320, 1260], [320, 1360], [336, 1530], [300, 1532], [294, 1468], [276, 1380], [262, 1290]];
const NECK: P[] = [hv([506, 672]), hv([596, 686]), [430, 1174], [368, 1170]];
const VNECK: P[] = [[362, 1162], [404, 1224], [436, 1162], [446, 1172], [404, 1252], [352, 1172]];
const HAIR_BACK: P[] = [[452, 620], [402, 560], [376, 470], [392, 372], [450, 296], [540, 262], [610, 270], [560, 330], [470, 420], [446, 520], [462, 640], [470, 760], [452, 880], [410, 990], [350, 1074], [296, 1102], [262, 1090], [296, 1040], [300, 960], [300, 860], [320, 760], [340, 690]];
const HAIR_STRANDS: P[][] = [[[430, 700], [420, 840], [380, 960], [320, 1060]], [[390, 640], [370, 780], [350, 900], [300, 1000]], [[440, 560], [440, 700], [430, 820]]];

// the seat of the high-waisted trousers, waist to crotch, over both legs' tops (V15-B's outline
// there, its sides ending where the legs' outer edges leave the hips); SEAT_TOP is the band of it
// painted again, with the seat's own shading, over the near thigh so its cut end never shows
const SEAT: P[] = [[300, 1524], [280, 1572], [268, 1630], [280, 1690], [340, 1708], [404, 1716], [466, 1700], [510, 1664], [514, 1630], [500, 1572], [484, 1524]];
const SEAT_TOP: P[] = [[300, 1524], [280, 1572], [268, 1630], [282, 1694], [404, 1712], [510, 1668], [514, 1630], [500, 1572], [484, 1524]];
const SEAT_L: P[] = [[300, 1524], [280, 1572], [268, 1630], [282, 1690]], SEAT_R: P[] = [[484, 1524], [500, 1572], [514, 1630], [509, 1662]];

// ---------------------------------------------------------------- the walk
const TRAINER: P[] = [[0, -8], [4, -50], [28, -62], [58, -58], [98, -46], [140, -36], [172, -26], [190, -12], [188, 4], [150, 8], [80, 8], [8, 6]];
const T_SOLE: P[] = [[-2, 2], [80, 6], [150, 6], [190, 0], [194, 12], [150, 20], [80, 20], [0, 16]];
const T_LACES: P[][] = [[[66, -56], [80, -68]], [[88, -50], [102, -62]], [[110, -44], [124, -56]]];
const BALL = 128;
const placeShoe = (pts: P[], heel: P, deg: number, bend = 0): P[] => turn(pts.map(([x, y]) => {
  const f = Math.max(0, Math.min(1, (x - BALL + 8) / 26)), a = (-bend * f * Math.PI) / 180, dx = x - BALL, dy = y - 4;
  const [bx, by] = f > 0 ? [BALL + dx * Math.cos(a) - dy * Math.sin(a), 4 + dx * Math.sin(a) + dy * Math.cos(a)] : [x, y];
  return [heel[0] + bx, heel[1] + by] as P;
}), heel[0], heel[1], deg);

// The foot through one cycle of ITS leg, ten keys a tenth of a cycle apart: the heel point
// relative to the hip (x, y), the sole's angle (negative lifts the toe) and the toe bend.
// Stance, 0 to 0.5: the foot is planted, so its keys slide back by STEP / 5 a key; it rolls from
// the heel onto the flat foot, then up onto the ball (bend = angle keeps the toes flat on the
// slab). Swing, 0.6 to 0.9: toe-off, passing with the foot tucked under, the reach.
// Key 0 is V15-B's far shoe, key 5 its near shoe, both relative to their own hip.
const FOOT: [number, number, number, number][] = [
  [199, 743, -24, 0],    // contact: heel strike, toes up
  [112, 735, -4, 0],     // down: the foot slaps flat
  [25, 729, 0, 0],
  [-61, 722, 0, 0],      // passing (the other leg swings by)
  [-139, 673, 20, 20],   // the heel peels up, the ball stays
  [-197, 617, 45, 45],   // push-off, on the ball
  [-246, 590, 65, 30],   // toe-off
  [-175, 586, 40, 8],    // the foot tucked under, the knee forward
  [-40, 610, 30, 0],     // passing, the toe hanging
  [130, 696, -4, 0],     // the reach, the toe coming up for the strike
];
// a closed Catmull-Rom through the keys: smooth, and periodic over one cycle
export const footAt = (u: number): [number, number, number, number] => {
  const n = FOOT.length, x = (((u % 1) + 1) % 1) * n, i = Math.floor(x), t = x - i;
  const k = (j: number) => FOOT[(j + n) % n];
  const p0 = k(i - 1), p1 = k(i), p2 = k(i + 1), p3 = k(i + 2);
  return p1.map((_, c) => 0.5 * (2 * p1[c] + (-p0[c] + p2[c]) * t + (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t * t + (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t * t * t)) as [number, number, number, number];
};
// the ankle in the shoe's own frame: the SAME point on both of V15-B's shoes (29.8, -45 from the
// heel, unrotated), which is what lets one rig carry either leg
const ANKLE_IN_SHOE: P = [29.8, -45];
// bone lengths: V15-B drew the pushing leg a little shorter (it bends away from us); the bones
// take that length round push-off and the reaching leg's elsewhere
export const BONES_FRONT: P = [358.6, 362.4], BONES_BACK: P = [320, 323];
const bonesAt = (u: number): P => { const d = Math.abs((((u % 1) + 1) % 1) - 0.5), w = Math.exp(-((d / 0.12) ** 2)); return [BONES_FRONT[0] + (BONES_BACK[0] - BONES_FRONT[0]) * w, BONES_FRONT[1] + (BONES_BACK[1] - BONES_FRONT[1]) * w]; };
// the body sinks at contact and rises at passing, twice a cycle; 0 at contact, so frame 0 is V15-B
const BOB = 7;
export const bobAt = (u: number) => BOB * (Math.cos(4 * Math.PI * u) - 1);

export type Leg = { hip: P; knee: P; ankle: P; heel: P; deg: number; bend: number };
// a two-bone solve: from `a` to `c` with bones l1 and l2, the joint bending to the side `bend`
// (+1: to the left of a -> c, which for a leg drawn downward is +x, forward)
export const twoBone = (a: P, c: P, l1: number, l2: number, bend: 1 | -1 = 1): P => {
  const dx = c[0] - a[0], dy = c[1] - a[1], d = Math.hypot(dx, dy), ux = dx / d, uy = dy / d;
  if (d >= l1 + l2) return [a[0] + ux * d * (l1 / (l1 + l2)), a[1] + uy * d * (l1 / (l1 + l2))];
  const along = (l1 * l1 - l2 * l2 + d * d) / (2 * d), h = Math.sqrt(Math.max(0, l1 * l1 - along * along)) * bend;
  return [a[0] + ux * along + uy * h, a[1] + uy * along - ux * h];
};
/** a leg from its hip (figure space, before the body's sway), a foot key (heel relative to that
 *  hip, sole angle, toe bend) and two bones, under a body moved by (lean, bob) */
export const legFrom = (hip0: P, foot: [number, number, number, number], bones: P, bob: number, lean = 0): Leg => {
  const [hx, hy, deg, bend] = foot, heel: P = [hip0[0] + hx, hip0[1] + hy];
  const a = (deg * Math.PI) / 180, ankle: P = [heel[0] + ANKLE_IN_SHOE[0] * Math.cos(a) - ANKLE_IN_SHOE[1] * Math.sin(a), heel[1] + ANKLE_IN_SHOE[0] * Math.sin(a) + ANKLE_IN_SHOE[1] * Math.cos(a)];
  const hip: P = [hip0[0] + lean, hip0[1] + bob];
  return { hip, knee: twoBone(hip, ankle, bones[0], bones[1]), ankle, heel, deg, bend };
};
/** a leg at phase `u` of the walk cycle */
export const legAt = (hip0: P, u: number, bob: number): Leg => legFrom(hip0, footAt(u), bonesAt(u), bob);

// ---------------------------------------------------------------- hands
export const fist = (d: P) => {
  const [dx, dy] = d;
  const back = sm(shift([[322, 1668], [362, 1664], [382, 1690], [386, 1736], [368, 1762], [336, 1760], [318, 1726]], dx, dy), 4);
  const fingers = [0, 1, 2, 3].map((k) => { const y = 1702 + k * 16 + dy, r = [40, 42, 38, 30][k]; return tube([[350 + dx, y], [350 + dx + r * 0.7, y - 1], [350 + dx + r, y + 6]], 9.5, 8.5, true); });
  const thumb = tube(shift([[346, 1680], [372, 1684], [394, 1700]], dx, dy), 10.5, 9, true);
  return { back, fingers, thumb };
};
export const PHONE = { cx: 596, cy: 1150, w: 104, h: 208, deg: -10 };
const phoneHand = (ph: (pts: P[]) => P[]) => {
  const back = sm(ph([[8, 36], [50, 26], [66, 66], [62, 110], [36, 132], [4, 124], [-10, 88]]), 4);
  const fingers = [0, 1, 2, 3].map((k) => { const v = 18 + k * 21, r = [92, 96, 90, 76][k]; return tube(ph([[30, v + 6], [30 - r * 0.6, v], [30 - r, v - 4]]), 10.5, 9.5, true); });
  const thumb = tube(ph([[44, 54], [54, 14], [58, -24]]), 11.5, 10, true);
  return { back, fingers, thumb };
};

// ---------------------------------------------------------------- the head (V7 "woman, curves", V7 coordinates)
const C_FACE: P[] = [[455, 366], [530, 336], [608, 346], [662, 396], [688, 460], [694, 522], [682, 582], [656, 634], [612, 674], [556, 690], [500, 678], [456, 642], [428, 586], [418, 516], [426, 440]];
const C_HAIR_FRONT: P[] = [[422, 470], [436, 380], [490, 318], [566, 290], [640, 296], [696, 330], [720, 384], [704, 392], [664, 360], [612, 344], [566, 352], [526, 384], [492, 440], [470, 520], [460, 600], [440, 660], [420, 600]];
const inHead = (g: Gfx, fn: () => void) => { g.push(HEAD_AT[0] - 560 * HEAD_S, HEAD_AT[1] - 500 * HEAD_S, HEAD_S); LW = 1.35; fn(); LW = 1; g.pop(); };
// the hair's ends trail the walk: points below the nape swing back and forth with the steps,
// more the lower they hang, a little after the body moves
const sway = (pts: P[], u: number): P[] => pts.map(([x, y]) => { const w = clamp((y - 720) / 380); return [x - 9 * w * w * (1 + Math.cos(4 * Math.PI * u - 0.9)), y - 4 * w * Math.sin(4 * Math.PI * u - 0.9)] as P; });
const hairBack = (g: Gfx, u: number) => {
  piece(g, sm(sway(HAIR_BACK, u)), "#2C3F66", "#18264A", 18, 7, 80);
  HAIR_STRANDS.forEach((s, k) => stroke(g, sway(s, u), 3, 84 + k, "#4A6496", 0.9, 0.8));
};
// talking: the jaw opens and closes on two beats that never line up, between 70 % and 100 % of
// the drawn mouth; the upper lip stays where V7 drew it
export const mouthOpen = (lp: Loop, frame: number) => 0.85 + 0.15 * (0.62 * lp.cyc(frame, 11) + 0.38 * lp.cyc(frame, 17, 1.3));
const head = (g: Gfx, open: number) => {
  const jaw = (pts: P[]): P[] => pts.map(([x, y]) => [x, y > 584 ? 584 + (y - 584) * open : y] as P);
  piece(g, sm(C_FACE), SKIN, SKIN_SH, 26, 6, 81);
  fillShape(g, sm([[514, 540], [544, 526], [568, 538], [554, 560], [524, 562]]), "#EE9D86", 0.45);
  fillShape(g, sm([[650, 524], [672, 516], [684, 532], [670, 548]]), "#EE9D86", 0.4);
  piece(g, sm(C_HAIR_FRONT), "#3A5486", "#1E2F55", 16, 6, 82);
  const eyeL = sm([[528, 464], [548, 448], [576, 450], [594, 464], [574, 474], [548, 474]], 4), eyeR = sm([[630, 458], [648, 444], [670, 446], [682, 458], [666, 468], [644, 468]], 4);
  fillShape(g, eyeL, WHITE); fillShape(g, eyeR, WHITE);
  fillShape(g, circle([562, 462], 11, 16), "#2F4C7A"); fillShape(g, circle([658, 457], 10, 16), "#2F4C7A");
  fillShape(g, circle([562, 462], 5, 10), T.ink); fillShape(g, circle([658, 457], 4.5, 10), T.ink);
  fillShape(g, circle([566, 458], 2.6, 8), WHITE); fillShape(g, circle([661, 453], 2.4, 8), WHITE);
  stroke(g, [[526, 466], [548, 448], [576, 450], [596, 466]], 5.5, 83, T.ink); stroke(g, [[628, 460], [648, 444], [670, 446], [684, 460]], 5, 84, T.ink);
  stroke(g, [[596, 466], [606, 456]], 3, 85, T.ink); stroke(g, [[684, 460], [694, 450]], 3, 86, T.ink);
  stroke(g, [[528, 424], [556, 410], [588, 416]], 4, 87, T.ink); stroke(g, [[630, 414], [652, 404], [676, 410]], 3.5, 88, T.ink);
  stroke(g, [[666, 492], [680, 520], [664, 528]], 4, 89, T.ink);
  const mouth = sm(jaw([[588, 588], [630, 580], [670, 576], [670, 602], [654, 626], [626, 638], [600, 632], [588, 610]]));
  fillShape(g, mouth, T.ink);
  clipped(g, mouth, () => { fillShape(g, sm([[592, 592], [668, 580], [668, 598], [596, 604]], 3), WHITE); fillShape(g, sm(jaw([[606, 630], [626, 618], [648, 620], [652, 632], [628, 640]])), "#E7826F"); });
  g.pen(smooth([[582, 584], [628, 572], [676, 570]], false, 6), { w: 7 * LW, color: "#C9645A", seed: 90, wobble: 0.3, boil: 0, taper: 0.9, opacity: 0.85, retrace: false });
  g.pen(smooth(jaw([[594, 640], [628, 646], [658, 630]]), false, 6), { w: 6 * LW, color: "#C9645A", seed: 91, wobble: 0.3, boil: 0, taper: 0.9, opacity: 0.75, retrace: false });
  outline(g, mouth, 4, 92, T.ink);
  fillShape(g, circle([436, 560], 9, 14), ACCENT); outline(g, circle([436, 560], 9, 14), 2.5, 93);
};

const strap = (g: Gfx, pts: P[], w: number, color: string, seed: number) => { stroke(g, pts, w + 3.2, seed, T.line, 0.1); stroke(g, pts, w, seed + 1, color, 0.1); };

// one trouser leg: the limb's two edges from above the hip (so its cut top lies well inside the
// seat, which covers it) down to the hem at the ankle; the far leg a half-tone back
const trouserLeg = (g: Gfx, leg: Leg, hws: number[], far: boolean, seed: number) => {
  const top: P = [leg.hip[0] + (leg.hip[0] - leg.knee[0]) * 0.2, leg.hip[1] - 70];
  const { left, right } = limb([top, leg.hip, leg.knee, leg.ankle], [hws[0], ...hws]), s = sm([...left, ...[...right].reverse()], 3);
  cel(g, s, PANTS, PANTS_SH, 22);
  if (far) clipped(g, s, () => fillShape(g, s, PANTS_SH, 0.35));
  outline(g, s, 5.5, seed);
};
const shoe = (g: Gfx, leg: Leg, k: number) => {
  piece(g, sm(placeShoe(TRAINER, leg.heel, leg.deg, leg.bend), 4), WHITE, T.shoeShade, 10, 5, 102 + k * 2);
  piece(g, sm(placeShoe(T_SOLE, leg.heel, leg.deg, leg.bend), 4), T.sole, T.soleShade, 4, 4, 103 + k * 2);
  T_LACES.forEach((l, j) => stroke(g, placeShoe(l, leg.heel, leg.deg, leg.bend), 2.6, 106 + k * 3 + j));
  // the crease across the vamp where the shoe flexes, as deep as the flex
  if (leg.bend > 4) stroke(g, placeShoe([[BALL - 6, -30], [BALL + 2, -12], [BALL + 4, 0]] as P[], leg.heel, leg.deg, leg.bend), 2.6, 115, T.line, 0.9, 0.7 * clamp(leg.bend / 30));
};
// the knee creases ride on the knees: V15-B's, relative to its knees
const CREASE_FAR: P[][] = [[[-26, -20], [2, 0], [28, -6]]];
const CREASE_NEAR: P[][] = [[[-34, -20], [-6, 14], [28, 8]], [[-30, 36], [-10, 50]]];
// ---------------------------------------------------------------- the phone, front
// her voice goes into the phone here, phone-local (u across, v down from the centre): past its
// top edge, so the strokes end behind the phone
export const PHONE_IN: P = [-4, -60];

/** what a scene asks of her: the posed legs, the body's bob (down) and lean (forward), the walk
 *  phase her hair trails, the mouth's opening, the near arm (shoulder, elbow, wrist) and what its
 *  hand does, and the phone's tilt */
export type Carry = { kind: "tote"; toteD: P; fistD: P } | { kind: "pole"; fistD: P };
export type Pose = { far: Leg; near: Leg; bob: number; lean: number; hairU: number; open: number; armNear: P[]; carry: Carry; phoneDeg: number };
/** the phone's mapping from its local (u, v) to figure space, for a pose */
export const phoneMap = (pose: Pose) => (pts: P[]): P[] => turn(pts.map(([x, y]) => [PHONE.cx + pose.lean + x, PHONE.cy + pose.bob + y] as P), PHONE.cx + pose.lean, PHONE.cy + pose.bob, pose.phoneDeg);
/** her lips in figure space, for a pose */
export const mouthAt = (pose: Pose): P => [MOUTH_F[0] + pose.lean, MOUTH_F[1] + pose.bob];

/**
 * Draw her, in figure space: the caller has pushed FIG. `voice` is drawn just before the phone
 * and the hand holding it, so the voice's strokes end behind the phone: they are seen going in.
 */
export const drawWoman = (g: Gfx, theme: Theme, pose: Pose, voice: () => void) => {
  T = theme;
  const { far, near, bob, lean } = pose, bodyFig = (pts: P[]) => shift(pts, lean, bob);
  const layer = (fn: () => void) => g.group("plain", fn);

  // her shadow on the ground, stretched a little toward whichever foot is out in front
  layer(() => fillShape(g, sm(SHADOW.map(([x, y]) => [x + (far.heel[0] - 651) * 0.25 * clamp((x - 150) / 500), y] as P)), T.shadow, T.shadowA));
  // behind the body: the hair down her back, the phone arm's upper arm
  layer(() => {
    g.push(lean, bob, 1); inHead(g, () => hairBack(g, pose.hairU)); g.pop();
    piece(g, limbTube(bodyFig([ARM_FAR[0], ARM_FAR[1]]), 40, 34), ACCENT, DEEP, 14, 5.5, 101);
  });
  // the legs: the far one, the seat over its top, the near one in front, the seat's top again over
  // the near thigh's cut end; then the top tucked into the trousers, neck, V neckline
  layer(() => {
    shoe(g, far, 0);
    trouserLeg(g, far, [60, 45, 36], true, 110);
    CREASE_FAR.forEach((c, j) => stroke(g, shift(c, far.knee[0], far.knee[1]), 3, 112 + j, T.line, 0.9, 0.7));
    const seat = sm(bodyFig(SEAT), 3);
    celAcross(g, seat, PANTS, PANTS_SH, 22);
    shoe(g, near, 1);
    trouserLeg(g, near, [62, 46, 37], false, 119);
    CREASE_NEAR.forEach((c, j) => stroke(g, shift(c, near.knee[0], near.knee[1]), 3.4 - j * 0.4, 113 + j * 7, T.line, 0.9, 0.8 - j * 0.2));
    clipped(g, sm(bodyFig(SEAT_TOP), 3), () => celAcross(g, seat, PANTS, PANTS_SH, 22));
    stroke(g, bodyFig(SEAT_L), 5.5, 117, T.line, 0.3);
    stroke(g, bodyFig(SEAT_R), 5.5, 118, T.line, 0.3);
    stroke(g, bodyFig([[400, 1640], [403, 1708]]), 2.6, 114, T.line, 0.9, 0.5);
    piece(g, sm(bodyFig(NECK)), SKIN, SKIN_SH, 10, 5, 115);
    piece(g, sm(bodyFig(TORSO)), ACCENT, DEEP, 30, 6, 116);
    fillShape(g, sm(bodyFig(TORSO_SH)), DEEP, 0.9);
    outline(g, sm(bodyFig(TORSO)), 6, 116);
    stroke(g, bodyFig([[300, 1530], [482, 1526]]), 4.5, 117);
    piece(g, sm(bodyFig(VNECK)), HIGH, DEEP, 4, 3.5, 118);
    fillShape(g, sm(bodyFig([[380, 1372], [440, 1390], [506, 1384], [516, 1404], [460, 1418], [392, 1408]])), DEEP, 0.55);
  });
  // the near arm and what its hand holds: the tote (its handles up into the fist) or the pole
  layer(() => {
    const { armNear, carry } = pose, [fx, fy] = carry.fistD;
    if (carry.kind === "tote") {
      const [tx, ty] = carry.toteD;
      const handle = (a: P, b: P): P[] => [[a[0] + tx, a[1] + ty], [(a[0] + tx + b[0] + fx) / 2 + 6, (a[1] + ty + b[1] + fy) / 2], [b[0] + fx, b[1] + fy]];
      strap(g, handle([290, 1848], [352, 1754]), 5, "#ECE5D8", 130);
      strap(g, handle([426, 1842], [366, 1756]), 5, "#ECE5D8", 132);
      const tote = shift([[262, 1846], [452, 1840], [470, 2112], [240, 2120]], tx, ty).flatMap((p, i, q) => { const r = q[(i + 1) % q.length]; return [p, [(p[0] * 2 + r[0]) / 3, (p[1] * 2 + r[1]) / 3], [(p[0] + r[0] * 2) / 3, (p[1] + r[1] * 2) / 3]] as P[]; });
      piece(g, tote, "#ECE5D8", "#D2C6B1", 16, 5.5, 134);
      clipped(g, tote, () => fillShape(g, shift([[414, 1842], [452, 1840], [470, 2112], [432, 2114]], tx, ty), "#D2C6B1", 0.9));
      outline(g, tote, 5.5, 134);
      stroke(g, shift([[268, 1876], [458, 1870]], tx, ty), 3, 135, T.line, 0.9, 0.45);
    }
    piece(g, limbTube(armNear, 42, 34), ACCENT, DEEP, 16, 6, 136);
    const elbow = armNear[1];
    stroke(g, [[elbow[0] + 18, elbow[1] - 14], [elbow[0] + 30, elbow[1] + 2]], 3, 137, DEEP, 0.9, 0.9);
    const cuffDir = Math.atan2(armNear[2][1] - armNear[1][1], armNear[2][0] - armNear[1][0]);
    const cuffA: P = [armNear[2][0] - Math.cos(cuffDir) * 32, armNear[2][1] - Math.sin(cuffDir) * 32];
    piece(g, tube([cuffA, armNear[2]], 35, 34, true), HIGH, DEEP, 4, 4, 138);
    const f = fist([fx, fy]);
    piece(g, f.back, SKIN, SKIN_SH, 8, 4.5, 140);
    f.fingers.forEach((s, j) => piece(g, s, SKIN, SKIN_SH, 4, 3.4, 141 + j));
    piece(g, f.thumb, SKIN, SKIN_SH, 4, 3.8, 145);
  });
  // the head, talking
  layer(() => { g.push(lean, bob, 1); inHead(g, () => head(g, pose.open)); g.pop(); });
  // her voice, then the phone arm in front of her chest: forearm up, the iPhone's back, her hand
  // on it (V15-B's)
  layer(voice);
  layer(() => {
    const ph = phoneMap(pose);
    const [e, w] = bodyFig([ARM_FAR[1], ARM_FAR[2]]);
    piece(g, limbTube([e, w], 36, 31), ACCENT, DEEP, 12, 5.5, 150);
    { const l = Math.hypot(w[0] - e[0], w[1] - e[1]), d: P = [(w[0] - e[0]) / l, (w[1] - e[1]) / l];
      piece(g, limbTube([[w[0] - d[0] * 40, w[1] - d[1] * 40], [w[0] - d[0] * 8, w[1] - d[1] * 8]], 32, 31), HIGH, DEEP, 4, 4, 162); }
    const { w: pw, h: phh } = PHONE;
    // the phone's edge shows its thickness on the side turned from us
    fillShape(g, ph(shift(softBox(0, 0, pw, phh, 6, 40), -8, 3)), "#121D33");
    piece(g, ph(softBox(0, 0, pw, phh, 6, 40)), "#3B5584", "#24365A", 8, 4.5, 151);
    // the camera module, top corner on the far side from her hand: three lenses and a flash
    piece(g, ph(softBox(-20, -66, 50, 50, 4, 24)), "#4A6496", "#2C3F66", 4, 3.5, 152);
    ([[-31, -77], [-31, -55], [-9, -66]] as P[]).forEach((c, j) => { const l = ph(circle(c, 9.5, 16)); fillShape(g, l, T.ink); outline(g, l, 2.4, 153 + j, T.ink); fillShape(g, ph(circle([c[0] + 2.5, c[1] - 2.5], 2.6, 8)), "#9DB6E0"); });
    fillShape(g, ph(circle([-8, -84], 3.6, 10)), "#E8F0FF");
    const ch = phoneHand(ph);
    piece(g, ch.back, SKIN, SKIN_SH, 6, 4.5, 156);
    ch.fingers.forEach((s, j) => piece(g, s, SKIN, SKIN_SH, 4, 3.4, 157 + j));
    piece(g, ch.thumb, SKIN, SKIN_SH, 4, 3.8, 161);
  });
};

// ---------------------------------------------------------------- her voice, into the phone
/** the path of her voice, figure space: out of her lips in the big arch of the App Store art,
 *  up and over to the right, then curling back and down into the top of the phone, where it
 *  ends behind it */
export const voicePath = (pose: Pose): Path => {
  const m = mouthAt(pose), ph = phoneMap(pose), [inP] = ph([PHONE_IN]);
  const d = (x: number, y: number): P => [m[0] + x, m[1] + y];
  return pathOf([d(14, -12), d(60, -104), d(160, -190), d(300, -214), d(410, -160), d(440, -60), d(384, 14), d(282, 26), [inP[0] + 72, inP[1] - 52], inP], 20);
};
/**
 * Three thin marker strokes from her lips into the phone, broken into pulses that travel along
 * them toward the phone: `n` pulses reach it per loop, so the stream is periodic. The strokes
 * fan out a little over the arch and gather again as they enter.
 */
export const drawVoice = (g: Gfx, pose: Pose, lp: Loop, frame: number, n: number) => {
  const path = voicePath(pose), L = path.total, period = L / 3.6, flow = (lp.tau(frame) * n) % 1;
  [-1, 0, 1].forEach((o, j) => {
    const lane = (s: number) => o * 14 * Math.sin(Math.PI * clamp(s / L)) + Math.sin((s / L) * Math.PI * [3, 4, 3.4][j] + j - flow * 2 * Math.PI) * 4 * Math.sin(Math.PI * clamp(s / L));
    // pulse k covers [start, start + 0.62 period]; starts advance with the flow, and a pulse is
    // cut at both ends of the path, so pulses are born at her lips and swallowed by the phone
    for (let k = -1; k <= 3; k++) {
      const a = (k + flow + j * 0.12) * period, b = a + period * 0.62, s0 = Math.max(0, a), s1 = Math.min(L, b);
      if (s1 - s0 < 6) continue;
      const pts: P[] = [];
      for (let s = s0; s <= s1 + 0.01; s += 5) pts.push(off(path, s, lane(s)));
      g.pen(pts, { w: [6.4, 8.4, 5.6][j], color: [HIGH, ACCENT, DEEP][j], seed: 170 + j, closed: false, wobble: 0.5, boil: 0, taper: 0.8, opacity: 1, retrace: false });
    }
  });
};
