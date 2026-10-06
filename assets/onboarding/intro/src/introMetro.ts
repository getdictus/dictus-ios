import { Gfx, type Ctx, type Env, type P } from "./core";
import type { Film } from "./film";
import { clipped, fillShape } from "./gallery";
import { BPM, FPS, FRAME, LOOP_B, loop, place, THEMES, type Theme } from "./theme";
import {
  ARM_NEAR, BAG_D, cel, drawVoice, drawWoman, FIG, LEG_FAR, LEG_NEAR, legFrom, MARKER, mouthOpen, outline, setTheme, stroke, twoBone, type Pose,
} from "./woman";

// ONBOARDING INTRO, SCENE B · "the metro, no network" (issue #667, headline "Même sans réseau.").
// The same woman as scene A (woman.ts), now standing in a metro carriage. One hand holds the
// grab pole, the other her phone at her mouth. A badge in the frame's top-right corner says NO
// NETWORK: the signal bars struck through in the recording red, drawn, never written. She talks
// and her voice still goes into the phone: dictation does not need the network.
//
// New art, drawn for this scene in the same marker comic: the carriage wall and floor, a bench
// under a window on the dark tunnel with its lights streaking past, the overhead rail and the pole.
// The carriage dissolves into the page at the frame's edges, as scene A's pavement does, so the
// video never shows a box against the screen.
//
// What moves, periodic over the 5.5 s loop: the tunnel lights stream past the window (three
// speeds, nearer lights faster); the carriage rocks and she sways with it, feet planted and the
// hand closed on the pole; she talks; the voice's pulses run into the phone; the badge pops twice. Noise around her (a neighbour) was optional in the brief and is left out: at this
// size a second figure takes the eye from her phone.

// Same source frame and placement as scene A, so she stands where she walked: the carousel
// does not jump between the two.
const W = 2640, H = 2868;
const PLACE = place([0, 750], 1466, [0, 0], 330);
const LP = loop(LOOP_B);
const FRAME_BOTTOM = 750 + FRAME.h / PLACE.k;

// ---------------------------------------------------------------- the carriage (canvas pixels)
const FLOOR_Y = 2330;                               // where the wall meets the floor
const RAIL_Y = 836;                                 // the overhead grab rail
const WIN = { x0: 690, y0: 930, x1: 1380, y1: 1520, r: 70 };
const BENCH = { x0: 760, x1: 1470, back: [1580, 1960] as P, seat: [1960, 2070] as P };
// the pole her hand closes round, figure space: a vertical tube from the rail to the floor
const POLE_X = 238, POLE_R = 13;
const POLE_FOOT = 2500;                            // it stands on the floor where she stands
const rrect = (x0: number, y0: number, x1: number, y1: number, r: number, n = 6): P[] => {
  const out: P[] = [], c = (cx: number, cy: number, a0: number) => { for (let i = 0; i <= n; i++) { const a = a0 + (i / n) * (Math.PI / 2); out.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]); } };
  c(x1 - r, y0 + r, -Math.PI / 2); c(x1 - r, y1 - r, 0); c(x0 + r, y1 - r, Math.PI / 2); c(x0 + r, y0 + r, Math.PI);
  return out;
};
// the tunnel's lights: height in the window, length, speed (whole passes per loop), phase, colour
const LIGHTS: [number, number, number, number, number][] = [
  [0.16, 230, 4, 0.1, 0], [0.3, 120, 6, 0.55, 1], [0.48, 300, 3, 0.35, 0], [0.62, 150, 6, 0.85, 1], [0.8, 260, 4, 0.62, 0], [0.9, 110, 5, 0.25, 1],
];

const carriage = (g: Gfx, t: Theme, frame: number, rock: number) => {
  // the wall, its lower panel a shade darker, and the floor
  fillShape(g, [[-20, 700], [W, 700], [W, FLOOR_Y], [-20, FLOOR_Y]], t.wall);
  fillShape(g, [[-20, 2120], [W, 2120], [W, FLOOR_Y], [-20, FLOOR_Y]], t.wallShade);
  stroke(g, [[-20, 2120], [1500, 2120]], 3, 600, t.line, 0.2, 0.35);
  fillShape(g, [[-20, FLOOR_Y], [W, FLOOR_Y], [W, H], [-20, H]], t.floor);
  stroke(g, [[-20, FLOOR_Y], [1500, FLOOR_Y]], 4, 601, t.line, 0.2, 0.6);
  // the window on the tunnel: its frame, the dark glass, the lights going by, a glint on the glass
  const glass = rrect(WIN.x0, WIN.y0 + rock, WIN.x1, WIN.y1 + rock, WIN.r);
  cel(g, rrect(WIN.x0 - 26, WIN.y0 - 26 + rock, WIN.x1 + 26, WIN.y1 + 26 + rock, WIN.r + 22), t.frameFill, t.wallShade, 8);
  fillShape(g, glass, t.tunnel);
  clipped(g, glass, () => {
    [0.34, 0.74].forEach((h, k) => stroke(g, [[WIN.x0 - 40, WIN.y0 + (WIN.y1 - WIN.y0) * h + rock], [WIN.x1 + 40, WIN.y0 + (WIN.y1 - WIN.y0) * h + 6 + rock]], 6, 610 + k, t.tunnelLine, 0.1, 1));
    const span = WIN.x1 - WIN.x0;
    LIGHTS.forEach(([h, len, n, ph, c], k) => {
      const f = (LP.tau(frame) * n + ph) % 1, x = WIN.x1 + len - f * (span + 2 * len), y = WIN.y0 + (WIN.y1 - WIN.y0) * h + rock;
      g.pen([[x, y], [x + len * 0.5, y + 1], [x + len, y]], { w: 7 - (k % 2) * 2, color: t.streak[c], seed: 620 + k, closed: false, wobble: 0.2, boil: 0, taper: 0.95, opacity: 0.95, retrace: false });
    });
    fillShape(g, [[WIN.x0 + 60, WIN.y1 + rock], [WIN.x0 + 200, WIN.y0 + rock], [WIN.x0 + 250, WIN.y0 + rock], [WIN.x0 + 110, WIN.y1 + rock]], "#FFFFFF", 0.06);
  });
  outline(g, glass, 6, 630);
  outline(g, rrect(WIN.x0 - 26, WIN.y0 - 26 + rock, WIN.x1 + 26, WIN.y1 + 26 + rock, WIN.r + 22), 6, 631);
  // the bench under the window: its back and its cushion
  const back = rrect(BENCH.x0, BENCH.back[0], BENCH.x1, BENCH.back[1], 34), seat = rrect(BENCH.x0 - 30, BENCH.seat[0], BENCH.x1 + 10, BENCH.seat[1], 30);
  cel(g, back, t.seat, t.seatShade, 14); outline(g, back, 5.5, 640);
  cel(g, seat, t.seat, t.seatShade, 10); outline(g, seat, 5.5, 641);
  stroke(g, [[BENCH.x0 + 330, BENCH.back[0] + 30], [BENCH.x0 + 330, BENCH.back[1] - 20]], 3, 642, t.line, 0.6, 0.4);
  // the overhead rail along the carriage, and the pole down from it to the floor
  const px = FIG.at[0] + POLE_X * FIG.s, pr = POLE_R * FIG.s;
  const rail: P[] = [[-20, RAIL_Y - pr], [1500, RAIL_Y - pr], [1500, RAIL_Y + pr], [-20, RAIL_Y + pr]];
  cel(g, rail, t.poleLit, t.pole, 6); outline(g, rail, 5, 650);
  const pole: P[] = [[px - pr, RAIL_Y], [px + pr, RAIL_Y], [px + pr, POLE_FOOT], [px - pr, POLE_FOOT]];
  cel(g, pole, t.poleLit, t.pole, 8); outline(g, pole, 5, 651);
  // where the pole meets the rail and the floor: a collar each
  [RAIL_Y + pr + 6, POLE_FOOT - 10].forEach((y, k) => { const c = rrect(px - pr * 1.9, y - 12, px + pr * 1.9, y + 12, 10); cel(g, c, t.poleLit, t.pole, 4); outline(g, c, 4, 652 + k); });
};

// ---------------------------------------------------------------- her, standing
// both feet flat, a little apart, her weight on both: foot keys relative to each hip, the way
// FOOT keys the walk (heel x, heel y, sole angle, toe bend)
const STAND_FAR: [number, number, number, number] = [64, 741, 0, 0], STAND_NEAR: [number, number, number, number] = [-36, 741, 0, 0];
// her near hand on the pole, at hip height behind her (figure space)
const GRIP: P = [POLE_X - 22, 1636];
const BONES_ARM: P = [213.4, 207.1];   // V15-B's upper arm and forearm
// standing, the legs are nearly straight: bones between V15-B's reaching and pushing legs
const BONES_STAND: P = [340, 343];

const poseAt = (frame: number): Pose => {
  // the carriage rocks twice a loop; she sways with it a little after it, her feet planted
  const lean = 7 * LP.cyc(frame, 2, -0.7), bob = -1.5 + 1.5 * LP.cyc(frame, 4, 0.3);
  const shoulder: P = [ARM_NEAR[0][0] + lean, ARM_NEAR[0][1] + bob];
  const elbow = twoBone(shoulder, GRIP, BONES_ARM[0], BONES_ARM[1], -1);
  return {
    far: legFrom(LEG_FAR[0], STAND_FAR, BONES_STAND, bob, lean), near: legFrom(LEG_NEAR[0], STAND_NEAR, BONES_STAND, bob, lean),
    bob, lean, hairU: 0.12 + 0.02 * LP.cyc(frame, 2), open: mouthOpen(LP, frame), armNear: [shoulder, elbow, GRIP],
    carry: { kind: "pole", fistD: [BAG_D[0] + GRIP[0] - ARM_NEAR[2][0], BAG_D[1] + GRIP[1] - ARM_NEAR[2][1]] },
    phoneDeg: -10 + 1.5 * LP.cyc(frame, 2, -1.2),
  };
};

// ---------------------------------------------------------------- the picture
const drawFor = (theme: Theme) => (ctx: Ctx, frame: number, env: Env) => {
  setTheme(theme);
  const g = new Gfx(ctx, env, frame, MARKER);
  const k = PLACE.k * env.scale, toFrame = () => ctx.setTransform(k, 0, 0, k, -PLACE.o[0] * k, -PLACE.o[1] * k);
  g.push(-PLACE.o[0] * PLACE.k, -PLACE.o[1] * PLACE.k, PLACE.k);
  const rock = 3 * LP.cyc(frame, 2);

  // 1. the carriage, dissolved into the page at the frame's four edges
  g.group("plain", () => carriage(g, theme, frame, rock));
  ctx.save(); toFrame(); ctx.globalCompositeOperation = "destination-out";
  const fade = (x0: number, y0: number, x1: number, y1: number) => { const gr = ctx.createLinearGradient(x0, y0, x1, y1); gr.addColorStop(0, "rgba(0,0,0,1)"); gr.addColorStop(1, "rgba(0,0,0,0)"); return gr; };
  ctx.fillStyle = fade(0, 0, 170, 0); ctx.fillRect(-30, 600, 200, H);
  ctx.fillStyle = fade(1466, 0, 1290, 0); ctx.fillRect(1280, 600, 300, H);
  ctx.fillStyle = fade(0, 750, 0, 900); ctx.fillRect(-30, 600, 1600, 300);
  ctx.fillStyle = fade(0, FRAME_BOTTOM, 0, FRAME_BOTTOM - 300); ctx.fillRect(-30, FRAME_BOTTOM - 300, 1600, 400);
  ctx.restore();

  // 2. her, and her voice going into her phone
  const pose = poseAt(frame);
  g.push(FIG.at[0], FIG.at[1], FIG.s);
  drawWoman(g, theme, pose, () => drawVoice(g, pose, LP, frame, 11));
  g.pop();

  // 3. no network, over the picture
  g.group("plain", () => noNetwork(g, theme, frame));
};

// ---------------------------------------------------------------- the no-network badge
// A disc in the frame's top-right corner, about 48 pt across on the phone, with the four signal
// bars (the mobile network is what a tunnel takes away) struck through in the app's recording red.
// The disc carries its own fill and contour, so it reads the same over the wall, the window or
// the page, in both appearances. Drawn in FRAME pixels (FX maps them to the source canvas), so its
// size on screen does not depend on the scene's scale. It swells a little twice a loop.
const BADGE = { cx: 890, cy: 112, r: 72 };
const RED = "#EF4444";
const FX = ([x, y]: P): P => [PLACE.o[0] + x / PLACE.k, PLACE.o[1] + y / PLACE.k];
const noNetwork = (g: Gfx, t: Theme, frame: number) => {
  const pop = 1 + 0.06 * Math.max(0, LP.cyc(frame, 2, -0.4)) ** 2, r = BADGE.r * pop;
  const at = (dx: number, dy: number): P => FX([BADGE.cx + dx * pop, BADGE.cy + dy * pop]), px = (w: number) => w / PLACE.k;
  const disc = Array.from({ length: 40 }, (_, i) => FX([BADGE.cx + Math.cos((i / 40) * Math.PI * 2) * r, BADGE.cy + Math.sin((i / 40) * Math.PI * 2) * r]));
  fillShape(g, disc, t.badge);
  outline(g, disc, px(5), 710);
  // four bars, rising left to right, standing on one baseline
  [20, 34, 48, 62].forEach((h, i) => {
    const x0 = -39 + i * 21, bar: P[] = [at(x0, 33), at(x0, 33 - h), at(x0 + 15, 33 - h), at(x0 + 15, 33)];
    fillShape(g, bar, t.line);
  });
  // the strike, falling left to right across the rising bars: a disc-coloured channel cut
  // through them, then the red slash in it
  const a = at(-48, -44), b = at(48, 46);
  g.pen([a, b], { w: px(13), color: t.badge, seed: 711, closed: false, wobble: 0, boil: 0, taper: 0, opacity: 1, retrace: false });
  g.pen([a, b], { w: px(8.5), color: RED, seed: 712, closed: false, wobble: 0.2, boil: 0, taper: 0.15, opacity: 1, retrace: false });
};

const film = (theme: Theme, title: string): Film => ({
  meta: { title: `Dictus onboarding intro B · the metro, no network · ${theme.name}`, W: FRAME.w, H: FRAME.h, fps: FPS, bpm: BPM, durationFrames: LOOP_B },
  assets: { images: {} },
  shots: [{ id: title, start: 0, end: LOOP_B, draw: drawFor(theme) }],
});
export const introMetroLight = film(THEMES.light, "introMetroLight");
export const introMetroDark = film(THEMES.dark, "introMetroDark");
