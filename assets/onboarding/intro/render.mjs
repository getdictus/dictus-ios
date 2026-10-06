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
const filmName = (id) => { const [s, t] = id.split("-"); return SCENES[s] + t[0].toUpperCase() + t.slice(1); };   // e.g. introWalkDark

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
const results = [];
for (const id of only) {
  const name = filmName(id);
  const page = await buildPage({ entry: `src/hosts/page-${name}.ts`, out: join(BUILD, `dist/${name}.html`), title: name });
  // one page, so every frame is drawn by the same canvas in the same order: nothing to reconcile
  const session = await playwright.open(env, page.out, { scale: 1, workers: 1 });
  const meta = await session.info();
  const dir = join(BUILD, "frames", id);
  rmSync(dir, { recursive: true, force: true }); mkdirSync(dir, { recursive: true });
  const list = frames ?? Array.from({ length: meta.durationFrames }, (_, n) => n);
  const all = createHash("sha256");
  for (const n of list) {
    const f = await session.frame(n, 0);
    writeFileSync(join(dir, `f${String(n).padStart(4, "0")}.png`), f.png);
    all.update(hash(f.png));
  }
  await session.close();
  const digest = all.digest("hex").slice(0, 16);
  if (frames) { console.log(`${id}: frames ${list.join(", ")} -> ${dir}`); continue; }

  // Opaque HEVC: each frame laid over the theme's background colour IN RGB, then turned into
  // BT.709 limited-range 4:2:0 with exact rounding and tagged so: the page colour that comes back
  // out of the decoder is then the app's own (#FFFFFF, #0A1628) to the code value, so the video's
  // edge never shows against the SwiftUI background. (ffmpeg's defaults, BT.601 and fast rounding,
  // land the dark page on #081426.) x265 Main profile, tagged hvc1 so AVFoundation plays it,
  // one keyframe per loop, no audio track. Why not HEVC with alpha: README.md.
  const bg = id.endsWith("dark") ? "0x0A1628" : "0xFFFFFF";
  const out = join(HERE, `intro-${id}.mp4`);
  run(FFMPEG, ["-y", "-loglevel", "error",
    "-f", "lavfi", "-i", `color=c=${bg}:s=${meta.W}x${meta.H}:r=${meta.fps},format=rgba`,
    "-framerate", String(meta.fps), "-i", join(dir, "f%04d.png"),
    "-filter_complex", "[0:v][1:v]overlay=shortest=1:format=rgb,scale=out_color_matrix=bt709:out_range=tv:flags=accurate_rnd+full_chroma_int,format=yuv420p[v]", "-map", "[v]",
    "-c:v", "libx265", "-preset", "slow", "-crf", "26", "-x265-params", `log-level=error:keyint=${meta.durationFrames}:min-keyint=${meta.durationFrames}`,
    "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709", "-color_range", "tv",
    "-tag:v", "hvc1", "-an", "-movflags", "+faststart", out]);
  const probe = execFileSync(FFPROBE, ["-v", "error", "-show_entries", "stream=codec_type,codec_name,width,height,nb_frames:format=duration", "-of", "compact=p=0", out]).toString().trim();
  results.push({ id, bytes: statSync(out).size, digest, probe });
}

if (!frames) {
  console.log("\nvideo                  size       frames sha256   ffprobe");
  for (const r of results) console.log(`intro-${r.id}.mp4`.padEnd(22), `${(r.bytes / 1024).toFixed(0)} KB`.padStart(8), "  ", r.digest, "  ", r.probe.replace(/\n/g, " | "));
}
