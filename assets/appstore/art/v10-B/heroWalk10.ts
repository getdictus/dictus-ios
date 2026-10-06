import { Gfx, softBox, tube, turn, type Ctx, type Env, type Medium, type P } from "./core";
import type { Film } from "./film";
import { clipped, fillShape, smooth } from "./gallery";

// DICTUS HERO V10-B · "hands full", round 2 (V9-B is art/v9-B/heroWalk9.ts). One action: she walks
// and dictates. The tote fills one hand, so typing is out; the other hand holds her iPhone up near
// her mouth, its BACK to us (the camera module in marker), and she speaks into it. Slide 2 is then
// the screen of the phone she holds. Her voice is three thin blue marker strokes, V6 to V8's, with
// her words hand-lettered along the top one; they cross the cut and slip under slide 2's recording
// panel at the height of its waveform.
//
// The canvas IS the strip: 2640 x 2868 placed at (0, 0), slides 1 and 2. PANEL_IN is where the
// strokes reach slide 2's lifted panel, in strip pixels, measured on screenshots.html.
//
// Character: V7's "woman, curves" (art/v7/heroCast.ts), its head drawn by V7's own code through a
// transform; same face, hair, V-neck top and high-waisted trousers, V7's ratios.
//
// Walk reference: the walk cycle's CONTACT position as drawn in Richard Williams, The Animator's
// Survival Kit (walk chapter), and Eadweard Muybridge's "woman walking" plates (Animal Locomotion,
// 1887), seen in three-quarter. She faces viewer-right, so her RIGHT side is the near side.
// - Front leg (her left, far): nearly straight, the heel striking, toes lifted.
// - Back leg (her right, near): pushing off, the knee BENT forward, the shin angled back, the heel
//   high, the shoe on its ball.
// - Arms swing against the legs: the near arm, with the tote, swings forward (her right leg is
//   back); the tote hangs plumb from the fist and lags a little behind it.
// - The phone arm: upper arm down from the shoulder, elbow at the waist, forearm up so the hand
//   holds the phone at chin height; the back of her hand on the phone's back, four fingers across
//   it, the thumb up the far edge.
// - Depth: pavement in two-point perspective (horizon at her hips), the far kerb behind her legs,
//   her cast shadow away from the light (upper left), the tote over her near leg, the phone arm
//   in front of her chest.
//
// Rebuild art/v10-B/hero.png (anidoodle engine; md5 printed as "reproducible"):
//   node ~/.claude/skills/anidoodle/engine/tools/scaffold.mjs /tmp/art --still hero
//   cp assets/appstore/art/v10-B/heroWalk10.ts /tmp/art/src/canvas-core/
//   printf 'import { heroWalk10 } from "../canvas-core/heroWalk10";\nimport { mountFilm } from "./page";\nmountFilm(heroWalk10);\n' > /tmp/art/src/hosts/page-heroWalk10.ts
//   cd /tmp/art && npm install && npx playwright-core install chromium && node tools/still.mjs heroWalk10 --out out/hero.png

export const W = 2640, H = 2868;
export const PANEL_IN: P = [1396, 1838.5];
const CUT = 1320;

const MARKER: Medium = { nib: 2.4, taper: 0.55, pressure: 0.6, retrace: false, wobble: 0.6, rough: 0.3 };
const LIGHT: P = [-0.6, -0.8];
const INK = "#0A1628", ACCENT = "#3D7EFF", DEEP = "#2563EB", HIGH = "#6BA3FF", WHITE = "#FFFFFF";
const SKIN = "#F1C09C", SKIN_SH = "#D59674";
const PANTS = "#1E3354", PANTS_SH = "#0F1E36";
const sm = (pts: P[], per = 6) => smooth(pts, true, per);
const circle = (c: P, r: number, n = 24): P[] => Array.from({ length: n }, (_, i) => [c[0] + Math.cos((i / n) * Math.PI * 2) * r, c[1] + Math.sin((i / n) * Math.PI * 2) * r] as P);

// line weights are multiplied by LW: the head is drawn at HEAD_S, so its V7 weights are raised to
// match the body's
let LW = 1;
const cel = (g: Gfx, s: P[], lit: string, shade: string, k = 18) => {
  fillShape(g, s, shade);
  clipped(g, s, () => fillShape(g, s.map(([x, y]) => [x + LIGHT[0] * k, y + LIGHT[1] * k] as P), lit));
};
const outline = (g: Gfx, s: P[], w: number, seed: number) =>
  g.pen(s, { w: w * LW, color: INK, seed, closed: true, wobble: 0.5, boil: 0, taper: 0.3, opacity: 1, retrace: false });
const stroke = (g: Gfx, pts: P[], w: number, seed: number, color = INK, taper = 0.9, op = 1) =>
  g.pen(smooth(pts, false, 8), { w: w * LW, color, seed, closed: false, wobble: 0.5, boil: 0, taper, opacity: op, retrace: false });
const piece = (g: Gfx, s: P[], lit: string, shade: string, k: number, w: number, seed: number) => { cel(g, s, lit, shade, k); outline(g, s, w, seed); };

// ---------------------------------------------------------------- path utilities
type Path = { pts: P[]; len: number[]; total: number };
const pathOf = (ctrl: P[], per = 24): Path => {
  const pts = smooth(ctrl, false, per), len = [0];
  for (let i = 1; i < pts.length; i++) len.push(len[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]));
  return { pts, len, total: len[len.length - 1] };
};
// point and unit tangent at arc length s
const at = (p: Path, s: number): { p: P; t: P } => {
  const v = Math.max(0, Math.min(p.total, s));
  let i = 1; while (i < p.len.length - 1 && p.len[i] < v) i++;
  const a = p.pts[i - 1], b = p.pts[i], f = (v - p.len[i - 1]) / Math.max(1e-6, p.len[i] - p.len[i - 1]);
  const dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy) || 1;
  return { p: [a[0] + dx * f, a[1] + dy * f], t: [dx / l, dy / l] };
};
// a point offset from the path: `up` is the side a letter's top faces (left of the direction)
const off = (p: Path, s: number, v: number): P => { const { p: c, t } = at(p, s); return [c[0] + t[1] * v, c[1] - t[0] * v]; };
// both edges of a band along a path, half-width from hw(s)
const band = (p: Path, s0: number, s1: number, hw: (s: number) => number, step = 8): P[] => {
  const L: P[] = [], R: P[] = [];
  for (let s = s0; s <= s1 + 0.01; s += step) { L.push(off(p, s, hw(s))); R.push(off(p, s, -hw(s))); }
  return [...L, ...R.reverse()];
};
// a limb's two edges from its joints, half-widths at each joint
const limb = (joints: P[], hws: number[], n = 40): { left: P[]; right: P[] } => {
  const c = smooth(joints, false, 14), L: P[] = [], R: P[] = [];
  for (let k = 0; k <= n; k++) {
    const u = k / n, i = Math.min(c.length - 2, Math.floor(u * (c.length - 1))), a = c[i], b = c[i + 1];
    const f = u * (c.length - 1) - i, p: P = [a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f];
    const dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy) || 1;
    const seg = u * (hws.length - 1), j = Math.min(hws.length - 2, Math.floor(seg)), hw = hws[j] + (hws[j + 1] - hws[j]) * (seg - j);
    // left of the direction of travel (down the limb) is +x for a limb that points down
    L.push([p[0] + (dy / l) * hw, p[1] - (dx / l) * hw]); R.push([p[0] - (dy / l) * hw, p[1] + (dx / l) * hw]);
  }
  return { left: L, right: R };
};

// a limb with round ends, both of them: a shoulder is a ball, never a corner
const limbTube = (joints: P[], r0: number, r1: number): P[] => {
  const c = smooth(joints, false, 14), n = c.length, L: P[] = [], R: P[] = [];
  const dir = (i: number): P => { const a = c[Math.max(0, i - 1)], b = c[Math.min(n - 1, i + 1)], l = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1; return [(b[0] - a[0]) / l, (b[1] - a[1]) / l]; };
  c.forEach((p, i) => { const [dx, dy] = dir(i), r = r0 + ((r1 - r0) * i) / (n - 1); L.push([p[0] - dy * r, p[1] + dx * r]); R.push([p[0] + dy * r, p[1] - dx * r]); });
  // an arc of half a turn round p, from angle a0, clockwise or not, ends excluded
  const arc = (p: P, r: number, a0: number, sgn: number): P[] => Array.from({ length: 5 }, (_, k) => { const a = a0 + sgn * ((k + 1) / 6) * Math.PI; return [p[0] + Math.cos(a) * r, p[1] + Math.sin(a) * r] as P; });
  const aEnd = Math.atan2(dir(n - 1)[1], dir(n - 1)[0]), aStart = Math.atan2(dir(0)[1], dir(0)[0]);
  return [...L, ...arc(c[n - 1], r1, aEnd + Math.PI / 2, -1), ...R.reverse(), ...arc(c[0], r0, aStart - Math.PI / 2, -1)];
};

// ---------------------------------------------------------------- comic lettering
// Single-stroke capitals, the comic letterer's alphabet, in cap-height units (y UP, baseline 0).
// Every letter is a few marker strokes in the order a hand makes them.
const GLYPHS: Record<string, { w: number; s: P[][] }> = {
  T: { w: 0.62, s: [[[0, 1], [0.62, 1]], [[0.31, 1], [0.31, 0]]] },
  H: { w: 0.6, s: [[[0, 1], [0, 0]], [[0.6, 1], [0.6, 0]], [[0, 0.52], [0.6, 0.52]]] },
  A: { w: 0.66, s: [[[0, 0], [0.33, 1], [0.66, 0]], [[0.13, 0.36], [0.53, 0.36]]] },
  N: { w: 0.6, s: [[[0, 0], [0, 1], [0.6, 0], [0.6, 1]]] },
  K: { w: 0.58, s: [[[0, 1], [0, 0]], [[0.56, 1], [0.02, 0.4]], [[0.2, 0.6], [0.58, 0]]] },
  S: { w: 0.54, s: [[[0.52, 0.86], [0.42, 0.97], [0.25, 1], [0.09, 0.93], [0.03, 0.77], [0.12, 0.61], [0.3, 0.53], [0.46, 0.44], [0.54, 0.27], [0.49, 0.08], [0.31, 0], [0.13, 0.02], [0, 0.14]]] },
  F: { w: 0.52, s: [[[0.52, 1], [0, 1], [0, 0]], [[0, 0.54], [0.42, 0.54]]] },
  O: { w: 0.7, s: [Array.from({ length: 13 }, (_, i) => { const a = -Math.PI / 2 - (i / 12) * Math.PI * 2; return [0.35 + Math.cos(a) * 0.35, 0.5 + Math.sin(a) * 0.5] as P; })] },
  R: { w: 0.58, s: [[[0, 0], [0, 1], [0.34, 1], [0.51, 0.92], [0.56, 0.77], [0.5, 0.62], [0.33, 0.54], [0, 0.54]], [[0.28, 0.54], [0.58, 0]]] },
  E: { w: 0.5, s: [[[0.5, 1], [0, 1], [0, 0], [0.5, 0]], [[0, 0.53], [0.42, 0.53]]] },
  ".": { w: 0.1, s: [[[0.0, 0.03], [0.05, -0.01], [0.1, 0.03], [0.05, 0.08], [0.0, 0.03], [0.05, -0.01]]] },
};
const SPACE = 0.42, TRACK = 0.17;
const textWidth = (t: string) => [...t].reduce((a, ch, i) => a + (ch === " " ? SPACE : GLYPHS[ch].w + (i < t.length - 1 ? TRACK : 0)), 0);
// lay the text on the path: every glyph point is mapped through the path, so the letters bend
// with the ribbon; a little hand jitter in baseline and size, seeded
const letter = (g: Gfx, p: Path, text: string, s0: number, cap: number, color: string, w: number, lift: (s: number) => number = () => 0) => {
  let x = 0;
  [...text].forEach((ch, i) => {
    if (ch === " ") { x += SPACE; return; }
    const gl = GLYPHS[ch], jy = Math.sin(i * 2.7) * 0.035, js = 1 + Math.sin(i * 1.9) * 0.03;
    gl.s.forEach((st, k) => {
      const pts = st.map(([u, v]) => { const sa = s0 + (x + u * js) * cap; return off(p, sa, (v * js - 0.5 + jy) * cap + lift(sa)); });
      g.pen(smooth(pts, false, 6), { w, color, seed: 300 + i * 7 + k, closed: false, wobble: 0.35, boil: 0, taper: 0.35, opacity: 1, retrace: false });
    });
    x += gl.w + TRACK;
  });
};

// ---------------------------------------------------------------- the ground
const HORIZON = 1640;
const VP_L: P = [-1700, HORIZON], VP_R: P = [3300, HORIZON];
const toward = (vp: P, through: P, y: number): P => [vp[0] + ((through[0] - vp[0]) * (y - vp[1])) / (through[1] - vp[1]), y];
const KERB_A: P = [0, 1806], KERB_B: P = [CUT, 1948];   // the far kerb, on the line to VP_L

const ground = (g: Gfx) => {
  // the road beyond the kerb, and the pavement she walks on
  fillShape(g, [[-10, HORIZON + 60], [CUT + 10, HORIZON + 60], [CUT + 10, KERB_B[1]], [-10, KERB_A[1]]], "#D9E0EB");
  fillShape(g, [[-10, KERB_A[1]], [CUT + 10, KERB_B[1]], [CUT + 10, H], [-10, H]], "#E4E9F1");
  // the kerb stone: its top edge in light, its face in shade
  const kerbFace = (y: number) => [[-10, KERB_A[1] + y], [CUT + 10, KERB_B[1] + y * 1.12]] as P[];
  fillShape(g, [...kerbFace(0), ...kerbFace(22).reverse()], "#C4CEDD");
  stroke(g, kerbFace(0), 3.2, 500, INK, 0.2, 0.55);
  stroke(g, kerbFace(22), 2.2, 501, INK, 0.2, 0.3);
  // slab joints: long ones to VP_L, cross ones to VP_R, closer together as they recede
  [2060, 2230, 2470, 2800, 3260].forEach((y, k) => {
    const yAt = (x: number) => HORIZON + ((y - HORIZON) * (x - VP_L[0])) / (CUT - VP_L[0]);
    stroke(g, [[-10, yAt(-10)], [CUT + 10, yAt(CUT + 10)]] as P[], 2.6, 510 + k, INK, 0.2, 0.22);
  });
  [-560, -40, 560, 1240, 2050].forEach((x, k) => {
    const foot: P = [x, H + 40], top = toward(VP_R, foot, KERB_A[1] + 40);
    stroke(g, [top, foot], 2.4, 520 + k, INK, 0.2, 0.2);
  });
};


// ---------------------------------------------------------------- the figure
// Everything below is in FIGURE space, drawn through one transform (FIG). canvas = FIG.at + p * FIG.s
const FIG = { at: [4.8, -72] as P, s: 1.06 };
const fig = ([x, y]: P): P => [FIG.at[0] + x * FIG.s, FIG.at[1] + y * FIG.s];
const shift = (pts: P[], dx: number, dy: number): P[] => pts.map(([x, y]) => [x + dx, y + dy]);

// her shadow, cast away from the light across the slabs: from the feet down to the right
const SHADOW: P[] = [[170, 2380], [300, 2420], [430, 2446], [590, 2452], [720, 2448], [880, 2470], [1010, 2506], [1080, 2540], [1020, 2562], [860, 2558], [690, 2530], [510, 2506], [330, 2474], [190, 2426]];

// head: V7 coordinates through a second transform; V7's face centre (560, 500) lands on HEAD_AT
const HEAD_AT: P = [401, 970], HEAD_S = 0.78;
const hv = ([x, y]: P): P => [HEAD_AT[0] + (x - 560) * HEAD_S, HEAD_AT[1] + (y - 500) * HEAD_S];
const MOUTH = fig(hv([688, 602]));

// legs: hip, knee, ankle. The back leg's knee is bent forward and its shin angled back (push-off)
const LEG_FAR = [[452, 1680], [540, 2032], [604, 2392]] as P[];    // her left, heel striking
const LEG_NEAR = [[344, 1690], [360, 2028], [212, 2316]] as P[];   // her right, pushing off
// arms: shoulder, elbow, wrist
const ARM_NEAR = [[298, 1238], [322, 1450], [376, 1650]] as P[];   // her right, swung forward, the tote
const ARM_FAR = [[500, 1228], [580, 1466], [676, 1300]] as P[];    // her left, the phone up at her chin
const BAG_D: P = [36, -14];                                          // the fist and tote follow the swing

// the top, three-quarter: back and near side on the left, the chest's profile on the right
const TORSO: P[] = [[368, 1160], [330, 1172], [292, 1192], [266, 1226], [262, 1290], [276, 1380], [294, 1468], [300, 1532], [482, 1528], [476, 1478], [492, 1420], [516, 1362], [524, 1300], [520, 1242], [502, 1198], [462, 1174], [428, 1162]];
const TORSO_SH: P[] = [[266, 1226], [292, 1192], [330, 1174], [320, 1260], [320, 1360], [336, 1530], [300, 1532], [294, 1468], [276, 1380], [262, 1290]];
const NECK: P[] = [hv([506, 672]), hv([596, 686]), [430, 1174], [368, 1170]];
const VNECK: P[] = [[362, 1162], [404, 1224], [436, 1162], [446, 1172], [404, 1252], [352, 1172]];
// the long hair falls down her back, its ends lifted a little behind her by the walk (V7 coordinates)
const HAIR_BACK: P[] = [[452, 620], [402, 560], [376, 470], [392, 372], [450, 296], [540, 262], [610, 270], [560, 330], [470, 420], [446, 520], [462, 640], [470, 760], [452, 880], [410, 990], [350, 1074], [296, 1102], [262, 1090], [296, 1040], [300, 960], [300, 860], [320, 760], [340, 690]];
const HAIR_STRANDS: P[][] = [[[430, 700], [420, 840], [380, 960], [320, 1060]], [[390, 640], [370, 780], [350, 900], [300, 1000]], [[440, 560], [440, 700], [430, 820]]];

const trousers = (): P[] => {
  const n = limb(LEG_NEAR, [62, 46, 37]), f = limb(LEG_FAR, [60, 45, 36]);
  // `right` is the screen-left edge of a limb drawn downward, `left` the screen-right one
  const nearOuter = n.right, nearInner = n.left, farInner = f.right, farOuter = f.left;
  return [[300, 1524], [280, 1572], [270, 1628], ...nearOuter.slice(4), ...[...nearInner].reverse().slice(0, -12), [404, 1756], ...farInner.slice(12), ...[...farOuter].reverse().slice(0, -4), [514, 1630], [500, 1572], [484, 1524]];
};

// a trainer in profile, heel at the origin, sole on y = 0, toe along +x; placed by its heel and
// the angle of the sole (negative lifts the toe)
const TRAINER: P[] = [[0, -8], [4, -50], [28, -62], [58, -58], [98, -46], [140, -36], [172, -26], [190, -12], [188, 4], [150, 8], [80, 8], [8, 6]];
const T_SOLE: P[] = [[-2, 2], [80, 6], [150, 6], [190, 0], [194, 12], [150, 20], [80, 20], [0, 16]];
const T_LACES: P[][] = [[[66, -56], [80, -68]], [[88, -50], [102, -62]], [[110, -44], [124, -56]]];
const place = (pts: P[], heel: P, deg: number): P[] => turn(pts.map(([x, y]) => [heel[0] + x, heel[1] + y] as P), heel[0], heel[1], deg);
const FEET = [{ heel: [588, 2448] as P, deg: -13 }, { heel: [176, 2330] as P, deg: 26 }];

// the tote, hanging plumb from the fist; it overlaps her near thigh
const TOTE: P[] = shift([[262, 1846], [452, 1840], [470, 2112], [240, 2120]], BAG_D[0], BAG_D[1]);
const TOTE_SH: P[] = shift([[414, 1842], [452, 1840], [470, 2112], [432, 2114]], BAG_D[0], BAG_D[1]);
const subdivide = (q: P[]): P[] => q.flatMap((p, i) => { const r = q[(i + 1) % q.length]; return [p, [(p[0] * 2 + r[0]) / 3, (p[1] * 2 + r[1]) / 3], [(p[0] + r[0] * 2) / 3, (p[1] + r[1] * 2) / 3]] as P[]; });

// ---------------------------------------------------------------- hands
// the fist round the tote's handles: the back of the hand, four curled fingers in front (index on
// top, little finger shortest at the bottom), the thumb laid across the index
const fist = () => {
  const [dx, dy] = BAG_D;
  const back = sm(shift([[322, 1668], [362, 1664], [382, 1690], [386, 1736], [368, 1762], [336, 1760], [318, 1726]], dx, dy), 4);
  const fingers = [0, 1, 2, 3].map((k) => { const y = 1702 + k * 16 + dy, r = [40, 42, 38, 30][k]; return tube([[350 + dx, y], [350 + dx + r * 0.7, y - 1], [350 + dx + r, y + 6]], 9.5, 8.5, true); });
  const thumb = tube(shift([[346, 1680], [372, 1684], [394, 1700]], dx, dy), 10.5, 9, true);
  return { back, fingers, thumb };
};
// the iPhone, back to us, held up at her chin; PHONE-local coordinates (u across, v down from the
// centre) are turned with the phone
const PHONE = { cx: 624, cy: 1176, w: 104, h: 208, deg: -10 };
const ph = (pts: P[]): P[] => turn(pts.map(([u, v]) => [PHONE.cx + u, PHONE.cy + v] as P), PHONE.cx, PHONE.cy, PHONE.deg);
const phoneHand = () => {
  // the back of her hand over the phone's lower back, the wrist below its bottom edge
  const back = sm(ph([[8, 36], [50, 26], [66, 66], [62, 110], [36, 132], [4, 124], [-10, 88]]), 4);
  // four fingers across the back toward the near edge, the index highest, the little finger shortest
  const fingers = [0, 1, 2, 3].map((k) => { const v = 18 + k * 21, r = [92, 96, 90, 76][k]; return tube(ph([[30, v + 6], [30 - r * 0.6, v], [30 - r, v - 4]]), 10.5, 9.5, true); });
  // the thumb up the far edge
  const thumb = tube(ph([[44, 54], [54, 14], [58, -24]]), 11.5, 10, true);
  return { back, fingers, thumb };
};

// ---------------------------------------------------------------- the voice (canvas pixels)
// one smooth arch from her lips, over the phone, down at the cut and into the panel
const VOICE = pathOf([[MOUTH[0] + 12, MOUTH[1] - 6], [600, 994], [700, 934], [830, 900], [960, 898], [1080, 930], [1178, 1008], [1246, 1136], [1282, 1314], [1300, 1510], [1320, 1684], [1354, 1790], [PANEL_IN[0], PANEL_IN[1]]], 30);
const TEXT = "THANKS FOR THE NOTES...", CAP = 50, TEXT_AT = 64;
const spread = (s: number) => { const t = Math.min(1, s / VOICE.total), e = t * t * (3 - 2 * t); return 4 + 30 * e; };

// ---------------------------------------------------------------- the head (V7 "woman, curves", V7 coordinates)
const C_FACE: P[] = [[455, 366], [530, 336], [608, 346], [662, 396], [688, 460], [694, 522], [682, 582], [656, 634], [612, 674], [556, 690], [500, 678], [456, 642], [428, 586], [418, 516], [426, 440]];
const C_HAIR_FRONT: P[] = [[422, 470], [436, 380], [490, 318], [566, 290], [640, 296], [696, 330], [720, 384], [704, 392], [664, 360], [612, 344], [566, 352], [526, 384], [492, 440], [470, 520], [460, 600], [440, 660], [420, 600]];
const inHead = (g: Gfx, fn: () => void) => { g.push(HEAD_AT[0] - 560 * HEAD_S, HEAD_AT[1] - 500 * HEAD_S, HEAD_S); LW = 1.35; fn(); LW = 1; g.pop(); };
const hairBack = (g: Gfx) => {
  piece(g, sm(HAIR_BACK), "#2C3F66", "#18264A", 18, 7, 80);
  HAIR_STRANDS.forEach((s, k) => stroke(g, s, 3, 84 + k, "#4A6496", 0.9, 0.8));
};
const head = (g: Gfx) => {
  piece(g, sm(C_FACE), SKIN, SKIN_SH, 26, 6, 81);
  fillShape(g, sm([[514, 540], [544, 526], [568, 538], [554, 560], [524, 562]]), "#EE9D86", 0.45);
  fillShape(g, sm([[650, 524], [672, 516], [684, 532], [670, 548]]), "#EE9D86", 0.4);
  piece(g, sm(C_HAIR_FRONT), "#3A5486", "#1E2F55", 16, 6, 82);
  const eyeL = sm([[528, 464], [548, 448], [576, 450], [594, 464], [574, 474], [548, 474]], 4), eyeR = sm([[630, 458], [648, 444], [670, 446], [682, 458], [666, 468], [644, 468]], 4);
  fillShape(g, eyeL, WHITE); fillShape(g, eyeR, WHITE);
  fillShape(g, circle([562, 462], 11, 16), "#2F4C7A"); fillShape(g, circle([658, 457], 10, 16), "#2F4C7A");
  fillShape(g, circle([562, 462], 5, 10), INK); fillShape(g, circle([658, 457], 4.5, 10), INK);
  fillShape(g, circle([566, 458], 2.6, 8), WHITE); fillShape(g, circle([661, 453], 2.4, 8), WHITE);
  stroke(g, [[526, 466], [548, 448], [576, 450], [596, 466]], 5.5, 83); stroke(g, [[628, 460], [648, 444], [670, 446], [684, 460]], 5, 84);
  stroke(g, [[596, 466], [606, 456]], 3, 85); stroke(g, [[684, 460], [694, 450]], 3, 86);
  stroke(g, [[528, 424], [556, 410], [588, 416]], 4, 87); stroke(g, [[630, 414], [652, 404], [676, 410]], 3.5, 88);
  stroke(g, [[666, 492], [680, 520], [664, 528]], 4, 89);
  const mouth = sm([[588, 588], [630, 580], [670, 576], [670, 602], [654, 626], [626, 638], [600, 632], [588, 610]]);
  fillShape(g, mouth, INK);
  clipped(g, mouth, () => { fillShape(g, sm([[592, 592], [668, 580], [668, 598], [596, 604]], 3), WHITE); fillShape(g, sm([[606, 630], [626, 618], [648, 620], [652, 632], [628, 640]]), "#E7826F"); });
  g.pen(smooth([[582, 584], [628, 572], [676, 570]], false, 6), { w: 7 * LW, color: "#C9645A", seed: 90, wobble: 0.3, boil: 0, taper: 0.9, opacity: 0.85, retrace: false });
  g.pen(smooth([[594, 640], [628, 646], [658, 630]], false, 6), { w: 6 * LW, color: "#C9645A", seed: 91, wobble: 0.3, boil: 0, taper: 0.9, opacity: 0.75, retrace: false });
  outline(g, mouth, 4, 92);
  fillShape(g, circle([436, 560], 9, 14), ACCENT); outline(g, circle([436, 560], 9, 14), 2.5, 93);
};

// a strap: an ink edge with the material inside
const strap = (g: Gfx, pts: P[], w: number, color: string, seed: number) => { stroke(g, pts, w + 3.2, seed, INK, 0.1); stroke(g, pts, w, seed + 1, color, 0.1); };

// ---------------------------------------------------------------- the picture
const draw = (ctx: Ctx, _frame: number, env: Env) => {
  const g = new Gfx(ctx, env, 0, MARKER);
  ctx.setTransform(env.scale, 0, 0, env.scale, 0, 0);
  ctx.clearRect(0, 0, W, H);

  // 1. the ground, faded out toward the horizon and before the cut
  g.group("plain", () => ground(g));
  ctx.save(); ctx.setTransform(env.scale, 0, 0, env.scale, 0, 0); ctx.globalCompositeOperation = "destination-out";
  const up = ctx.createLinearGradient(0, HORIZON + 60, 0, KERB_A[1] + 40); up.addColorStop(0, "rgba(0,0,0,1)"); up.addColorStop(1, "rgba(0,0,0,0)");
  ctx.fillStyle = up; ctx.fillRect(0, HORIZON, CUT + 20, KERB_B[1] + 60 - HORIZON);
  const right = ctx.createLinearGradient(980, 0, CUT, 0); right.addColorStop(0, "rgba(0,0,0,0)"); right.addColorStop(1, "rgba(0,0,0,1)");
  ctx.fillStyle = right; ctx.fillRect(980, HORIZON, CUT + 40 - 980, H - HORIZON);
  ctx.fillStyle = "rgba(0,0,0,1)"; ctx.fillRect(CUT, 0, W - CUT, H);
  ctx.restore();

  const inFig = (fn: () => void) => g.group("plain", () => { g.push(FIG.at[0], FIG.at[1], FIG.s); fn(); g.pop(); });
  // 2. her shadow on the slabs
  inFig(() => fillShape(g, sm(SHADOW), INK, 0.16));
  // 3. behind the body: her hair down her back, the phone arm's upper arm, the shoes
  inFig(() => {
    inHead(g, () => hairBack(g));
    piece(g, limbTube([ARM_FAR[0], ARM_FAR[1]], 40, 34), ACCENT, DEEP, 14, 5.5, 101);
    FEET.forEach((f, k) => {
      piece(g, sm(place(TRAINER, f.heel, f.deg), 4), WHITE, "#D3DCEA", 10, 5, 102 + k * 2);
      piece(g, sm(place(T_SOLE, f.heel, f.deg), 4), "#C4CEDD", "#A9B6CA", 4, 4, 103 + k * 2);
      T_LACES.forEach((l, j) => stroke(g, place(l, f.heel, f.deg), 2.6, 106 + k * 3 + j));
    });
  });
  // 4. the trousers (both legs, one silhouette), the top tucked into them, neck, V neckline
  inFig(() => {
    const tr = sm(trousers(), 3);
    cel(g, tr, PANTS, PANTS_SH, 22);
    // the far leg sits a half-tone back
    clipped(g, tr, () => fillShape(g, tube([[500, 1840], ...LEG_FAR.slice(1), [640, 2420]], 40, 34, true), PANTS_SH, 0.35));
    outline(g, tr, 5.5, 110);
    // knee creases: the far knee nearly straight, the near one folded
    stroke(g, [[516, 2008], [544, 2028], [570, 2024]], 3, 112, INK, 0.9, 0.7);
    stroke(g, [[326, 2010], [352, 2042], [384, 2036]], 3.4, 113, INK, 0.9, 0.8);
    stroke(g, [[330, 2060], [350, 2074]], 3, 111, INK, 0.9, 0.6);
    stroke(g, [[402, 1700], [404, 1756]], 3, 114, INK, 0.9, 0.6);
    piece(g, sm(NECK), SKIN, SKIN_SH, 10, 5, 115);
    piece(g, sm(TORSO), ACCENT, DEEP, 30, 6, 116);
    fillShape(g, sm(TORSO_SH), DEEP, 0.9);
    outline(g, sm(TORSO), 6, 116);
    stroke(g, [[300, 1530], [482, 1526]], 4.5, 117);
    piece(g, sm(VNECK), HIGH, DEEP, 4, 3.5, 118);
    // the chest's form, a soft shade under it, no line
    fillShape(g, sm([[380, 1372], [440, 1390], [506, 1384], [516, 1404], [460, 1418], [392, 1408]]), DEEP, 0.55);
  });
  // 5. the tote over her near leg, its handles up into the fist, the near arm swung forward
  inFig(() => {
    const [dx, dy] = BAG_D;
    strap(g, shift([[290, 1848], [318, 1790], [352, 1754]], dx, dy), 5, "#ECE5D8", 130);
    strap(g, shift([[426, 1842], [398, 1786], [366, 1756]], dx, dy), 5, "#ECE5D8", 132);
    const tote = subdivide(TOTE);
    piece(g, tote, "#ECE5D8", "#D2C6B1", 16, 5.5, 134);
    clipped(g, tote, () => fillShape(g, TOTE_SH, "#D2C6B1", 0.9));
    outline(g, tote, 5.5, 134);
    stroke(g, shift([[268, 1876], [458, 1870]], dx, dy), 3, 135, INK, 0.9, 0.45);
    piece(g, limbTube(ARM_NEAR, 42, 34), ACCENT, DEEP, 16, 6, 136);
    stroke(g, [[340, 1436], [352, 1452]], 3, 137, DEEP, 0.9, 0.9);
    piece(g, tube([[366, 1618], [376, 1652]], 35, 34, true), HIGH, DEEP, 4, 4, 138);
    const f = fist();
    piece(g, f.back, SKIN, SKIN_SH, 8, 4.5, 140);
    f.fingers.forEach((s, k) => piece(g, s, SKIN, SKIN_SH, 4, 3.4, 141 + k));
    piece(g, f.thumb, SKIN, SKIN_SH, 4, 3.8, 145);
  });
  // 6. the head
  inFig(() => inHead(g, () => head(g)));
  // 7. the phone arm in front of her chest: forearm up, the iPhone's back, her hand on it
  inFig(() => {
    piece(g, limbTube([ARM_FAR[1], ARM_FAR[2]], 36, 31), ACCENT, DEEP, 12, 5.5, 150);
    // the cuff at the wrist, along the forearm
    { const [e, w] = [ARM_FAR[1], ARM_FAR[2]], l = Math.hypot(w[0] - e[0], w[1] - e[1]), u: P = [(w[0] - e[0]) / l, (w[1] - e[1]) / l];
      piece(g, limbTube([[w[0] - u[0] * 40, w[1] - u[1] * 40], [w[0] - u[0] * 8, w[1] - u[1] * 8]], 32, 31), HIGH, DEEP, 4, 4, 162); }
    const { w, h } = PHONE;
    // the phone's edge shows its thickness on the side turned from us
    fillShape(g, ph(shift(softBox(0, 0, w, h, 6, 40), -8, 3)), "#121D33");
    const back = ph(softBox(0, 0, w, h, 6, 40));
    piece(g, back, "#3B5584", "#24365A", 8, 4.5, 151);
    // the camera module, top corner on the far side from her hand: three lenses and a flash
    const cam = ph(softBox(-20, -66, 50, 50, 4, 24));
    piece(g, cam, "#4A6496", "#2C3F66", 4, 3.5, 152);
    ([[-31, -77], [-31, -55], [-9, -66]] as P[]).forEach((c, k) => { const l = ph(circle(c, 9.5, 16)); fillShape(g, l, INK); outline(g, l, 2.4, 153 + k); fillShape(g, ph(circle([c[0] + 2.5, c[1] - 2.5], 2.6, 8)), "#9DB6E0"); });
    fillShape(g, ph(circle([-8, -84], 3.6, 10)), "#E8F0FF");
    const ch = phoneHand();
    piece(g, ch.back, SKIN, SKIN_SH, 6, 4.5, 156);
    ch.fingers.forEach((s, k) => piece(g, s, SKIN, SKIN_SH, 4, 3.4, 157 + k));
    piece(g, ch.thumb, SKIN, SKIN_SH, 4, 3.8, 161);

  });

  // 8. the voice: three thin marker strokes, her words lettered along the top one
  g.group("plain", () => {
    [-1, 0, 1].forEach((o, k) => {
      const pts: P[] = [];
      for (let s = 0; s <= VOICE.total; s += 10) {
        const t = s / VOICE.total, wave = Math.sin(t * Math.PI * 5 + k * 1.3) * 5 * Math.sin(Math.PI * Math.min(1, t * 1.15));
        pts.push(off(VOICE, s, o * spread(s) + wave));
      }
      g.pen(pts, { w: [5.2, 6.6, 4.4][k], color: [HIGH, ACCENT, DEEP][k], seed: 170 + k, closed: false, wobble: 0.3, boil: 0, taper: 0.5, opacity: 1, retrace: false });
    });
    letter(g, VOICE, TEXT, TEXT_AT, CAP, INK, 4, (s) => spread(s) + 20 + CAP / 2);
  });
};

export const heroWalk10: Film = {
  meta: { title: "Dictus hero V10-B · hands full, round 2", W, H, fps: 30, bpm: 120, durationFrames: 1 }, assets: { images: {} },
  shots: [{ id: "heroWalk10", start: 0, end: 1, draw }],
};
