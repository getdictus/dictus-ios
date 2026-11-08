import type { P } from "./core";

// DICTUS HERO V6 · the geometry (V5 is art/v5/heroShapes.ts) of the two style candidates (#643).
//
// One idea: a person speaking with joy, her voice leaving her mouth as one bold stream that
// lands at the bottom right and runs on as the Dictus BrandWaveform (drawn by the screenshot
// template from VOICE_END). Focal subject: the open, laughing mouth and the stream leaving it.
// Light from the upper left.
//
// Anatomy and pose, hand-placed (no ellipse heads): three-quarter view turned to the right, chin
// lifted; eyes closed in two upward arcs (laughing); open smile with the upper teeth showing; a
// small hooked nose on the turned side; the ear on the far side under the hair; hair pulled back
// into a bun; neck in a ribbed crew collar; a loose jumper. The back arm (viewer's left) is
// raised, palm open, fingers spread: the gesture. The front hand holds a phone at the chest.
// The figure is cut at the hips by the canvas.
//
// Rebuild art/hero-comic.png and art/hero-paper.png (anidoodle engine, ~/.claude/skills/anidoodle;
// same source, same pixels, md5 printed as "reproducible"):
//   node ~/.claude/skills/anidoodle/engine/tools/scaffold.mjs /tmp/art --still hero
//   cp assets/appstore/art/v5/*.ts /tmp/art/src/canvas-core/
//   for f in heroComic heroPaper; do printf 'import { %s } from "../canvas-core/%s";\nimport { mountFilm } from "./page";\nmountFilm(%s);\n' $f $f $f > /tmp/art/src/hosts/page-$f.ts; done
//   cd /tmp/art && npm install && npx playwright-core install chromium
//   node tools/still.mjs heroComic --out out/heroComic.png && node tools/still.mjs heroPaper --out out/heroPaper.png
//
// // Proportions checked against the usual figure: the head is about one seventh of a standing
// figure, so head-to-hips is about 3.3 heads; shoulders about two heads wide.

// V6: the canvas spans slides 1 AND 2 (2640 wide), so the sound strokes can travel from the mouth
// across the cut to the left edge of slide 2's recording panel (PANEL_IN, in canvas pixels).
export const W = 2640, H = 2000;
export const PANEL_IN: P = [1400, 1387];

export const C = {
  ink: "#0A1628", accent: "#3D7EFF", accentDeep: "#2563EB", high: "#6BA3FF",
  skin: "#F3C7A6", skinShade: "#DC9C7E", blush: "#EE9D86", hair: "#1B2C4A", hairLight: "#2F4C7A",
  jumper: "#3D7EFF", jumperShade: "#2563EB", collar: "#6BA3FF", phone: "#0A1628", white: "#FFFFFF",
  mouth: "#0A1628", tongue: "#E7826F", sleeveCuff: "#6BA3FF",
};

export const FACE: P[] = [[452, 372], [530, 336], [612, 348], [668, 404], [694, 472], [700, 528], [690, 586], [664, 640], [618, 684], [556, 702], [496, 690], [446, 650], [414, 590], [404, 520], [414, 446]];
export const FACE_SHADE: P[] = [[414, 446], [452, 372], [470, 420], [452, 500], [462, 590], [500, 660], [556, 702], [496, 690], [446, 650], [414, 590], [404, 520]];
export const HAIR: P[] = [[388, 640], [362, 540], [366, 430], [404, 344], [470, 284], [556, 256], [640, 270], [702, 318], [728, 386], [716, 418], [670, 392], [600, 372], [530, 382], [478, 418], [448, 482], [440, 560], [430, 640], [404, 690]];
export const BUN: P[] = [[340, 300], [380, 250], [440, 236], [488, 262], [496, 316], [462, 352], [404, 360], [356, 342]];
export const HAIR_LIGHT: P[] = [[430, 320], [500, 280], [580, 270], [540, 300], [470, 330]];
export const EAR: P[] = [[430, 530], [418, 500], [432, 486], [450, 500], [452, 540], [440, 560]];
export const EYE_L: P[] = [[530, 470], [550, 452], [574, 452], [592, 468]];
export const EYE_R: P[] = [[624, 462], [640, 446], [660, 446], [674, 460]];
export const BROW_L: P[] = [[524, 428], [552, 414], [584, 418]];
export const BROW_R: P[] = [[626, 418], [648, 408], [670, 414]];
export const NOSE: P[] = [[662, 486], [686, 530], [668, 544]];
export const MOUTH: P[] = [[586, 584], [626, 578], [672, 572], [674, 604], [658, 636], [626, 652], [598, 644], [586, 616]];
export const TEETH: P[] = [[594, 590], [668, 580], [668, 598], [598, 604]];
export const TONGUE: P[] = [[604, 640], [624, 626], [648, 628], [652, 640], [628, 650]];
export const BLUSH_L: P[] = [[516, 540], [544, 526], [568, 538], [554, 560], [524, 562]];
export const BLUSH_R: P[] = [[652, 520], [676, 512], [688, 528], [674, 546]];
// Rebuild art/hero-comic-v6.png (anidoodle engine; md5 printed as "reproducible"):
//   node ~/.claude/skills/anidoodle/engine/tools/scaffold.mjs /tmp/art --still hero
//   cp assets/appstore/art/v5/heroShapes.ts assets/appstore/art/v6/*.ts /tmp/art/src/canvas-core/
//   printf 'import { heroComic6 } from "../canvas-core/heroComic6";\nimport { mountFilm } from "./page";\nmountFilm(heroComic6);\n' > /tmp/art/src/hosts/page-heroComic6.ts
//   cd /tmp/art && npm install && npx playwright-core install chromium && node tools/still.mjs heroComic6 --out out/heroComic6.png

// ---------------------------------------------------------------- the body, on a skeleton
// Pose reference: a standing adult, half figure, three-quarter view, in the usual figure
// canon (head about 1/7 of the height, enlarged here by the comic convention): shoulders wider
// than the neck (about 1.2 head widths), upper arm and forearm of equal length meeting at an
// elbow, the hand about three quarters of the face. Each arm is built as a tube along its own
// shoulder, elbow and wrist, so it leaves the shoulder joint and nothing else. The torso tapers
// from the shoulders to the waist; the figure is cropped below the waist by a fade (deliberate).
export const NECK: P[] = [[500, 676], [596, 690], [600, 800], [500, 800]];
export const SHOULDER_L: P = [372, 852], SHOULDER_R: P = [728, 856];
export const ELBOW_L: P = [246, 690], WRIST_L: P = [214, 468];          // raised, waving: 203 / 224 px
export const ELBOW_R: P = [790, 1082], WRIST_R: P = [616, 972];         // bent, phone at the chest: 234 / 206 px
export const TORSO: P[] = [[500, 792], [430, 806], [376, 832], [338, 884], [330, 980], [352, 1120], [386, 1260], [398, 1380], [392, 1520], [386, 1700], [716, 1700], [710, 1520], [704, 1380], [716, 1260], [748, 1120], [770, 980], [764, 884], [728, 834], [672, 806], [600, 792]];
export const TORSO_SHADE: P[] = [[338, 884], [376, 832], [430, 806], [420, 900], [410, 1100], [436, 1300], [446, 1700], [386, 1700], [392, 1520], [398, 1380], [386, 1260], [352, 1120], [330, 980]];
export const COLLAR: P[] = [[488, 790], [548, 812], [614, 796], [622, 830], [548, 846], [480, 822]];
// the raised hand: palm toward the viewer, four fingers spread, thumb out, above WRIST_L
export const HAND_UP: P[] = [[186, 470], [176, 420], [150, 360], [144, 300], [166, 296], [180, 352], [186, 282], [210, 276], [214, 348], [232, 284], [256, 290], [246, 356], [268, 318], [290, 330], [262, 404], [252, 452], [240, 480]];
// the phone hand: fingers wrapped round the phone's lower half
export const HAND_FRONT: P[] = [[650, 990], [608, 1004], [570, 990], [556, 952], [574, 930], [612, 940], [640, 948]];
export const PHONE_AT = { cx: 572, cy: 880, w: 104, h: 206, deg: -10 };

// ---------------------------------------------------------------- the voice
// Three flowing marker strokes leave the mouth, fan out, cross the cut and come together at
// the recording panel's left edge (PANEL_IN), where the real waveform takes over. Three short
// sound arcs at the lips say "speaking" before the strokes say "travelling".
export const STROKES: P[][] = [
  [[704, 584], [840, 556], [990, 660], [1130, 920], [1270, 1230], [PANEL_IN[0], PANEL_IN[1] - 34]],
  [[708, 608], [860, 630], [980, 820], [1110, 1080], [1262, 1310], [PANEL_IN[0], PANEL_IN[1]]],
  [[704, 632], [830, 716], [930, 930], [1080, 1190], [1240, 1372], [PANEL_IN[0], PANEL_IN[1] + 34]],
];
export const SOUND_ARCS: P[][] = [0, 1, 2].map((k) => {
  const r = 34 + k * 26, cx = 690, cy = 606;
  return Array.from({ length: 7 }, (_, i) => { const a = -0.75 + (i / 6) * 1.5; return [cx + Math.cos(a) * r, cy + Math.sin(a) * r] as P; });
});
