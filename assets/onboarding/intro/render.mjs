#!/usr/bin/env node
// Re-render the onboarding intro videos (issue #667), one set of six per language (issue #771).
// One command, no manual step:
//
//   node assets/onboarding/intro/render.mjs                    # the six English videos
//   node assets/onboarding/intro/render.mjs --locale fr        # the six French ones
//   node assets/onboarding/intro/render.mjs --locale en,fr     # both, comma-separated
//   node assets/onboarding/intro/render.mjs --only a-dark      # one or more, comma-separated
//   node assets/onboarding/intro/render.mjs --frames 0,67      # write those frames as PNG, no video
//
// What it needs is in README.md: Node 20+, ffmpeg with libx265, network access for the first
// `npm install`, and the anidoodle engine installed at ~/.claude/skills/anidoodle (or the path in
// $ANIDOODLE). A locale's videos go to <locale>.lproj/ next to this file, its still frames into
// DictusApp's asset catalog; everything else goes to .build/ next to this file, which git
// ignores; delete it for a clean render.
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";
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
const locales = (arg("locale") ?? "en").split(",");
const cap = (w) => w[0].toUpperCase() + w.slice(1);
// e.g. introWalkDark in English, introWalkDarkFr in French: the English names are the films' names
// from before #771, so an English render is the same film as before
const filmName = (id, locale) => { const [s, t] = id.split("-"); return SCENES[s] + cap(t) + (locale === "en" ? "" : cap(locale)); };
// the still frame of each scene in the asset catalog, taken at OnboardingIntroScene.stillFrameSeconds
// (DictusCore): 4.5 s into A and B, 3.0 s into C, at 30 fps
const STILL_FRAME = { a: 135, b: 135, c: 90 };
const CATALOG = resolve(HERE, "../../../DictusApp/Assets.xcassets");

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
// the engine's page builder wants one module and one host page per film, both named after it;
// the module builds the scene in its appearance and the locale's text (src/strings.ts)
for (const locale of locales) for (const id of ALL) {
  const name = filmName(id, locale), [s, t] = id.split("-");
  writeFileSync(join(core, `${name}.ts`), `import { ${SCENES[s]} } from "./${SCENES[s]}";\nexport const ${name} = ${SCENES[s]}("${t}", "${locale}", "${name}");\n`);
  writeFileSync(join(hosts, `page-${name}.ts`), `import { ${name} } from "../canvas-core/${name}";\nimport { mountFilm } from "./page";\nmountFilm(${name});\n`);
}

// ---------------------------------------------------------------- 2b. every locale's text, checked before any frame
// Building each film runs the scenes' checks: a locale with no strings, a character with no
// hand-lettered glyph (it would be drawn as a blank gap), a line wider than its card, a typed
// letter with no key, a cue off the 5-frame grid. Any of them stops the render here, before
// Chromium draws anything.
{
  const { build } = await import(pathToFileURL(join(BUILD, "node_modules/esbuild/lib/main.js")).href);
  const entry = locales.flatMap((locale) => Object.values(SCENES).flatMap((scene) => ["light", "dark"].map((t) => `${scene}("${t}", "${locale}", "check");`)));
  const imports = Object.values(SCENES).map((scene) => `import { ${scene} } from "./${scene}";`).join("\n");
  const out = await build({ stdin: { contents: `${imports}\n${entry.join("\n")}\n`, resolveDir: core, loader: "ts" }, bundle: true, write: false, format: "esm", platform: "neutral", logLevel: "silent" });
  try { await import(`data:text/javascript;base64,${Buffer.from(out.outputFiles[0].text).toString("base64")}`); }
  catch (e) { die(`the ${locales.join(", ")} text cannot be rendered:\n${e.message}`); }
}

// ---------------------------------------------------------------- 3. frames, then the video
const hash = (b) => createHash("sha256").update(b).digest("hex");
// x265's sample adaptive offset (SAO) nudges flat areas next to detailed ones by a code value or
// so, which left a corner of the page one value off (F2F2F8). Off for every scene.
const X265_EXTRA = ":no-sao=1";
// the quality per scene: C's flat page is wide around a small phone, and at CRF 26 the encoder
// rounds its bottom right one code value off (F2F2F8); CRF 24 keeps it exact, and C stays small
const CRF = { a: "26", b: "26", c: "24" };
const results = [];
for (const locale of locales) for (const id of only) {
  const name = filmName(id, locale);
  const page = await buildPage({ entry: `src/hosts/page-${name}.ts`, out: join(BUILD, `dist/${name}.html`), title: name });
  // one page, so every frame is drawn by the same canvas in the same order: nothing to reconcile
  const session = await playwright.open(env, page.out, { scale: 1, workers: 1 });
  const meta = await session.info();
  const dir = join(BUILD, "frames", locale, id);
  rmSync(dir, { recursive: true, force: true }); mkdirSync(dir, { recursive: true });
  const list = frames ?? Array.from({ length: meta.durationFrames }, (_, n) => n);
  const all = createHash("sha256");
  for (const n of list) {
    const f = await session.frame(n, 0);
    writeFileSync(join(dir, `f${String(n).padStart(4, "0")}.png`), f.png);
    all.update(hash(f.png));
  }
  // the loop closes: the frame one loop on draws exactly frame 0
  const seam = frames ? null : await session.frame(meta.durationFrames, 0);
  await session.close();
  if (seam && hash(seam.png) !== hash(readFileSync(join(dir, "f0000.png")))) die(`${locale} ${id}: frame ${meta.durationFrames} differs from frame 0, the loop does not close`);
  const digest = all.digest("hex").slice(0, 16);
  if (frames) { console.log(`${locale} ${id}: frames ${list.join(", ")} -> ${dir}`); continue; }

  // Opaque HEVC: each frame laid over the theme's background colour IN RGB, then turned into
  // BT.709 limited-range 4:2:0 with exact rounding and tagged so: the page colour that comes back
  // out of the decoder is then the page's own (#F2F2F7, #0A1628) to the code value, so the video's
  // edge never shows against the SwiftUI background. (ffmpeg's defaults, BT.601 and fast rounding,
  // land the dark page on #081426.) 10-bit (HEVC Main 10): in 8 bits no Y'CbCr code decodes back
  // to the light page's #F2F2F7 (the nearest is #F2F2F6); in 10 bits it does, for about 4 % more
  // bytes, and every iPhone that runs iOS 17 decodes Main 10 in hardware. Tagged hvc1 so
  // AVFoundation plays it, one keyframe per loop, no audio track. Why not HEVC with alpha: README.md.
  // the page under the art, the same colours as theme.ts: the onboarding's grouped background in
  // light (#F2F2F7, the #649 mock-up's page), the app's navy in dark
  const bg = id.endsWith("dark") ? "0x0A1628" : "0xF2F2F7";
  mkdirSync(join(HERE, `${locale}.lproj`), { recursive: true });
  const out = join(HERE, `${locale}.lproj`, `intro-${id}.mp4`);
  run(FFMPEG, ["-y", "-loglevel", "error",
    "-f", "lavfi", "-i", `color=c=${bg}:s=${meta.W}x${meta.H}:r=${meta.fps},format=rgba`,
    "-framerate", String(meta.fps), "-i", join(dir, "f%04d.png"),
    "-filter_complex", "[0:v][1:v]overlay=shortest=1:format=rgb,scale=out_color_matrix=bt709:out_range=tv:flags=accurate_rnd+full_chroma_int,format=yuv420p10le[v]", "-map", "[v]",
    "-c:v", "libx265", "-preset", "slow", "-crf", CRF[id[0]], "-x265-params", `log-level=error:keyint=${meta.durationFrames}:min-keyint=${meta.durationFrames}${X265_EXTRA}`,
    "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709", "-color_range", "tv",
    "-tag:v", "hvc1", "-an", "-movflags", "+faststart", out]);
  const probe = execFileSync(FFPROBE, ["-v", "error", "-show_entries", "stream=codec_type,codec_name,width,height,nb_frames:format=duration", "-of", "compact=p=0", out]).toString().trim();

  // decoded as the phone decodes it (BT.709, limited range, exact rounding), every frame's four
  // corners must be the page colour to the code value
  const rgb = (args) => execFileSync(FFMPEG, ["-v", "error", "-i", out, ...args, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], { maxBuffer: 1 << 30 });
  const decode = "scale=in_color_matrix=bt709:in_range=tv:flags=accurate_rnd+full_chroma_int,format=rgb24";
  const want = bg.slice(2).toLowerCase();
  for (const [x, y] of [[0, 0], [meta.W - 1, 0], [0, meta.H - 1], [meta.W - 1, meta.H - 1]]) {
    const px = rgb(["-vf", `${decode},crop=1:1:${x}:${y}`]);
    for (let n = 0; n < px.length; n += 3) {
      const got = px.subarray(n, n + 3).toString("hex");
      if (got !== want) die(`${locale} ${id}: frame ${n / 3}, corner (${x}, ${y}) decodes to #${got}, not #${want}`);
    }
  }

  // the still frame in DictusApp's asset catalog (OnboardingIntroScene.stillImageName): the same
  // decode of the frame the video starts on. English keeps the catalog's original file names,
  // another locale adds its code (intro-a-light-fr.png), listed with its "locale" in the image
  // set's Contents.json. A still whose pixels already match is left untouched, so a re-render
  // does not rewrite PNGs that only differ in their compression.
  const [scene, theme] = id.split("-");
  const still = join(CATALOG, `intro-${scene}-still.imageset`, `intro-${id}${locale === "en" ? "" : `-${locale}`}.png`);
  const stillPx = rgb(["-vf", `select=eq(n\\,${STILL_FRAME[scene]}),${decode}`, "-frames:v", "1"]);
  const samePx = existsSync(still) && execFileSync(FFMPEG, ["-v", "error", "-i", still, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], { maxBuffer: 1 << 30 }).equals(stillPx);
  if (!samePx) run(FFMPEG, ["-y", "-v", "error", "-i", out, "-vf", `select=eq(n\\,${STILL_FRAME[scene]}),${decode}`, "-frames:v", "1", still]);
  if (!readFileSync(join(dirname(still), "Contents.json"), "utf8").includes(`"${basename(still)}"`)) console.warn(`render: ${basename(still)} is not listed in intro-${scene}-still.imageset/Contents.json (theme ${theme}, locale ${locale})`);
  results.push({ id: `${locale}.lproj/intro-${id}`, bytes: statSync(out).size, digest, probe, still: samePx ? "unchanged" : "written" });
}

if (!frames) {
  console.log("\nloops closed on frame 0, corners exact on every frame\n");
  console.log("video                          size       frames sha256   still      ffprobe");
  for (const r of results) console.log(`${r.id}.mp4`.padEnd(30), `${(r.bytes / 1024).toFixed(0)} KB`.padStart(8), "  ", r.digest, "  ", r.still.padEnd(9), "  ", r.probe.replace(/\n/g, " | "));
}
