import { Gfx, rng, tube, type Ctx, type Env, type Medium, type P } from "./core";
import type { Film } from "./film";
import { bounds, clamp, clipped, fillShape, smooth } from "./gallery";

// DICTUS HERO · ink + line-wash (after wren.ts), for the App Store's first screenshot (#643).
//
// The idea in one sentence: a person speaks, and her voice leaves her lips as a line of ink that
// is about to become text. Focal subject: the lips and the voice line leaving them. One light,
// upper left.
//
// Medium: washes first, wet, flooding a little past where the line will be and pooling along
// each shape's bottom edge; then a flexible nib, thick on the press, hair-thin on the lift,
// contours left open where the light eats the edge. Monochrome in the Dictus palette only:
// navy ink #0A1628, accent #3D7EFF, highlight #6BA3FF. No paper and no background: the canvas
// stays transparent and the screenshot template lays it on its own light background.
//
// Anatomy, profile facing right, drawn from hand-placed points (no ellipses for the head):
// forehead sloping back to the hairline; brow ridge; nose bridge, tip and wing; philtrum; upper
// and lower lips parted (she is speaking), the corner of the mouth set back; chin and jaw
// running back to the ear; ear under the hair, its rim and tragus; eye as a lidded almond seen
// side-on with the lashes' line; a chin-length bob tucked behind the ear; neck with the
// sternocleidomastoid running from behind the ear to the collarbone; a crew-neck jumper over
// the shoulders. Reference: standard adult profile proportions (eye at half the head height,
// nose base at three quarters, ear between brow and nose base).
//
// The voice line ends at VOICE_END, where the template's BrandWaveform takes over
// (screenshots.html: ILLU.voiceEnd must equal VOICE_END).
//
// Rebuild art/hero-illustration.png (drawn in code with the anidoodle engine,
// ~/.claude/skills/anidoodle; same source, same pixels, md5 printed as "reproducible"):
//   node ~/.claude/skills/anidoodle/engine/tools/scaffold.mjs /tmp/art --still hero
//   cp assets/appstore/art/dictusHero.ts /tmp/art/src/canvas-core/
//   printf 'import { dictusHero } from "../canvas-core/dictusHero";\nimport { mountFilm } from "./page";\nmountFilm(dictusHero);\n' > /tmp/art/src/hosts/page-dictusHero.ts
//   cd /tmp/art && npm install && npx playwright-core install chromium
//   node tools/still.mjs dictusHero --out out/dictusHero.png

const INK_M: Medium = { nib: 1.9, taper: 1, pressure: 1.8, retrace: false, wobble: 1.2, rough: 0.5 };
const INK = "#0A1628", ACCENT = "#3D7EFF", HIGH = "#6BA3FF", NAVYWASH = "#1E3A66";

export const W = 1320, H = 1500;
export const VOICE_END: P = [900, 1420];

const wet = (g: Gfx, pts: P[], color: string, alpha: number, seed: number, pool = 0.55) => {
  const b = bounds(pts);
  g.group("paint", () => {
    g.wash(pts, color, { alpha, seed, dx: 7, dy: 6, shrink: 1.05, rim: true });
    clipped(g, pts, () => {
      const c = g.cur, gr = c.createLinearGradient(0, b.y0 + (b.y1 - b.y0) * 0.45, 0, b.y1 + 2);
      const hex = (a: number) => Math.round(255 * clamp(a)).toString(16).padStart(2, "0");
      gr.addColorStop(0, color + "00"); gr.addColorStop(0.75, color + hex(alpha * pool * 0.6)); gr.addColorStop(1, color + hex(alpha * pool * 1.3));
      c.fillStyle = gr; c.fillRect(b.x0 - 20, b.y0, b.x1 - b.x0 + 40, b.y1 - b.y0 + 20);
    });
  });
};
const pen = (g: Gfx, pts: P[], w: number, seed: number, op = 0.95, wob = 0.8) =>
  g.pen(pts, { w, color: INK, seed, wobble: wob, boil: 0, taper: 1, opacity: op, retrace: false });

// ---------------------------------------------------------------- the head, hand-placed
// Authored at a small size, then scaled as one piece so the head-to-shoulders proportion
// is right (V1 of this still had a long neck under a small head).
const HS = 1.3, HC: P = [450, 420], HD: P = [0, 40];
const Hd = (pts: P[]): P[] => pts.map(([x, y]) => [HC[0] + (x - HC[0]) * HS + HD[0], HC[1] + (y - HC[1]) * HS + HD[1]]);
const FACE: P[] = Hd([ // front silhouette, from the hairline down to the throat
  [452, 214], [492, 246], [514, 296], [522, 350], [528, 382], [520, 404], [534, 432], [552, 462],
  [566, 488], [560, 500], [540, 508], [536, 524], [546, 538], [552, 548], [540, 556],
  [534, 562], [548, 572], [544, 590], [532, 612], [518, 630], [494, 640], [470, 646], [452, 660],
]);
const JAW: P[] = Hd([[494, 640], [452, 630], [418, 604], [396, 572]]);
const SKIN: P[] = Hd([ // the lit face, washed before the line
  [452, 214], [492, 246], [514, 296], [522, 350], [520, 404], [552, 462], [566, 488], [540, 508], [552, 548],
  [534, 562], [548, 572], [532, 612], [494, 640], [440, 640], [390, 600], [380, 470], [420, 330],
]).concat([[476, 760], [500, 880], [400, 890], [390, 790]]);
const HAIR: P[] = Hd([ // a chin-length bob, the fringe swept back from the forehead
  [452, 214], [420, 196], [372, 196], [322, 216], [282, 256], [258, 312], [252, 380], [258, 450],
  [272, 520], [296, 590], [330, 636], [366, 650], [392, 628], [396, 580], [392, 520], [412, 470],
  [432, 400], [446, 330], [470, 288], [486, 252],
]);
const NECK_BACK: P[] = [[392, 790], [394, 846], [404, 892]];
const NECK_FRONT: P[] = [[476, 756], [480, 820], [500, 884]];
const STERNO: P[] = [[436, 760], [452, 820], [478, 880]];
const EAR: P[] = Hd([[398, 452], [412, 440], [428, 450], [432, 478], [424, 506], [408, 520], [398, 510]]);
const EYE_TOP: P[] = Hd([[478, 392], [496, 384], [510, 392]]);
const EYE_LOW: P[] = Hd([[482, 400], [498, 404], [508, 398]]);
const BROW: P[] = Hd([[470, 366], [494, 358], [516, 364]]);
const NOSTRIL: P[] = Hd([[540, 486], [548, 494], [544, 500]]);
const MOUTH_CORNER: P[] = Hd([[520, 552], [528, 556]]);

// ---------------------------------------------------------------- the jumper
const JUMPER: P[] = [
  [404, 892], [350, 930], [260, 960], [170, 1010], [110, 1100], [86, 1240], [80, 1500],
  [760, 1500], [752, 1300], [728, 1160], [680, 1060], [610, 990], [548, 940], [500, 884],
];
const COLLAR: P[] = [[404, 892], [430, 918], [468, 926], [500, 886]];
const COLLAR2: P[] = [[394, 906], [426, 938], [470, 946], [512, 900]];
const FOLD1: P[] = [[240, 1120], [262, 1260], [252, 1440]];
const FOLD2: P[] = [[630, 1140], [664, 1290], [672, 1460]];
const SHOULDER_SHADE: P[] = [[86, 1240], [110, 1100], [170, 1010], [260, 960], [220, 1060], [168, 1180], [130, 1360], [80, 1360]];

// ---------------------------------------------------------------- the voice
// It leaves the parted lips as a single ink line that swells into a wave, the amplitude growing
// with distance, and ends at VOICE_END, where the BrandWaveform bars begin.
const VOICE: P[] = (() => {
  // A long S that falls from the lips beside the shoulder to VOICE_END, so the wave that
  // takes over there can run gently down to the ribbon (V4 composition). The ripple is
  // applied along the curve's normal, so it stays visible where the line falls.
  const m = Hd([[568, 548]])[0], c1: P = [m[0] + 230, m[1] + 30], c2: P = [VOICE_END[0] + 30, VOICE_END[1] - 420];
  const at = (t: number): P => { const u = 1 - t; return [0, 1].map((k) => u*u*u*m[k] + 3*u*u*t*c1[k] + 3*u*t*t*c2[k] + t*t*t*VOICE_END[k]) as P; };
  const out: P[] = [];
  for (let i = 0; i <= 90; i++) {
    const t = i / 90, a = at(Math.max(0, t - 0.005)), b = at(Math.min(1, t + 0.005)), p = at(t);
    const dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy) || 1, nx = -dy / l, ny = dx / l;
    const amp = (4 + 40 * Math.pow(t, 0.9)) * (1 - Math.pow(t, 8));   // opens up, then settles into the bars
    const w = Math.sin(t * Math.PI * 9);
    out.push([p[0] + nx * amp * w, p[1] + ny * amp * w]);
  }
  return out;
})();

export const drawDictusHero = (ctx: Ctx, _frame: number, env: Env) => {
  const g = new Gfx(ctx, env, 0, INK_M);
  ctx.setTransform(env.scale, 0, 0, env.scale, 0, 0);
  ctx.clearRect(0, 0, W, H);

  // 1. washes: jumper, skin, hair, then the shade side
  wet(g, smooth(JUMPER, true, 6), ACCENT, 0.26, 3, 0.7);
  wet(g, smooth(SHOULDER_SHADE, true, 4), "#2563EB", 0.16, 4, 0.5);
  wet(g, smooth(SKIN, true, 6), HIGH, 0.16, 5, 0.4);
  wet(g, smooth(HAIR, true, 6), NAVYWASH, 0.52, 6, 0.8);
  g.group("paint", () => fillShape(g, smooth(Hd([[300, 300], [360, 250], [420, 236], [380, 300], [330, 360]]), true, 4), "#ffffff", 0.2)); // light caught on the crown

  // 2. the pen: open where the light hits (forehead top, crown), pressed on the shade side
  g.group("plain", () => {
    pen(g, smooth(FACE.slice(0, 6), false, 6), 2.4, 11, 0.9);
    pen(g, smooth(FACE.slice(5, 15), false, 6), 3.0, 12);
    pen(g, smooth(FACE.slice(15), false, 6), 3.4, 13);
    pen(g, smooth(JAW, false, 6), 2.2, 14, 0.75);
    pen(g, smooth(HAIR.slice(9, 15), false, 6), 3.2, 15, 0.9);
    pen(g, smooth(HAIR.slice(3, 9), false, 6), 2.2, 16, 0.7);
    pen(g, smooth(HAIR.slice(15).concat([[452, 214]]), false, 5), 2.0, 17, 0.8);
    const r = rng(18); // a few strands inside the bob
    for (let i = 0; i < 7; i++) { const x = 300 + i * 18 + r() * 8; pen(g, smooth(Hd([[x + 40, 240 + r() * 20], [x + 6, 400 + r() * 30], [x + 18, 560 + r() * 40]]), false, 4), 1.3, 19 + i, 0.5, 0.4); }
    pen(g, smooth(EAR, false, 5), 1.8, 30, 0.8);
    pen(g, smooth(Hd([[412, 470], [420, 486], [414, 500]]), false, 4), 1.4, 31, 0.6);
    pen(g, smooth(EYE_TOP, false, 4), 2.6, 32);
    pen(g, smooth(EYE_LOW, false, 4), 1.2, 33, 0.6);
    fillShape(g, smooth(Hd([[496, 390], [503, 392], [502, 400], [495, 399]]), true, 3), INK, 0.9); // the iris, seen side-on
    pen(g, smooth(BROW, false, 4), 2.2, 34, 0.75);
    pen(g, smooth(NOSTRIL, false, 3), 1.6, 35, 0.8);
    pen(g, MOUTH_CORNER, 1.8, 36, 0.8);
    pen(g, smooth(NECK_BACK, false, 4), 2.6, 37);
    pen(g, smooth(NECK_FRONT, false, 4), 2.2, 38, 0.85);
    pen(g, smooth(STERNO, false, 4), 1.2, 39, 0.45);
    // the jumper: shoulder pressed, the far side lifting off
    pen(g, smooth(JUMPER.slice(0, 8), false, 6), 3.2, 40);
    pen(g, smooth(JUMPER.slice(9).concat([[470, 836]]), false, 6), 2.6, 41, 0.85);
    pen(g, smooth(COLLAR, false, 4), 2.2, 42);
    pen(g, smooth(COLLAR2, false, 4), 1.6, 43, 0.7);
    for (let i = 0; i < 9; i++) { const t = i / 8, x = 400 + (508 - 400) * t, y = 904 + Math.sin(t * Math.PI) * 30; pen(g, [[x, y], [x + 2, y + 16]], 0.9, 44 + i, 0.5, 0.2); }
    pen(g, smooth(FOLD1, false, 4), 1.4, 60, 0.5);
    pen(g, smooth(FOLD2, false, 4), 1.6, 61, 0.55);
  });

  // 3. the voice: a highlight wash under it, then the line itself, pressed and lifting
  g.group("paint", () => fillShape(g, tube(VOICE, 4, 30, true), HIGH, 0.22));
  g.group("plain", () => {
    // an echo a little behind, then the voice itself: the strongest mark in the picture
    g.pen(VOICE.map(([x, y]) => [x - 4, y + 14] as P), { w: 2.2, color: HIGH, seed: 69, wobble: 0.5, boil: 0, taper: 0.8, opacity: 0.7, retrace: false });
    g.pen(VOICE, { w: 6.5, color: ACCENT, seed: 70, wobble: 0.35, boil: 0, taper: 0.5, opacity: 1, retrace: false });
    // three short breaths at the lips, where the sound starts
    const m = VOICE[0];
    [[0, -20], [8, 0], [0, 20]].forEach(([dx, dy], i) => pen(g, [[m[0] + 4 + dx, m[1] + dy], [m[0] + 26 + dx, m[1] + dy * 1.4]], 1.6, 80 + i, 0.6, 0.3));
  });
};

export const dictusHero: Film = {
  meta: { title: "Dictus hero · ink + line-wash", W, H, fps: 30, bpm: 120, durationFrames: 1 },
  assets: { images: {} },
  shots: [{ id: "dictusHero", start: 0, end: 1, draw: drawDictusHero }],
};
