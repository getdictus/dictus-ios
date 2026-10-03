// Export the App Store screenshots from screenshots.html (issue #643).
//
//   npm run export                         every locale in strings/, both themes
//   npm run export -- --locale en-GB       one locale
//   npm run export -- --theme navy         one theme
//
// Output: export/<locale>/<theme>/<NN-id>.png, 1320×2868, opaque sRGB (App Store
// Connect rejects screenshots with an alpha channel), plus
// export/<locale>/montage-<theme>.jpg, the six side by side for review (JPEG:
// it is only looked at, and a PNG montage weighs 4.6 MB in git).
//
// Headless Chromium through Playwright, from a file:// URL: no server, no window.
import { chromium } from "playwright";
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readdirSync } from "node:fs";
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
const themes = opt("theme") ? [opt("theme")] : ["navy", "light"];

if (!existsSync(join(ROOT, ".bezels"))) {
  console.error("Apple bezel missing. Run `npm run bezel` first (see tools/fetch-bezel.sh).");
  process.exit(1);
}

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({
  viewport: { width: PANEL_W * 6, height: PANEL_H },
  deviceScaleFactor: 1,
});

for (const locale of locales) {
  for (const theme of themes) {
    const url = pathToFileURL(join(ROOT, "screenshots.html"));
    url.search = `?locale=${locale}&theme=${theme}`;
    await page.goto(url.href, { waitUntil: "networkidle" });
    const ok = await page.evaluate(() => window.whenReady);
    if (!ok) throw new Error("screenshots.html reports the bezel is missing");
    const ids = await page.evaluate(() => window.SLIDE_IDS);

    const out = join(ROOT, "export", locale, theme);
    mkdirSync(out, { recursive: true });
    const files = [];
    for (const [i, id] of ids.entries()) {
      const file = join(out, `${id}.png`);
      await page.screenshot({
        path: file,
        clip: { x: i * PANEL_W, y: 0, width: PANEL_W, height: PANEL_H },
      });
      // Flatten: no alpha channel, sRGB.
      execFileSync("magick", [file, "-background", "white", "-alpha", "remove", "-alpha", "off",
        "-colorspace", "sRGB", "-strip", file]);
      files.push(file);
    }
    const montage = join(ROOT, "export", locale, `montage-${theme}.jpg`);
    execFileSync("magick", ["montage", ...files, "-tile", "6x1", "-geometry", "440x956+12+12",
      "-background", "#1C1F26", "-quality", "90", montage]);
    console.log(`${locale}/${theme}: ${files.length} slides, montage ${montage}`);
  }
}
await browser.close();
