import { Gfx, tube, type Ctx, type Env, type Medium, type P } from "./core";
import type { Film } from "./film";
import { clipped, fillShape, smooth } from "./gallery";
import { drop, mm, MM, mmPts, rrect, WAVE } from "./phoneGeometry";
import { drawDigits, drawScribble, scribbleLine } from "./scribble";
import { BPM, FPS, FRAME, LOOP_C, loop, place, THEMES, type Theme } from "./theme";

// ONBOARDING INTRO, SCENE C · "the keyboard in a note" (issue #667, headline "Dans votre
// clavier."). The giant drawn iPhone of the App Store hero V10-A (branch chore/643-hero-a), its
// screen now a note above the Dictus keyboard, and one whole dictation on it, in nine seconds:
//
//   1. her hand, at a real hand's size, types a few keys (each key flashes as it is hit); scribbled letters appear;
//   2. the index taps the blue mic in the keyboard's top bar;
//   3. RECORDING: the bars follow the voice, the timer runs, the x and check pills are up;
//   4. it taps the check;
//   5. TRANSCRIBING: the pills are gone, the bars stop following the voice and a sine runs
//      across them, a bright band riding its crest;
//   6. a scribbled paragraph lands in the note and the keyboard returns to its keys; the note
//      clears, and the loop starts again on an empty note.
//
// The states follow the real keyboard (DictusKeyboard/Views/KeyboardWaveformView.swift,
// resolvedAnimation(for:): recording draws `.micLevels`, transcribing `.sweep`, whose bars are
// processingEnergy = 0.2 + 0.25 (sin(2 pi (i / (n - 1) + phase)) + 1); RecordingOverlay.swift: the
// pills and the timer while recording, an empty bar of the same height while transcribing, so the
// waveform never moves). The layout is read off the captures (assets/appstore/captures/en-GB/
// 04-keyboard-azerty-fr.png at rest, fr-FR/01-recording-reminders.png recording), in the phone's
// millimetres. No key carries a letter and no label is written: the keys are blank caps with their
// icons (shift, delete, emoji, return, globe, mic), the suggestions, the caption and the note's
// text are scribbles. The timer's digits are the one exception: numerals, the same in every
// language the app ships.
//
// Marker comic, like the figure (V10-A): every face a flat fill, one hard-edged shadow tone per
// face, a heavy contour round the slab and along the glass.

// The frame shows V10-A's phone box (x 54..1268, y 1347..2728 of the strip), laid out as the #649
// mock-up does (designs/onboarding-649-assets/intro-keyboard.png): 300 pt wide, at 15 / 83 pt.
const PLACE = place([54, 1347], 1214, [15, 83], 300);
const LP = loop(LOOP_C);

const MARKER: Medium = { nib: 2.4, taper: 0.55, pressure: 0.6, retrace: false, wobble: 0.6, rough: 0.3 };
const LIGHT: P = [-0.6, -0.8];
const ACCENT = "#3D7EFF", DEEP = "#2563EB", HIGH = "#6BA3FF", WHITE = "#FFFFFF", GREEN = "#22C55E";
const SKIN = "#F1C09C", SKIN_SH = "#D59674";
const sm = (pts: P[], per = 6) => smooth(pts, true, per);
const clamp = (v: number, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const ease = (t: number) => { const x = clamp(t); return x * x * (3 - 2 * x); };
const lerp = (a: P, b: P, t: number): P => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];

let T: Theme = THEMES.light;
const outline = (g: Gfx, s: P[], w: number, seed: number, color = T.line) =>
  g.pen(s, { w, color, seed, closed: true, wobble: 0.5, boil: 0, taper: 0.3, opacity: 1, retrace: false });
const stroke = (g: Gfx, pts: P[], w: number, seed: number, color = T.line, taper = 0.9, op = 1) =>
  g.pen(smooth(pts, false, 8), { w, color, seed, closed: false, wobble: 0.5, boil: 0, taper, opacity: op, retrace: false });
const cel = (g: Gfx, s: P[], lit: string, shade: string, k = 18) => {
  fillShape(g, s, shade);
  clipped(g, s, () => fillShape(g, s.map(([x, y]) => [x + LIGHT[0] * k, y + LIGHT[1] * k] as P), lit));
};

// ---------------------------------------------------------------- the story, frame by frame
// ONE cue table holds every frame number of the scene; everything below reads it. Events sit on
// the engine's 5-frame grid (checked at load).
const CUE = {
  taps: [20, 30, 40, 50],    // the four keys, and the moment each one is hit
  mic: 75,                   // the mic tapped: recording starts
  check: 195,                // the check tapped: transcribing starts
  land: 240,                 // the text lands, the keys come back
  clear: [255, 270] as P,    // the note fades out for the next loop
};
// the finger's way through the scene: [frame, where (a key name, or "away"), pressed]
type Spot = "away" | "k0" | "k1" | "k2" | "k3" | "mic" | "check";
const FINGER: [number, Spot, boolean][] = [
  [0, "away", false], [12, "k0", false], [20, "k0", true], [24, "k0", false], [30, "k1", true], [34, "k1", false],
  [40, "k2", true], [44, "k2", false], [50, "k3", true], [54, "k3", false], [70, "mic", false], [75, "mic", true],
  [80, "mic", false], [105, "away", false], [170, "away", false], [190, "check", false], [195, "check", true],
  [200, "check", false], [225, "away", false], [270, "away", false],
];
const onGrid = (f: number) => f % 5 === 0;
const problems = [...CUE.taps, CUE.mic, CUE.check, CUE.land, ...CUE.clear].filter((f) => !onGrid(f) || f > LOOP_C);
if (problems.length) throw new Error(`introKeyboard cue table off the 5-frame grid or past the loop: ${problems.join(", ")}`);
type Mode = "keys" | "recording" | "transcribing";
const modeAt = (f: number): Mode => (f >= CUE.mic && f < CUE.check ? "recording" : f >= CUE.check && f < CUE.land ? "transcribing" : "keys");

// ---------------------------------------------------------------- the keyboard, in phone mm
// read off the at-rest capture (04-keyboard-azerty-fr.png): the panel from y 100, the top bar
// centred at 108, four rows of keys, the globe and mic row at 156
const PANEL_TOP = 100, BAR_Y = 108, ROWS = [116.8, 126.2, 135.7, 145.4], KEY_H = 7.4, BOTTOM_Y = 155.4;
const PITCH = 7.28, KEY_W = 6.2, X0 = 6.25;
type Key = { x0: number; x1: number; y: number; icon?: "shift" | "delete" | "emoji" | "return" };
const KEYS: Key[] = [
  ...Array.from({ length: 10 }, (_, i) => ({ x0: X0 + i * PITCH - KEY_W / 2, x1: X0 + i * PITCH + KEY_W / 2, y: ROWS[0] })),
  ...Array.from({ length: 10 }, (_, i) => ({ x0: X0 + i * PITCH - KEY_W / 2, x1: X0 + i * PITCH + KEY_W / 2, y: ROWS[1] })),
  { x0: 3.15, x1: 12.4, y: ROWS[2], icon: "shift" },
  ...Array.from({ length: 7 }, (_, i) => ({ x0: 16.4 + i * PITCH - KEY_W / 2, x1: 16.4 + i * PITCH + KEY_W / 2, y: ROWS[2] })),
  { x0: 65.1, x1: 74.9, y: ROWS[2], icon: "delete" },
  { x0: 3.15, x1: 12.4, y: ROWS[3] }, { x0: 13.9, x1: 23.2, y: ROWS[3], icon: "emoji" },
  { x0: 24.7, x1: 56.6, y: ROWS[3] }, { x0: 58.1, x1: 74.9, y: ROWS[3], icon: "return" },
];
// the four keys typed, by index into KEYS (a short word across the top two rows)
const TYPED = [12, 2, 15, 7];
const MIC_PILL = { x0: 62.4, x1: 73.6, y0: 104.6, y1: 111.4 };
// the recording overlay (01-recording-reminders.png): the pills in the top bar, the waveform, the
// timer and its caption; the waveform keeps V10-A's 17 wider bars, which read at this size
const PILL_X: P = [3.4, 14.6], PILL_CHECK: P = [62.4, 73.6], PILL_Y: P = [104.6, 111.4];
const WAVE_CY = 125.6, WAVE_H = 21, TIMER_Y = 138.6, TIMER_H = 3.6, CAPTION_Y = 146;
const BARS = [0.55, 0.8, 0.86, 0.5, 0.3, 0.34, 0.62, 0.56, 0.36, 0.28, 0.66, 0.9, 1, 0.84, 0.7, 0.92, 0.8];
const spotMM = (s: Spot): P => {
  if (s === "mic") return [(MIC_PILL.x0 + MIC_PILL.x1) / 2, BAR_Y];
  if (s === "check") return [(PILL_CHECK[0] + PILL_CHECK[1]) / 2, (PILL_Y[0] + PILL_Y[1]) / 2];
  const k = KEYS[TYPED[Number(s.slice(1))]];
  return [(k.x0 + k.x1) / 2, k.y];
};

// ---------------------------------------------------------------- the voice the bars follow
// a speech-like level per bar: syllables (the 7-beat) under phrases (the 2-beat), never silent
// for long, the centre a little louder; the same function a microphone would never give twice,
// and a pure one of the frame
const micLevel = (i: number, f: number) => {
  const n = BARS.length, d = Math.abs(i - (n - 1) / 2) / ((n - 1) / 2);
  const syll = 0.5 + 0.5 * LP.cyc(f, 37, i * 1.7), phrase = 0.55 + 0.45 * LP.cyc(f, 9, 0.4 + i * 0.3);
  return clamp((0.18 + 0.82 * syll * phrase) * (1 - 0.35 * d) + 0.12 * LP.cyc(f, 61, i * 2.3));
};
// the transcription sweep (processingEnergy), its phase advancing from the check tap
const sweepLevel = (i: number, f: number) => {
  const phase = (f - CUE.check) / 36, x = i / (BARS.length - 1);
  return { level: 0.2 + 0.25 * (Math.sin(2 * Math.PI * (x + phase)) + 1), crest: Math.max(0, Math.sin(2 * Math.PI * (x + phase))) ** 3 };
};

// ---------------------------------------------------------------- the note's text
// the typed word: the first word of a scribbled line, and where it ends (for the caret)
const WORD = scribbleLine(15, 2.6, 801).slice(0, 1), WORD_END = Math.max(...WORD[0].map(([x]) => x));
const PARAGRAPH = [scribbleLine(46, 2.6, 811), scribbleLine(66, 2.6, 823), scribbleLine(62, 2.6, 835), scribbleLine(38, 2.6, 847)];
const DATE = scribbleLine(18, 1.8, 861);
const CAPTION_REC = scribbleLine(13, 1.6, 871), CAPTION_TRANS = scribbleLine(17, 1.6, 873);
const SUGGEST = [scribbleLine(12, 2, 881), scribbleLine(11, 2, 883), scribbleLine(10, 2, 885)];
const NOTE = { x: 7, line0: 32, lead: 7 };

// ---------------------------------------------------------------- the hand
// Her right hand at the size of a real hand next to this phone: about 19 cm from fingertip to
// wrist against the phone's 16, the index about one and a half keys wide. At that size it comes
// up from the frame's bottom edge, cut by it, and covers the keyboard below whatever it taps;
// the target itself is always at the tip of the index, so it is in plain sight at the moment of
// the tap.
//
// It is built the way the woman's hands are (heroWalk15.ts `fist` and `phoneHand`): a back of
// the hand, fingers as tubes with V15-B's skin, shade and contour, the light from the upper left.
// What a hand has and a blob does not: an index in three phalanges with the creases of its two
// joints and a nail; the knuckles of the four fingers along the back; the middle, ring and little
// fingers folded, each a proximal phalanx ending in its bent middle joint; a thumb in two
// segments with its nail; the wrist; her blue sleeve. Proportions from the hand chapters of
// Andrew Loomis' "Drawing the Head and Hands" (the palm as long as the middle finger, the index
// reaching the middle finger's last joint), in millimetres.
//
// The hand's frame, in millimetres: `a` runs from the index's fingertip back toward the wrist,
// `b` across it, positive on the thumb's side (image left: a right hand, palm down).
const HAND_DIR: P = [0.38, 0.925];          // from the fingertip toward the wrist, on the page
// a finger tapping glass comes down at about 45 degrees, so seen from above the hand is
// foreshortened along its length: that is what brings its knuckles and thumb into the frame
const FORESHORTEN = 0.68;
const PX_PER_MM = 10.6;                     // the phone's own scale across the keyboard
const AWAY_DROP: P = [260, 1500];           // away: the hand slid down, out of the frame
const fingerAt = (f: number): { tip: P; press: number; lift: number } => {
  let a = FINGER[0], b = FINGER[FINGER.length - 1];
  for (let i = 0; i < FINGER.length - 1; i++) if (f >= FINGER[i][0] && f < FINGER[i + 1][0]) { a = FINGER[i]; b = FINGER[i + 1]; break; }
  // a spot on the glass; "away" is below the last spot the hand left or the next it goes to
  const target = (s: Spot, other: Spot): P => mm(...spotMM(s === "away" ? (other === "away" ? "k0" : other) : s));
  const where = (s: Spot, pressed: boolean, other: Spot): P => { const p = target(s, other); return s === "away" ? [p[0] + AWAY_DROP[0], p[1] + AWAY_DROP[1]] : pressed ? p : [p[0] + 22, p[1] + 48]; };
  const t = ease((f - a[0]) / Math.max(1, b[0] - a[0]));
  const press = (a[2] ? 1 - t : 0) + (b[2] ? t : 0);
  return { tip: lerp(where(a[1], a[2], b[1]), where(b[1], b[2], a[1]), t), press, lift: 1 - press };
};
type Seg = { pts: P[]; r0: number; r1: number };
// the index: tip, end joint, middle joint, knuckle (mm), the finger a little thicker at its root
const INDEX: Seg = { pts: [[0, 0], [22, 0.6], [47, 1.6], [92, 3.2]], r0: 7.2, r1: 9 };
const INDEX_NAIL: Seg = { pts: [[2.5, 0], [12, 0.2]], r0: 4.6, r1: 5 };
// the folded fingers, little to middle: from the knuckle forward to the bent middle joint
const FOLDED: Seg[] = [
  { pts: [[112, -50], [100, -52], [94, -50]], r0: 8, r1: 8.6 },
  { pts: [[103, -35], [88, -37], [82, -35]], r0: 9, r1: 9.6 },
  { pts: [[96, -18], [80, -20], [74, -18]], r0: 9.4, r1: 10 },
];
// the thumb, from its root at the wrist to its tip, lying along the folded middle finger
const THUMB: Seg = { pts: [[160, 30], [122, 38], [96, 34], [78, 24]], r0: 11, r1: 8 };
const THUMB_NAIL: Seg = { pts: [[81, 26], [90, 31]], r0: 4, r1: 4.4 };
// the back of the hand: the index knuckle, down the thumb's web to the wrist, across the wrist,
// up the little finger's edge, and back along the knuckles
const BACK: P[] = [[90, 12], [112, 22], [136, 30], [168, 38], [196, 34], [200, -42], [168, -60], [130, -62], [112, -58], [104, -46], [98, -30], [92, -12]];
const KNUCKLES: P[] = [[93, 3], [96, -17], [101, -34], [109, -49]];
const SLEEVE: P[] = [[192, 40], [420, 56], [420, -78], [196, -48]];
const drawHand = (g: Gfx, tip: P, press: number, lift: number) => {
  const s = PX_PER_MM * (1 + 0.05 * lift);   // a lifted hand is a little nearer the eye
  const [dx, dy] = HAND_DIR, nx = -dy, ny = dx;
  const H = ([a0, b]: P): P => { const a = a0 * FORESHORTEN; return [tip[0] + (dx * a + nx * b) * s, tip[1] + (dy * a + ny * b) * s]; };
  const seg = (q: Seg) => tube(q.pts.map(H), q.r0 * s, q.r1 * s, true);
  const skin = (shape: P[], w: number, seed: number, k = 6) => { cel(g, shape, SKIN, SKIN_SH, k); outline(g, shape, w, seed); };
  // a nail: one smooth pale shape, a thin contour and a glint, no cel (at this size a cel's
  // offset reads as a dent)
  const nailOf = (shape: P[], seed: number) => {
    const n = sm(shape, 4);
    fillShape(g, n, "#F7D6C2"); g.pen(n, { w: 2.6, color: SKIN_SH, seed, closed: true, wobble: 0.15, boil: 0, taper: 0.3, opacity: 1, retrace: false });
  };
  // its shadow on the glass, closer as the finger presses
  const sh = 26 - 18 * press, shadow = (pts: P[]) => pts.map(([x, y]) => [x + sh, y + sh * 0.6] as P);
  [seg(INDEX), sm(BACK.map(H)), seg(THUMB)].forEach((p) => fillShape(g, shadow(p), T.shadow, 0.1 + 0.1 * press));
  // the sleeve at the wrist, its cuff
  const sleeve = SLEEVE.map(H);
  cel(g, sleeve, ACCENT, DEEP, 12); outline(g, sleeve, 6, 910);
  stroke(g, [H([206, 42]), H([210, -50])], 5, 911, HIGH, 0.3, 0.9);
  // the back of the hand: its knuckles, the faint lines of its tendons toward the wrist
  const back = sm(BACK.map(H));
  skin(back, 6, 930, 12);
  KNUCKLES.slice(1).forEach(([a, b], k) => stroke(g, [H([a + 4, b + 5]), H([a + 1, b]), H([a + 4, b - 5])], 3, 931 + k, SKIN_SH, 0.6, 0.9));
  KNUCKLES.forEach(([a, b], k) => stroke(g, [H([a + 14, b * 0.95]), H([a + 52, b * 0.8 + 4])], 2.4, 935 + k, SKIN_SH, 0.9, 0.45));
  // the folded fingers, each with the crease of its bent joint
  FOLDED.forEach((q, k) => { const f = seg(q); cel(g, f, SKIN, SKIN_SH, 3); outline(g, f, 5, 920 + k); const [a, b] = q.pts[2]; stroke(g, [H([a + 3, b + 6]), H([a + 1, b]), H([a + 3, b - 6])], 2.6, 925 + k, SKIN_SH, 0.6, 0.9); });
  // the thumb and its nail
  skin(seg(THUMB), 5.5, 945, 6);
  nailOf(seg(THUMB_NAIL), 946);
  stroke(g, [H([100, 40]), H([96, 34]), H([100, 28])], 2.6, 947, SKIN_SH, 0.6, 0.9);
  // the index, stretched out to the glass: its nail and the creases of its two joints
  skin(seg(INDEX), 6, 940, 6);
  nailOf(seg(INDEX_NAIL), 941);
  ([[22, 0.6], [47, 1.6]] as P[]).forEach(([a, b], k) => { stroke(g, [H([a, b + 6]), H([a - 1.5, b]), H([a, b - 6])], 3, 942 + k, T.line, 0.7, 0.7); stroke(g, [H([a + 3, b + 4]), H([a + 2, b - 4])], 2.2, 944 + k, SKIN_SH, 0.7, 0.8); });
  stroke(g, [H([90, 9]), H([93, 3]), H([90, -3])], 3, 948, SKIN_SH, 0.6, 0.9);
};

// ---------------------------------------------------------------- the picture
const drawFor = (theme: Theme) => (ctx: Ctx, frame: number, env: Env) => {
  T = theme;
  const g = new Gfx(ctx, env, frame, MARKER);
  g.push(-PLACE.o[0] * PLACE.k, -PLACE.o[1] * PLACE.k, PLACE.k);
  const mode = modeAt(frame), finger = fingerAt(frame);
  const body = rrect(0, 0, MM.w, MM.h, MM.r, 12);
  const top = mmPts(body), dropped = (k: number) => body.map(([x, y]) => { const p = mm(x, y); return [p[0], p[1] + drop(x, y) * k] as P; });
  const bottom = dropped(1);
  const at = (pts: P[]) => mmPts(pts), local = (x0: number, y0: number) => ([x, y]: P): P => mm(x0 + x, y0 + y);

  // the cast shadow on the ground: one flat, hard-edged tone down and to the right of the slab
  g.group("plain", () => fillShape(g, bottom.map(([x, y]) => [x + 46, y + 40] as P), T.groundShadow, 1));

  g.group("plain", () => {
    // ---- the slab (V10-A's)
    for (let k = 0; k <= 14; k++) fillShape(g, dropped(1 - k / 14), T.titanLit);
    const endIdx = body.map((p, i) => [p, i] as [P, number]).filter(([p]) => p[1] > MM.h - MM.r * 0.55).map(([, i]) => i);
    fillShape(g, [...endIdx.map((i) => top[i]), ...endIdx.map((i) => bottom[i]).reverse()], T.titanDark);
    stroke(g, dropped(0.3).filter((_, i) => body[i][0] < MM.r && body[i][1] < MM.h - MM.r), 3.2, 3, T.rim, 0.4, 0.9);
    [[22, 28], [34, 46], [50, 62]].forEach(([y0, y1], k) => {
      const a = mm(0, y0), b = mm(0, y1), da = drop(0, y0) * 0.5, db = drop(0, y1) * 0.5;
      const btn = sm([[a[0] + 2, a[1] + da - 8], [b[0] + 2, b[1] + db - 8], [b[0] - 9, b[1] + db + 7], [a[0] - 9, a[1] + da + 7]], 2);
      fillShape(g, btn, T.titan); outline(g, btn, 3.6, 60 + k);
    });
    const edge = (x: number): P => { const p = mm(x, MM.h); return [p[0], p[1] + drop(x, MM.h) * 0.52]; };
    const pr = drop(39, MM.h) * 0.16;
    fillShape(g, sm([[edge(33)[0], edge(33)[1] - pr], [edge(45)[0], edge(45)[1] - pr], [edge(45)[0], edge(45)[1] + pr], [edge(33)[0], edge(33)[1] + pr]], 3), T.ink);
    [[16, 29], [49, 62]].forEach(([x0, x1]) => { for (let x = x0; x <= x1; x += 2.6) fillShape(g, Array.from({ length: 8 }, (_, i) => [edge(x)[0] + Math.cos(i * 0.785) * 3.4, edge(x)[1] + Math.sin(i * 0.785) * 3.4] as P), T.ink); });
    outline(g, bottom, 9, 4);
    const left = top.reduce((m, p, i) => (p[0] < top[m][0] ? i : m), 0);
    stroke(g, [top[left], bottom[left]], 8, 5);
    fillShape(g, top, T.ink);
    const screen = at(rrect(2.6, 2.6, MM.w - 2.6, MM.h - 2.6, MM.r - 2.4, 12));
    fillShape(g, screen, T.screen);

    clipped(g, screen, () => {
      // ---- the note (Apple Notes-like): back chevron, the date in grey, the text, the caret
      stroke(g, at([[8.6, 12.2], [6.4, 14.6], [8.6, 17]]), 3.6, 700, T.notesAccent, 0.2);
      drawScribble(g, DATE, 1, local(30, 23), { w: 2, color: T.screenFaint, seed: 702 });
      const clearK = 1 - ease((frame - CUE.clear[0]) / (CUE.clear[1] - CUE.clear[0]));
      const typed = CUE.taps.reduce((n, t) => n + ease((frame - t) / 2), 0) / CUE.taps.length;
      const wordLen = WORD_END * typed;
      if (clearK > 0) {
        drawScribble(g, WORD, typed, local(NOTE.x, NOTE.line0), { w: 2.8, color: T.screenInk, seed: 710, opacity: clearK });
        // the paragraph lands line after line, fast, the way inserted text appears
        PARAGRAPH.forEach((words, i) => {
          const p = ease((frame - CUE.land - i * 3) / 9), x0 = i === 0 ? NOTE.x + 18 : NOTE.x;
          drawScribble(g, words, p, local(x0, NOTE.line0 + i * NOTE.lead), { w: 2.8, color: T.screenInk, seed: 720 + i * 11, opacity: clearK });
        });
      }
      // the caret: after the typed word, then after the paragraph; it blinks nine times a loop
      const landed = frame >= CUE.land + 12 && frame < CUE.clear[0];
      const caret: P = landed ? [NOTE.x + 39.5, NOTE.line0 + 3 * NOTE.lead] : frame >= CUE.clear[0] ? [NOTE.x + 1.2, NOTE.line0] : [NOTE.x + wordLen + 1.2, NOTE.line0];
      if (Math.floor(frame / 15) % 2 === 0 || mode !== "keys") stroke(g, at([[caret[0], caret[1] + 0.8], [caret[0], caret[1] - 4.4]]), 2.6, 705, T.notesAccent, 0.1);
      // the comic glass shine across the empty part of the note
      fillShape(g, at([[0, 70], [MM.w * 0.62, 50], [MM.w * 0.78, 50], [0, 76]]), T.shine, 0.6);

      // ---- the keyboard panel and its hard shadow edge
      fillShape(g, at(rrect(0, PANEL_TOP, MM.w, MM.h + 20, 8, 10)), T.panel);
      fillShape(g, at([[0, PANEL_TOP - 1.4], [MM.w, PANEL_TOP - 1.4], [MM.w, PANEL_TOP + 0.2], [0, PANEL_TOP + 0.2]]), T.panelEdge);
      const pill = (x: P, n: number, glyph: () => void) => { const sh = at(rrect(x[0], PILL_Y[0], x[1], PILL_Y[1], 3.4, 8)); fillShape(g, sh, T.pill); outline(g, sh, 3.2, n); glyph(); };
      if (mode === "keys") {
        // the top bar: three suggestions (scribbles) between thin dividers, the blue mic pill
        SUGGEST.forEach((w, i) => drawScribble(g, w, 1, local(5 + i * 19.5, BAR_Y + 1.2), { w: 2.2, color: T.screenInk, seed: 730 + i, opacity: 0.75 }));
        [21, 40.5].forEach((x, i) => stroke(g, at([[x, BAR_Y - 2.6], [x, BAR_Y + 2.6]]), 2, 735 + i, T.screenFaint, 0.2));
        const hit = clamp(1 - Math.abs(frame - CUE.mic + 2) / 4);
        const mic = at(rrect(MIC_PILL.x0, MIC_PILL.y0, MIC_PILL.x1, MIC_PILL.y1, 3.4, 8));
        outline(g, at(rrect(MIC_PILL.x0 - 0.9, MIC_PILL.y0 - 0.9, MIC_PILL.x1 + 0.9, MIC_PILL.y1 + 0.9, 4.2, 8)), 4, 739, HIGH);
        fillShape(g, mic, hit > 0 ? HIGH : ACCENT); outline(g, mic, 3, 740);
        const mc: P = [(MIC_PILL.x0 + MIC_PILL.x1) / 2, BAR_Y];
        const cap = at(rrect(mc[0] - 0.9, mc[1] - 2.4, mc[0] + 0.9, mc[1] + 0.6, 0.9, 5)); fillShape(g, cap, WHITE);
        stroke(g, at([[mc[0] - 1.7, mc[1] - 0.4], [mc[0] - 1.4, mc[1] + 1.2], [mc[0], mc[1] + 1.8], [mc[0] + 1.4, mc[1] + 1.2], [mc[0] + 1.7, mc[1] - 0.4]]), 2.2, 741, WHITE, 0.1);
        // the keys: blank caps, a darker lip under each, flashing while hit
        KEYS.forEach((k, i) => {
          const typedAt = TYPED.indexOf(i), hitK = typedAt >= 0 ? clamp(1 - Math.abs(frame - CUE.taps[typedAt] - 1) / 4) : 0;
          const lip = at(rrect(k.x0, k.y - KEY_H / 2 + 0.6, k.x1, k.y + KEY_H / 2 + 0.6, 1.4, 4)), cap = at(rrect(k.x0, k.y - KEY_H / 2, k.x1, k.y + KEY_H / 2, 1.4, 4));
          fillShape(g, lip, T.keyShade); fillShape(g, cap, hitK > 0.3 ? T.keyHit : T.key);
          const c: P = [(k.x0 + k.x1) / 2, k.y], ic = (pts: P[], s: number, closed = false) => g.pen(at(pts.map(([x, y]) => [c[0] + x, c[1] + y] as P)), { w: s, color: T.glyph, seed: 760 + i, closed, wobble: 0.2, boil: 0, taper: 0.2, opacity: 0.85, retrace: false });
          if (k.icon === "shift") ic([[0, -2.4], [2.2, 0], [1, 0], [1, 2], [-1, 2], [-1, 0], [-2.2, 0]], 2.2, true);
          if (k.icon === "delete") { ic([[-3, 0], [-1.6, -2], [3, -2], [3, 2], [-1.6, 2]], 2.2, true); ic([[-0.2, -0.9], [1.6, 0.9]], 2); ic([[1.6, -0.9], [-0.2, 0.9]], 2); }
          if (k.icon === "emoji") { ic(Array.from({ length: 12 }, (_, j) => [Math.cos(j * 0.5236) * 2.3, Math.sin(j * 0.5236) * 2.3] as P), 2.2, true); ic([[-1.2, 0.6], [0, 1.4], [1.2, 0.6]], 2); }
          if (k.icon === "return") { ic([[2.6, -1.8], [2.6, 0.8], [-2.4, 0.8]], 2.2); ic([[-1.2, -0.4], [-2.4, 0.8], [-1.2, 2]], 2.2); }
        });
      } else {
        // the recording overlay: the pills while recording, an empty bar while transcribing
        if (mode === "recording") {
          const hitC = clamp(1 - Math.abs(frame - CUE.check + 2) / 4);
          pill(PILL_X, 70, () => { const c: P = [(PILL_X[0] + PILL_X[1]) / 2, (PILL_Y[0] + PILL_Y[1]) / 2]; stroke(g, at([[c[0] - 1.6, c[1] - 1.6], [c[0] + 1.6, c[1] + 1.6]]), 3.4, 72, T.pillGlyph, 0.2); stroke(g, at([[c[0] + 1.6, c[1] - 1.6], [c[0] - 1.6, c[1] + 1.6]]), 3.4, 73, T.pillGlyph, 0.2); });
          pill(PILL_CHECK, 71, () => { const c: P = [(PILL_CHECK[0] + PILL_CHECK[1]) / 2, (PILL_Y[0] + PILL_Y[1]) / 2]; stroke(g, at([[c[0] - 2, c[1] + 0.1], [c[0] - 0.4, c[1] + 1.8], [c[0] + 2.2, c[1] - 1.8]]), 4, 74, GREEN, 0.2); });
          if (hitC > 0.3) fillShape(g, at(rrect(PILL_CHECK[0], PILL_Y[0], PILL_CHECK[1], PILL_Y[1], 3.4, 8)), T.keyHit, 0.5);
          // the timer: whole seconds since the mic was tapped, and the caption under it
          const s = Math.floor((frame - CUE.mic) / FPS), text = `00:0${s}`;
          const wTimer = text.length * 0.7 * TIMER_H - 0.38 * TIMER_H;
          drawDigits(g, text, TIMER_H, local(MM.w / 2 - wTimer / 2, TIMER_Y), { w: 2.8, color: T.screenInk, seed: 780 });
        }
        drawScribble(g, mode === "recording" ? CAPTION_REC : CAPTION_TRANS, 1, local(MM.w / 2 - (mode === "recording" ? 6.5 : 8.5), CAPTION_Y), { w: 2, color: T.pillGlyph, seed: 790 });
        // the BrandWaveform: flat bars, blue through the centre 40 %, grey toward the edges, each
        // with a hard darker lower half and a thin ink edge
        const n = BARS.length, pitch = (WAVE.x1 - WAVE.x0) / (n - 1);
        // the first frames of the recording grow out of the still bars, as the meter wakes
        const wake = mode === "recording" ? ease((frame - CUE.mic) / 8) : 1;
        BARS.forEach((_, i) => {
          const sw = sweepLevel(i, frame), v = mode === "recording" ? micLevel(i, frame) * wake : sw.level;
          const cx = WAVE.x0 + i * pitch, d = Math.abs(i / (n - 1) - 0.5) * 2, hh = (1.2 + v * (WAVE_H - 1.2)) / 2;
          const blue = d < 0.42, lit = blue ? HIGH : d < 0.75 ? T.barLit[0] : T.barLit[1], shade = blue ? DEEP : d < 0.75 ? T.barShade[0] : T.barShade[1];
          const bar = at(rrect(cx - WAVE.w / 2, WAVE_CY - hh, cx + WAVE.w / 2, WAVE_CY + hh, WAVE.w / 2, 5));
          fillShape(g, bar, shade);
          clipped(g, bar, () => {
            fillShape(g, at([[cx - 2, WAVE_CY - hh - 1], [cx + 2, WAVE_CY - hh - 1], [cx + 2, WAVE_CY + hh * 0.25], [cx - 2, WAVE_CY + hh * 0.25]]), lit);
            // the sweep's bright band, riding the sine's crest
            if (mode === "transcribing" && sw.crest > 0.02) fillShape(g, bar, WHITE, 0.7 * sw.crest);
          });
          outline(g, bar, 2.6, 100 + i);
        });
      }
      // globe and mic at the bottom corners, in every state
      const ring = (c: P, r: number) => at(Array.from({ length: 24 }, (_, i) => [c[0] + Math.cos((i / 24) * Math.PI * 2) * r, c[1] + Math.sin((i / 24) * Math.PI * 2) * r] as P));
      g.pen(ring([10.5, BOTTOM_Y], 2.8), { w: 2.6, color: T.glyph, seed: 75, closed: true, wobble: 0.3, boil: 0, taper: 0.2, opacity: 1, retrace: false });
      stroke(g, at([[7.7, BOTTOM_Y], [13.3, BOTTOM_Y]]), 2.2, 76, T.glyph); stroke(g, at([[10.5, BOTTOM_Y - 2.8], [9.3, BOTTOM_Y], [10.5, BOTTOM_Y + 2.8]]), 2.2, 77, T.glyph); stroke(g, at([[10.5, BOTTOM_Y - 2.8], [11.7, BOTTOM_Y], [10.5, BOTTOM_Y + 2.8]]), 2.2, 78, T.glyph);
      const mic = at(rrect(66.3, BOTTOM_Y - 3.5, 69.7, BOTTOM_Y + 1.9, 1.7, 6)); fillShape(g, mic, T.pill); outline(g, mic, 2.6, 79, T.glyph);
      stroke(g, at([[65, BOTTOM_Y + 0.1], [65.6, BOTTOM_Y + 2.9], [68, BOTTOM_Y + 3.9], [70.4, BOTTOM_Y + 2.9], [71, BOTTOM_Y + 0.1]]), 2.4, 80, T.glyph); stroke(g, at([[68, BOTTOM_Y + 3.9], [68, BOTTOM_Y + 5.4]]), 2.4, 81, T.glyph);
    });
    // the Dynamic Island, and the heavy contour round the glass
    fillShape(g, at(rrect(MM.w / 2 - 10.5, 4.6, MM.w / 2 + 10.5, 10.6, 3, 8)), T.ink);
    outline(g, top, 9, 6);
  });

  // the hand, over everything
  g.group("plain", () => drawHand(g, finger.tip, finger.press, finger.lift));
};

const film = (theme: Theme, title: string): Film => ({
  meta: { title: `Dictus onboarding intro C · the keyboard in a note · ${theme.name}`, W: FRAME.w, H: FRAME.h, fps: FPS, bpm: BPM, durationFrames: LOOP_C },
  assets: { images: {} },
  shots: [{ id: title, start: 0, end: LOOP_C, draw: drawFor(theme) }],
});
export const introKeyboardLight = film(THEMES.light, "introKeyboardLight");
export const introKeyboardDark = film(THEMES.dark, "introKeyboardDark");
