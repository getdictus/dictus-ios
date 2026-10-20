// Export the App Store screenshots from screenshots.html (issue #643).
//
//   npm run export                         every locale in strings/
//   npm run export -- --locale en-GB       one locale
//   npm run export -- --theme navy         force one theme
//   npm run export -- --art v8             slide 1's art (screenshots.html ?art=, default v9-B)
//
// Output: export/<locale>/<iteration>/<theme>/<NN-id>.png, 1320×2868, opaque sRGB
// (App Store Connect rejects screenshots with an alpha channel), plus review
// montages (JPEG: they are only looked at, and a PNG montage weighs 4.6 MB in git).
//
// The template decides what an iteration renders:
// - window.ITERATION: the output folder, so an iteration never overwrites another;
// - window.EXPORT_THEMES: the themes rendered unless --theme forces one;
// - window.VARIANTS: [{ name, query }]. The first is the main set (every slide,
//   montage.jpg); every other one exports only the slides whose id it changes, and
//   a montage-<name>.jpg with those slides swapped in. (A plain string is read as
//   the V3 form, ?variant=<name>.)
// With several themes, montages are suffixed with the theme.
//
// Headless Chromium through Playwright, from a file:// URL: no server, no window.
import { chromium } from "playwright";
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const PANEL_W = 1320, PANEL_H = 2868;

const args = process.argv.slice(2);
const opt = (name) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : undefined;
};
const locales = opt("locale")
  ? [opt("locale")]
  : readdirSync(join(ROOT, "strings")).filter((f) => f.endsWith(".js")).map((f) => f.slice(0, -3));

if (!existsSync(join(ROOT, ".bezels"))) {
  console.error("Apple bezel missing. Run `npm run bezel` first (see tools/fetch-bezel.sh).");
  process.exit(1);
}

const browser = await chromium.launch({ headless: true });
// Wide enough for any strip: the template sets its own width from its slides.
const page = await browser.newPage({ viewport: { width: PANEL_W * 8, height: PANEL_H }, deviceScaleFactor: 1 });

const asVariant = (v) => (typeof v === "string" ? { name: v, query: `variant=${v}` } : v || { name: "main", query: "" });

async function load(locale, theme, variant) {
  const url = pathToFileURL(join(ROOT, "screenshots.html"));
  const q = asVariant(variant).query;
  url.search = `?locale=${locale}${theme ? `&theme=${theme}` : ""}${opt("art") ? `&art=${opt("art")}` : ""}${q ? `&${q}` : ""}`;
  await page.goto(url.href, { waitUntil: "networkidle" });
  if (!(await page.evaluate(() => window.whenReady))) throw new Error("screenshots.html reports the bezel is missing");
  return page.evaluate(() => ({
    ids: window.SLIDE_IDS, iteration: window.ITERATION,
    themes: window.EXPORT_THEMES || ["navy", "light"], variants: window.VARIANTS || [undefined],
    pair: window.PAIR || null, only: window.EXPORT_SLIDES || null, reuse: window.REUSE_FROM || null,
    sheet: window.SHEET || null, cut: window.CUT_PAIR || null, cutAlt: window.CUT_ALT || null, cut3: window.CUT_TRIPLE || null,
  }));
}

const shoot = async (file, i) => {
  await page.screenshot({ path: file, clip: { x: i * PANEL_W, y: 0, width: PANEL_W, height: PANEL_H } });
  // Flatten: no alpha channel, sRGB.
  execFileSync("magick", [file, "-background", "white", "-alpha", "remove", "-alpha", "off", "-colorspace", "sRGB", "-strip", file]);
};
const montage = (files, out) => execFileSync("magick", ["montage", ...files, "-tile", `${files.length}x1`,
  "-geometry", "440x956+12+12", "-background", "#1C1F26", "-quality", "90", out]);

for (const locale of locales) {
  const meta = await load(locale);
  const themes = opt("theme") ? [opt("theme")] : meta.themes;
  for (const theme of themes) {
    const out = join(ROOT, "export", locale, meta.iteration, theme);
    mkdirSync(out, { recursive: true });
    const suffix = themes.length > 1 || opt("theme") ? `-${theme}` : "";
    let mainFiles = [];
    const sheetFiles = [];
    for (const [v, variant] of meta.variants.entries()) {
      const { ids } = await load(locale, theme, variant);
      const files = [];
      for (const [i, id] of ids.entries()) {
        // window.EXPORT_SLIDES limits an iteration to the slides it changes; the others are
        // taken as they were exported in window.REUSE_FROM.
        if (meta.only && !meta.only.includes(i)) {
          const kept = join(ROOT, "export", locale, meta.reuse, theme, `${id}.png`);
          if (!existsSync(kept)) throw new Error(`Missing ${kept} to reuse`);
          files.push(kept);
          continue;
        }
        const file = join(out, `${id}.png`);
        // A secondary variant only re-exports the slides it changes.
        if (v === 0 || !mainFiles.includes(file)) await shoot(file, i);
        files.push(file);
      }
      if (meta.sheet) sheetFiles.push(files[meta.sheet.slide]);
      // A side-by-side of two slides (window.PAIR), for judging a cut: the main set's, or
      // every variant's when PAIR.everyVariant.
      if (meta.pair && (v === 0 || meta.pair.everyVariant)) execFileSync("magick", [...meta.pair.slides.map((n) => files[n]), "+append", "-resize", `${meta.pair.width}x`,
        "-quality", "90", join(ROOT, "export", locale, meta.iteration, meta.pair.file.replace("{name}", asVariant(variant).name))]);
      // Slides cut apart at store size (window.CUT_PAIR): each one alone, a gap between them.
      for (const c of [meta.cut, meta.cut3]) if (c && v === 0) execFileSync("magick", [...c.slides.map((n) => files[n]), "-resize", `${c.width}x`, "-bordercolor", "#FFFFFF", "-border", `${c.gap / 2}`,
        "+append", "-quality", "92", join(ROOT, "export", locale, meta.iteration, c.file)]);
      if (v === 0) mainFiles = files;
      // (V7 skipped the montage of secondary variants here; every variant now gets one.)
      const vname = asVariant(variant).name;
      const name = asVariant(variant).montage ?? (v === 0 ? `montage${suffix}.jpg` : `montage-${vname}${suffix}.jpg`);
      montage(files, join(ROOT, "export", locale, meta.iteration, name));
      console.log(`${locale}/${meta.iteration}/${theme}/${vname}: ${files.length} slides, ${name}`);
    }
    // The same cut view for an alternative layout (window.CUT_ALT), shot to a temporary folder:
    // its slides are only for the comparison, never delivered.
    if (meta.cutAlt && meta.cut) {
      const tmp = mkdtempSync(join(tmpdir(), "dictus-cut-alt-"));
      await load(locale, theme, { name: "alt", query: meta.cutAlt.query });
      const alt = meta.cut.slides.map((n) => join(tmp, `${n}.png`));
      for (const [k, n] of meta.cut.slides.entries()) await shoot(alt[k], n);
      execFileSync("magick", [...alt, "-resize", `${meta.cut.width}x`, "-bordercolor", "#FFFFFF", "-border", `${meta.cut.gap / 2}`,
        "+append", "-quality", "92", join(ROOT, "export", locale, meta.iteration, meta.cutAlt.file)]);
    }
    // One sheet of the same slide across every variant (window.SHEET), side by side.
    if (meta.sheet) execFileSync("magick", [...sheetFiles, "-bordercolor", "#1C1F26", "-border", "12", "+append", "-resize", "2100x",
      "-quality", "90", join(ROOT, "export", locale, meta.iteration, meta.sheet.file)]);
  }
}
await browser.close();
