import { Gfx, type Ctx, type Env, type Medium, type P } from "./core";
import { clearEdges } from "./edges";
import type { Film } from "./film";
import { clipped, fillShape, smooth } from "./gallery";
import { drop, mm, MM, mmPts, rrect, WAVE } from "./phoneGeometry";
import { drawDigits, drawText, textWidth } from "./handLettering";
import { BPM, FPS, FRAME, LOOP_C, loop, place, THEMES, type Theme } from "./theme";

// ONBOARDING INTRO, SCENE C · "the keyboard in a note" (issue #667, headline "Dans votre
// clavier."). The giant drawn iPhone of the App Store hero V10-A (branch chore/643-hero-a), its
// screen now a note above the Dictus keyboard, and one whole dictation on it, in 6.5 seconds.
// No hand: every tap is a touch indicator (an accent disc spreading into a fading ring where the
// finger lands), with the key's own flash.
//
//   1. two keys are typed, a short beat (each key flashes as it is hit); the letters appear;
//   2. the blue mic in the keyboard's top bar is tapped;
//   3. RECORDING: the bars follow the voice, the timer runs, the x and check pills are up;
//   4. the check is tapped;
//   5. TRANSCRIBING: the pills are gone, the bars stop following the voice and a sine runs
//      across them, a bright band riding its crest;
//   6. the dictated paragraph lands in the note and the keyboard returns to its keys; the note
//      clears, and the loop starts again on an empty note.
//
// The states follow the real keyboard (DictusKeyboard/Views/KeyboardWaveformView.swift,
// resolvedAnimation(for:): recording draws `.micLevels`, transcribing `.sweep`, whose bars are
// processingEnergy = 0.2 + 0.25 (sin(2 pi (i / (n - 1) + phase)) + 1); RecordingOverlay.swift: the
// pills and the timer while recording, an empty bar of the same height while transcribing, so the
// waveform never moves). The layout is read off the captures (assets/appstore/captures/en-GB/
// 04-keyboard-azerty-fr.png at rest, fr-FR/01-recording-reminders.png recording), in the phone's
// millimetres. The keys carry QWERTY letters and their icons (shift, delete, emoji, return,
// globe, mic); the suggestions, the captions and the note are short English, hand-lettered
// (handLettering.ts), as is the timer.
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
const sm = (pts: P[], per = 6) => smooth(pts, true, per);
const clamp = (v: number, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const ease = (t: number) => { const x = clamp(t); return x * x * (3 - 2 * x); };

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
  taps: [10, 20],            // two keys typed, a short beat, and the moment each one is hit
  mic: 35,                   // the mic tapped: recording starts
  check: 125,                // the check tapped: transcribing starts
  land: 155,                 // the text lands, the keys come back
  clear: [175, 195] as P,    // the note fades out for the next loop
};
// where each touch lands, and when: the touch indicator draws them (no hand, by Pierre's call:
// a drawn hand covered what it tapped and never looked right)
type Spot = "k0" | "k1" | "mic" | "check";
// the touch lands three frames before its cue, so the contact is seen on the mic or the check
// before the overlay swaps them away
const LEAD = 3;
const TOUCHES: [number, Spot][] = [[CUE.taps[0], "k0"], [CUE.taps[1], "k1"], [CUE.mic - LEAD, "mic"], [CUE.check - LEAD, "check"]];
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
type Key = { x0: number; x1: number; y: number; icon?: "shift" | "delete" | "emoji" | "return"; ch?: string };
const KEYS: Key[] = [
  ...[..."qwertyuiop"].map((ch, i) => ({ x0: X0 + i * PITCH - KEY_W / 2, x1: X0 + i * PITCH + KEY_W / 2, y: ROWS[0], ch })),
  ...[..."asdfghjkl"].map((ch, i) => ({ x0: X0 + (i + 0.5) * PITCH - KEY_W / 2, x1: X0 + (i + 0.5) * PITCH + KEY_W / 2, y: ROWS[1], ch })),
  { x0: 3.15, x1: 12.4, y: ROWS[2], icon: "shift" },
  ...[..."zxcvbnm"].map((ch, i) => ({ x0: 16.4 + i * PITCH - KEY_W / 2, x1: 16.4 + i * PITCH + KEY_W / 2, y: ROWS[2], ch })),
  { x0: 65.1, x1: 74.9, y: ROWS[2], icon: "delete" },
  { x0: 3.15, x1: 12.4, y: ROWS[3] }, { x0: 13.9, x1: 23.2, y: ROWS[3], icon: "emoji" },
  { x0: 24.7, x1: 56.6, y: ROWS[3] }, { x0: 58.1, x1: 74.9, y: ROWS[3], icon: "return" },
];
// the two keys typed, by index into KEYS (the letter keys run QWERTY, row by row)
const TYPED = [15, 7];   // h, then i: the note's first word is "Hi"
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
// the note's text (handLettering.ts): the word typed, the paragraph dictated after it, the title;
// the keyboard's suggestions for what was typed; the overlay's captions, as the keyboard says them
const XH = 2.2, WORD = "Hi", WORD_END = textWidth(WORD, XH);
const PARAGRAPH = ["Sam, quick reminder:", "dinner at eight tonight.", "I'll bring dessert, can", "you pick up the bread?"];
const LAST_END = textWidth(PARAGRAPH[3], XH);
const DATE = "Notes";
const CAPTION_REC = "Listening...", CAPTION_TRANS = "Transcribing...";
const SUGGEST = ["Hi", "Hey", "Hello"];
const NOTE = { x: 7, line0: 32, lead: 7 };

// ---------------------------------------------------------------- the touches
// Where a finger lands, a soft accent disc appears on the glass and spreads out as a fading ring,
// in perspective on the screen (drawn in the phone's millimetres): the touch indicator of screen
// recordings, legible on the light and the dark keyboard alike, and it never hides the target.
// It shows from two frames before the hit (the contact) to twelve after.
const TOUCH_R = 3.6;   // mm, about a fingertip's contact
const drawTouches = (g: Gfx, f: number) => {
  TOUCHES.forEach(([t, s], k) => {
    const dt = f - t;
    if (dt < -2 || dt > 12) return;
    const c = spotMM(s), grow = dt < 0 ? 0.7 + 0.15 * (dt + 2) : 1 + 1.2 * ease(dt / 12), fade = dt < 0 ? 0.6 + 0.2 * (dt + 2) : 1 - ease(dt / 12);
    const ring = (r: number) => mmPts(Array.from({ length: 32 }, (_, i) => [c[0] + Math.cos((i / 32) * Math.PI * 2) * r, c[1] + Math.sin((i / 32) * Math.PI * 2) * r] as P));
    fillShape(g, ring(TOUCH_R * grow), ACCENT, 0.34 * fade);
    g.pen(ring(TOUCH_R * grow), { w: 4, color: ACCENT, seed: 990 + k, closed: true, wobble: 0.2, boil: 0, taper: 0, opacity: 0.9 * fade, retrace: false });
  });
};

// ---------------------------------------------------------------- the picture
const drawFor = (theme: Theme) => (ctx: Ctx, frame: number, env: Env) => {
  T = theme;
  const g = new Gfx(ctx, env, frame, MARKER);
  g.push(-PLACE.o[0] * PLACE.k, -PLACE.o[1] * PLACE.k, PLACE.k);
  const mode = modeAt(frame);
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
      drawText(g, DATE, 1, local(MM.w / 2 - textWidth(DATE, 1.6) / 2, 23.5), { h: 1.6, w: 2, color: T.screenFaint, seed: 702 });
      const clearK = 1 - ease((frame - CUE.clear[0]) / (CUE.clear[1] - CUE.clear[0]));
      const typed = CUE.taps.reduce((n, t) => n + ease((frame - t) / 2), 0) / CUE.taps.length;
      const wordLen = WORD_END * typed;
      if (clearK > 0) {
        drawText(g, WORD, typed, local(NOTE.x, NOTE.line0), { h: XH, w: 2.8, color: T.screenInk, seed: 710, opacity: clearK });
        // the paragraph lands line after line, fast, the way inserted text appears
        PARAGRAPH.forEach((line, i) => {
          const p = ease((frame - CUE.land - i * 3) / 9), x0 = i === 0 ? NOTE.x + WORD_END + textWidth(" ", XH) : NOTE.x;
          drawText(g, line, p, local(x0, NOTE.line0 + i * NOTE.lead), { h: XH, w: 2.8, color: T.screenInk, seed: 720 + i * 37, opacity: clearK });
        });
      }
      // the caret: after the typed word, then after the paragraph; it blinks five times a loop
      const landed = frame >= CUE.land + 12 && frame < CUE.clear[0];
      const caret: P = landed ? [NOTE.x + LAST_END + 1, NOTE.line0 + 3 * NOTE.lead] : frame >= CUE.clear[0] ? [NOTE.x + 1.2, NOTE.line0] : [NOTE.x + wordLen + 1.2, NOTE.line0];
      if (frame % 39 < 20 || mode !== "keys") stroke(g, at([[caret[0], caret[1] + 0.8], [caret[0], caret[1] - 4.4]]), 2.6, 705, T.notesAccent, 0.1);
      // the comic glass shine across the empty part of the note
      fillShape(g, at([[0, 70], [MM.w * 0.62, 50], [MM.w * 0.78, 50], [0, 76]]), T.shine, 0.6);

      // ---- the keyboard panel and its hard shadow edge
      fillShape(g, at(rrect(0, PANEL_TOP, MM.w, MM.h + 20, 8, 10)), T.panel);
      fillShape(g, at([[0, PANEL_TOP - 1.4], [MM.w, PANEL_TOP - 1.4], [MM.w, PANEL_TOP + 0.2], [0, PANEL_TOP + 0.2]]), T.panelEdge);
      const pill = (x: P, n: number, glyph: () => void) => { const sh = at(rrect(x[0], PILL_Y[0], x[1], PILL_Y[1], 3.4, 8)); fillShape(g, sh, T.pill); outline(g, sh, 3.2, n); glyph(); };
      if (mode === "keys") {
        // the top bar: three suggestions between thin dividers, the blue mic pill
        SUGGEST.forEach((w, i) => drawText(g, w, 1, local(11 + i * 19.5 - textWidth(w, 1.8) / 2, BAR_Y + 1), { h: 1.8, w: 2.2, color: T.screenInk, seed: 730 + i * 13, opacity: 0.8 }));
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
          // a letter key's letter, hand-lettered, centred on the key
          if (k.ch) { const lw = textWidth(k.ch, 2.5) - 0.5; drawText(g, k.ch, 1, ([x, y]) => mm(c[0] - lw / 2 + x, c[1] + 1.25 + y), { h: 2.5, w: 2.4, color: T.glyph, seed: 800 + i * 3, opacity: 0.9 }); }
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
        { const cap = mode === "recording" ? CAPTION_REC : CAPTION_TRANS; drawText(g, cap, 1, local(MM.w / 2 - textWidth(cap, 1.5) / 2, CAPTION_Y + 0.6), { h: 1.5, w: 2, color: T.pillGlyph, seed: 790 }); }
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

  // the touches, over everything
  g.group("plain", () => drawTouches(g, frame));
  // a clean band round the frame, so the page colour decodes exactly at its edge (edges.ts)
  clearEdges(ctx, env);
};

const film = (theme: Theme, title: string): Film => ({
  meta: { title: `Dictus onboarding intro C · the keyboard in a note · ${theme.name}`, W: FRAME.w, H: FRAME.h, fps: FPS, bpm: BPM, durationFrames: LOOP_C },
  assets: { images: {} },
  shots: [{ id: title, start: 0, end: LOOP_C, draw: drawFor(theme) }],
});
export const introKeyboardLight = film(THEMES.light, "introKeyboardLight");
export const introKeyboardDark = film(THEMES.dark, "introKeyboardDark");
