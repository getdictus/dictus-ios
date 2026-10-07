import { Gfx, turn, type Ctx, type Env, type P } from "./core";
import { clearEdges } from "./edges";
import type { Film } from "./film";
import { fillShape } from "./gallery";
import { BPM, FPS, FRAME, LOOP_A, loop, place, THEMES, type Theme } from "./theme";
import { drawNoteCard, type Card } from "./noteCard";
import {
  ARM_NEAR, BAG_D, bobAt, drawVoice, drawWoman, FIG, fig, LEG_FAR, LEG_NEAR, legAt, MARKER, mouthOpen, phoneMap, setTheme, stroke, type Pose,
} from "./woman";

// ONBOARDING INTRO, SCENE A · "walking" (issue #667, headline "Parlez. Dictus écrit.").
// The App Store hero V15-B set in motion: she walks in place on a pavement that slides back
// under her, the phone up at her mouth (seen from the back, as V15-B drew it), talking. Her
// voice leaves her lips as the three blue strokes, in the App Store art's big arch, and goes
// INTO the phone; the text comes OUT of it, as a sent chat message that springs from the
// phone's edge and grows a line at a time (woman.ts draws her and the voice, noteCard.ts the
// message).
//
// What moves, all of it periodic over the 5.5 s loop:
// - the legs: five walk cycles (1.1 s each, about 109 steps a minute), the planted foot sliding
//   back at the pavement's speed, the slab joints running at that speed at the feet's depth;
// - the body rises at the passing positions and sinks at contact; the tote arm swings against
//   the near leg and the tote follows the fist a beat late; the hair's ends sway; the phone rocks;
// - the mouth talks; the voice's pulses travel from her lips into the phone, eleven a loop;
// - the message springs out, grows four lines, and fades before the seam.

// The source canvas is the App Store strip (2640 x 2868); the frame shows x 0..1466 of it at the
// scale of the #649 mock-up's crop (designs/onboarding-649-assets/intro-walk.png), from y 690
// rather than the crop's 750, so the top of her head has a clear margin under the frame's edge.
const W = 2640, H = 2868;
const PLACE = place([0, 690], 1466, [0, 0], 330);
const FRAME_BOTTOM = PLACE.o[1] + FRAME.h / PLACE.k;
const LP = loop(LOOP_A);

// ---------------------------------------------------------------- the ground (V15-B's)
const HORIZON = 1640;
const VP_L: P = [-1700, HORIZON], VP_R: P = [3300, HORIZON];
const toward = (vp: P, through: P, y: number): P => [vp[0] + ((through[0] - vp[0]) * (y - vp[1])) / (through[1] - vp[1]), y];
const KERB_A: P = [0, 1806], KERB_B: P = [1320, 1948];   // the far kerb, on the line to VP_L
const GROUND_R = 1320;                                    // V15-B's slide edge: the pavement fades out before it
// the frame's own edges: the slabs fade out over the last 260 source pixels above its bottom
const EDGE_FADE = { left: 160, bottom: [FRAME_BOTTOM - 260, FRAME_BOTTOM] as P };

// One step (heel strike to the other heel strike) carries the planted foot STEP figure units
// back; it is measured on V15-B (the near shoe's ball, planted at push-off, sits one step behind
// where the far heel struck).
const CYCLES = 5, STEP = 434;
// cross joints of the slabs, on lines to VP_R, spaced one step apart at the feet (y FEET_Y) so the
// pattern has slid exactly one joint per step and the loop closes on itself
const FEET_Y = 2510, FOOT_LINE = H + 40;
const atFeet = (FEET_Y - HORIZON) / (FOOT_LINE - HORIZON);

const ground = (g: Gfx, t: Theme, frame: number) => {
  fillShape(g, [[-10, HORIZON + 60], [GROUND_R + 10, HORIZON + 60], [GROUND_R + 10, KERB_B[1]], [-10, KERB_A[1]]], t.road);
  fillShape(g, [[-10, KERB_A[1]], [GROUND_R + 10, KERB_B[1]], [GROUND_R + 10, H], [-10, H]], t.pave);
  const kerbFace = (y: number) => [[-10, KERB_A[1] + y], [GROUND_R + 10, KERB_B[1] + y * 1.12]] as P[];
  fillShape(g, [...kerbFace(0), ...kerbFace(22).reverse()], t.kerb);
  stroke(g, kerbFace(0), 3.2, 500, t.joint, 0.2, 0.55 * t.jointK);
  stroke(g, kerbFace(22), 2.2, 501, t.joint, 0.2, 0.3 * t.jointK);
  // long joints to VP_L run along her way: they stay put
  [2060, 2230, 2470, 2800, 3260].forEach((y, k) => {
    const yAt = (x: number) => HORIZON + ((y - HORIZON) * (x - VP_L[0])) / (GROUND_R - VP_L[0]);
    stroke(g, [[-10, yAt(-10)], [GROUND_R + 10, yAt(GROUND_R + 10)]] as P[], 2.6, 510 + k, t.joint, 0.2, 0.22 * t.jointK);
  });
  // cross joints slide back (left) one step per step
  const gap = (STEP * FIG.s) / atFeet, slide = gap * CYCLES * 2 * LP.tau(frame);
  for (let k = -3; k <= 3; k++) {
    const foot: P = [-40 + k * gap - (slide % gap), FOOT_LINE], top = toward(VP_R, foot, KERB_A[1] + 40);
    stroke(g, [top, foot], 2.4, 520, t.joint, 0.2, 0.2 * t.jointK);
  }
};

// the arm with the tote swings against the near leg: forward (as V15-B drew it) when that leg is back
const swing = (v: number) => 15 * (1 - Math.cos(2 * Math.PI * v)) / 2;
const poseAt = (frame: number): Pose => {
  const u = (LP.tau(frame) * CYCLES) % 1, bob = bobAt(u);
  const armNear = turn(ARM_NEAR.map(([x, y]) => [x, y + bob] as P), ARM_NEAR[0][0], ARM_NEAR[0][1] + bob, swing(u)) as P[];
  const wristD: P = [armNear[2][0] - ARM_NEAR[2][0], armNear[2][1] - ARM_NEAR[2][1]];
  const lag = turn([ARM_NEAR[2]], ARM_NEAR[0][0], ARM_NEAR[0][1], swing(u - 0.06))[0];
  return {
    far: legAt(LEG_FAR[0], u, bob), near: legAt(LEG_NEAR[0], u + 0.5, bob), bob, lean: 0, hairU: u, open: mouthOpen(LP, frame), armNear,
    carry: { kind: "tote", toteD: [BAG_D[0] + lag[0] - ARM_NEAR[2][0], BAG_D[1] + lag[1] - ARM_NEAR[2][1] + bob], fistD: [BAG_D[0] + wristD[0], BAG_D[1] + wristD[1]] },
    phoneDeg: -10 + 1.2 * Math.sin(4 * Math.PI * u - 0.5),
  };
};

// ---------------------------------------------------------------- the picture
const drawFor = (theme: Theme) => (ctx: Ctx, frame: number, env: Env) => {
  setTheme(theme);
  const g = new Gfx(ctx, env, frame, MARKER);
  const k = PLACE.k * env.scale, toFrame = () => ctx.setTransform(k, 0, 0, k, -PLACE.o[0] * k, -PLACE.o[1] * k);
  g.push(-PLACE.o[0] * PLACE.k, -PLACE.o[1] * PLACE.k, PLACE.k);

  // 1. the ground, faded out toward the horizon, before its right edge and at the frame's edges
  g.group("plain", () => ground(g, theme, frame));
  ctx.save(); toFrame(); ctx.globalCompositeOperation = "destination-out";
  const fade = (x0: number, y0: number, x1: number, y1: number, from: number, to: number) => { const gr = ctx.createLinearGradient(x0, y0, x1, y1); gr.addColorStop(0, `rgba(0,0,0,${from})`); gr.addColorStop(1, `rgba(0,0,0,${to})`); return gr; };
  ctx.fillStyle = fade(0, HORIZON + 60, 0, KERB_A[1] + 40, 1, 0); ctx.fillRect(-10, HORIZON, GROUND_R + 30, KERB_B[1] + 60 - HORIZON);
  ctx.fillStyle = fade(980, 0, GROUND_R, 0, 0, 1); ctx.fillRect(980, HORIZON, GROUND_R + 40 - 980, H - HORIZON);
  ctx.fillStyle = "rgba(0,0,0,1)"; ctx.fillRect(GROUND_R, HORIZON, W - GROUND_R, H - HORIZON);
  ctx.fillStyle = fade(0, 0, EDGE_FADE.left, 0, 1, 0); ctx.fillRect(-10, HORIZON, EDGE_FADE.left + 10, H - HORIZON);
  ctx.fillStyle = fade(0, EDGE_FADE.bottom[0], 0, EDGE_FADE.bottom[1], 0, 1); ctx.fillRect(-10, EDGE_FADE.bottom[0], GROUND_R + 20, H - EDGE_FADE.bottom[0] + 10);
  ctx.restore();

  // 2. her, and her voice going into her phone
  const pose = poseAt(frame);
  g.push(FIG.at[0], FIG.at[1], FIG.s);
  drawWoman(g, theme, pose, () => drawVoice(g, pose, LP, frame, 11));
  g.pop();

  // 3. the text, coming out of the phone as a chat message
  g.group("plain", () => drawNoteCard(g, theme, LP, frame, CARD, fig(phoneMap(pose)([[56, -6]])[0])));
  // 4. a clean band round the frame, so the page colour decodes exactly at its edge (edges.ts)
  clearEdges(ctx, env);
};

// the message, canvas pixels: in the empty right of the frame, under the voice's arch
const CARD: Card = { style: "bubble", c: [1185, 1270], w: 400, deg: -2 };

const film = (theme: Theme, title: string): Film => ({
  meta: { title: `Dictus onboarding intro A · walking · ${theme.name}`, W: FRAME.w, H: FRAME.h, fps: FPS, bpm: BPM, durationFrames: LOOP_A },
  assets: { images: {} },
  shots: [{ id: title, start: 0, end: LOOP_A, draw: drawFor(theme) }],
});
export const introWalkLight = film(THEMES.light, "introWalkLight");
export const introWalkDark = film(THEMES.dark, "introWalkDark");
