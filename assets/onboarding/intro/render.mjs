#!/usr/bin/env node
// Re-render the onboarding intro videos (issue #667). One command, no manual step:
//
//   node assets/onboarding/intro/render.mjs                 # all six videos
//   node assets/onboarding/intro/render.mjs --only a-dark   # one or more, comma-separated
//   node assets/onboarding/intro/render.mjs --frames 0,67   # write those frames as PNG, no video
//
// What it needs is in README.md: Node 20+, ffmpeg with libx265, network access for the first
// `npm install`, and the anidoodle engine installed at ~/.claude/skills/anidoodle (or the path in
// $ANIDOODLE). Everything it writes outside the six .mp4 files goes to .build/ next to this file,
// which git ignores; delete it for a clean render.
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { cpSync, existsSync, mkdirSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const BUILD = join(HERE, ".build");
const SKILL = resolve(process.env.ANIDOODLE ?? join(homedir(), ".claude/skills/anidoodle"));
const ENGINE = join(SKILL, "engine");
const FFMPEG = process.env.FFMPEG ?? "ffmpeg";
const FFPROBE = process.env.FFPROBE ?? "ffprobe";
// the engine revision these videos were rendered with; another one may move pixels (see README)
const ENGINE_REV = "9a1a762";

const arg = (k) => { const i = process.argv.indexOf(`--${k}`); return i > 0 ? process.argv[i + 1] : undefined; };
const die = (m) => { console.error(`render: ${m}`); process.exit(1); };
const run = (cmd, args, opts = {}) => execFileSync(cmd, args, { stdio: "inherit", ...opts });

// ---------------------------------------------------------------- the six videos
// scene letter -> the film module's export prefix; the file is intro-<scene>-<theme>.mp4
const SCENES = { a: "introWalk", b: "introMetro", c: "introKeyboard" };
const ALL = Object.keys(SCENES).flatMap((s) => ["light", "dark"].map((t) => `${s}-${t}`));
const only = arg("only")?.split(",") ?? ALL;
only.forEach((id) => ALL.includes(id) || die(`unknown video '${id}', expected one of ${ALL.join(", ")}`));
const frames = arg("frames")?.split(",").map(Number);
// both variants of a scene are drawn from ONE film, the light art: the dark video is that art
// faded into the dark page (see DARK below)
const filmName = (id) => SCENES[id.split("-")[0]] + "Light";   // e.g. introWalkLight

// ---------------------------------------------------------------- the dark variant
// The dark video shows the LIGHT art (its black marker outlines, its #F2F2F7 page) in a soft pool
// of light that fades into the app's dark page, #0A1628, the way the light video's pavement and
// carriage fade into the light page. (Round 10: a dark palette with light outlines read wrong for
// a marker drawing; a feathered rectangle read as a box with dark corners.)
// - The art is drawn at DARK.scale about the frame's centre, so the fade has room all round it.
// - The pool is a union of soft superellipses per scene, in frame pixels after that scaling: full
//   light inside (d <= 1), fading with a smoothstep to the dark page at d = 1 + fade. Everything that
//   matters sits inside d <= 1 in every frame; the scene's edges (pavement, carriage) fade with it.
// - Corners and edges are far outside the pool, so they are the dark page exactly.
const DARK = { scale: 0.7, p: 2.8 };
// soft superellipses [cx, cy, rx, ry] in the dark frame's pixels; the pool is their SMOOTH union
// (a soft minimum of their signed distances, so blobs merge without a crease where they meet),
// fading over FADE px outside it
const FADE = 165, BLEND = { a: 30, b: 45, c: 30 };   // B's badge lobe merges into the body slowly
const POOL = {
  a: [[498, 692, 330, 516]],
  b: [[505, 701, 317, 487], [772, 293, 55, 57]],
  c: [[500, 753, 336, 393]],
};
const poolExpr = (blobs, blend) => {
  // signed distance to a blob's edge, in pixels: (r - 1) times the blob's radius in that
  // direction (an ellipse's, near enough for p = 2.4), so the fade spans FADE px all round it
  const sd = blobs.map(([cx, cy, rx, ry]) => `((pow(pow(abs((X-${cx})/${rx}),${DARK.p})+pow(abs((Y-${cy})/${ry}),${DARK.p}),${1 / DARK.p})-1)*${rx * ry}*hypot(X-${cx},Y-${cy})/(hypot(${rx}*(Y-${cy}),${ry}*(X-${cx}))+0.001))`);
  const u = sd.length === 1 ? sd[0] : `(-${blend}*log(${sd.map((d) => `exp(-${d}/${blend})`).join("+")}))`;
  const t = `clip(${u}/${FADE},0,1)`;
  return `65535*(1-${t}*${t}*(3-2*${t}))`;
};

// ---------------------------------------------------------------- 1. the engine, scaffolded into .build
if (!existsSync(join(ENGINE, "tools/scaffold.mjs"))) die(`no anidoodle engine at ${ENGINE} (set ANIDOODLE to the skill's folder)`);
let rev = "unknown";
try { rev = execFileSync("git", ["-C", SKILL, "rev-parse", "--short", "HEAD"], { stdio: ["ignore", "pipe", "ignore"] }).toString().trim(); } catch { /* not a git checkout */ }
console.log(`anidoodle engine: ${SKILL} @ ${rev}${rev === ENGINE_REV ? "" : `  (the committed videos were rendered @ ${ENGINE_REV}: pixels may differ)`}`);
try { console.log(execFileSync(FFMPEG, ["-version"]).toString().split("\n")[0]); } catch { die(`ffmpeg not found (set FFMPEG=/path/to/ffmpeg)`); }

// scaffold copies the engine's src/, tools/ and package files; it is re-run every time, so an
// updated engine is always the one rendering
run(process.execPath, [join(ENGINE, "tools/scaffold.mjs"), BUILD], { stdio: ["ignore", "ignore", "inherit"] });
if (!existsSync(join(BUILD, "node_modules/playwright-core")) || !existsSync(join(BUILD, "node_modules/esbuild"))) {
  // the optional Remotion packages are another backend; this render only uses Playwright
  run("npm", ["install", "--omit=optional", "--no-audit", "--no-fund"], { cwd: BUILD });
}
process.chdir(BUILD);   // the engine's tools resolve src/ against the working directory
const { detect } = await import(pathToFileURL(join(BUILD, "tools/detect.mjs")).href);
let env = detect();
if (!env.browser.ok) { run("npx", ["playwright-core", "install", "chromium"], { cwd: BUILD }); env = detect(); }
if (!env.chosen) die(`no render backend:\n${Object.entries(env.report).map(([k, v]) => `  ${k}: ${v}`).join("\n")}`);
const { buildPage } = await import(pathToFileURL(join(BUILD, "tools/build-page.mjs")).href);
const playwright = await import(pathToFileURL(join(BUILD, "tools/adapters/playwright.mjs")).href);

// ---------------------------------------------------------------- 2. the art, next to the engine's core
const core = join(BUILD, "src/canvas-core"), hosts = join(BUILD, "src/hosts");
// anything left from an earlier render that the engine does not ship goes first, so a scene
// that was renamed or removed cannot linger in the build
const shipped = (dir) => new Set(readdirSync(join(ENGINE, "src", dir)));
for (const [dir, abs] of [["canvas-core", core], ["hosts", hosts]]) { const keep = shipped(dir); for (const f of readdirSync(abs)) if (!keep.has(f)) rmSync(join(abs, f), { recursive: true, force: true }); }
for (const f of readdirSync(join(HERE, "src"))) if (f.endsWith(".ts")) cpSync(join(HERE, "src", f), join(core, f));
// the engine's page builder wants one module and one host page per film, both named after it
for (const id of ALL) {
  const name = filmName(id), [s] = id.split("-");
  writeFileSync(join(core, `${name}.ts`), `export { ${name} } from "./${SCENES[s]}";\n`);
  writeFileSync(join(hosts, `page-${name}.ts`), `import { ${name} } from "../canvas-core/${name}";\nimport { mountFilm } from "./page";\nmountFilm(${name});\n`);
}

// ---------------------------------------------------------------- 3. frames, then the video
const hash = (b) => createHash("sha256").update(b).digest("hex");
// x265's sample adaptive offset (SAO) nudges flat areas next to detailed ones by a code value or
// so, which left a corner of the page one value off (F2F2F8). Off for every scene.
const X265_EXTRA = ":no-sao=1";
// the quality per scene: C's flat page is wide around a small phone, and at CRF 26 the encoder
// rounds its bottom right one code value off (F2F2F8); CRF 24 keeps it exact, and C stays small
const CRF = { a: "26", b: "26", c: "24" };
// Opaque HEVC: each frame laid over the light page IN RGB (for the dark variant, scaled into its
// pool of light over the dark page: maskedmerge at 16 bits per channel, so the long fade has no
// banding), then turned into BT.709 limited-range 4:2:0 with exact rounding and tagged so. The
// page colour that comes back out of the decoder is the page's own (#F2F2F7, #0A1628) to the code
// value, so the video's edge never shows against the SwiftUI background. (ffmpeg's defaults,
// BT.601 and fast rounding, land the dark page on #081426.) 10-bit (HEVC Main 10): in 8 bits no
// Y'CbCr code decodes back to the light page's #F2F2F7 (the nearest is #F2F2F6); in 10 bits it
// does, for about 4 % more bytes, and every iPhone that runs iOS 17 decodes Main 10 in hardware.
// Tagged hvc1 so AVFoundation plays it, one keyframe per loop, no audio track. Why not HEVC with
// alpha: README.md.
const poolPng = (scene, W, H) => {
  const png = join(BUILD, `pool-${scene}.png`);
  run(FFMPEG, ["-y", "-loglevel", "error", "-f", "lavfi", "-i", `color=c=black:s=${W}x${H},format=gray16le`, "-vf", `geq=lum='${poolExpr(POOL[scene], BLEND[scene])}'`, "-frames:v", "1", png]);
  return png;
};
/** `input` is a frame pattern (f%04d.png) for a video, or one frame's PNG for a still */
const compose = (id, input, meta, out, still) => {
  const { W, H, fps } = meta, dark = id.endsWith("dark");
  const ins = ["-f", "lavfi", "-i", `color=c=0xF2F2F7:s=${W}x${H}:r=${fps},format=rgba`, ...(still ? ["-i", input] : ["-framerate", String(fps), "-i", input])];
  let graph = "[0:v][1:v]overlay=shortest=1:format=rgb";
  if (dark) {
    const w = Math.round(W * DARK.scale), h = Math.round(H * DARK.scale), x = Math.round((W - w) / 2), y = Math.round((H - h) / 2);
    ins.push("-loop", "1", "-framerate", String(fps), "-i", poolPng(id[0], W, H), "-f", "lavfi", "-i", `color=c=0x0A1628:s=${W}x${H}:r=${fps},format=rgba`);
    graph += `,scale=${w}:${h}:flags=lanczos,pad=${W}:${H}:${x}:${y}:color=0xF2F2F7,format=gbrp16le[l];[2:v]format=gbrp16le[m];[3:v]format=gbrp16le[d];[d][l][m]maskedmerge,format=rgb24`;
  }
  graph += still ? ",format=rgb24[v]" : ",scale=out_color_matrix=bt709:out_range=tv:flags=accurate_rnd+full_chroma_int,format=yuv420p10le[v]";
  const enc = still ? ["-frames:v", "1", out] : ["-frames:v", String(meta.durationFrames), "-c:v", "libx265", "-preset", "slow", "-crf", CRF[id[0]], "-x265-params", `log-level=error:keyint=${meta.durationFrames}:min-keyint=${meta.durationFrames}${X265_EXTRA}`,
    "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709", "-color_range", "tv", "-tag:v", "hvc1", "-an", "-movflags", "+faststart", out];
  run(FFMPEG, ["-y", "-loglevel", "error", ...ins, "-filter_complex", graph, "-map", "[v]", ...enc]);
};

// each scene's light art is drawn once; both of its videos are made from those frames
const results = [], drawn = new Map();
const drawScene = async (scene) => {
  if (drawn.has(scene)) return drawn.get(scene);
  const name = SCENES[scene] + "Light";
  const page = await buildPage({ entry: `src/hosts/page-${name}.ts`, out: join(BUILD, `dist/${name}.html`), title: name });
  // one page, so every frame is drawn by the same canvas in the same order: nothing to reconcile
  const session = await playwright.open(env, page.out, { scale: 1, workers: 1 });
  const meta = await session.info();
  const dir = join(BUILD, "frames", scene);
  rmSync(dir, { recursive: true, force: true }); mkdirSync(dir, { recursive: true });
  const list = frames ?? Array.from({ length: meta.durationFrames }, (_, n) => n);
  const all = createHash("sha256");
  for (const n of list) {
    const f = await session.frame(n, 0);
    writeFileSync(join(dir, `f${String(n).padStart(4, "0")}.png`), f.png);
    all.update(hash(f.png));
  }
  await session.close();
  const r = { meta, dir, list, digest: all.digest("hex").slice(0, 16) };
  drawn.set(scene, r);
  return r;
};
for (const id of only) {
  const { meta, dir, list, digest } = await drawScene(id[0]);
  if (frames) {
    // stills of the finished picture, light or dark, next to the drawn frames
    const sdir = join(BUILD, "stills", id); rmSync(sdir, { recursive: true, force: true }); mkdirSync(sdir, { recursive: true });
    for (const n of list) compose(id, join(dir, `f${String(n).padStart(4, "0")}.png`), meta, join(sdir, `f${String(n).padStart(4, "0")}.png`), true);
    console.log(`${id}: frames ${list.join(", ")} -> ${sdir}`);
    continue;
  }
  const out = join(HERE, `intro-${id}.mp4`);
  compose(id, join(dir, "f%04d.png"), meta, out, false);
  const probe = execFileSync(FFPROBE, ["-v", "error", "-show_entries", "stream=codec_type,codec_name,width,height,nb_frames:format=duration", "-of", "compact=p=0", out]).toString().trim();
  results.push({ id, bytes: statSync(out).size, digest, probe });
}

if (!frames) {
  console.log("\nvideo                  size       frames sha256   ffprobe");
  for (const r of results) console.log(`intro-${r.id}.mp4`.padEnd(22), `${(r.bytes / 1024).toFixed(0)} KB`.padStart(8), "  ", r.digest, "  ", r.probe.replace(/\n/g, " | "));
}
