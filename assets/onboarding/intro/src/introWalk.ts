import { Gfx, softBox, tube, turn, type Ctx, type Env, type Medium, type P } from "./core";
import type { Film } from "./film";
import { clipped, fillShape, smooth } from "./gallery";
import { BPM, cyc, FPS, FRAME, LOOP, place, tau, THEMES, type Theme } from "./theme";

// ONBOARDING INTRO, SCENE A · "walking" (issue #667). The App Store hero V15-B
// (assets/appstore/art/v15-B/heroWalk15.ts, untouched) set in motion: the same woman, the same
// marker lines, now walking in place on a pavement that slides back under her, the phone up at
// her chin, talking; her voice leaves as the three blue strokes and turns into three bars of the
// Dictus waveform at the end of its run. V15-B's lettering along the strokes is gone: the
// headline is SwiftUI text under the video.
//
// What moves, all of it periodic over the 4.5 s loop (theme.ts):
// - the legs: four walk cycles (1.125 s each, about 107 steps a minute). One cycle drives both
//   legs half a cycle apart. A leg is its hip, its foot (heel point, sole angle, toe bend) and two
//   bone lengths; the knee is solved from them. V15-B's pose is the cycle's CONTACT position
//   (Richard Williams, The Animator's Survival Kit, walk chapter): phase 0 is the far leg's heel
//   strike and phase 0.5 the near leg's push-off, and the solver gives back V15-B's knees to the
//   pixel, so frame 0 is the App Store drawing. In between: down, passing and up, keyed in FOOT.
// - the stance foot is planted: it slides back at the pavement's speed, and the slab joints run
//   at that speed at the feet's depth, so the floor carries her instead of her skating on it.
// - the body rises at the passing positions and sinks at contact, twice a cycle; the tote arm
//   swings against the near leg and the tote follows the fist a beat late; the hair's ends sway.
// - the mouth opens and closes on an irregular, speech-like beat; the voice strokes' waver
//   travels out from her lips; the three bars at their end pulse like the recording waveform.
//
// Lines, fills and shapes are V15-B's; only the trousers are now two legs and a seat instead of
// one silhouette, because one outline round both legs cannot survive them crossing.

// The source canvas is the App Store strip (2640 x 2868); the frame shows x 0..1466, y 750..2868
// of it, the crop of the #649 mock-up (designs/onboarding-649-assets/intro-walk.png).
const W = 2640, H = 2868;
const PLACE = place([0, 750], 1466, [0, 0], 330);

const MARKER: Medium = { nib: 2.4, taper: 0.55, pressure: 0.6, retrace: false, wobble: 0.6, rough: 0.3 };
const LIGHT: P = [-0.6, -0.8];
const ACCENT = "#3D7EFF", DEEP = "#2563EB", HIGH = "#6BA3FF", WHITE = "#FFFFFF";
const SKIN = "#F1C09C", SKIN_SH = "#D59674";
const PANTS = "#1E3354", PANTS_SH = "#0F1E36";
const sm = (pts: P[], per = 6) => smooth(pts, true, per);
const circle = (c: P, r: number, n = 24): P[] => Array.from({ length: n }, (_, i) => [c[0] + Math.cos((i / n) * Math.PI * 2) * r, c[1] + Math.sin((i / n) * Math.PI * 2) * r] as P);
const shift = (pts: P[], dx: number, dy: number): P[] => pts.map(([x, y]) => [x + dx, y + dy]);
const clamp = (v: number, a = 0, b = 1) => Math.max(a, Math.min(b, v));

// line weights are multiplied by LW: the head is drawn at HEAD_S, so its V7 weights are raised to
// match the body's. T is the appearance being drawn. Both are set at the top of every frame and
// read only while it draws, so a frame stays a pure function of (frame, theme).
let LW = 1;
let T: Theme = THEMES.light;
const cel = (g: Gfx, s: P[], lit: string, shade: string, k = 18) => {
  fillShape(g, s, shade);
  clipped(g, s, () => fillShape(g, s.map(([x, y]) => [x + LIGHT[0] * k, y + LIGHT[1] * k] as P), lit));
};
const outline = (g: Gfx, s: P[], w: number, seed: number, color = T.line) =>
  g.pen(s, { w: w * LW, color, seed, closed: true, wobble: 0.5, boil: 0, taper: 0.3, opacity: 1, retrace: false });
const stroke = (g: Gfx, pts: P[], w: number, seed: number, color = T.line, taper = 0.9, op = 1) =>
  g.pen(smooth(pts, false, 8), { w: w * LW, color, seed, closed: false, wobble: 0.5, boil: 0, taper, opacity: op, retrace: false });
const piece = (g: Gfx, s: P[], lit: string, shade: string, k: number, w: number, seed: number) => { cel(g, s, lit, shade, k); outline(g, s, w, seed); };

// ---------------------------------------------------------------- path utilities (V15-B's)
type Path = { pts: P[]; len: number[]; total: number };
const pathOf = (ctrl: P[], per = 24): Path => {
  const pts = smooth(ctrl, false, per), len = [0];
  for (let i = 1; i < pts.length; i++) len.push(len[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]));
  return { pts, len, total: len[len.length - 1] };
};
const at = (p: Path, s: number): { p: P; t: P } => {
  const v = Math.max(0, Math.min(p.total, s));
  let i = 1; while (i < p.len.length - 1 && p.len[i] < v) i++;
  const a = p.pts[i - 1], b = p.pts[i], f = (v - p.len[i - 1]) / Math.max(1e-6, p.len[i] - p.len[i - 1]);
  const dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy) || 1;
  return { p: [a[0] + dx * f, a[1] + dy * f], t: [dx / l, dy / l] };
};
const off = (p: Path, s: number, v: number): P => { const { p: c, t } = at(p, s); return [c[0] + t[1] * v, c[1] - t[0] * v]; };
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
const limbTube = (joints: P[], r0: number, r1: number): P[] => {
  const c = smooth(joints, false, 14), n = c.length, L: P[] = [], R: P[] = [];
  const dir = (i: number): P => { const a = c[Math.max(0, i - 1)], b = c[Math.min(n - 1, i + 1)], l = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1; return [(b[0] - a[0]) / l, (b[1] - a[1]) / l]; };
  c.forEach((p, i) => { const [dx, dy] = dir(i), r = r0 + ((r1 - r0) * i) / (n - 1); L.push([p[0] - dy * r, p[1] + dx * r]); R.push([p[0] + dy * r, p[1] - dx * r]); });
  const arc = (p: P, r: number, a0: number, sgn: number): P[] => Array.from({ length: 5 }, (_, k) => { const a = a0 + sgn * ((k + 1) / 6) * Math.PI; return [p[0] + Math.cos(a) * r, p[1] + Math.sin(a) * r] as P; });
  const aEnd = Math.atan2(dir(n - 1)[1], dir(n - 1)[0]), aStart = Math.atan2(dir(0)[1], dir(0)[0]);
  return [...L, ...arc(c[n - 1], r1, aEnd + Math.PI / 2, -1), ...R.reverse(), ...arc(c[0], r0, aStart - Math.PI / 2, -1)];
};

// ---------------------------------------------------------------- the ground
const HORIZON = 1640;
const VP_L: P = [-1700, HORIZON], VP_R: P = [3300, HORIZON];
const toward = (vp: P, through: P, y: number): P => [vp[0] + ((through[0] - vp[0]) * (y - vp[1])) / (through[1] - vp[1]), y];
const KERB_A: P = [0, 1806], KERB_B: P = [1320, 1948];   // the far kerb, on the line to VP_L
const GROUND_R = 1320;                                    // V15-B's slide edge: the pavement fades out before it
// the frame's own edges: the frame's bottom is source y 750 + 1440 / PLACE.k = 2861
const EDGE_FADE = { left: 160, bottom: [2600, 2861] as P };

// The walk's numbers. One step (heel strike to the other heel strike) carries the planted foot
// STEP figure units back; it is measured on V15-B (the near shoe's ball, planted at push-off, sits
// one step behind where the far heel struck). FIG.s turns it into canvas pixels at the feet.
const CYCLES = 4, STEP = 434;
// cross joints of the slabs, on lines to VP_R, spaced one step apart at the feet (y FEET_Y) so the
// pattern has slid exactly one joint per step and the loop closes on itself
const FEET_Y = 2510, FOOT_LINE = H + 40;
const atFeet = (FEET_Y - HORIZON) / (FOOT_LINE - HORIZON);

const ground = (g: Gfx, frame: number) => {
  fillShape(g, [[-10, HORIZON + 60], [GROUND_R + 10, HORIZON + 60], [GROUND_R + 10, KERB_B[1]], [-10, KERB_A[1]]], T.road);
  fillShape(g, [[-10, KERB_A[1]], [GROUND_R + 10, KERB_B[1]], [GROUND_R + 10, H], [-10, H]], T.pave);
  const kerbFace = (y: number) => [[-10, KERB_A[1] + y], [GROUND_R + 10, KERB_B[1] + y * 1.12]] as P[];
  fillShape(g, [...kerbFace(0), ...kerbFace(22).reverse()], T.kerb);
  stroke(g, kerbFace(0), 3.2, 500, T.joint, 0.2, 0.55 * T.jointK);
  stroke(g, kerbFace(22), 2.2, 501, T.joint, 0.2, 0.3 * T.jointK);
  // long joints to VP_L run along her way: they stay put
  [2060, 2230, 2470, 2800, 3260].forEach((y, k) => {
    const yAt = (x: number) => HORIZON + ((y - HORIZON) * (x - VP_L[0])) / (GROUND_R - VP_L[0]);
    stroke(g, [[-10, yAt(-10)], [GROUND_R + 10, yAt(GROUND_R + 10)]] as P[], 2.6, 510 + k, T.joint, 0.2, 0.22 * T.jointK);
  });
  // cross joints slide back (left) one step per step
  const gap = (STEP * FIG.s) / atFeet, slide = gap * CYCLES * 2 * tau(frame);
  for (let k = -3; k <= 3; k++) {
    const foot: P = [-40 + k * gap - (slide % gap), FOOT_LINE], top = toward(VP_R, foot, KERB_A[1] + 40);
    stroke(g, [top, foot], 2.4, 520, T.joint, 0.2, 0.2 * T.jointK);
  }
};

// ---------------------------------------------------------------- the figure (V15-B's, figure space)
const FIG = { at: [4.8, -72] as P, s: 1.06 };
const fig = ([x, y]: P): P => [FIG.at[0] + x * FIG.s, FIG.at[1] + y * FIG.s];

const SHADOW: P[] = [[150, 2404], [300, 2436], [450, 2452], [640, 2460], [800, 2456], [930, 2476], [1046, 2508], [1104, 2540], [1044, 2562], [880, 2558], [700, 2534], [520, 2510], [330, 2480], [168, 2432]];

const HEAD_AT: P = [401, 970], HEAD_S = 0.78;
const hv = ([x, y]: P): P => [HEAD_AT[0] + (x - 560) * HEAD_S, HEAD_AT[1] + (y - 500) * HEAD_S];
const MOUTH_F = hv([688, 602]);   // her lips, figure space

// V15-B's limbs at the contact position: hip, knee, ankle; shoulder, elbow, wrist
const LEG_FAR = [[452, 1680], [566, 2020], [660, 2370]] as P[];    // her left, reaching forward, heel striking
const LEG_NEAR = [[344, 1690], [350, 2010], [200, 2296]] as P[];   // her right, behind, heel lifted
const ARM_NEAR = [[298, 1238], [322, 1450], [376, 1650]] as P[];   // her right, swung forward, the tote
const ARM_FAR = [[500, 1228], [566, 1456], [650, 1278]] as P[];    // her left, the phone up at her chin
const BAG_D: P = [36, -14];

const TORSO: P[] = [[368, 1160], [330, 1172], [292, 1192], [266, 1226], [262, 1290], [276, 1380], [294, 1468], [300, 1532], [482, 1528], [476, 1478], [492, 1420], [516, 1362], [524, 1300], [520, 1242], [502, 1198], [462, 1174], [428, 1162]];
const TORSO_SH: P[] = [[266, 1226], [292, 1192], [330, 1174], [320, 1260], [320, 1360], [336, 1530], [300, 1532], [294, 1468], [276, 1380], [262, 1290]];
const NECK: P[] = [hv([506, 672]), hv([596, 686]), [430, 1174], [368, 1170]];
const VNECK: P[] = [[362, 1162], [404, 1224], [436, 1162], [446, 1172], [404, 1252], [352, 1172]];
const HAIR_BACK: P[] = [[452, 620], [402, 560], [376, 470], [392, 372], [450, 296], [540, 262], [610, 270], [560, 330], [470, 420], [446, 520], [462, 640], [470, 760], [452, 880], [410, 990], [350, 1074], [296, 1102], [262, 1090], [296, 1040], [300, 960], [300, 860], [320, 760], [340, 690]];
const HAIR_STRANDS: P[][] = [[[430, 700], [420, 840], [380, 960], [320, 1060]], [[390, 640], [370, 780], [350, 900], [300, 1000]], [[440, 560], [440, 700], [430, 820]]];

// the seat of the high-waisted trousers, waist to crotch, over both legs' tops (V15-B's outline
// there, its sides ending where the legs' outer edges leave the hips); SEAT_TOP is the band of it
// painted again, with the seat's own shading, over the near thigh so its cut end never shows
const SEAT: P[] = [[300, 1524], [280, 1572], [268, 1630], [280, 1690], [330, 1736], [404, 1756], [462, 1726], [510, 1664], [514, 1630], [500, 1572], [484, 1524]];
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
const footAt = (u: number): [number, number, number, number] => {
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
const BONES_FRONT: P = [358.6, 362.4], BONES_BACK: P = [320, 323];
const bonesAt = (u: number): P => { const d = Math.abs((((u % 1) + 1) % 1) - 0.5), w = Math.exp(-((d / 0.12) ** 2)); return [BONES_FRONT[0] + (BONES_BACK[0] - BONES_FRONT[0]) * w, BONES_FRONT[1] + (BONES_BACK[1] - BONES_FRONT[1]) * w]; };
// the body sinks at contact and rises at passing, twice a cycle; 0 at contact, so frame 0 is V15-B
const BOB = 7;
const bobAt = (u: number) => BOB * (Math.cos(4 * Math.PI * u) - 1);

type Leg = { hip: P; knee: P; ankle: P; heel: P; deg: number; bend: number };
const legAt = (hip0: P, u: number, bob: number): Leg => {
  const [hx, hy, deg, bend] = footAt(u), heel: P = [hip0[0] + hx, hip0[1] + hy];
  const a = (deg * Math.PI) / 180, ankle: P = [heel[0] + ANKLE_IN_SHOE[0] * Math.cos(a) - ANKLE_IN_SHOE[1] * Math.sin(a), heel[1] + ANKLE_IN_SHOE[0] * Math.sin(a) + ANKLE_IN_SHOE[1] * Math.cos(a)];
  const hip: P = [hip0[0], hip0[1] + bob], [l1, l2] = bonesAt(u);
  // two-bone solve, the knee bending forward (+x)
  const dx = ankle[0] - hip[0], dy = ankle[1] - hip[1], d = Math.hypot(dx, dy), ux = dx / d, uy = dy / d;
  let knee: P;
  if (d >= l1 + l2) knee = [hip[0] + ux * d * (l1 / (l1 + l2)), hip[1] + uy * d * (l1 / (l1 + l2))];
  else { const along = (l1 * l1 - l2 * l2 + d * d) / (2 * d), h = Math.sqrt(Math.max(0, l1 * l1 - along * along)); knee = [hip[0] + ux * along + uy * h, hip[1] + uy * along - ux * h]; }
  return { hip, knee, ankle, heel, deg, bend };
};

// ---------------------------------------------------------------- hands
const fist = (d: P) => {
  const [dx, dy] = d;
  const back = sm(shift([[322, 1668], [362, 1664], [382, 1690], [386, 1736], [368, 1762], [336, 1760], [318, 1726]], dx, dy), 4);
  const fingers = [0, 1, 2, 3].map((k) => { const y = 1702 + k * 16 + dy, r = [40, 42, 38, 30][k]; return tube([[350 + dx, y], [350 + dx + r * 0.7, y - 1], [350 + dx + r, y + 6]], 9.5, 8.5, true); });
  const thumb = tube(shift([[346, 1680], [372, 1684], [394, 1700]], dx, dy), 10.5, 9, true);
  return { back, fingers, thumb };
};
const PHONE = { cx: 596, cy: 1150, w: 104, h: 208, deg: -10 };
const phoneHand = (ph: (pts: P[]) => P[]) => {
  const back = sm(ph([[8, 36], [50, 26], [66, 66], [62, 110], [36, 132], [4, 124], [-10, 88]]), 4);
  const fingers = [0, 1, 2, 3].map((k) => { const v = 18 + k * 21, r = [92, 96, 90, 76][k]; return tube(ph([[30, v + 6], [30 - r * 0.6, v], [30 - r, v - 4]]), 10.5, 9.5, true); });
  const thumb = tube(ph([[44, 54], [54, 14], [58, -24]]), 11.5, 10, true);
  return { back, fingers, thumb };
};

// ---------------------------------------------------------------- the voice (canvas pixels)
// V15-B's soft S, now ending at the frame's right side, where it turns into three waveform bars
const VOICE_END: P = [1356, 1600];
const voiceFrom = (mouth: P) => pathOf([[mouth[0] + 14, mouth[1] - 16], [630, 950], [720, 904], [820, 888], [910, 904], [990, 950], [1052, 1030], [1098, 1146], [1136, 1290], [1178, 1424], [1228, 1524], [1286, 1580], [1330, VOICE_END[1] + 1], VOICE_END], 30);
const spread = (s: number) => { const t = Math.min(1, s / 700), e = t * t * (3 - 2 * t); return 4 + 16 * e; };
// the three bars: x, resting height (canvas px, read off the mock-up's crop of the strip, where
// slide 2's band grows from them), cycles per loop of their pulse
const BARS: [number, number, number][] = [[1356, 74, 6], [1400, 122, 5], [1444, 166, 7]];

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
export const mouthOpen = (frame: number) => 0.85 + 0.15 * (0.62 * cyc(frame, 11) + 0.38 * cyc(frame, 17, 1.3));
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

// one trouser leg: the limb's two edges, the hem at the ankle; the far leg a half-tone back
const trouserLeg = (g: Gfx, leg: Leg, hws: number[], far: boolean, seed: number) => {
  const { left, right } = limb([leg.hip, leg.knee, leg.ankle], hws), s = sm([...left, ...[...right].reverse()], 3);
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

// ---------------------------------------------------------------- the picture
const drawFor = (theme: Theme) => (ctx: Ctx, frame: number, env: Env) => {
  T = theme;
  const u = (tau(frame) * CYCLES) % 1;               // the far leg's phase; the near leg is half a cycle on
  const bob = bobAt(u), bodyFig = (pts: P[]) => shift(pts, 0, bob);
  const g = new Gfx(ctx, env, frame, MARKER);
  const k = PLACE.k * env.scale, toFrame = () => ctx.setTransform(k, 0, 0, k, -PLACE.o[0] * k, -PLACE.o[1] * k);
  g.push(-PLACE.o[0] * PLACE.k, -PLACE.o[1] * PLACE.k, PLACE.k);

  // 1. the ground, faded out toward the horizon and before its right edge
  g.group("plain", () => ground(g, frame));
  ctx.save(); toFrame(); ctx.globalCompositeOperation = "destination-out";
  const up = ctx.createLinearGradient(0, HORIZON + 60, 0, KERB_A[1] + 40); up.addColorStop(0, "rgba(0,0,0,1)"); up.addColorStop(1, "rgba(0,0,0,0)");
  ctx.fillStyle = up; ctx.fillRect(-10, HORIZON, GROUND_R + 30, KERB_B[1] + 60 - HORIZON);
  const right = ctx.createLinearGradient(980, 0, GROUND_R, 0); right.addColorStop(0, "rgba(0,0,0,0)"); right.addColorStop(1, "rgba(0,0,0,1)");
  ctx.fillStyle = right; ctx.fillRect(980, HORIZON, GROUND_R + 40 - 980, H - HORIZON);
  ctx.fillStyle = "rgba(0,0,0,1)"; ctx.fillRect(GROUND_R, HORIZON, W - GROUND_R, H - HORIZON);
  // the frame's left and bottom edges: the slabs dissolve into the page there too, as on the
  // mock-up, so the video never shows a cut edge of pavement against the screen
  const left = ctx.createLinearGradient(0, 0, EDGE_FADE.left, 0); left.addColorStop(0, "rgba(0,0,0,1)"); left.addColorStop(1, "rgba(0,0,0,0)");
  ctx.fillStyle = left; ctx.fillRect(-10, HORIZON, EDGE_FADE.left + 10, H - HORIZON);
  const low = ctx.createLinearGradient(0, EDGE_FADE.bottom[0], 0, EDGE_FADE.bottom[1]); low.addColorStop(0, "rgba(0,0,0,0)"); low.addColorStop(1, "rgba(0,0,0,1)");
  ctx.fillStyle = low; ctx.fillRect(-10, EDGE_FADE.bottom[0], GROUND_R + 20, H - EDGE_FADE.bottom[0] + 10);
  ctx.restore();

  const inFig = (fn: () => void) => g.group("plain", () => { g.push(FIG.at[0], FIG.at[1], FIG.s); fn(); g.pop(); });
  const far = legAt(LEG_FAR[0], u, bob), near = legAt(LEG_NEAR[0], u + 0.5, bob);
  // the arm with the tote swings against the near leg: forward (as drawn) when that leg is back
  const swing = (v: number) => 15 * (1 - Math.cos(2 * Math.PI * v)) / 2;
  const armNear = turn(bodyFig(ARM_NEAR), ARM_NEAR[0][0], ARM_NEAR[0][1] + bob, swing(u)) as P[];
  // the fist follows the wrist; the tote hangs from the fist a beat behind it
  const wristD: P = [armNear[2][0] - ARM_NEAR[2][0], armNear[2][1] - ARM_NEAR[2][1]];
  const lag = turn([ARM_NEAR[2]], ARM_NEAR[0][0], ARM_NEAR[0][1], swing(u - 0.06))[0];
  const toteD: P = [BAG_D[0] + lag[0] - ARM_NEAR[2][0], BAG_D[1] + lag[1] - ARM_NEAR[2][1] + bob];
  const fistD: P = [BAG_D[0] + wristD[0], BAG_D[1] + wristD[1]];

  // 2. her shadow on the slabs, stretched a little toward whichever foot is out in front
  inFig(() => fillShape(g, sm(SHADOW.map(([x, y]) => [x + (far.heel[0] - 651) * 0.25 * clamp((x - 150) / 500), y] as P)), T.shadow, T.shadowA));
  // 3. behind the body: the hair down her back, the phone arm's upper arm
  inFig(() => {
    g.push(0, bob, 1); inHead(g, () => hairBack(g, u)); g.pop();
    piece(g, limbTube(bodyFig([ARM_FAR[0], ARM_FAR[1]]), 40, 34), ACCENT, DEEP, 14, 5.5, 101);
  });
  // 4. the legs: the far one, the seat over its top, the near one in front, the seat's top again
  //    over the near thigh's cut end; then the top tucked into the trousers, neck, V neckline
  inFig(() => {
    shoe(g, far, 0);
    trouserLeg(g, far, [60, 45, 36], true, 110);
    CREASE_FAR.forEach((c, j) => stroke(g, shift(c, far.knee[0], far.knee[1]), 3, 112 + j, T.line, 0.9, 0.7));
    const seat = sm(bodyFig(SEAT), 3);
    cel(g, seat, PANTS, PANTS_SH, 22);
    outline(g, seat, 5.5, 111);
    shoe(g, near, 1);
    trouserLeg(g, near, [62, 46, 37], false, 119);
    CREASE_NEAR.forEach((c, j) => stroke(g, shift(c, near.knee[0], near.knee[1]), 3.4 - j * 0.4, 113 + j * 7, T.line, 0.9, 0.8 - j * 0.2));
    clipped(g, sm(bodyFig(SEAT_TOP), 3), () => cel(g, seat, PANTS, PANTS_SH, 22));
    stroke(g, bodyFig(SEAT_L), 5.5, 117, T.line, 0.3);
    stroke(g, bodyFig(SEAT_R), 5.5, 118, T.line, 0.3);
    stroke(g, bodyFig([[402, 1700], [404, 1756]]), 3, 114, T.line, 0.9, 0.6);
    piece(g, sm(bodyFig(NECK)), SKIN, SKIN_SH, 10, 5, 115);
    piece(g, sm(bodyFig(TORSO)), ACCENT, DEEP, 30, 6, 116);
    fillShape(g, sm(bodyFig(TORSO_SH)), DEEP, 0.9);
    outline(g, sm(bodyFig(TORSO)), 6, 116);
    stroke(g, bodyFig([[300, 1530], [482, 1526]]), 4.5, 117);
    piece(g, sm(bodyFig(VNECK)), HIGH, DEEP, 4, 3.5, 118);
    fillShape(g, sm(bodyFig([[380, 1372], [440, 1390], [506, 1384], [516, 1404], [460, 1418], [392, 1408]])), DEEP, 0.55);
  });
  // 5. the tote over her near leg, its handles up into the fist, the near arm swinging
  inFig(() => {
    const [tx, ty] = toteD, [fx, fy] = fistD;
    // the handles run from the bag's mouth up into the fist, wherever each one is
    const handle = (a: P, b: P): P[] => [[a[0] + tx, a[1] + ty], [(a[0] + tx + b[0] + fx) / 2 + 6, (a[1] + ty + b[1] + fy) / 2], [b[0] + fx, b[1] + fy]];
    strap(g, handle([290, 1848], [352, 1754]), 5, "#ECE5D8", 130);
    strap(g, handle([426, 1842], [366, 1756]), 5, "#ECE5D8", 132);
    const tote = shift([[262, 1846], [452, 1840], [470, 2112], [240, 2120]], tx, ty).flatMap((p, i, q) => { const r = q[(i + 1) % q.length]; return [p, [(p[0] * 2 + r[0]) / 3, (p[1] * 2 + r[1]) / 3], [(p[0] + r[0] * 2) / 3, (p[1] + r[1] * 2) / 3]] as P[]; });
    piece(g, tote, "#ECE5D8", "#D2C6B1", 16, 5.5, 134);
    clipped(g, tote, () => fillShape(g, shift([[414, 1842], [452, 1840], [470, 2112], [432, 2114]], tx, ty), "#D2C6B1", 0.9));
    outline(g, tote, 5.5, 134);
    stroke(g, shift([[268, 1876], [458, 1870]], tx, ty), 3, 135, T.line, 0.9, 0.45);
    piece(g, limbTube(armNear, 42, 34), ACCENT, DEEP, 16, 6, 136);
    const elbow = armNear[1];
    stroke(g, [[elbow[0] + 18, elbow[1] - 14], [elbow[0] + 30, elbow[1] + 2]], 3, 137, DEEP, 0.9, 0.9);
    const cuffDir = Math.atan2(armNear[2][1] - armNear[1][1], armNear[2][0] - armNear[1][0]);
    const cuffA: P = [armNear[2][0] - Math.cos(cuffDir) * 32, armNear[2][1] - Math.sin(cuffDir) * 32];
    piece(g, tube([cuffA, armNear[2]], 35, 34, true), HIGH, DEEP, 4, 4, 138);
    const f = fist(fistD);
    piece(g, f.back, SKIN, SKIN_SH, 8, 4.5, 140);
    f.fingers.forEach((s, j) => piece(g, s, SKIN, SKIN_SH, 4, 3.4, 141 + j));
    piece(g, f.thumb, SKIN, SKIN_SH, 4, 3.8, 145);
  });
  // 6. the head, talking
  const open = mouthOpen(frame);
  inFig(() => { g.push(0, bob, 1); inHead(g, () => head(g, open)); g.pop(); });
  // 7. the phone arm in front of her chest: forearm up, the iPhone's back, her hand on it; the
  //    phone rocks a degree with the steps
  inFig(() => {
    const deg = PHONE.deg + 1.2 * Math.sin(4 * Math.PI * u - 0.5);
    const ph = (pts: P[]): P[] => turn(pts.map(([x, y]) => [PHONE.cx + x, PHONE.cy + bob + y] as P), PHONE.cx, PHONE.cy + bob, deg);
    const [e, w] = bodyFig([ARM_FAR[1], ARM_FAR[2]]);
    piece(g, limbTube([e, w], 36, 31), ACCENT, DEEP, 12, 5.5, 150);
    { const l = Math.hypot(w[0] - e[0], w[1] - e[1]), d: P = [(w[0] - e[0]) / l, (w[1] - e[1]) / l];
      piece(g, limbTube([[w[0] - d[0] * 40, w[1] - d[1] * 40], [w[0] - d[0] * 8, w[1] - d[1] * 8]], 32, 31), HIGH, DEEP, 4, 4, 162); }
    const { w: pw, h: phh } = PHONE;
    fillShape(g, ph(shift(softBox(0, 0, pw, phh, 6, 40), -8, 3)), "#121D33");
    piece(g, ph(softBox(0, 0, pw, phh, 6, 40)), "#3B5584", "#24365A", 8, 4.5, 151);
    piece(g, ph(softBox(-20, -66, 50, 50, 4, 24)), "#4A6496", "#2C3F66", 4, 3.5, 152);
    ([[-31, -77], [-31, -55], [-9, -66]] as P[]).forEach((c, j) => { const l = ph(circle(c, 9.5, 16)); fillShape(g, l, T.ink); outline(g, l, 2.4, 153 + j, T.ink); fillShape(g, ph(circle([c[0] + 2.5, c[1] - 2.5], 2.6, 8)), "#9DB6E0"); });
    fillShape(g, ph(circle([-8, -84], 3.6, 10)), "#E8F0FF");
    const ch = phoneHand(ph);
    piece(g, ch.back, SKIN, SKIN_SH, 6, 4.5, 156);
    ch.fingers.forEach((s, j) => piece(g, s, SKIN, SKIN_SH, 4, 3.4, 157 + j));
    piece(g, ch.thumb, SKIN, SKIN_SH, 4, 3.8, 161);
  });

  // 8. the voice: three thin marker strokes; their waver travels out from her lips, three
  //    swells per loop, and they end in three bars of the waveform that pulse like it
  const VOICE = voiceFrom(fig([MOUTH_F[0], MOUTH_F[1] + bob]));
  g.group("plain", () => {
    const flow = 2 * Math.PI * 3 * tau(frame);
    [-1, 0, 1].forEach((o, j) => {
      const pts: P[] = [], f1 = [3.2, 4.1, 3.6][j], f2 = [9.5, 7.3, 11.2][j], ph = [0.4, 2.1, 4.0][j];
      for (let s = 0; s <= VOICE.total; s += 8) {
        const t = s / VOICE.total, rise = Math.min(1, s / 90), x = at(VOICE, s).p[0];
        const level = Math.max(0.25, Math.min(1, (1300 - x) / 160));
        const waver = (Math.sin(t * Math.PI * f1 + ph - flow) * 6 + Math.sin(t * Math.PI * f2 + ph * 1.7 - 2 * flow) * 2.2) * rise * level;
        pts.push(off(VOICE, s, o * spread(s) * (0.85 + 0.15 * Math.sin(t * 9 + j)) + waver));
      }
      g.pen(pts, { w: [5, 6.4, 4.2][j], color: [HIGH, ACCENT, DEEP][j], seed: 170 + j, closed: false, wobble: 0.9, boil: 0, taper: 0.9, opacity: 1, retrace: false });
    });
    BARS.forEach(([x, h0, n], j) => {
      const h = h0 * (1 + 0.24 * cyc(frame, n, j * 1.9)), y = VOICE_END[1];
      fillShape(g, tube([[x, y - h / 2 + 13], [x, y + h / 2 - 13]], 13, 13, true), T.voiceEnd[j]);
    });
  });
};

const film = (theme: Theme, title: string): Film => ({
  meta: { title: `Dictus onboarding intro A · walking · ${theme.name}`, W: FRAME.w, H: FRAME.h, fps: FPS, bpm: BPM, durationFrames: LOOP },
  assets: { images: {} },
  shots: [{ id: title, start: 0, end: LOOP, draw: drawFor(theme) }],
});
export const introWalkLight = film(THEMES.light, "introWalkLight");
export const introWalkDark = film(THEMES.dark, "introWalkDark");
