import { Gfx, turn, type Ctx, type Env, type P } from "./core";
import type { Film } from "./film";
import { fillShape, smooth } from "./gallery";
import { LOOP_A, loop, THEMES } from "./theme";
import {
  ARM_NEAR, at, BAG_D, drawWoman, FIG, LEG_FAR, LEG_NEAR, legAt, MARKER, mouthAt, mouthOpen, off, pathOf, setTheme, stroke, type Path, type Pose,
} from "./woman";

// DICTUS HERO V16-B · the onboarding intro's woman (issue #758; V15-B is art/v15-B/heroWalk15.ts).
// While the intro scenes were animated (#667, PR #670) the character was redrawn at Pierre's
// request: a jaw-length bob, reworked hands (the bag hand 1.25x larger, four fingers across the
// phone's lower back), the phone held out in front of her mouth, and trousers drawn as two legs and
// a seat. Slide 1 is the listing's first picture and the intro is the app's first screen, so they
// must show ONE character: V16-B draws her with the intro's own code (assets/onboarding/intro/src/
// woman.ts, drawWoman), not a copy of it, posed as scene A's frame 0.
//
// Everything else is V15-B's, line for line: the ground, the three voice strokes from her lips
// with her words lettered along the top one, level with the strip's band at slide 1's right edge
// and cut there, so slide 2 is unchanged. Her lips have not moved (the head is V15-B's in both), so
// the strokes start where they did; the phone, further out and lower, sits under their arch.
//
// The pose: scene A (introWalk.ts, poseAt) at frame 0, which is the walk cycle's contact position,
// V15-B's own stride (woman.ts: "the solver gives back V15-B's knees to the pixel"): the far leg's
// heel striking, the near leg pushing off, the tote arm forward, the tote a hair behind the fist,
// the hair's ends trailing, the mouth open as the intro's first frame has it.
//
// Rebuild art/v16-B/hero.png (anidoodle engine; md5 printed as "reproducible"). woman.ts and
// theme.ts are copied from the intro at build time: a change to her there changes her here on the
// next rebuild, which is the point (one character); the committed PNGs are from this commit's.
//   node ~/.claude/skills/anidoodle/engine/tools/scaffold.mjs /tmp/art --still hero
//   cp assets/appstore/art/v16-B/heroWalk16.ts assets/onboarding/intro/src/{woman,theme}.ts /tmp/art/src/canvas-core/
//   printf 'import { heroWalk16 } from "../canvas-core/heroWalk16";\nimport { mountFilm } from "./page";\nmountFilm(heroWalk16);\n' > /tmp/art/src/hosts/page-heroWalk16.ts
//   cd /tmp/art && npm install && npx playwright-core install chromium && node tools/still.mjs heroWalk16 --out out/hero.png
// The other locales the same way, with film files re-exporting heroWalk16FrFR, heroWalk16DeDE and
// heroWalk16EsES (as art/v15-B/heroWalk15.ts describes), into hero-<locale>.png.

export const W = 2640, H = 2868;
// the strip's BrandWaveform band (screenshots.html), as V15-B: the strokes reach the cut level with it
const BAND = { y: 1600 };
// the strokes run past the cut and the frame cuts them there
export const PANEL_IN: P = [1380, BAND.y];   // 60 px past the cut
const CUT = 1320;

const INK = "#0A1628", ACCENT = "#3D7EFF", DEEP = "#2563EB", HIGH = "#6BA3FF";

// ---------------------------------------------------------------- her pose (scene A, frame 0)
// introWalk.ts's poseAt(0): u = 0, so no bob and no arm swing; the tote lags the fist by the swing
// 0.06 of a cycle earlier; the mouth and the phone's rock at the loop's first frame
const SWING_LAG = 15 * (1 - Math.cos(2 * Math.PI * -0.06)) / 2;
const LAG = turn([ARM_NEAR[2]], ARM_NEAR[0][0], ARM_NEAR[0][1], SWING_LAG)[0];
const POSE: Pose = {
  far: legAt(LEG_FAR[0], 0, 0), near: legAt(LEG_NEAR[0], 0.5, 0), bob: 0, lean: 0, hairU: 0,
  open: mouthOpen(loop(LOOP_A), 0), armNear: ARM_NEAR,
  carry: { kind: "tote", toteD: [BAG_D[0] + LAG[0] - ARM_NEAR[2][0], BAG_D[1] + LAG[1] - ARM_NEAR[2][1]] },
  phoneDeg: -10 + 1.2 * Math.sin(-0.5),
};
// her lips in canvas pixels (V15-B's MOUTH)
const MOUTH: P = ((m: P) => [FIG.at[0] + m[0] * FIG.s, FIG.at[1] + m[1] * FIG.s] as P)(mouthAt(POSE));

// ---------------------------------------------------------------- comic lettering (V15-B's)
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
  // fr-FR ("MERCI POUR TES NOTES..."): the five letters the French words add, in the same hand
  M: { w: 0.74, s: [[[0, 0], [0, 1], [0.37, 0.36], [0.74, 1], [0.74, 0]]] },
  C: { w: 0.6, s: [Array.from({ length: 11 }, (_, i) => { const a = Math.PI * (0.22 + (i / 10) * 1.56); return [0.34 + Math.cos(a) * 0.34, 0.5 + Math.sin(a) * 0.5] as P; })] },
  I: { w: 0.08, s: [[[0.04, 1], [0.04, 0]]] },
  P: { w: 0.54, s: [[[0, 0], [0, 1], [0.32, 1], [0.49, 0.92], [0.54, 0.77], [0.49, 0.62], [0.32, 0.54], [0, 0.54]]] },
  U: { w: 0.6, s: [[[0, 1], [0, 0.32], [0.05, 0.11], [0.16, 0.01], [0.3, -0.01], [0.44, 0.01], [0.55, 0.11], [0.6, 0.32], [0.6, 1]]] },
  // de-DE ("DANKE FÜR DIE NOTIZEN...") and es-ES ("GRACIAS POR LAS NOTAS..."): D, Ü, Z, G, L
  D: { w: 0.6, s: [[[0, 0], [0, 1], [0.26, 1], [0.46, 0.92], [0.58, 0.72], [0.6, 0.5], [0.58, 0.28], [0.46, 0.08], [0.26, 0], [0, 0]]] },
  Ü: { w: 0.6, s: [[[0, 0.86], [0, 0.32], [0.05, 0.11], [0.16, 0.01], [0.3, -0.01], [0.44, 0.01], [0.55, 0.11], [0.6, 0.32], [0.6, 0.86]],
    [[0.15, 1.08], [0.18, 1.04], [0.21, 1.08], [0.18, 1.12], [0.15, 1.08]], [[0.39, 1.08], [0.42, 1.04], [0.45, 1.08], [0.42, 1.12], [0.39, 1.08]]] },
  Z: { w: 0.56, s: [[[0, 1], [0.56, 1], [0, 0], [0.56, 0]]] },
  G: { w: 0.66, s: [[...Array.from({ length: 10 }, (_, i) => { const a = Math.PI * (0.24 + (i / 9) * 1.58); return [0.34 + Math.cos(a) * 0.34, 0.5 + Math.sin(a) * 0.5] as P; }), [0.66, 0.44], [0.4, 0.44]]] },
  L: { w: 0.48, s: [[[0, 1], [0, 0], [0.48, 0]]] },
};
const SPACE = 0.42, TRACK = 0.17;
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

// ---------------------------------------------------------------- the ground (V15-B's)
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

// ---------------------------------------------------------------- the voice (canvas pixels, V15-B's)
// ONE soft S: up from her lips over the phone, over the top with her words, down a long diagonal,
// and level at the end, at the band's height, cut by slide 1's right edge
const voiceFor = (end: P) => pathOf([[MOUTH[0] + 14, MOUTH[1] - 16], [630, 950], [720, 904], [820, 888], [910, 904], [990, 950], [1052, 1030], [1098, 1146], [1136, 1290], [1178, 1424], [1228, 1524], [1286, 1590], [1340, end[1] + 1], [end[0], end[1]]], 30);
// Her words, per locale: they are the first words of slide 2's email (strings/<locale>.js).
const TEXT = "THANKS FOR THE NOTES...", CAP = 44, TEXT_AT = 76;
export const TEXT_FR_FR = "MERCI POUR TES NOTES...";
export const TEXT_DE_DE = "DANKE FÜR DIE NOTIZEN...";
export const TEXT_ES_ES = "GRACIAS POR LAS NOTAS...";
const spread = (s: number) => { const t = Math.min(1, s / 700), e = t * t * (3 - 2 * t); return 4 + 16 * e; };

// ---------------------------------------------------------------- the picture
const drawFor = (end: P, text = TEXT) => (ctx: Ctx, _frame: number, env: Env) => {
  const VOICE = voiceFor(end);
  setTheme(THEMES.light);
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

  // 2. her, the intro's woman, in figure space; her voice is not the intro's bars here but the
  //    strokes below, drawn over her as V15-B drew them
  g.push(FIG.at[0], FIG.at[1], FIG.s);
  drawWoman(g, THEMES.light, POSE, () => {});
  g.pop();

  // 3. the voice: three thin marker strokes, her words lettered along the top one
  g.group("plain", () => {
    // three uneven marker strokes: each wavers on its own, slower or faster, and they all settle
    // flat for the last stretch so they leave the frame at the band's height
    [-1, 0, 1].forEach((o, k) => {
      const pts: P[] = [], f1 = [3.2, 4.1, 3.6][k], f2 = [9.5, 7.3, 11.2][k], ph = [0.4, 2.1, 4.0][k];
      for (let s = 0; s <= VOICE.total; s += 8) {
        // the hand's waver, quieter on the level run so the strokes leave the frame at the band's height
        const t = s / VOICE.total, rise = Math.min(1, s / 90), x = at(VOICE, s).p[0];
        const level = Math.max(0.3, Math.min(1, (1300 - x) / 160));
        const waver = (Math.sin(t * Math.PI * f1 + ph) * 6 + Math.sin(t * Math.PI * f2 + ph * 1.7) * 2.2) * rise * level;
        pts.push(off(VOICE, s, o * spread(s) * (0.85 + 0.15 * Math.sin(t * 9 + k)) + waver));
      }
      g.pen(pts, { w: [5, 6.4, 4.2][k], color: [HIGH, ACCENT, DEEP][k], seed: 170 + k, closed: false, wobble: 0.9, boil: 0, taper: 0.9, opacity: 1, retrace: false });
    });
    letter(g, VOICE, text, TEXT_AT, CAP, INK, 4, (s) => spread(s) + 22 + CAP / 2);
  });
  // slide 1's frame cuts the strokes: nothing of the hero is drawn on slide 2
  ctx.save(); ctx.setTransform(env.scale, 0, 0, env.scale, 0, 0); ctx.clearRect(CUT, 0, W - CUT, H); ctx.restore();
};

const film = (id: string, locale: string, text: string): Film => ({
  meta: { title: `Dictus hero V16-B · the intro's woman${locale ? `, ${locale}` : ""}`, W, H, fps: 30, bpm: 120, durationFrames: 1 }, assets: { images: {} },
  shots: [{ id, start: 0, end: 1, draw: drawFor(PANEL_IN, text) }],
});
export const heroWalk16 = film("heroWalk16", "", TEXT);
export const heroWalk16FrFR = film("heroWalk16FrFR", "fr-FR", TEXT_FR_FR);
export const heroWalk16DeDE = film("heroWalk16DeDE", "de-DE", TEXT_DE_DE);
export const heroWalk16EsES = film("heroWalk16EsES", "es-ES", TEXT_ES_ES);
