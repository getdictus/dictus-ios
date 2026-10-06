import { Gfx, tube, type Ctx, type Env, type Medium, type P } from "./core";
import type { Film } from "./film";
import { clipped, fillShape, smooth } from "./gallery";

// DICTUS HERO V10-A · "the voice that writes", round 2 (issue #643, concept A). V9-A is
// art/v9-A/heroSpeak.ts. V10, from Pierre's review of V9-A: the giant phone shows the Dictus
// keyboard RECORDING (the panel with the BrandWaveform, × and ✓), not an email that slide 2
// repeats; the phone is drawn in the marker comic like the figure (flat faces, hard shadow edges,
// heavy contour); the voice is three thin marker strokes flowing from her mouth into the
// waveform; the phone sits higher so the app-icon wave can run across slide 1's bottom.
//
// V9-A header, still true where it speaks of the figure:
//
// The idea in one sentence: she sits on a giant iPhone lying in perspective and SPEAKS, and her
// voice flows into its keyboard, which is recording (V9-A: onto its screen, as the line being written). One action, speaking; the
// open hand is the gesture that goes with talking to someone, aimed at the screen.
//
// Focal subject: the mouth → voice → cursor path. Light: one, from the upper left; cast shadows
// fall to the lower right (the figure on the screen, the phone on the ground).
//
// Character: V7's `woman-curves` (export/en-GB/v7/light/01-hero-woman-curves.png), unchanged in
// face, hair and outfit (soft oval face, open almond eyes, long side-parted hair falling down the
// back, V-neck top in Dictus blue tucked into navy high-waisted trousers), V7's proportions, not
// V8's accentuated bust and hips. Only the pose is new.
//
// Pose reference: the classic figure-drawing pose "seated on the floor, knees drawn up, leaning
// back on one straight arm, three-quarter view" (life-drawing pose sheets; the usual canon with
// the comic's larger head: thigh ~1.25 face lengths, shin a touch shorter, upper arm ~ forearm).
// Three-quarter view turned to the viewer's right, so her RIGHT side is the near side: the right
// shoulder sits on the image-left of the torso, the right arm props her up behind her hip (palm
// flat, fingers pointing back, thumb on the near side), the right leg is the near leg. Her LEFT
// arm reaches forward over the knees, palm up and open toward the screen (thumb on the far, upper
// side), the speaker's gesture. Knees up, feet flat on the glass, white trainers.
//
// The phone: an iPhone 17 Pro Max-shaped slab (163 × 78 mm, display corners ~12 mm, Dynamic
// Island 4 mm from the top, volume buttons and Action button on the left side, USB-C and speaker
// grille on the bottom edge) lying screen-up, top end away from us, seen from above in true
// perspective (a homography from the phone's millimetres to the slide). The left side and the
// bottom edge face us, so those are the faces we see. The keyboard panel is drawn in the same
// millimetres, so it bends with the phone.
//
// Two shots of one film, stacked by screenshots.html (?scene=v10a):
//   back  = ground shadow + phone + keyboard panel
//   front = figure, her shadow, the voice
//
// Rebuild art/v10-A/hero-back.png and hero-front.png (anidoodle engine; md5 printed as "reproducible"):
//   node ~/.claude/skills/anidoodle/engine/tools/scaffold.mjs /tmp/art --still heroA
//   cp assets/appstore/art/v10-A/heroSpeak10.ts /tmp/art/src/canvas-core/heroA.ts
//   cd /tmp/art && npm install && npx playwright-core install chromium
//   node tools/still.mjs heroA   (writes out/still-heroA-back.png and out/still-heroA-front.png)

// The canvas covers slides 1 and 2 at strip scale, top-left on the strip's origin.
export const W = 2640, H = 2868;

// ---------------------------------------------------------------- the phone in perspective
// Top-face corners in strip pixels: (0,0) top-left, (1,0) top-right, (1,1) bottom-right, (0,1)
// bottom-left in the phone's own (across, along) unit square. SAME numbers in screenshots.html
// (HERO_A10.quad, unused by the template since V10: the screen is drawn here): change both or neither.
export const QUAD: P[] = [[40, 1560], [740, 1330], [1260, 2330], [450, 2650]];
const MM = { w: 78, h: 163, r: 12.5, thick: 9 };
const homography = (q: P[]) => {
  const [[x0, y0], [x1, y1], [x2, y2], [x3, y3]] = q;
  const dx1 = x1 - x2, dx2 = x3 - x2, dx3 = x0 - x1 + x2 - x3, dy1 = y1 - y2, dy2 = y3 - y2, dy3 = y0 - y1 + y2 - y3;
  const den = dx1 * dy2 - dx2 * dy1, g = (dx3 * dy2 - dx2 * dy3) / den, h = (dx1 * dy3 - dx3 * dy1) / den;
  const a = x1 - x0 + g * x1, b = x3 - x0 + h * x3, d = y1 - y0 + g * y1, e = y3 - y0 + h * y3;
  return (u: number, v: number): P => { const z = g * u + h * v + 1; return [(a * u + b * v + x0) / z, (d * u + e * v + y0) / z]; };
};
const toUnit = homography(QUAD);
/** phone millimetres (x across from the left side, y along from the top end) → strip pixels */
export const mm = (x: number, y: number): P => toUnit(x / MM.w, y / MM.h);
const mmPts = (pts: P[]) => pts.map(([x, y]) => mm(x, y));
// pixels per millimetre at a point, measured across the phone (sets the extrusion depth)
const ppm = (x: number, y: number) => { const a = mm(x, y), b = mm(x + 1, y); return Math.hypot(b[0] - a[0], b[1] - a[1]); };
// a rounded rectangle in phone millimetres, sampled densely so it bends with the perspective
const rrect = (x0: number, y0: number, x1: number, y1: number, r: number, n = 10): P[] => {
  const out: P[] = [];
  const corner = (cx: number, cy: number, a0: number) => { for (let i = 0; i <= n; i++) { const a = a0 + (i / n) * (Math.PI / 2); out.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]); } };
  corner(x1 - r, y0 + r, -Math.PI / 2); corner(x1 - r, y1 - r, 0); corner(x0 + r, y1 - r, Math.PI / 2); corner(x0 + r, y0 + r, Math.PI);
  // densify the straight runs too
  const dense: P[] = [];
  out.forEach((p, i) => { const q = out[(i + 1) % out.length], l = Math.hypot(q[0] - p[0], q[1] - p[1]), k = Math.max(1, Math.ceil(l / 4)); for (let j = 0; j < k; j++) dense.push([p[0] + ((q[0] - p[0]) * j) / k, p[1] + ((q[1] - p[1]) * j) / k]); });
  return dense;
};
// the drop of the slab's thickness, straight down the page, scaled by the local size (the view
// is about 50° above the ground, so a vertical edge reads at ~0.75 of its length)
const drop = (x: number, y: number) => MM.thick * ppm(x, y) * 0.75;

const MARKER: Medium = { nib: 2.4, taper: 0.55, pressure: 0.6, retrace: false, wobble: 0.6, rough: 0.3 };
const LIGHT: P = [-0.6, -0.8];
const INK = "#0A1628", ACCENT = "#3D7EFF", DEEP = "#2563EB", HIGH = "#6BA3FF", WHITE = "#FFFFFF";
const SKIN = "#F1C09C", SKIN_S = "#D59674", TROUSER = "#1E3354", TROUSER_S = "#0F1E36";
const TITAN = "#2B3A5C", TITAN_L = "#46577D", TITAN_D = "#1A2642";
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

// ---------------------------------------------------------------- BACK: the ground shadow and the phone
// Marker comic, like the figure (V10, Pierre: the V9 phone read as rendered): every face a FLAT
// fill, one hard-edged shadow tone per face, a heavy ink contour around the slab and along the
// edge where the glass meets the frame, a comic glass shine (two hard slanted stripes). No blur.

// The keyboard panel while recording (captures/en-GB/01-recording-reminders.png, the panel from
// y 1767: × and ✓ pills at the top, the BrandWaveform across the middle, blue in its centre 40 %,
// grey toward the edges; globe and mic at the bottom). In phone millimetres.
const PANEL_TOP = 98;
// bar heights read off the capture, left to right (fraction of the tallest); fewer and wider
// bars than the capture's 27, so the waveform reads as one at App Store search size
const BARS = [0.55, 0.8, 0.86, 0.5, 0.3, 0.34, 0.62, 0.56, 0.36, 0.28, 0.66, 0.9, 1, 0.84, 0.7, 0.92, 0.8];
const WAVE = { x0: 7, x1: 71, cy: 123, h: 25, w: 2.7 };
export const WAVE_MM: P = [39, WAVE.cy];

const drawBack = (ctx: Ctx, _f: number, env: Env) => {
  const g = new Gfx(ctx, env, 0, MARKER);
  ctx.setTransform(env.scale, 0, 0, env.scale, 0, 0);
  ctx.clearRect(0, 0, W, H);
  const body = rrect(0, 0, MM.w, MM.h, MM.r, 12);
  const top = mmPts(body), dropped = (k: number) => body.map(([x, y]) => { const p = mm(x, y); return [p[0], p[1] + drop(x, y) * k] as P; });
  const bottom = dropped(1);

  // the cast shadow on the ground: one flat, hard-edged tone down and to the right of the slab
  g.group("plain", () => fillShape(g, bottom.map(([x, y]) => [x + 46, y + 40] as P), "#C6CFDF", 1));

  g.group("plain", () => {
    // the slab: the union of slices from the bottom face up to the top face, the left side lit
    for (let k = 0; k <= 14; k++) fillShape(g, dropped(1 - k / 14), TITAN_L);
    // the bottom end faces away from the light: its own darker flat tone, a hard edge where the
    // rounded corner turns from the side onto the end
    const endIdx = body.map((p, i) => [p, i] as [P, number]).filter(([p]) => p[1] > MM.h - MM.r * 0.55).map(([, i]) => i);
    const endTop = endIdx.map((i) => top[i]), endBot = endIdx.map((i) => bottom[i]);
    fillShape(g, [...endTop, ...[...endBot].reverse()], TITAN_D);
    // a highlight stroke along the lit side, just under the glass
    const rim = dropped(0.3).filter((_, i) => body[i][0] < MM.r && body[i][1] < MM.h - MM.r);
    stroke(g, rim, 3.2, 3, "#7F92BC", 0.4, 0.9);
    // side buttons on the left side: Action button, volume up, volume down (from the top end)
    [[22, 28], [34, 46], [50, 62]].forEach(([y0, y1], k) => {
      const a = mm(0, y0), b = mm(0, y1), da = drop(0, y0) * 0.5, db = drop(0, y1) * 0.5;
      const btn = sm([[a[0] + 2, a[1] + da - 8], [b[0] + 2, b[1] + db - 8], [b[0] - 9, b[1] + db + 7], [a[0] - 9, a[1] + da + 7]], 2);
      fillShape(g, btn, TITAN); outline(g, btn, 3.6, 60 + k);
    });
    // the bottom end: USB-C between two speaker grilles
    const at = (x: number): P => { const p = mm(x, MM.h); return [p[0], p[1] + drop(x, MM.h) * 0.52]; };
    const pc = at(39), pr = drop(39, MM.h) * 0.16;
    const portS = sm([[at(33)[0], at(33)[1] - pr], [at(45)[0], at(45)[1] - pr], [at(45)[0], at(45)[1] + pr], [at(33)[0], at(33)[1] + pr]], 3);
    fillShape(g, portS, INK); void pc;
    [[16, 29], [49, 62]].forEach(([x0, x1]) => { for (let x = x0; x <= x1; x += 2.6) fillShape(g, circle(at(x), 3.4, 8), INK); });
    // heavy contour: the slab's silhouette, the vertical edge at its leftmost point
    outline(g, bottom, 9, 4);
    const left = top.reduce((m, p, i) => (p[0] < top[m][0] ? i : m), 0);
    stroke(g, [top[left], bottom[left]], 8, 5);

    // the top face: the black glass rim, then the display
    fillShape(g, top, INK);
    const scr = rrect(2.6, 2.6, MM.w - 2.6, MM.h - 2.6, MM.r - 2.4, 12), screen = mmPts(scr);
    fillShape(g, screen, WHITE);
    clipped(g, screen, () => {
      // the keyboard panel, recording
      fillShape(g, mmPts(rrect(0, PANEL_TOP, MM.w, MM.h + 20, 8, 10)), "#E3E5EB");
      // its hard shadow edge: a darker flat band along the panel's top, the way the capture's
      // panel lifts off the app above it
      fillShape(g, mmPts([[0, PANEL_TOP - 1.4], [MM.w, PANEL_TOP - 1.4], [MM.w, PANEL_TOP + 0.2], [0, PANEL_TOP + 0.2]]), "#C9CED9");
      // the comic glass shine: two hard slanted stripes across the empty app area
      fillShape(g, mmPts([[0, 20], [MM.w * 0.62, 0], [MM.w * 0.78, 0], [0, 26]].map(([x, y]) => [x, y + 30] as P)), "#EAF1FF");
      fillShape(g, mmPts([[0, 30], [MM.w * 0.8, 0], [MM.w * 0.86, 0], [0, 32.5]].map(([x, y]) => [x, y + 30] as P)), "#EAF1FF");
      // × and ✓ pills
      const pill = (x0: number, x1: number, n: number) => { const sh = mmPts(rrect(x0, 101.5, x1, 110.5, 4.5, 8)); fillShape(g, sh, WHITE); outline(g, sh, 3.2, n); };
      pill(6, 21, 70); pill(57, 72, 71);
      stroke(g, mmPts([[11.6, 104.2], [15.4, 107.8]]), 3.4, 72, "#7B8496", 0.2); stroke(g, mmPts([[15.4, 104.2], [11.6, 107.8]]), 3.4, 73, "#7B8496", 0.2);
      stroke(g, mmPts([[62.2, 106.3], [64, 108.2], [67.2, 103.8]]), 4, 74, "#22C55E", 0.2);
      // the BrandWaveform: flat bars, blue through the centre 40 %, grey toward the edges, each
      // with a hard darker lower half (the shadow side) and a thin ink edge
      const n = BARS.length, pitch = (WAVE.x1 - WAVE.x0) / (n - 1);
      BARS.forEach((v, i) => {
        const cx = WAVE.x0 + i * pitch, d = Math.abs(i / (n - 1) - 0.5) * 2, hh = (4 + v * (WAVE.h - 4)) / 2;
        const blue = d < 0.42, lit = blue ? HIGH : d < 0.75 ? "#A7ADBB" : "#C3C7D1", shade = blue ? DEEP : d < 0.75 ? "#8E95A5" : "#AEB3BF";
        const bar = mmPts(rrect(cx - WAVE.w / 2, WAVE.cy - hh, cx + WAVE.w / 2, WAVE.cy + hh, WAVE.w / 2, 5));
        fillShape(g, bar, shade);
        clipped(g, bar, () => fillShape(g, mmPts([[cx - 2, WAVE.cy - hh - 1], [cx + 2, WAVE.cy - hh - 1], [cx + 2, WAVE.cy + hh * 0.25], [cx - 2, WAVE.cy + hh * 0.25]]), lit));
        outline(g, bar, 2.6, 100 + i);
      });
      // globe and mic at the bottom corners
      const ring = (c: P, r: number) => mmPts(Array.from({ length: 24 }, (_, i) => [c[0] + Math.cos((i / 24) * Math.PI * 2) * r, c[1] + Math.sin((i / 24) * Math.PI * 2) * r] as P));
      g.pen(ring([10.5, 152.5], 2.8), { w: 2.6, color: INK, seed: 75, closed: true, wobble: 0.3, boil: 0, taper: 0.2, opacity: 1, retrace: false });
      stroke(g, mmPts([[7.7, 152.5], [13.3, 152.5]]), 2.2, 76); stroke(g, mmPts([[10.5, 149.7], [9.3, 152.5], [10.5, 155.3]]), 2.2, 77); stroke(g, mmPts([[10.5, 149.7], [11.7, 152.5], [10.5, 155.3]]), 2.2, 78);
      const mic = mmPts(rrect(66.3, 149, 69.7, 154.4, 1.7, 6)); fillShape(g, mic, WHITE); outline(g, mic, 2.6, 79);
      stroke(g, mmPts([[65, 152.6], [65.6, 155.4], [68, 156.4], [70.4, 155.4], [71, 152.6]]), 2.4, 80); stroke(g, mmPts([[68, 156.4], [68, 158]]), 2.4, 81);
    });
    // the Dynamic Island
    fillShape(g, mmPts(rrect(MM.w / 2 - 10.5, 4.6, MM.w / 2 + 10.5, 10.6, 3, 8)), INK);
    // heavy contour around the glass, the edge where the frame meets the side
    outline(g, top, 9, 6);
  });
};

// ---------------------------------------------------------------- FRONT: the figure and her voice
// Figure-local coordinates are V7's (art/v7/heroCast.ts), so the head is V7's woman-curves head,
// point for point. FIG maps them to the strip.
const FIG = { k: 0.7, seat: [520, 1452] as P, at: mm(40, 28) };
const fig = (p: P): P => [FIG.at[0] + (p[0] - FIG.seat[0]) * FIG.k, FIG.at[1] + (p[1] - FIG.seat[1]) * FIG.k];

const C_FACE: P[] = [[455, 366], [530, 336], [608, 346], [662, 396], [688, 460], [694, 522], [682, 582], [656, 634], [612, 674], [556, 690], [500, 678], [456, 642], [428, 586], [418, 516], [426, 440]];
const C_HAIR_BACK: P[] = [[452, 620], [402, 560], [376, 470], [392, 372], [450, 296], [540, 262], [610, 270], [560, 330], [470, 420], [446, 520], [462, 640], [480, 760], [470, 880], [436, 1000], [392, 1070], [340, 1066], [316, 990], [330, 900], [324, 800], [350, 700]];
const C_HAIR_FRONT: P[] = [[422, 470], [436, 380], [490, 318], [566, 290], [640, 296], [696, 330], [720, 384], [704, 392], [664, 360], [612, 344], [566, 352], [526, 384], [492, 440], [470, 520], [460, 600], [440, 660], [420, 600]];
const MOUTH_AT: P = [678, 604];

// joints (figure-local)
const J = {
  // near side, her RIGHT: the arm props her up behind the hip
  shR: [440, 836] as P, elR: [370, 1092] as P, wrR: [338, 1338] as P,
  // far side, her LEFT: the arm reaches forward over the knees, palm up toward the screen
  shL: [700, 822] as P, elL: [820, 1076] as P, wrL: [1050, 1066] as P,
  // legs: near (right) and far (left)
  hipR: [560, 1350] as P, kneeR: [930, 1150] as P, ankR: [1012, 1500] as P, toeR: [1150, 1528] as P,
  hipL: [610, 1310] as P, kneeL: [985, 1100] as P, ankL: [1092, 1444] as P, toeL: [1226, 1462] as P,
};

// open hand, palm up and toward the viewer: palm, four fingers fanned from the knuckles (middle
// longest, little finger shortest), a thumb from the side of the palm
const openHand = (wrist: P, dir: number, s: number, thumbSide: 1 | -1) => {
  const ux = Math.cos(dir), uy = Math.sin(dir), nx = -uy, ny = ux;
  const at = (a: number, b: number): P => [wrist[0] + ux * a * s + nx * b * s, wrist[1] + uy * a * s + ny * b * s];
  const palm = sm([at(-4, -34), at(30, -42), at(78, -40), at(86, 0), at(78, 40), at(30, 40), at(-4, 32)], 4);
  // from the thumb side outward: index, middle, ring, little
  const spec = [[0.66, 66, 0.1], [0.22, 74, 0.03], [-0.22, 68, -0.05], [-0.64, 52, -0.13]];
  const fingers = spec.map(([off, len, spread], i) => {
    const base = at(80, (off as number) * 40 * thumbSide), d = dir + (spread as number) * thumbSide;
    const mid: P = [base[0] + Math.cos(d) * (len as number) * 0.55 * s, base[1] + Math.sin(d) * (len as number) * 0.55 * s];
    // a soft curl: the tip lifts a little toward the palm's normal (an open, relaxed hand)
    const curl = dir + (spread as number) * thumbSide - 0.22 * thumbSide;
    const tip: P = [mid[0] + Math.cos(curl) * (len as number) * 0.45 * s, mid[1] + Math.sin(curl) * (len as number) * 0.45 * s];
    return tube(smooth([base, mid, tip], false, 6), 12.5 * s, 10 * s, true);
  });
  const tb = at(24, thumbSide * 38), td = dir + thumbSide * 0.8;
  const tm: P = [tb[0] + Math.cos(td) * 32 * s, tb[1] + Math.sin(td) * 32 * s], td2 = td - thumbSide * 0.5;
  const thumb = tube(smooth([tb, tm, [tm[0] + Math.cos(td2) * 30 * s, tm[1] + Math.sin(td2) * 30 * s]], false, 6), 14 * s, 11 * s, true);
  // the palm's creases, the "life line" read as the palm turned up
  const crease = [at(60, -26 * thumbSide), at(36, -4 * thumbSide), at(16, 22 * thumbSide)];
  return { palm, fingers, thumb, crease };
};

// a hand planted flat behind her: seen from above, the back of the hand, four fingers pointing
// back (left), the thumb on the near (lower) side pointing forward
const plantedHand = (wrist: P, s: number) => {
  const [x, y] = wrist;
  const palm = sm([[x + 30 * s, y - 30 * s], [x - 10 * s, y - 40 * s], [x - 70 * s, y - 34 * s], [x - 78 * s, y + 4 * s], [x - 70 * s, y + 34 * s], [x - 30 * s, y + 42 * s], [x + 26 * s, y + 30 * s]], 4);
  // index (nearest the thumb, lowest) to little finger (highest, shortest), fanned a little
  const fingers = [0, 1, 2, 3].map((k) => {
    const by = y + 26 * s - k * 17 * s, len = [60, 68, 62, 48][k] * s, bx = x - 66 * s + k * 4 * s, fan = (1.5 - k) * 0.09;
    const ux = -Math.cos(fan), uy = Math.sin(fan) + 0.12;
    return tube(smooth([[bx, by], [bx + ux * len * 0.55, by + uy * len * 0.55 + 3 * s], [bx + ux * len, by + uy * len + 8 * s]], false, 6), 12 * s, 10 * s, true);
  });
  const thumb = tube(smooth([[x - 4 * s, y + 30 * s], [x - 26 * s, y + 52 * s], [x - 56 * s, y + 58 * s]], false, 6), 13 * s, 10.5 * s, true);
  return { palm, fingers, thumb };
};

// a white trainer seen from the outer side, toe forward: heel counter, ankle collar, laced instep,
// a rounded toe box, and a thicker rubber sole along the ground (figure-local points)
// where the trouser hem stops: a little above the ankle bone, so the trainer's collar shows
const hem = (knee: P, ank: P): P => { const d = [ank[0] - knee[0], ank[1] - knee[1]], l = Math.hypot(d[0], d[1]); return [ank[0] - (d[0] / l) * 64, ank[1] - (d[1] / l) * 64]; };
const shoe = (g: Gfx, ank: P, toe: P, upper: string, seed: number) => {
  const F = (pts: P[]) => pts.map(fig), [ax, ay] = ank, sy = ay + 52, tx = toe[0] + 24;
  piece(g, tube(F([[ax - 6, ay - 56], [ax - 2, ay - 10]]), 22 * FIG.k, 24 * FIG.k, true), SKIN, SKIN_S, 3, 3.5, seed + 9);   // the ankle
  const body = sm(F([[ax - 54, sy + 8], [ax - 62, ay + 10], [ax - 50, ay - 22], [ax - 8, ay - 32], [ax + 28, ay - 20], [ax + 72, ay + 2], [tx - 64, sy - 48], [tx - 22, sy - 44], [tx + 2, sy - 28], [tx + 8, sy - 4], [tx, sy + 10], [ax - 20, sy + 12]]), 5);
  cel(g, body, upper, "#C9D2E2", 5);
  // the rubber sole: a band along the ground inside the same outline, so shoe and sole are one object
  clipped(g, body, () => fillShape(g, F([[ax - 80, sy - 6], [tx + 30, sy - 6], [tx + 30, sy + 30], [ax - 80, sy + 30]]), "#D3DBE7"));
  stroke(g, F([[ax - 58, sy - 6], [tx + 6, sy - 6]]), 2.8, seed + 1, "#8E9AB0", 0.4);
  outline(g, body, 4.2, seed);
  stroke(g, F([[tx - 66, sy - 44], [tx - 50, sy - 22], [tx - 44, sy - 8]]), 2.6, seed + 2, "#9AA6BC", 0.6);       // toe cap
  [0, 1, 2].forEach((n) => stroke(g, F([[ax + 22 + n * 18, ay - 12 + n * 10], [ax + 40 + n * 18, ay - 2 + n * 10]]), 3, seed + 3 + n, ACCENT, 0.5)); // laces
};

// the voice: three marker strokes from the mouth, out and over, falling onto the screen and
// narrowing into the cursor; a ripple rides each stroke like a sound wave
const ripple = (pts: P[], amp: number, waves: number): P[] => {
  const s = smooth(pts, false, 14);
  return s.map(([x, y], i) => {
    const a = s[Math.max(0, i - 1)], b = s[Math.min(s.length - 1, i + 1)], dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy) || 1;
    const t = i / (s.length - 1), w = Math.sin(t * Math.PI * waves) * amp * Math.sin(Math.PI * Math.min(1, t * 1.15)) * (1 - t);
    return [x - (dy / l) * w, y + (dx / l) * w] as P;
  });
};
const soundArcs = (m: P, k: number): P[][] => [0, 1, 2].map((n) => {
  const r = (34 + n * 26) * k;
  return Array.from({ length: 7 }, (_, i) => { const a = -0.75 + (i / 6) * 1.5; return [m[0] - 4 * k + Math.cos(a) * r, m[1] + 4 * k + Math.sin(a) * r] as P; });
});

const drawFront = (ctx: Ctx, _f: number, env: Env) => {
  const g = new Gfx(ctx, env, 0, MARKER);
  ctx.setTransform(env.scale, 0, 0, env.scale, 0, 0);
  ctx.clearRect(0, 0, W, H);
  const F = (pts: P[]) => pts.map(fig), k = FIG.k;
  const mouth = fig(MOUTH_AT), wave = mm(WAVE_MM[0] + 6, WAVE_MM[1] - 9);

  // her cast shadow on the glass: down and to the right of the seat and the feet
  g.group("plain", () => {
    fillShape(g, sm(F([[360, 1430], [640, 1410], [980, 1470], [1250, 1520], [1270, 1560], [1000, 1560], [620, 1500], [380, 1480]])), "#D3D9E4", 1);
  });

  // the voice, behind the hand that gestures at it
  g.group("plain", () => {
    // out of the mouth, forward and over the knees, then down onto the caret
    // three thin marker strokes (V6-V8's), apart, in one smooth S: out of the mouth, a gentle
    // rise past her open hand, a long easy fall down the right side, into the waveform's centre
    const dx = wave[0] - mouth[0], dy = wave[1] - mouth[1];
    const path = (o: number): P[] => [
      [mouth[0] + 14, mouth[1] + o * 0.3],
      [mouth[0] + 200, mouth[1] - 40 + o],
      [mouth[0] + dx + 330 + o * 0.6, mouth[1] + 0.3 * dy],
      [wave[0] + 250 + o * 0.9, mouth[1] + 0.68 * dy],
      [wave[0] + 70 + o * 0.6, wave[1] - 110 + o * 0.3],
      [wave[0] + o * 0.35, wave[1] + o * 0.15]];
    stroke(g, ripple(path(-40), 10, 6), 6.5, 1, HIGH, 0.7);
    stroke(g, ripple(path(0), 14, 7), 8, 2, ACCENT, 0.6);
    stroke(g, ripple(path(40), 9, 6), 5.5, 3, DEEP, 0.7);
    soundArcs(mouth, k * 1.2).forEach((a, n) => stroke(g, a, 6 - n, 4 + n, INK, 0.9, 0.9));
  });

  g.group("plain", () => {
    // the long hair down her back
    piece(g, sm(F(C_HAIR_BACK)), "#2C3F66", "#18264A", 12, 5.5, 80);

    // far leg (her left): thigh, shin, trainer
    piece(g, tube(F([J.hipL, J.kneeL]), 76 * k, 54 * k, true), TROUSER, TROUSER_S, 10, 5, 40);
    shoe(g, J.ankL, J.toeL, "#EEF2F8", 42);
    piece(g, tube(F([J.kneeL, hem(J.kneeL, J.ankL)]), 54 * k, 40 * k, true), TROUSER, TROUSER_S, 10, 5, 41);

    // the far upper arm (her left) leaves the shoulder behind the chest, as a 3/4 view shows it
    piece(g, tube(F([J.shL, J.elL]), 54 * k, 48 * k, true), ACCENT, DEEP, 12, 5, 60);
    // torso: the fitted top, V7's proportions (no added bust or hips), tucked into the trousers
    const torso = sm(F([[500, 756], [440, 768], [402, 798], [380, 852], [376, 944], [388, 1044], [410, 1130], [432, 1204], [690, 1204], [706, 1140], [726, 1066], [744, 990], [748, 910], [736, 848], [706, 802], [660, 772], [604, 756]]));
    cel(g, torso, ACCENT, DEEP, 28 * k);
    fillShape(g, sm(F([[380, 852], [402, 798], [440, 768], [436, 860], [440, 1000], [462, 1204], [432, 1204], [410, 1130], [388, 1044], [376, 944]])), DEEP);
    outline(g, torso, 5.5, 44);
    // high-waisted trousers over the pelvis, the seat on the glass
    const pelvis = sm(F([[428, 1196], [694, 1196], [716, 1262], [700, 1334], [640, 1420], [540, 1462], [452, 1446], [414, 1388], [412, 1290]]));
    piece(g, pelvis, TROUSER, TROUSER_S, 14 * k, 5.5, 45);
    stroke(g, F([[432, 1214], [692, 1214]]), 3.5, 46, TROUSER_S, 0.6);
    // the near arm (her right) props her up behind the hip: in front of the hair that hangs down
    // her back, beside the seat
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

    // neck, V neckline, head: V7's woman-curves, unchanged
    piece(g, sm(F([[506, 672], [596, 686], [600, 772], [506, 772]])), SKIN, SKIN_S, 10, 4, 53);
    piece(g, sm(F([[488, 756], [552, 840], [616, 758], [628, 776], [552, 870], [476, 776]])), HIGH, DEEP, 4, 3.5, 54);
    piece(g, sm(F(C_FACE)), SKIN, SKIN_S, 16, 5, 81);
    fillShape(g, sm(F([[514, 540], [544, 526], [568, 538], [554, 560], [524, 562]])), "#EE9D86", 0.45);
    fillShape(g, sm(F([[650, 524], [672, 516], [684, 532], [670, 548]])), "#EE9D86", 0.4);
    piece(g, sm(F(C_HAIR_FRONT)), "#3A5486", "#1E2F55", 10, 5, 82);
    const eyeL = sm(F([[528, 464], [548, 448], [576, 450], [594, 464], [574, 474], [548, 474]]), 4), eyeR = sm(F([[630, 458], [648, 444], [670, 446], [682, 458], [666, 468], [644, 468]]), 4);
    fillShape(g, eyeL, WHITE); fillShape(g, eyeR, WHITE);
    // she looks down and right, at the screen her words land on
    const look: P = [6, 5];
    clipped(g, eyeL, () => { fillShape(g, circle(fig([562 + look[0], 462 + look[1]]), 11 * k, 16), "#2F4C7A"); fillShape(g, circle(fig([562 + look[0], 462 + look[1]]), 5 * k, 10), INK); fillShape(g, circle(fig([566 + look[0], 458 + look[1]]), 2.6 * k, 8), WHITE); });
    clipped(g, eyeR, () => { fillShape(g, circle(fig([658 + look[0], 457 + look[1]]), 10 * k, 16), "#2F4C7A"); fillShape(g, circle(fig([658 + look[0], 457 + look[1]]), 4.5 * k, 10), INK); fillShape(g, circle(fig([661 + look[0], 453 + look[1]]), 2.4 * k, 8), WHITE); });
    stroke(g, F([[526, 466], [548, 448], [576, 450], [596, 466]]), 4, 83); stroke(g, F([[628, 460], [648, 444], [670, 446], [684, 460]]), 3.6, 84);
    stroke(g, F([[596, 466], [606, 456]]), 2.4, 85); stroke(g, F([[684, 460], [694, 450]]), 2.4, 86);
    stroke(g, F([[528, 424], [556, 410], [588, 416]]), 3, 87); stroke(g, F([[630, 414], [652, 404], [676, 410]]), 2.6, 88);
    stroke(g, F([[666, 492], [680, 520], [664, 528]]), 3, 89);
    const mouthS = sm(F([[588, 588], [630, 580], [670, 576], [670, 602], [654, 626], [626, 638], [600, 632], [588, 610]]));
    fillShape(g, mouthS, INK);
    clipped(g, mouthS, () => { fillShape(g, sm(F([[592, 592], [668, 580], [668, 598], [596, 604]]), 3), WHITE); fillShape(g, sm(F([[606, 630], [626, 618], [648, 620], [652, 632], [628, 640]])), "#E7826F"); });
    g.pen(smooth(F([[582, 584], [628, 572], [676, 570]]), false, 6), { w: 5, color: "#C9645A", seed: 90, wobble: 0.3, boil: 0, taper: 0.9, opacity: 0.85, retrace: false });
    g.pen(smooth(F([[594, 640], [628, 646], [658, 630]]), false, 6), { w: 4.4, color: "#C9645A", seed: 91, wobble: 0.3, boil: 0, taper: 0.9, opacity: 0.75, retrace: false });
    outline(g, mouthS, 3, 92);
    fillShape(g, circle(fig([436, 560]), 9 * k, 14), ACCENT); outline(g, circle(fig([436, 560]), 9 * k, 14), 2, 93);

    // the far arm reaches forward over the knees: upper arm, forearm, cuff, open hand palm up
    const dir = Math.atan2(J.wrL[1] - J.elL[1], J.wrL[0] - J.elL[0]) - 0.32;
    const hand = openHand(fig(J.wrL), dir, k * 1.08, -1);
    piece(g, hand.thumb, SKIN, SKIN_S, 4, 3.5, 61);
    hand.fingers.forEach((f, n) => piece(g, f, SKIN, SKIN_S, 4, 3.5, 62 + n));
    piece(g, hand.palm, SKIN, SKIN_S, 5, 4, 66);
    stroke(g, hand.crease, 2.4, 67, SKIN_S, 0.8, 0.9);
    piece(g, tube(F([J.elL, J.wrL]), 48 * k, 42 * k, true), ACCENT, DEEP, 10, 5, 68);
    const cd = [J.wrL[0] - J.elL[0], J.wrL[1] - J.elL[1]], cl = Math.hypot(cd[0], cd[1]);
    piece(g, tube(F([[J.wrL[0] - (cd[0] / cl) * 40, J.wrL[1] - (cd[1] / cl) * 40], J.wrL]), 44 * k, 43 * k, true), HIGH, DEEP, 4, 3.5, 69);
  });
};

export const heroA: Film = {
  meta: { title: "Dictus hero V10-A · the voice that writes, round 2", W, H, fps: 30, bpm: 120, durationFrames: 30 },
  assets: { images: {} },
  shots: [
    { id: "back", start: 0, end: 15, draw: drawBack },
    { id: "front", start: 15, end: 30, draw: drawFront },
  ],
};

