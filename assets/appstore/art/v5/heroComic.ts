import { Gfx, softBox, tube, turn, type Ctx, type Env, type Medium, type P } from "./core";
import type { Film } from "./film";
import { clipped, fillShape, smooth } from "./gallery";
import * as S from "./heroShapes";

// DICTUS HERO V5, style A · marker comic (after koi.ts). Bold cel fills with a hard shadow edge:
// each form is laid in its shade colour, then its lit colour offset toward the light and clipped
// to the form, so the terminator is one crisp edge. Then one heavy confident contour in navy that
// thickens on the side away from the light. Order: fills, shade edges, contour, details. No paper,
// transparent background (the screenshot template supplies the page).

const MARKER: Medium = { nib: 2.4, taper: 0.55, pressure: 0.6, retrace: false, wobble: 0.6, rough: 0.3 };
const LIGHT: P = [-0.6, -0.8];
const sm = (pts: P[], per = 6) => smooth(pts, true, per);

const cel = (g: Gfx, pts: P[], lit: string, shade: string, k = 18) => {
  const s = sm(pts);
  fillShape(g, s, shade);
  clipped(g, s, () => fillShape(g, s.map(([x, y]) => [x + LIGHT[0] * k, y + LIGHT[1] * k] as P), lit));
};
const line = (g: Gfx, pts: P[], w: number, seed: number, closed = true, color = S.C.ink) =>
  g.pen(closed ? sm(pts) : smooth(pts, false, 6), { w, color, seed, closed, wobble: 0.5, boil: 0, taper: closed ? 0.3 : 0.9, opacity: 1, retrace: false });

export const drawHeroComic = (ctx: Ctx, _frame: number, env: Env) => {
  const g = new Gfx(ctx, env, 0, MARKER);
  ctx.setTransform(env.scale, 0, 0, env.scale, 0, 0);
  ctx.clearRect(0, 0, S.W, S.H);
  const C = S.C;

  // the voice first, so the figure overlaps its root: a fat tapered stream, two thin echoes
  g.group("plain", () => {
    fillShape(g, tube(smooth(S.VOICE, false, 10), 30, 10, true), C.high, 0.95);
    fillShape(g, tube(smooth(S.VOICE.map(([x, y]) => [x + 9, y + 6] as P), false, 10), 20, 6, true), C.accent, 1);
    g.pen(smooth(S.VOICE.map(([x, y]) => [x + 46, y - 4] as P).slice(1, 8), false, 10), { w: 5, color: C.high, seed: 3, wobble: 0.3, boil: 0, taper: 1, opacity: 0.8, retrace: false });
    g.pen(smooth(S.VOICE.map(([x, y]) => [x - 40, y + 10] as P).slice(2, 7), false, 10), { w: 4, color: C.accent, seed: 4, wobble: 0.3, boil: 0, taper: 1, opacity: 0.6, retrace: false });
  });

  g.group("plain", () => {
    cel(g, S.BUN, C.hairLight, C.hair, 14);
    cel(g, S.ARM_UP, C.jumper, C.jumperShade, 22);
    cel(g, S.CUFF_UP, C.collar, C.jumperShade, 6);
    cel(g, S.HAND_UP, C.skin, C.skinShade, 10);
    cel(g, S.JUMPER, C.jumper, C.jumperShade, 46);
    cel(g, S.NECK, C.skin, C.skinShade, 16);
    cel(g, S.COLLAR, C.collar, C.jumperShade, 6);
    cel(g, S.FACE, C.skin, C.skinShade, 26);
    fillShape(g, sm(S.BLUSH_L), C.blush, 0.55); fillShape(g, sm(S.BLUSH_R), C.blush, 0.45);
    cel(g, S.HAIR, C.hairLight, C.hair, 20);
    cel(g, S.EAR, C.skin, C.skinShade, 6);
    fillShape(g, sm(S.MOUTH), C.mouth);
    clipped(g, sm(S.MOUTH), () => { fillShape(g, sm(S.TEETH), C.white); fillShape(g, sm(S.TONGUE), C.tongue); });
    cel(g, S.ARM_FRONT, C.jumper, C.jumperShade, 20);
    const ph = S.PHONE_AT, body = turn(softBox(ph.cx, ph.cy, ph.w, ph.h, 6, 40), ph.cx, ph.cy, ph.deg), screen = turn(softBox(ph.cx, ph.cy, ph.w - 18, ph.h - 18, 6, 40), ph.cx, ph.cy, ph.deg);
    fillShape(g, body, C.phone); fillShape(g, screen, "#E8F0FF");
    // three lines of text on the screen: the dictation, arriving
    [0, 1, 2].forEach((k) => fillShape(g, turn(softBox(ph.cx - 8 + (k === 2 ? -12 : 0), ph.cy - 40 + k * 28, k === 2 ? 46 : 66, 9, 3, 16), ph.cx, ph.cy, ph.deg), C.accent, 0.85));
    cel(g, S.HAND_FRONT, C.skin, C.skinShade, 10);
  });

  // contours: heavy on the shade side of the body, lighter on details
  g.group("plain", () => {
    line(g, S.BUN, 6, 10); line(g, S.ARM_UP, 7, 11); line(g, S.HAND_UP, 5, 12); line(g, S.CUFF_UP, 4, 13);
    line(g, S.JUMPER, 8, 14); line(g, S.NECK, 5, 15); line(g, S.COLLAR, 4, 16);
    line(g, S.FACE, 6, 17); line(g, S.HAIR, 7, 18); line(g, S.EAR, 4, 19);
    line(g, S.EYE_L, 6, 20, false); line(g, S.EYE_R, 6, 21, false);
    line(g, S.BROW_L, 5, 22, false); line(g, S.BROW_R, 4, 23, false);
    line(g, S.NOSE, 4.5, 24, false); line(g, S.MOUTH, 4.5, 25);
    line(g, S.ARM_FRONT, 7, 26); line(g, S.HAND_FRONT, 5, 28);
    // a few fold lines in the jumper and the sleeve
    line(g, [[420, 1000], [440, 1200], [430, 1420]], 3.5, 29, false);
    line(g, [[720, 1180], [740, 1400], [736, 1600]], 3.5, 30, false);
    line(g, [[240, 640], [270, 700]], 3, 31, false);
    // the voice's own edge, one confident stroke on its shade side
    g.pen(smooth(S.VOICE.map(([x, y]) => [x + 22, y + 10] as P), false, 10), { w: 4, color: S.C.ink, seed: 32, wobble: 0.4, boil: 0, taper: 1, opacity: 0.85, retrace: false });
  });
};

export const heroComic: Film = {
  meta: { title: "Dictus hero V5 · marker comic", W: S.W, H: S.H, fps: 30, bpm: 120, durationFrames: 1 },
  assets: { images: {} },
  shots: [{ id: "heroComic", start: 0, end: 1, draw: drawHeroComic }],
};
