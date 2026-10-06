import { Gfx, type Ctx, type Env, type Medium, type P } from "./core";
import type { Film } from "./film";
import { clipped, fillShape, smooth } from "./gallery";
import { drop, mm, MM, mmPts, rrect, WAVE } from "./phoneGeometry";
import { BPM, cyc, FPS, FRAME, LOOP, place, tau, THEMES, type Theme } from "./theme";

// ONBOARDING INTRO, SCENE C · "the keyboard" (issue #667). The App Store hero V10-A's back layer
// (branch chore/643-hero-a, assets/appstore/art/v10-A/heroSpeak10.ts, drawBack) set in motion:
// the giant drawn iPhone with the Dictus keyboard recording, its waveform reacting to a voice.
//
// What moves, periodic over the 4.5 s loop (theme.ts):
// - the waveform: every bar's height follows a speech-like level that runs across the bars from
//   the centre outward, on two beats that never line up, the way the BrandWaveform answers a voice;
// - the phone hovers: it lifts a few pixels off the ground and settles, twice a loop, its cast
//   shadow staying on the ground, so the gap under it opens and closes.
//
// The brief has the phone "appear". A loop that must close on itself cannot show an entrance
// without also showing an exit every 4.5 s, so the phone is there from frame 0 and the entrance,
// if the screen wants one, is a SwiftUI transition on the video view (#649's PR B).
//
// Marker comic, like the figure (V10-A): every face a flat fill, one hard-edged shadow tone per
// face, a heavy contour round the slab and along the glass, a comic shine on the glass.

// The frame shows the drawing's own box (x 54..1268, y 1347..2728 of the strip), laid out as the
// #649 mock-up does (designs/onboarding-649-assets/intro-keyboard.png): 300 pt wide, at 15 / 83 pt.
const PLACE = place([54, 1347], 1214, [15, 83], 300);

const MARKER: Medium = { nib: 2.4, taper: 0.55, pressure: 0.6, retrace: false, wobble: 0.6, rough: 0.3 };
const DEEP = "#2563EB", HIGH = "#6BA3FF";
const sm = (pts: P[], per = 6) => smooth(pts, true, per);
const circle = (c: P, r: number, n = 24): P[] => Array.from({ length: n }, (_, i) => [c[0] + Math.cos((i / n) * Math.PI * 2) * r, c[1] + Math.sin((i / n) * Math.PI * 2) * r] as P);

let T: Theme = THEMES.light;
const outline = (g: Gfx, s: P[], w: number, seed: number, color = T.line) =>
  g.pen(s, { w, color, seed, closed: true, wobble: 0.5, boil: 0, taper: 0.3, opacity: 1, retrace: false });
const stroke = (g: Gfx, pts: P[], w: number, seed: number, color = T.line, taper = 0.9, op = 1) =>
  g.pen(smooth(pts, false, 8), { w, color, seed, closed: false, wobble: 0.5, boil: 0, taper, opacity: op, retrace: false });

// The keyboard panel while recording, in phone millimetres (V10-A's).
const PANEL_TOP = 98;
// bar heights at rest, left to right (fraction of the tallest): V10-A's, read off the capture
const BARS = [0.55, 0.8, 0.86, 0.5, 0.3, 0.34, 0.62, 0.56, 0.36, 0.28, 0.66, 0.9, 1, 0.84, 0.7, 0.92, 0.8];
// the level a bar shows at a frame: its drawn height, carried up and down by a voice. The level
// starts in the centre and spreads outward (phase grows with the distance from the middle), on
// a 5- and a 3-beat that never line up; 0.28 to 1 of the bar's drawn height
const level = (i: number, frame: number) => {
  const d = Math.abs(i - (BARS.length - 1) / 2);
  const v = (0.5 + 0.5 * cyc(frame, 5, -0.55 * d + i * 0.9)) * (0.62 + 0.38 * cyc(frame, 3, 1.3 * i));
  return 0.28 + 0.72 * v;
};
// the hover, canvas pixels up from where V10-A drew it: 0 at frame 0, two lifts a loop
const hover = (frame: number) => 16 * (1 - Math.cos(2 * Math.PI * 2 * tau(frame))) / 2;

const drawFor = (theme: Theme) => (ctx: Ctx, frame: number, env: Env) => {
  T = theme;
  const g = new Gfx(ctx, env, frame, MARKER);
  g.push(-PLACE.o[0] * PLACE.k, -PLACE.o[1] * PLACE.k, PLACE.k);
  const lift = hover(frame);
  // the phone's points, raised by the hover; the shadow is computed without it
  const up = (p: P): P => [p[0], p[1] - lift];
  const at = (x: number, y: number) => up(mm(x, y)), atPts = (pts: P[]) => mmPts(pts).map(up);
  const body = rrect(0, 0, MM.w, MM.h, MM.r, 12);
  const top = atPts(body), dropped = (k: number) => body.map(([x, y]) => { const p = at(x, y); return [p[0], p[1] + drop(x, y) * k] as P; });
  const bottom = dropped(1);

  // the cast shadow on the ground: one flat, hard-edged tone down and to the right of the slab,
  // where the slab would rest: it does not rise with the hover
  g.group("plain", () => fillShape(g, body.map(([x, y]) => { const p = mm(x, y); return [p[0] + 46, p[1] + drop(x, y) + 40] as P; }), T.groundShadow, 1));

  g.group("plain", () => {
    // the slab: slices from the bottom face up to the top face, the left side lit
    for (let k = 0; k <= 14; k++) fillShape(g, dropped(1 - k / 14), T.titanLit);
    // the bottom end faces away from the light: its own darker flat tone
    const endIdx = body.map((p, i) => [p, i] as [P, number]).filter(([p]) => p[1] > MM.h - MM.r * 0.55).map(([, i]) => i);
    const endTop = endIdx.map((i) => top[i]), endBot = endIdx.map((i) => bottom[i]);
    fillShape(g, [...endTop, ...[...endBot].reverse()], T.titanDark);
    // a highlight stroke along the lit side, just under the glass
    const rim = dropped(0.3).filter((_, i) => body[i][0] < MM.r && body[i][1] < MM.h - MM.r);
    stroke(g, rim, 3.2, 3, T.rim, 0.4, 0.9);
    // side buttons on the left side: Action button, volume up, volume down (from the top end)
    [[22, 28], [34, 46], [50, 62]].forEach(([y0, y1], k) => {
      const a = at(0, y0), b = at(0, y1), da = drop(0, y0) * 0.5, db = drop(0, y1) * 0.5;
      const btn = sm([[a[0] + 2, a[1] + da - 8], [b[0] + 2, b[1] + db - 8], [b[0] - 9, b[1] + db + 7], [a[0] - 9, a[1] + da + 7]], 2);
      fillShape(g, btn, T.titan); outline(g, btn, 3.6, 60 + k);
    });
    // the bottom end: USB-C between two speaker grilles
    const edge = (x: number): P => { const p = at(x, MM.h); return [p[0], p[1] + drop(x, MM.h) * 0.52]; };
    const pr = drop(39, MM.h) * 0.16;
    fillShape(g, sm([[edge(33)[0], edge(33)[1] - pr], [edge(45)[0], edge(45)[1] - pr], [edge(45)[0], edge(45)[1] + pr], [edge(33)[0], edge(33)[1] + pr]], 3), T.ink);
    [[16, 29], [49, 62]].forEach(([x0, x1]) => { for (let x = x0; x <= x1; x += 2.6) fillShape(g, circle(edge(x), 3.4, 8), T.ink); });
    // heavy contour: the slab's silhouette, the vertical edge at its leftmost point
    outline(g, bottom, 9, 4);
    const left = top.reduce((m, p, i) => (p[0] < top[m][0] ? i : m), 0);
    stroke(g, [top[left], bottom[left]], 8, 5);

    // the top face: the black glass rim, then the display
    fillShape(g, top, T.ink);
    const screen = atPts(rrect(2.6, 2.6, MM.w - 2.6, MM.h - 2.6, MM.r - 2.4, 12));
    fillShape(g, screen, T.screen);
    clipped(g, screen, () => {
      // the keyboard panel, recording, and the hard shadow edge along its top
      fillShape(g, atPts(rrect(0, PANEL_TOP, MM.w, MM.h + 20, 8, 10)), T.panel);
      fillShape(g, atPts([[0, PANEL_TOP - 1.4], [MM.w, PANEL_TOP - 1.4], [MM.w, PANEL_TOP + 0.2], [0, PANEL_TOP + 0.2]]), T.panelEdge);
      // the comic glass shine: two hard slanted stripes across the empty app area
      fillShape(g, atPts([[0, 20], [MM.w * 0.62, 0], [MM.w * 0.78, 0], [0, 26]].map(([x, y]) => [x, y + 30] as P)), T.shine);
      fillShape(g, atPts([[0, 30], [MM.w * 0.8, 0], [MM.w * 0.86, 0], [0, 32.5]].map(([x, y]) => [x, y + 30] as P)), T.shine);
      // x and check pills
      const pill = (x0: number, x1: number, n: number) => { const sh = atPts(rrect(x0, 101.5, x1, 110.5, 4.5, 8)); fillShape(g, sh, T.pill); outline(g, sh, 3.2, n); };
      pill(6, 21, 70); pill(57, 72, 71);
      stroke(g, atPts([[11.6, 104.2], [15.4, 107.8]]), 3.4, 72, T.pillGlyph, 0.2); stroke(g, atPts([[15.4, 104.2], [11.6, 107.8]]), 3.4, 73, T.pillGlyph, 0.2);
      stroke(g, atPts([[62.2, 106.3], [64, 108.2], [67.2, 103.8]]), 4, 74, "#22C55E", 0.2);
      // the BrandWaveform: flat bars, blue through the centre 40 %, grey toward the edges, each
      // with a hard darker lower half and a thin ink edge; heights follow the voice
      const n = BARS.length, pitch = (WAVE.x1 - WAVE.x0) / (n - 1);
      BARS.forEach((v0, i) => {
        const v = v0 * level(i, frame);
        const cx = WAVE.x0 + i * pitch, d = Math.abs(i / (n - 1) - 0.5) * 2, hh = (4 + v * (WAVE.h - 4)) / 2;
        const blue = d < 0.42, lit = blue ? HIGH : d < 0.75 ? T.barLit[0] : T.barLit[1], shade = blue ? DEEP : d < 0.75 ? T.barShade[0] : T.barShade[1];
        const bar = atPts(rrect(cx - WAVE.w / 2, WAVE.cy - hh, cx + WAVE.w / 2, WAVE.cy + hh, WAVE.w / 2, 5));
        fillShape(g, bar, shade);
        clipped(g, bar, () => fillShape(g, atPts([[cx - 2, WAVE.cy - hh - 1], [cx + 2, WAVE.cy - hh - 1], [cx + 2, WAVE.cy + hh * 0.25], [cx - 2, WAVE.cy + hh * 0.25]]), lit));
        outline(g, bar, 2.6, 100 + i);
      });
      // globe and mic at the bottom corners
      const ring = (c: P, r: number) => atPts(Array.from({ length: 24 }, (_, i) => [c[0] + Math.cos((i / 24) * Math.PI * 2) * r, c[1] + Math.sin((i / 24) * Math.PI * 2) * r] as P));
      g.pen(ring([10.5, 152.5], 2.8), { w: 2.6, color: T.glyph, seed: 75, closed: true, wobble: 0.3, boil: 0, taper: 0.2, opacity: 1, retrace: false });
      stroke(g, atPts([[7.7, 152.5], [13.3, 152.5]]), 2.2, 76, T.glyph); stroke(g, atPts([[10.5, 149.7], [9.3, 152.5], [10.5, 155.3]]), 2.2, 77, T.glyph); stroke(g, atPts([[10.5, 149.7], [11.7, 152.5], [10.5, 155.3]]), 2.2, 78, T.glyph);
      const mic = atPts(rrect(66.3, 149, 69.7, 154.4, 1.7, 6)); fillShape(g, mic, T.pill); outline(g, mic, 2.6, 79, T.glyph);
      stroke(g, atPts([[65, 152.6], [65.6, 155.4], [68, 156.4], [70.4, 155.4], [71, 152.6]]), 2.4, 80, T.glyph); stroke(g, atPts([[68, 156.4], [68, 158]]), 2.4, 81, T.glyph);
    });
    // the Dynamic Island
    fillShape(g, atPts(rrect(MM.w / 2 - 10.5, 4.6, MM.w / 2 + 10.5, 10.6, 3, 8)), T.ink);
    // heavy contour around the glass, the edge where the frame meets the side
    outline(g, top, 9, 6);
  });
};

const film = (theme: Theme, title: string): Film => ({
  meta: { title: `Dictus onboarding intro C · the keyboard · ${theme.name}`, W: FRAME.w, H: FRAME.h, fps: FPS, bpm: BPM, durationFrames: LOOP },
  assets: { images: {} },
  shots: [{ id: title, start: 0, end: LOOP, draw: drawFor(theme) }],
});
export const introKeyboardLight = film(THEMES.light, "introKeyboardLight");
export const introKeyboardDark = film(THEMES.dark, "introKeyboardDark");
