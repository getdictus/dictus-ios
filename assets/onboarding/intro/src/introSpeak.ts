import { Gfx, tube, turn, type Ctx, type Env, type Medium, type P } from "./core";
import type { Film } from "./film";
import { clipped, fillShape, smooth } from "./gallery";
import { mm, WAVE_MM } from "./phoneGeometry";
import { BPM, cyc, FPS, FRAME, LOOP, place, tau, THEMES, type Theme } from "./theme";

// ONBOARDING INTRO, SCENE B · "dictating" (issue #667). The App Store hero V10-A's front layer
// (branch chore/643-hero-a, assets/appstore/art/v10-A/heroSpeak10.ts, drawFront) set in motion:
// the woman alone, seated, speaking; the voice strokes flow out of her. The phone she sat on in
// V10-A is scene C's subject, so it is not drawn here; its geometry still places her and aims
// her voice (phoneGeometry.ts), so she and the strokes are V10-A's to the pixel.
//
// What moves, periodic over the 4.5 s loop (theme.ts):
// - the mouth opens and closes on an irregular, speech-like beat, and the head nods a degree or
//   two with it, about the neck;
// - the three sound arcs at her lips are emitted: each one leaves the mouth, widens and fades,
//   four waves a loop;
// - the ripple riding each voice stroke travels out along it, away from her;
// - her open hand, the speaker's gesture, lifts and settles about the elbow.
//
// Character (V10-A's header): V7's woman-curves, the seated pose "on the floor, knees drawn up,
// leaning back on one straight arm, three-quarter view", turned to the viewer's right.

// The frame shows the drawing's own box (x 238..1135, y 755..2120 of the strip), laid out as the
// #649 mock-up does (designs/onboarding-649-assets/intro-speak.png): 289.5 pt wide, at 20.5 / 34 pt.
const PLACE = place([238, 755], 897, [20.5, 34], 289.5);

const MARKER: Medium = { nib: 2.4, taper: 0.55, pressure: 0.6, retrace: false, wobble: 0.6, rough: 0.3 };
const LIGHT: P = [-0.6, -0.8];
const ACCENT = "#3D7EFF", DEEP = "#2563EB", HIGH = "#6BA3FF", WHITE = "#FFFFFF";
const SKIN = "#F1C09C", SKIN_S = "#D59674", TROUSER = "#1E3354", TROUSER_S = "#0F1E36";
const sm = (pts: P[], per = 6) => smooth(pts, true, per);
const circle = (c: P, r: number, n = 24): P[] => Array.from({ length: n }, (_, i) => [c[0] + Math.cos((i / n) * Math.PI * 2) * r, c[1] + Math.sin((i / n) * Math.PI * 2) * r] as P);

// T is the appearance being drawn: set at the top of every frame, read only while it draws
let T: Theme = THEMES.light;
const cel = (g: Gfx, s: P[], lit: string, shade: string, k = 18) => {
  fillShape(g, s, shade);
  clipped(g, s, () => fillShape(g, s.map(([x, y]) => [x + LIGHT[0] * k, y + LIGHT[1] * k] as P), lit));
};
const outline = (g: Gfx, s: P[], w: number, seed: number, color = T.line) =>
  g.pen(s, { w, color, seed, closed: true, wobble: 0.5, boil: 0, taper: 0.3, opacity: 1, retrace: false });
const stroke = (g: Gfx, pts: P[], w: number, seed: number, color = T.line, taper = 0.9, op = 1) =>
  g.pen(smooth(pts, false, 8), { w, color, seed, closed: false, wobble: 0.5, boil: 0, taper, opacity: op, retrace: false });
const piece = (g: Gfx, s: P[], lit: string, shade: string, k: number, w: number, seed: number) => { cel(g, s, lit, shade, k); outline(g, s, w, seed); };

// ---------------------------------------------------------------- the figure (V10-A's)
// Figure-local coordinates are V7's (art/v7/heroCast.ts), so the head is V7's woman-curves head,
// point for point. FIG maps them to the strip.
const FIG = { k: 0.7, seat: [520, 1452] as P, at: mm(40, 28) };
const fig = (p: P): P => [FIG.at[0] + (p[0] - FIG.seat[0]) * FIG.k, FIG.at[1] + (p[1] - FIG.seat[1]) * FIG.k];

const C_FACE: P[] = [[455, 366], [530, 336], [608, 346], [662, 396], [688, 460], [694, 522], [682, 582], [656, 634], [612, 674], [556, 690], [500, 678], [456, 642], [428, 586], [418, 516], [426, 440]];
const C_HAIR_BACK: P[] = [[452, 620], [402, 560], [376, 470], [392, 372], [450, 296], [540, 262], [610, 270], [560, 330], [470, 420], [446, 520], [462, 640], [480, 760], [470, 880], [436, 1000], [392, 1070], [340, 1066], [316, 990], [330, 900], [324, 800], [350, 700]];
const C_HAIR_FRONT: P[] = [[422, 470], [436, 380], [490, 318], [566, 290], [640, 296], [696, 330], [720, 384], [704, 392], [664, 360], [612, 344], [566, 352], [526, 384], [492, 440], [470, 520], [460, 600], [440, 660], [420, 600]];
const MOUTH_AT: P = [678, 604];
// the head nods about the top of the neck
const NAPE: P = [552, 720];

const J = {
  shR: [440, 836] as P, elR: [370, 1092] as P, wrR: [338, 1338] as P,
  shL: [700, 822] as P, elL: [820, 1076] as P, wrL: [1050, 1066] as P,
  hipR: [560, 1350] as P, kneeR: [930, 1150] as P, ankR: [1012, 1500] as P, toeR: [1150, 1528] as P,
  hipL: [610, 1310] as P, kneeL: [985, 1100] as P, ankL: [1092, 1444] as P, toeL: [1226, 1462] as P,
};

const openHand = (wrist: P, dir: number, s: number, thumbSide: 1 | -1) => {
  const ux = Math.cos(dir), uy = Math.sin(dir), nx = -uy, ny = ux;
  const at = (a: number, b: number): P => [wrist[0] + ux * a * s + nx * b * s, wrist[1] + uy * a * s + ny * b * s];
  const palm = sm([at(-4, -34), at(30, -42), at(78, -40), at(86, 0), at(78, 40), at(30, 40), at(-4, 32)], 4);
  const spec = [[0.66, 66, 0.1], [0.22, 74, 0.03], [-0.22, 68, -0.05], [-0.64, 52, -0.13]];
  const fingers = spec.map(([o, len, spread]) => {
    const base = at(80, o * 40 * thumbSide), d = dir + spread * thumbSide;
    const mid: P = [base[0] + Math.cos(d) * len * 0.55 * s, base[1] + Math.sin(d) * len * 0.55 * s];
    const curl = dir + spread * thumbSide - 0.22 * thumbSide;
    const tip: P = [mid[0] + Math.cos(curl) * len * 0.45 * s, mid[1] + Math.sin(curl) * len * 0.45 * s];
    return tube(smooth([base, mid, tip], false, 6), 12.5 * s, 10 * s, true);
  });
  const tb = at(24, thumbSide * 38), td = dir + thumbSide * 0.8;
  const tm: P = [tb[0] + Math.cos(td) * 32 * s, tb[1] + Math.sin(td) * 32 * s], td2 = td - thumbSide * 0.5;
  const thumb = tube(smooth([tb, tm, [tm[0] + Math.cos(td2) * 30 * s, tm[1] + Math.sin(td2) * 30 * s]], false, 6), 14 * s, 11 * s, true);
  const crease = [at(60, -26 * thumbSide), at(36, -4 * thumbSide), at(16, 22 * thumbSide)];
  return { palm, fingers, thumb, crease };
};
const plantedHand = (wrist: P, s: number) => {
  const [x, y] = wrist;
  const palm = sm([[x + 30 * s, y - 30 * s], [x - 10 * s, y - 40 * s], [x - 70 * s, y - 34 * s], [x - 78 * s, y + 4 * s], [x - 70 * s, y + 34 * s], [x - 30 * s, y + 42 * s], [x + 26 * s, y + 30 * s]], 4);
  const fingers = [0, 1, 2, 3].map((k) => {
    const by = y + 26 * s - k * 17 * s, len = [60, 68, 62, 48][k] * s, bx = x - 66 * s + k * 4 * s, fan = (1.5 - k) * 0.09;
    const ux = -Math.cos(fan), uy = Math.sin(fan) + 0.12;
    return tube(smooth([[bx, by], [bx + ux * len * 0.55, by + uy * len * 0.55 + 3 * s], [bx + ux * len, by + uy * len + 8 * s]], false, 6), 12 * s, 10 * s, true);
  });
  const thumb = tube(smooth([[x - 4 * s, y + 30 * s], [x - 26 * s, y + 52 * s], [x - 56 * s, y + 58 * s]], false, 6), 13 * s, 10.5 * s, true);
  return { palm, fingers, thumb };
};
const hem = (knee: P, ank: P): P => { const d = [ank[0] - knee[0], ank[1] - knee[1]], l = Math.hypot(d[0], d[1]); return [ank[0] - (d[0] / l) * 64, ank[1] - (d[1] / l) * 64]; };
const shoe = (g: Gfx, ank: P, toe: P, upper: string, seed: number) => {
  const F = (pts: P[]) => pts.map(fig), [ax, ay] = ank, sy = ay + 52, tx = toe[0] + 24;
  piece(g, tube(F([[ax - 6, ay - 56], [ax - 2, ay - 10]]), 22 * FIG.k, 24 * FIG.k, true), SKIN, SKIN_S, 3, 3.5, seed + 9);
  const body = sm(F([[ax - 54, sy + 8], [ax - 62, ay + 10], [ax - 50, ay - 22], [ax - 8, ay - 32], [ax + 28, ay - 20], [ax + 72, ay + 2], [tx - 64, sy - 48], [tx - 22, sy - 44], [tx + 2, sy - 28], [tx + 8, sy - 4], [tx, sy + 10], [ax - 20, sy + 12]]), 5);
  cel(g, body, upper, "#C9D2E2", 5);
  clipped(g, body, () => fillShape(g, F([[ax - 80, sy - 6], [tx + 30, sy - 6], [tx + 30, sy + 30], [ax - 80, sy + 30]]), "#D3DBE7"));
  stroke(g, F([[ax - 58, sy - 6], [tx + 6, sy - 6]]), 2.8, seed + 1, "#8E9AB0", 0.4);
  outline(g, body, 4.2, seed);
  stroke(g, F([[tx - 66, sy - 44], [tx - 50, sy - 22], [tx - 44, sy - 8]]), 2.6, seed + 2, "#9AA6BC", 0.6);
  [0, 1, 2].forEach((n) => stroke(g, F([[ax + 22 + n * 18, ay - 12 + n * 10], [ax + 40 + n * 18, ay - 2 + n * 10]]), 3, seed + 3 + n, ACCENT, 0.5));
};

// ---------------------------------------------------------------- the voice
// V10-A's ripple, with a phase: the waves now run out along the stroke
const ripple = (pts: P[], amp: number, waves: number, phase: number): P[] => {
  const s = smooth(pts, false, 14);
  return s.map(([x, y], i) => {
    const a = s[Math.max(0, i - 1)], b = s[Math.min(s.length - 1, i + 1)], dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy) || 1;
    const t = i / (s.length - 1), w = Math.sin(t * Math.PI * waves - phase) * amp * Math.sin(Math.PI * Math.min(1, t * 1.15)) * (1 - t);
    return [x - (dy / l) * w, y + (dx / l) * w] as P;
  });
};
// one sound arc at radius r round the lips (V10-A's arc shape)
const soundArc = (m: P, k: number, r: number): P[] => Array.from({ length: 7 }, (_, i) => { const a = -0.75 + (i / 6) * 1.5; return [m[0] - 4 * k + Math.cos(a) * r, m[1] + 4 * k + Math.sin(a) * r] as P; });
// talking: the jaw between 70 % and 100 % of the drawn opening, on two beats that never line up
const mouthOpen = (frame: number) => 0.85 + 0.15 * (0.62 * cyc(frame, 11) + 0.38 * cyc(frame, 17, 1.3));

// ---------------------------------------------------------------- the picture
const drawFor = (theme: Theme) => (ctx: Ctx, frame: number, env: Env) => {
  T = theme;
  const g = new Gfx(ctx, env, frame, MARKER);
  g.push(-PLACE.o[0] * PLACE.k, -PLACE.o[1] * PLACE.k, PLACE.k);
  const F = (pts: P[]) => pts.map(fig), k = FIG.k;
  // the head: nod about the nape (degrees), and the jaw
  const nod = 1.3 * cyc(frame, 3, 0.4) + 0.6 * cyc(frame, 7);
  const open = mouthOpen(frame);
  const pivot = fig(NAPE), Hd = (pts: P[]) => turn(F(pts), pivot[0], pivot[1], nod) as P[];
  const jaw = (pts: P[]): P[] => pts.map(([x, y]) => [x, y > 584 ? 584 + (y - 584) * open : y] as P);
  const mouth = Hd([MOUTH_AT])[0], wave = mm(WAVE_MM[0] + 6, WAVE_MM[1] - 9);
  // the gesturing hand: the forearm turns about the elbow, the hand with it
  const lift = 2.6 * cyc(frame, 2, -0.6) + 1.2 * cyc(frame, 5, 1.1);
  const wrL = turn([J.wrL], J.elL[0], J.elL[1], lift)[0] as P;

  // her cast shadow where she sits
  g.group("plain", () => {
    fillShape(g, sm(F([[360, 1430], [640, 1410], [980, 1470], [1250, 1520], [1270, 1560], [1000, 1560], [620, 1500], [380, 1480]])), T.sitShadow, 1);
  });

  // the voice, behind the hand that gestures at it
  g.group("plain", () => {
    const dx = wave[0] - mouth[0], dy = wave[1] - mouth[1];
    const path = (o: number): P[] => [
      [mouth[0] + 14, mouth[1] + o * 0.3],
      [mouth[0] + 200, mouth[1] - 40 + o],
      [mouth[0] + dx + 330 + o * 0.6, mouth[1] + 0.3 * dy],
      [wave[0] + 250 + o * 0.9, mouth[1] + 0.68 * dy],
      [wave[0] + 70 + o * 0.6, wave[1] - 110 + o * 0.3],
      [wave[0] + o * 0.35, wave[1] + o * 0.15]];
    const flow = 2 * Math.PI * 3 * tau(frame);
    stroke(g, ripple(path(-40), 10, 6, flow), 6.5, 1, HIGH, 0.7);
    stroke(g, ripple(path(0), 14, 7, flow + 0.7), 8, 2, ACCENT, 0.6);
    stroke(g, ripple(path(40), 9, 6, flow + 1.4), 5.5, 3, DEEP, 0.7);
    // the sound arcs: three in flight at a time, each born at the lips and fading as it widens
    const k12 = k * 1.2;
    [0, 1, 2].forEach((n) => {
      const f = (4 * tau(frame) + n / 3) % 1, r = (26 + f * 66) * k12;
      const fade = Math.min(1, f / 0.15) * (1 - f) ** 0.7;
      stroke(g, soundArc(mouth, k12, r), 6 - 2.5 * f, 4 + n, T.line, 0.9, 0.9 * fade);
    });
  });

  g.group("plain", () => {
    // the long hair down her back
    piece(g, sm(Hd(C_HAIR_BACK)), "#2C3F66", "#18264A", 12, 5.5, 80);

    // far leg (her left): thigh, shin, trainer
    piece(g, tube(F([J.hipL, J.kneeL]), 76 * k, 54 * k, true), TROUSER, TROUSER_S, 10, 5, 40);
    shoe(g, J.ankL, J.toeL, "#EEF2F8", 42);
    piece(g, tube(F([J.kneeL, hem(J.kneeL, J.ankL)]), 54 * k, 40 * k, true), TROUSER, TROUSER_S, 10, 5, 41);

    // the far upper arm (her left) leaves the shoulder behind the chest
    piece(g, tube(F([J.shL, J.elL]), 54 * k, 48 * k, true), ACCENT, DEEP, 12, 5, 60);
    // torso: the fitted top, tucked into the trousers
    const torso = sm(F([[500, 756], [440, 768], [402, 798], [380, 852], [376, 944], [388, 1044], [410, 1130], [432, 1204], [690, 1204], [706, 1140], [726, 1066], [744, 990], [748, 910], [736, 848], [706, 802], [660, 772], [604, 756]]));
    cel(g, torso, ACCENT, DEEP, 28 * k);
    fillShape(g, sm(F([[380, 852], [402, 798], [440, 768], [436, 860], [440, 1000], [462, 1204], [432, 1204], [410, 1130], [388, 1044], [376, 944]])), DEEP);
    outline(g, torso, 5.5, 44);
    const pelvis = sm(F([[428, 1196], [694, 1196], [716, 1262], [700, 1334], [640, 1420], [540, 1462], [452, 1446], [414, 1388], [412, 1290]]));
    piece(g, pelvis, TROUSER, TROUSER_S, 14 * k, 5.5, 45);
    stroke(g, F([[432, 1214], [692, 1214]]), 3.5, 46, TROUSER_S, 0.6);
    // the near arm (her right) props her up behind the hip
    const upR = tube(F([J.shR, J.elR]), 54 * k, 46 * k, true), foreR = tube(F([J.elR, J.wrR]), 46 * k, 40 * k, true);
    const handR = plantedHand(fig([J.wrR[0] - 10, J.wrR[1] + 70]), k);
    piece(g, handR.thumb, SKIN, SKIN_S, 4, 3.5, 30);
    [...handR.fingers].reverse().forEach((f, n) => piece(g, f, SKIN, SKIN_S, 4, 3.2, 31 + n));
    piece(g, handR.palm, SKIN, SKIN_S, 6, 4, 35);
    fillShape(g, tube(F([[J.wrR[0] - 14, J.wrR[1] + 40], [J.wrR[0] - 30, J.wrR[1] + 70]]), 26 * k, 26 * k, true), SKIN);
    piece(g, foreR, ACCENT, DEEP, 10, 5, 36);
    piece(g, tube(F([[J.wrR[0] + 4, J.wrR[1] - 20], [J.wrR[0] - 6, J.wrR[1] + 22]]), 42 * k, 42 * k, true), HIGH, DEEP, 4, 3.5, 37);
    piece(g, upR, ACCENT, DEEP, 12, 5, 38);

    // near leg (her right), in front of everything below the waist
    piece(g, tube(F([J.hipR, J.kneeR]), 80 * k, 56 * k, true), TROUSER, TROUSER_S, 12, 5.5, 47);
    shoe(g, J.ankR, J.toeR, WHITE, 50);
    piece(g, tube(F([J.kneeR, hem(J.kneeR, J.ankR)]), 56 * k, 42 * k, true), TROUSER, TROUSER_S, 12, 5.5, 48);
    stroke(g, F([[J.kneeR[0] - 30, J.kneeR[1] + 10], [J.kneeR[0] + 10, J.kneeR[1] - 30]]), 3, 49, TROUSER_S, 0.8, 0.8);

    // neck, V neckline, head: V7's woman-curves, nodding, talking
    piece(g, sm(F([[506, 672], [596, 686], [600, 772], [506, 772]])), SKIN, SKIN_S, 10, 4, 53);
    piece(g, sm(F([[488, 756], [552, 840], [616, 758], [628, 776], [552, 870], [476, 776]])), HIGH, DEEP, 4, 3.5, 54);
    piece(g, sm(Hd(C_FACE)), SKIN, SKIN_S, 16, 5, 81);
    fillShape(g, sm(Hd([[514, 540], [544, 526], [568, 538], [554, 560], [524, 562]])), "#EE9D86", 0.45);
    fillShape(g, sm(Hd([[650, 524], [672, 516], [684, 532], [670, 548]])), "#EE9D86", 0.4);
    piece(g, sm(Hd(C_HAIR_FRONT)), "#3A5486", "#1E2F55", 10, 5, 82);
    const eyeL = sm(Hd([[528, 464], [548, 448], [576, 450], [594, 464], [574, 474], [548, 474]]), 4), eyeR = sm(Hd([[630, 458], [648, 444], [670, 446], [682, 458], [666, 468], [644, 468]]), 4);
    fillShape(g, eyeL, WHITE); fillShape(g, eyeR, WHITE);
    const look: P = [6, 5], eye = (c: P) => Hd([[c[0] + look[0], c[1] + look[1]]])[0];
    clipped(g, eyeL, () => { fillShape(g, circle(eye([562, 462]), 11 * k, 16), "#2F4C7A"); fillShape(g, circle(eye([562, 462]), 5 * k, 10), T.ink); fillShape(g, circle(eye([566, 458]), 2.6 * k, 8), WHITE); });
    clipped(g, eyeR, () => { fillShape(g, circle(eye([658, 457]), 10 * k, 16), "#2F4C7A"); fillShape(g, circle(eye([658, 457]), 4.5 * k, 10), T.ink); fillShape(g, circle(eye([661, 453]), 2.4 * k, 8), WHITE); });
    stroke(g, Hd([[526, 466], [548, 448], [576, 450], [596, 466]]), 4, 83, T.ink); stroke(g, Hd([[628, 460], [648, 444], [670, 446], [684, 460]]), 3.6, 84, T.ink);
    stroke(g, Hd([[596, 466], [606, 456]]), 2.4, 85, T.ink); stroke(g, Hd([[684, 460], [694, 450]]), 2.4, 86, T.ink);
    stroke(g, Hd([[528, 424], [556, 410], [588, 416]]), 3, 87, T.ink); stroke(g, Hd([[630, 414], [652, 404], [676, 410]]), 2.6, 88, T.ink);
    stroke(g, Hd([[666, 492], [680, 520], [664, 528]]), 3, 89, T.ink);
    const mouthS = sm(Hd(jaw([[588, 588], [630, 580], [670, 576], [670, 602], [654, 626], [626, 638], [600, 632], [588, 610]])));
    fillShape(g, mouthS, T.ink);
    clipped(g, mouthS, () => { fillShape(g, sm(Hd([[592, 592], [668, 580], [668, 598], [596, 604]]), 3), WHITE); fillShape(g, sm(Hd(jaw([[606, 630], [626, 618], [648, 620], [652, 632], [628, 640]]))), "#E7826F"); });
    g.pen(smooth(Hd([[582, 584], [628, 572], [676, 570]]), false, 6), { w: 5, color: "#C9645A", seed: 90, wobble: 0.3, boil: 0, taper: 0.9, opacity: 0.85, retrace: false });
    g.pen(smooth(Hd(jaw([[594, 640], [628, 646], [658, 630]])), false, 6), { w: 4.4, color: "#C9645A", seed: 91, wobble: 0.3, boil: 0, taper: 0.9, opacity: 0.75, retrace: false });
    outline(g, mouthS, 3, 92, T.ink);
    fillShape(g, circle(Hd([[436, 560]])[0], 9 * k, 14), ACCENT); outline(g, circle(Hd([[436, 560]])[0], 9 * k, 14), 2, 93);

    // the far arm reaches forward over the knees: upper arm, forearm, cuff, open hand palm up
    const dir = Math.atan2(wrL[1] - J.elL[1], wrL[0] - J.elL[0]) - 0.32;
    const hand = openHand(fig(wrL), dir, k * 1.08, -1);
    piece(g, hand.thumb, SKIN, SKIN_S, 4, 3.5, 61);
    hand.fingers.forEach((f, n) => piece(g, f, SKIN, SKIN_S, 4, 3.5, 62 + n));
    piece(g, hand.palm, SKIN, SKIN_S, 5, 4, 66);
    stroke(g, hand.crease, 2.4, 67, SKIN_S, 0.8, 0.9);
    piece(g, tube(F([J.elL, wrL]), 48 * k, 42 * k, true), ACCENT, DEEP, 10, 5, 68);
    const cd = [wrL[0] - J.elL[0], wrL[1] - J.elL[1]], cl = Math.hypot(cd[0], cd[1]);
    piece(g, tube(F([[wrL[0] - (cd[0] / cl) * 40, wrL[1] - (cd[1] / cl) * 40], wrL]), 44 * k, 43 * k, true), HIGH, DEEP, 4, 3.5, 69);
  });
};

const film = (theme: Theme, title: string): Film => ({
  meta: { title: `Dictus onboarding intro B · dictating · ${theme.name}`, W: FRAME.w, H: FRAME.h, fps: FPS, bpm: BPM, durationFrames: LOOP },
  assets: { images: {} },
  shots: [{ id: title, start: 0, end: LOOP, draw: drawFor(theme) }],
});
export const introSpeakLight = film(THEMES.light, "introSpeakLight");
export const introSpeakDark = film(THEMES.dark, "introSpeakDark");
