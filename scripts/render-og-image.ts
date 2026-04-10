import { chromium } from "playwright";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

async function main() {
  const __dirname = dirname(fileURLToPath(import.meta.url));
  const htmlPath = resolve(__dirname, "og-image.html");
  const outputPath = resolve(__dirname, "../web/public/og.png");

  const browser = await chromium.launch();
  const page = await browser.newPage({
    viewport: { width: 1200, height: 630 },
    deviceScaleFactor: 2,
  });

  await page.goto(`file://${htmlPath}`, { waitUntil: "networkidle" });
  await page.screenshot({ path: outputPath, type: "png" });

  await browser.close();
  console.log(`✓ OpenGraph image saved to ${outputPath}`);
}

main();
