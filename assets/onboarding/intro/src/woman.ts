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
// V15-B's, seen from the back, held out in front of her mouth (round 7: further out than V15-B's,
// so her voice has a gap to cross); her hair is a jaw-length bob (round 7, replacing V15-B's);
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
// her left arm holds the phone out in front of her, between chin and collarbone (round 8: held at
// her mouth it read as a selfie), the elbow low, the forearm rising forward, so her voice has a
// clear gap to cross down to the phone (the forearm 15 % longer than V15-B's, which the eye takes
// for the reach; the elbow solved from the bones)
export const ARM_FAR = [[500, 1228], [645, 1407], [854, 1318]] as P[];
export const BAG_D: P = [36, -14];

const TORSO: P[] = [[368, 1160], [330, 1172], [292, 1192], [266, 1226], [262, 1290], [276, 1380], [294, 1468], [300, 1532], [482, 1528], [476, 1478], [492, 1420], [516, 1362], [524, 1300], [520, 1242], [502, 1198], [462, 1174], [428, 1162]];
const TORSO_SH: P[] = [[266, 1226], [292, 1192], [330, 1174], [320, 1260], [320, 1360], [336, 1530], [300, 1532], [294, 1468], [276, 1380], [262, 1290]];
const NECK: P[] = [hv([506, 672]), hv([596, 686]), [430, 1174], [368, 1170]];
const VNECK: P[] = [[362, 1162], [404, 1224], [436, 1162], [446, 1172], [404, 1252], [352, 1172]];

// the seat of the high-waisted trousers: ONE fixed shape attached to the torso, moving only with
// the body's bob (round 9: a seat whose sides followed the outermost leg changed shape from frame
// to frame as the legs swapped). Its back flares out from the waist into a modest rounded hip and
// curves back in to the fold under the buttock; its front runs almost straight down. The legs
// pivot at hips hidden under it and are drawn behind it, so no leg edge ever shapes the seat.
const SEAT_BACK: P[] = [[300, 1524], [280, 1560], [266, 1604], [262, 1648], [270, 1688]];
const SEAT_FRONT: P[] = [[484, 1524], [494, 1566], [502, 1612], [508, 1660], [514, 1704]];
const SEAT_BOTTOM: P[] = [[496, 1724], [440, 1738], [380, 1740]];
const LEG_HW_FAR = [60, 45, 36], LEG_HW_NEAR = [62, 46, 37];

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
  [25, 736, 0, 0],
  [-61, 732, 0, 0],      // passing (the other leg swings by)
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
// (22: enough that the stance leg straightens at the passing position instead of sitting in a
// squat, as a walking body rises over its supporting leg)
const BOB = 22;
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
// the phone sits on her wrist as V15-B's does (its centre 54 left and 128 up from the wrist)
export const PHONE = { cx: 800, cy: 1190, w: 104, h: 208, deg: -10 };
// how she carries the tote in scene A (round 10, Pierre to choose): in her hand by its handles,
// or on her shoulder
export type BagStyle = "hand" | "shoulder";
let BAG: BagStyle = "hand";
export const setBag = (b: BagStyle) => { BAG = b; };
// a frame on the hand: `u` down the forearm's line from the wrist, `v` across it toward her front
const handFrame = (wrist: P, dir: P) => { const l = Math.hypot(dir[0], dir[1]) || 1, ux = dir[0] / l, uy = dir[1] / l, vx = uy, vy = -ux; return ([u, v]: P): P => [wrist[0] + ux * u + vx * v, wrist[1] + uy * u + vy * v]; };
// the hand carrying the tote by its handles, as a hand does: the arm hanging nearly straight, the
// palm toward her thigh, so we see the back of the hand and its knuckles; the four fingers side
// by side, the proximal phalanges down from the knuckles, curling at the middle joint into the
// palm round the handles; the thumb relaxed along the index at the front. Proportions after
// Loomis: the back of the hand (wrist to knuckles) about the length of the fingers' first two
// phalanges; the hand as wide as the wrist and a little more at the knuckles.
const bagHand = (wrist: P, dir: P) => {
  const H = handFrame(wrist, dir), Hs = (pts: P[]) => pts.map(H);
  // the back of the hand, wrist to knuckles, a little wider at the knuckles
  const back = sm(Hs([[0, -31], [0, 31], [20, 35], [46, 37], [60, 30], [64, 12], [64, -12], [60, -30], [46, -36], [20, -35]]), 4);
  // the fingers curled round the handles, seen from the back of the hand: one rounded mass below
  // the knuckles (the four proximal phalanges side by side, no gap), its lower edge the row of
  // bent middle joints turning in toward the palm; three short lines part the fingers
  const fingers = [sm(Hs([[50, -31], [50, 31], [70, 33], [86, 26], [92, 12], [93, -4], [90, -18], [82, -30], [66, -33]]), 4)];
  const knuckles = [21, 7, -7, -20].map((v) => Hs([[56, v - 6], [52, v], [56, v + 6]]));
  const joints = [14, 0, -13].map((v) => Hs([[66, v], [88, v - 1]]));
  // the thumb, relaxed along the index at the front, its tip on the folded index
  const thumb = tube(Hs([[16, 34], [44, 42], [70, 38]]), 11, 9, true), thumbNail = tube(Hs([[62, 39], [71, 38]]), 5.5, 5.5, true);
  // where the handles go into the hand, under the curled fingers
  const hooks: P[] = Hs([[88, 16], [88, -12]]);
  return { back, fingers, joints, knuckles, thumb, thumbNail, hooks };
};
// the free hand on the shoulder-bag walk, holding a takeaway coffee: a paper cup, upright in the
// world whatever the arm does, lid and sleeve; the fingers wrap across its front side by side, the
// back of the hand at its back edge, the thumb out of sight behind it
const cupHand = (wrist: P, dir: P) => {
  // the hand holds the cup around its lower third, so the lid, the sleeve and the cup's taper
  // stay in view above it
  const H = handFrame(wrist, dir), g: P = H([66, 4]), c: P = [g[0] + 4, g[1] - 40];
  const cup: P[] = [[c[0] - 44, c[1] - 74], [c[0] + 44, c[1] - 74], [c[0] + 32, c[1] + 76], [c[0] - 32, c[1] + 76]];
  const lid = sm([[c[0] - 50, c[1] - 72], [c[0] - 49, c[1] - 86], [c[0] - 34, c[1] - 92], [c[0] - 30, c[1] - 104], [c[0] + 30, c[1] - 104], [c[0] + 34, c[1] - 92], [c[0] + 49, c[1] - 86], [c[0] + 50, c[1] - 72]], 3);
  const sleeve: P[] = [[c[0] - 42, c[1] - 44], [c[0] + 42, c[1] - 44], [c[0] + 38, c[1] + 4], [c[0] - 38, c[1] + 4]];
  // the back of the hand: from the wrist down the cup's back edge to the finger roots, rounded
  const back = sm([[wrist[0] - 26, wrist[1] + 2], [wrist[0] + 20, wrist[1] - 4], [g[0] - 22, g[1] + 6], [g[0] - 24, g[1] + 34], [g[0] - 34, g[1] + 56], [g[0] - 50, g[1] + 44], [g[0] - 52, g[1] + 16]], 4);
  // three fingers wrap across the cup's front side by side, the little finger hidden under them
  const ys = [8, 26, 43], rad = [10.5, 11, 10];
  const fingers = ys.map((dy, k) => tube([[g[0] - 34, g[1] + dy], [g[0] - 6, g[1] + dy + 1], [g[0] + 20 - k * 4, g[1] + dy + 2]], rad[k], rad[k], true));
  return { cup, lid, sleeve, back, fingers };
};
// the hand holding the phone, seen from the phone's back, the way a phone is held in one hand:
// the hand cups it from the near edge, so the side of her palm shows there; on the back only the
// four fingers, side by side, laid across it to the far edge, where they curl round; the thumb is
// on the screen side, out of sight, and nothing shows under the bottom edge. One clean knuckle
// line on each finger. Phone-local coordinates (u across from the centre, v down).
const phoneHand = (ph: (pts: P[]) => P[]) => {
  const palm = sm(ph([[40, -14], [62, -4], [66, 50], [62, 96], [50, 124], [26, 132], [30, 108], [44, 90], [48, 50]]), 4);
  const spec: [number, number, number][] = [[-6, 12.5, 0], [19, 13, 1], [44, 12.5, 2], [67, 11, 3]];
  const fingers = spec.map(([v, r, i]) => tube(ph([[48, v + 2], [0, v - 4 + i], [-52 + i * 2, v - 2 + i], [-58 + i * 2, v + 10 + i]]), r, r - 0.5, true));
  const joints = spec.map(([v, r, i]) => ph([[-6 + i, v - 4 + i - r * 0.6], [-9 + i, v - 4 + i + r * 0.6]]));
  return { palm, fingers, joints };
};
// a hand closed round the vertical pole at `at` (its axis), the wrist straight on the forearm: the
// back of the hand from the wrist to the knuckles, which show as a row of bumps on the near side
// of the pole, and the four fingers wrapped round it, stacked, the index on top; their tips and
// the thumb are behind the pole
const gripHand = (wrist: P, at: P, r: number) => {
  const kx = at[0] + r + 12, ys = [-27, -9, 9, 26], rad = [10, 10.5, 10, 9];
  const fingers = ys.map((dy, k) => tube([[kx, at[1] + dy], [at[0], at[1] + dy + 2], [at[0] - r - 3, at[1] + dy + 6]], rad[k], rad[k] - 1.5, true));
  const back = sm([[wrist[0] - 30, wrist[1] + 6], [kx - 6, at[1] + 38], [kx - 4, at[1] - 38], [wrist[0] + 4, wrist[1] - 34], [wrist[0] + 28, wrist[1] - 8], [wrist[0] + 18, wrist[1] + 22]], 4);
  const knuckles = ys.map((dy) => [[kx + 4, at[1] + dy - 7], [kx + 9, at[1] + dy], [kx + 4, at[1] + dy + 7]] as P[]);
  return { back, fingers, knuckles };
};

// ---------------------------------------------------------------- the head (V7 "woman, curves", V7 coordinates)
const C_FACE: P[] = [[455, 366], [530, 336], [608, 346], [662, 396], [688, 460], [694, 522], [682, 582], [656, 634], [612, 674], [556, 690], [500, 678], [456, 642], [428, 586], [418, 516], [426, 440]];
const inHead = (g: Gfx, fn: () => void) => { g.push(HEAD_AT[0] - 560 * HEAD_S, HEAD_AT[1] - 500 * HEAD_S, HEAD_S); LW = 1.35; fn(); LW = 1; g.pop(); };
// ---- the hair, in V7's head coordinates (face oval x 418..694, y 336..690, the back of the
// head to the left): a jaw-length bob (Pierre's pick in round 7, over a ponytail and long loose
// hair), which replaced V15-B's roll on top and stiff ponytail.
const HAIR_LIT = "#3A5486", HAIR_SH = "#1E2F55", HAIR_BACK_LIT = "#2C3F66", HAIR_BACK_SH = "#18264A", HAIR_STRAND = "#5A75A8";
// a swing that grows toward the hair's ends (below `from`), trailing the walk or the rocking
const swing = (pts: P[], u: number, from: number, amp: number): P[] => pts.map(([x, y]) => { const w = clamp((y - from) / 300); return [x - amp * w * w * (1 + Math.cos(4 * Math.PI * u - 0.9)), y - amp * 0.45 * w * Math.sin(4 * Math.PI * u - 0.9)] as P; });
// The front: the hair over the crown, parted high on her right, swept over
// the forehead and ending in two soft locks above her brows (a fringe, not a roll), down to the
// temple in front of the ear. Strand lines follow the way the hair falls from the parting.
const FRONT: P[] = [[452, 600], [430, 520], [428, 440], [452, 368], [504, 316], [572, 292], [640, 304], [688, 338], [704, 384], [696, 414], [680, 396], [656, 418], [630, 392], [596, 396], [556, 402], [516, 428], [486, 474], [468, 540], [462, 604]];
const FRONT_STRANDS: P[][] = [[[600, 300], [540, 320], [490, 360], [460, 430], [450, 520]], [[620, 306], [600, 340], [588, 380]], [[650, 316], [668, 350], [676, 396]]];
// the back of the head and the hair down to her jaw, its ends cut in a few soft points
const BOB_BACK: P[] = [[600, 290], [520, 266], [440, 286], [388, 340], [360, 420], [352, 520], [358, 620], [374, 700], [402, 742], [424, 716], [446, 750], [470, 714], [492, 736], [496, 690], [470, 620], [452, 540]];
const BOB_STRANDS: P[][] = [[[420, 360], [392, 460], [388, 580], [404, 690]], [[460, 330], [430, 440], [430, 600]]];
const hairBack = (g: Gfx, u: number) => {
  piece(g, sm(swing(BOB_BACK, u, 620, 5)), HAIR_BACK_LIT, HAIR_BACK_SH, 16, 7, 80);
  BOB_STRANDS.forEach((s, k) => stroke(g, swing(s, u, 620, 5), 2.6, 84 + k, HAIR_STRAND, 0.9, 0.7));
};
const hairFront = (g: Gfx) => {
  piece(g, smooth(FRONT, true, 4), HAIR_LIT, HAIR_SH, 12, 6, 82);
  FRONT_STRANDS.forEach((s, k) => stroke(g, s, 2.6, 86 + k, HAIR_STRAND, 0.9, 0.7));
};
// talking: the jaw opens and closes on two beats that never line up, between 70 % and 100 % of
// the drawn mouth; the upper lip stays where V7 drew it
export const mouthOpen = (lp: Loop, frame: number) => 0.85 + 0.15 * (0.62 * lp.cyc(frame, 11) + 0.38 * lp.cyc(frame, 17, 1.3));
const head = (g: Gfx, open: number) => {
  const jaw = (pts: P[]): P[] => pts.map(([x, y]) => [x, y > 584 ? 584 + (y - 584) * open : y] as P);
  piece(g, sm(C_FACE), SKIN, SKIN_SH, 26, 6, 81);
  fillShape(g, sm([[514, 540], [544, 526], [568, 538], [554, 560], [524, 562]]), "#EE9D86", 0.45);
  fillShape(g, sm([[650, 524], [672, 516], [684, 532], [670, 548]]), "#EE9D86", 0.4);
  hairFront(g);
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
  const { l, r } = legEdges(leg, hws), s = sm([...r, ...[...l].reverse()], 3);
  cel(g, s, PANTS, PANTS_SH, 22);
  // the far leg sits a half-tone back, fading in below the hip, so the seat over its top (the
  // nearer fabric's tone) shows no seam of tone where the two meet
  if (far) clipped(g, s, () => {
    const c = g.cur, gr = c.createLinearGradient(0, leg.hip[1], 0, leg.hip[1] + 140);
    gr.addColorStop(0, "rgba(15,30,54,0)"); gr.addColorStop(1, "rgba(15,30,54,0.35)");
    c.fillStyle = gr; c.fillRect(leg.hip[0] - 300, leg.hip[1], 600, 1200);
  });
  outline(g, s, 5.5, seed);
};
// x of a polyline at height y (its first crossing), or undefined
const xOn = (pts: P[], y: number): number | undefined => {
  for (let i = 1; i < pts.length; i++) { const [x0, y0] = pts[i - 1], [x1, y1] = pts[i]; if ((y0 - y) * (y1 - y) <= 0 && y0 !== y1) return x0 + ((x1 - x0) * (y - y0)) / (y1 - y0); }
  return undefined;
};
// a trouser leg's two screen edges (left, right), top to bottom, as trouserLeg draws them
// (it starts a little above the hip and narrower there, so its top lies inside the seat)
const legEdges = (leg: Leg, hws: number[]) => {
  const top: P = [leg.hip[0] + (leg.hip[0] - leg.knee[0]) * 0.15, leg.hip[1] - 50];
  const { left, right } = limb([top, leg.hip, leg.knee, leg.ankle], [hws[0] - 16, ...hws]);
  // `right` is the screen-left edge of a limb drawn downward, `left` the screen-right one
  return { l: right, r: left };
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

/** what a scene asks of her: the posed legs, the body's bob (down) and lean (forward), the walk
 *  phase her hair trails, the mouth's opening, the near arm (shoulder, elbow, wrist) and what its
 *  hand does, and the phone's tilt */
export type Carry = { kind: "tote"; toteD: P; shoulderD: P } | { kind: "grip"; at: P; poleR: number };
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
  // the legs, far then near, then the seat over both their tops: its sides run from the waist out
  // over the hip and down each side into the outer edge of whichever leg is outermost there, so
  // the contour from waist to leg is one smooth line with no corner; its bottom, between the legs,
  // has no outline. Then the top tucked into the trousers, neck, V neckline
  layer(() => {
    shoe(g, far, 0);
    trouserLeg(g, far, LEG_HW_FAR, true, 110);
    CREASE_FAR.forEach((c, j) => stroke(g, shift(c, far.knee[0], far.knee[1]), 3, 112 + j, T.line, 0.9, 0.7));
    shoe(g, near, 1);
    trouserLeg(g, near, LEG_HW_NEAR, false, 119);
    CREASE_NEAR.forEach((c, j) => stroke(g, shift(c, near.knee[0], near.knee[1]), 3.4 - j * 0.4, 113 + j * 7, T.line, 0.9, 0.8 - j * 0.2));
    // the seat's back runs from the waist over the hip (fixed) and then, under the buttock, eases
    // into the back of the near thigh wherever that thigh is: the near leg moves continuously, so
    // the line does too. (Round 10: a fixed seat corner overhung the thigh for a few frames of
    // each stride when it swung back, a dark wedge left of her fist.)
    const at = (pts: P[]) => shift(pts, lean, bob), hip = at(SEAT_BACK.slice(0, 5));
    const thigh = legEdges(near, LEG_HW_NEAR).l, tY = hip[4][1] + 95, tX = xOn(thigh, tY) ?? hip[4][0] + 30;
    const bridge: P[] = [[(hip[4][0] + tX) / 2 + 4, (hip[4][1] + tY) / 2], [tX, tY]];
    const backLine = [...hip, ...bridge], left = smooth(backLine, false, 6), right = smooth(at(SEAT_FRONT), false, 6);
    const fill: P[] = [...backLine, [tX + 70, tY], ...at(SEAT_BOTTOM).reverse(), ...[...at(SEAT_FRONT)].reverse()];
    // the seat lit all over, with the legs' shade strip only down its side away from the light: a
    // shade cast by an offset copy (cel) would also show along its bottom, which reads as a line
    const seatFill = sm(fill, 3);
    fillShape(g, seatFill, PANTS);
    clipped(g, seatFill, () => g.pen(shift(right, -7, 0), { w: 13, color: PANTS_SH, seed: 116, closed: false, wobble: 0, boil: 0, taper: 0, opacity: 1, retrace: false }));
    stroke(g, left, 5.5, 117, T.line, 0.15);
    stroke(g, right, 5.5, 118, T.line, 0.15);
    stroke(g, bodyFig([[400, 1640], [402, 1690]]), 2.6, 114, T.line, 0.9, 0.45);
    piece(g, sm(bodyFig(NECK)), SKIN, SKIN_SH, 10, 5, 115);
    piece(g, sm(bodyFig(TORSO)), ACCENT, DEEP, 30, 6, 116);
    fillShape(g, sm(bodyFig(TORSO_SH)), DEEP, 0.9);
    outline(g, sm(bodyFig(TORSO)), 6, 116);
    stroke(g, bodyFig([[300, 1530], [482, 1526]]), 4.5, 117);
    piece(g, sm(bodyFig(VNECK)), HIGH, DEEP, 4, 3.5, 118);
    fillShape(g, sm(bodyFig([[380, 1372], [440, 1390], [506, 1384], [516, 1404], [460, 1418], [392, 1408]])), DEEP, 0.55);
  });
  // the near arm and what its hand holds: the tote by its handles or on her shoulder (scene A),
  // the pole (scene B)
  layer(() => {
    const { armNear, carry } = pose, [sh, el, wr] = armNear, dir: P = [wr[0] - el[0], wr[1] - el[1]];
    const toteAt = (tx: number, ty: number) => {
      const tote = shift([[262, 1846], [452, 1840], [470, 2112], [240, 2120]], tx, ty).flatMap((p, i, q) => { const r = q[(i + 1) % q.length]; return [p, [(p[0] * 2 + r[0]) / 3, (p[1] * 2 + r[1]) / 3], [(p[0] + r[0] * 2) / 3, (p[1] + r[1] * 2) / 3]] as P[]; });
      piece(g, tote, "#ECE5D8", "#D2C6B1", 16, 5.5, 134);
      clipped(g, tote, () => fillShape(g, shift([[414, 1842], [452, 1840], [470, 2112], [432, 2114]], tx, ty), "#D2C6B1", 0.9));
      outline(g, tote, 5.5, 134);
      stroke(g, shift([[268, 1876], [458, 1870]], tx, ty), 3, 135, T.line, 0.9, 0.45);
    };
    if (carry.kind === "tote" && BAG === "hand") {
      const [tx, ty] = carry.toteD, hk = bagHand(wr, dir).hooks;
      // the handles taut from the bag's mouth straight up into the crook of her fingers
      strap(g, [[290 + tx, 1848 + ty], hk[1]], 5, "#ECE5D8", 130);
      strap(g, [[426 + tx, 1842 + ty], hk[0]], 5, "#ECE5D8", 132);
      toteAt(tx, ty);
    }
    if (carry.kind === "tote" && BAG === "shoulder") {
      // the handles over her shoulder, the bag against her hip, bobbing a beat after her steps
      const [bx, by] = carry.shoulderD, top: P = [sh[0] + 10, sh[1] - 26];
      strap(g, [[296 + bx, 1848 + by], [(296 + bx + top[0]) / 2 - 10, (1848 + by + top[1]) / 2], top], 5, "#ECE5D8", 130);
      strap(g, [[426 + bx, 1842 + by], [(426 + bx + top[0]) / 2 + 14, (1842 + by + top[1]) / 2], [top[0] + 16, top[1] + 4]], 5, "#ECE5D8", 132);
      toteAt(bx, by);
    }
    // the arm: the upper arm and the forearm as two pieces meeting in a rounded elbow, the
    // forearm over the upper arm, a short crease inside the bend
    piece(g, limbTube([sh, el], 42, 37), ACCENT, DEEP, 16, 6, 136);
    piece(g, limbTube([el, wr], 37, 34), ACCENT, DEEP, 14, 6, 139);
    const bend = Math.abs(Math.atan2(sh[1] - el[1], sh[0] - el[0]) - Math.atan2(wr[1] - el[1], wr[0] - el[0]));
    if (Math.min(bend, 2 * Math.PI - bend) < 2.6) { const m: P = [(sh[0] + wr[0]) / 2, (sh[1] + wr[1]) / 2], l = Math.hypot(m[0] - el[0], m[1] - el[1]) || 1, u: P = [(m[0] - el[0]) / l, (m[1] - el[1]) / l]; stroke(g, [[el[0] + u[0] * 30 - u[1] * 8, el[1] + u[1] * 30 + u[0] * 8], [el[0] + u[0] * 40, el[1] + u[1] * 40], [el[0] + u[0] * 30 + u[1] * 8, el[1] + u[1] * 30 - u[0] * 8]], 3, 137, DEEP, 0.7, 0.9); }
    const cuffDir = Math.atan2(dir[1], dir[0]), cuffA: P = [wr[0] - Math.cos(cuffDir) * 32, wr[1] - Math.sin(cuffDir) * 32];
    piece(g, tube([cuffA, wr], 35, 34, true), HIGH, DEEP, 4, 4, 138);
    if (carry.kind === "tote" && BAG === "hand") {
      // in her hand by the handles, the fingers curled round them
      const h = bagHand(wr, dir);
      piece(g, h.back, SKIN, SKIN_SH, 8, 4.5, 140);
      h.fingers.slice().reverse().forEach((f, j) => piece(g, f, SKIN, SKIN_SH, 4, 3.4, 141 + j));
      h.knuckles.forEach((k, j) => stroke(g, k, 2.6, 146 + j, SKIN_SH, 0.6, 0.9));
      h.joints.forEach((k, j) => stroke(g, k, 2.6, 150 + j, T.line, 0.6, 0.55));
      piece(g, h.thumb, SKIN, SKIN_SH, 4, 3.8, 145);
      piece(g, h.thumbNail, "#F7D6C2", "#E8B9A0", 2, 2.4, 154);
    } else if (carry.kind === "tote") {
      // the bag on her shoulder, a takeaway coffee in this hand
      const h = cupHand(wr, dir);
      piece(g, h.cup, "#FFFFFF", "#DCE3EE", 8, 5, 171);
      piece(g, h.sleeve, "#C9935E", "#A8743F", 6, 4, 172);
      piece(g, h.lid, "#FFFFFF", "#DCE3EE", 4, 5, 173);
      piece(g, h.back, SKIN, SKIN_SH, 8, 4.5, 140);
      h.fingers.forEach((f, j) => piece(g, f, SKIN, SKIN_SH, 4, 3.4, 141 + j));
    } else {
      const h = gripHand(wr, carry.at, carry.poleR);
      piece(g, h.back, SKIN, SKIN_SH, 8, 4.5, 140);
      h.fingers.forEach((f, j) => piece(g, f, SKIN, SKIN_SH, 4, 3.4, 141 + j));
      h.knuckles.forEach((k, j) => stroke(g, k, 2.6, 146 + j, SKIN_SH, 0.6, 0.9));
    }
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
    piece(g, ch.palm, SKIN, SKIN_SH, 6, 4.5, 156);
    ch.fingers.forEach((f, j) => piece(g, f, SKIN, SKIN_SH, 4, 3.4, 157 + j));
    ch.joints.forEach((k, j) => stroke(g, k, 2.4, 165 + j, SKIN_SH, 0.6, 0.9));
  });
};

// ---------------------------------------------------------------- her voice, into the phone
/** the path of her voice, figure space: straight across the gap from her lips, gently down,
 *  into the near edge of the phone she holds out */
export const voicePath = (pose: Pose): Path => {
  const m = mouthAt(pose), ph = phoneMap(pose);
  const d = (x: number, y: number): P => [m[0] + x, m[1] + y];
  const [edge] = ph([[-58, -24]]), [into] = ph([[-22, -28]]), s0 = d(18, 4);
  // a straight line from her lips to the phone's edge, bowed up very slightly so it reads as
  // breath carried across rather than a ruler
  const mid = (k: number): P => [s0[0] + (edge[0] - s0[0]) * k, s0[1] + (edge[1] - s0[1]) * k - 10 * Math.sin(Math.PI * k)];
  return pathOf([s0, mid(1 / 3), mid(2 / 3), edge, into], 20);
};
// Her voice as the Dictus waveform crossing the gap (Pierre's pick in round 7, over the App Store
// art's marker strokes): small rounded bars, upright, ride the path from her lips into the phone,
// born small, swelling mid-way with her speech, shrinking as they reach it. The row moves 17
// bar-spacings a loop, in the blues of the BrandWaveform's centre.
export const drawVoice = (g: Gfx, pose: Pose, lp: Loop, frame: number) => {
  const path = voicePath(pose), L = path.total, gap = 26, n = Math.floor(L / gap), flow = (lp.tau(frame) * 17) % 1;
  for (let k = 0; k < n; k++) {
    const s = ((k + flow) / n) * L, t = s / L;
    if (t > 0.96) continue;
    const speech = 0.55 + 0.45 * Math.abs(Math.sin(2 * Math.PI * (lp.tau(frame) * 11 + k * 0.37)));
    const h = 16 + (8 + 50 * speech) * Math.sin(Math.PI * Math.min(1, t * 1.05)), [x, y] = at(path, s).p;
    // a capsule: straight sides, round ends, as the BrandWaveform draws its bars
    const r = 8, bar: P[] = [...Array.from({ length: 9 }, (_, i) => { const a = Math.PI + (i / 8) * Math.PI; return [x + Math.cos(a) * r, y - h / 2 + r + Math.sin(a) * r] as P; }), ...Array.from({ length: 9 }, (_, i) => { const a = (i / 8) * Math.PI; return [x + Math.cos(a) * r, y + h / 2 - r + Math.sin(a) * r] as P; })];
    fillShape(g, bar, [HIGH, ACCENT, DEEP][k % 3]);
  }
};
