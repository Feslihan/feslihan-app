import { chromium } from "playwright";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const TEMPLATE_DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "templates");

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

/**
 * Fills a template: `{{key}}` is HTML-escaped, `{{{key}}}` is raw HTML
 * (used for pre-built lists).
 */
export function fillTemplate(templateName: string, values: Record<string, string>): string {
  let html = readFileSync(path.join(TEMPLATE_DIR, templateName), "utf8");
  for (const [key, value] of Object.entries(values)) {
    html = html.replaceAll(`{{{${key}}}}`, value);
    html = html.replaceAll(`{{${key}}}`, escapeHtml(value));
  }
  return html;
}

/** Renders final HTML to a 1080×1350 Instagram-portrait PNG. */
export async function renderToPng(html: string, outputPath: string): Promise<void> {
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage({ viewport: { width: 1080, height: 1350 } });
    await page.setContent(html, { waitUntil: "networkidle" });
    // Give webfonts a settle beat even after networkidle.
    await page.evaluate(() => (document as any).fonts?.ready);
    await page.screenshot({ path: outputPath });
  } finally {
    await browser.close();
  }
}
