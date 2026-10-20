import type { P } from "./core";

// DICTUS HERO V5 · the shared geometry of the two style candidates (#643).
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

export const W = 1320, H = 2000;
export const VOICE_END: P = [1190, 1990];

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
export const NECK: P[] = [[502, 676], [592, 690], [600, 790], [500, 790]];

export const JUMPER: P[] = [[322, 818], [420, 782], [500, 792], [600, 792], [690, 788], [774, 816], [822, 884], [838, 1000], [812, 1160], [786, 1330], [804, 1520], [812, 1660], [318, 1660], [326, 1520], [342, 1330], [312, 1160], [292, 1000], [296, 880]];
export const JUMPER_SHADE: P[] = [[296, 880], [322, 818], [380, 800], [366, 980], [380, 1200], [372, 1660], [318, 1660], [342, 1330], [312, 1160], [292, 1000]];
export const COLLAR: P[] = [[488, 784], [544, 806], [612, 800], [618, 832], [546, 842], [482, 818]];

// the back arm, raised: shoulder, elbow out to the left, forearm up, open palm
export const ARM_UP: P[] = [[340, 840], [250, 760], [196, 640], [178, 520], [222, 506], [246, 620], [300, 720], [400, 800]];
export const CUFF_UP: P[] = [[170, 528], [222, 506], [232, 546], [180, 566]];
export const HAND_UP: P[] = [[176, 520], [150, 470], [128, 400], [150, 396], [168, 452], [170, 380], [194, 376], [198, 446], [214, 382], [238, 388], [228, 456], [256, 410], [276, 422], [244, 488], [232, 520]];
// the front arm: sleeve down the side, forearm across to the phone
export const ARM_FRONT: P[] = [[774, 820], [830, 900], [852, 1020], [836, 1120], [760, 1160], [660, 1132], [646, 1080], [740, 1070], [768, 990], [760, 900]];
export const HAND_FRONT: P[] = [[662, 1070], [620, 1058], [600, 1100], [618, 1140], [664, 1136]];
// the phone: a rounded rectangle, 96 x 196, tilted back 12 degrees (built by the renderer)
export const PHONE_AT = { cx: 600, cy: 1010, w: 100, h: 200, deg: -12 };
export const HEM: P[] = [[318, 1600], [812, 1600], [812, 1660], [318, 1660]];

// the voice: from the mouth, out and down in one S, landing level at VOICE_END
export const VOICE: P[] = [[686, 600], [790, 616], [890, 680], [960, 800], [980, 960], [950, 1160], [910, 1380], [920, 1600], [980, 1800], [1070, 1940], [VOICE_END[0], VOICE_END[1]]];
