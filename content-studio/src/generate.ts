import { mkdirSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import type { SeedRecipe } from "../../feslihan-backend/src/platform-recipes-data.js";
import { fillTemplate, renderToPng } from "./render.js";
import { recipeCaption, suggestionCaption, tipContent, type CaptionResult } from "./captions.js";
import {
  loadState, saveState, typeForToday, pickRecipe, pickTipTopic, nextSeriesNo,
  type ContentType,
} from "./pick.js";

const HANDLE = "@feslihanapp";
const REPO_ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "..");

function slugify(text: string): string {
  const map: Record<string, string> = { ç: "c", ğ: "g", ı: "i", ö: "o", ş: "s", ü: "u" };
  return text
    .toLowerCase()
    .replace(/[çğıöşü]/g, (c) => map[c] ?? c)
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

function formatTime(minutes: number): string {
  if (minutes >= 60) {
    const h = Math.floor(minutes / 60);
    const m = minutes % 60;
    return m > 0 ? `${h} sa ${m} dk` : `${h} saat`;
  }
  return `${minutes} dakika`;
}

function ingredientsHtml(recipe: SeedRecipe): string {
  // The card fits ~14 rows across two columns; overflow gets a "+N" row.
  const max = 14;
  const items = recipe.ingredientsWithMeasures.slice(0, max);
  const rest = recipe.ingredientsWithMeasures.length - items.length;
  const esc = (s: string) => s.replaceAll("&", "&amp;").replaceAll("<", "&lt;");
  let html = items
    .map((i) => `<div><span>${esc(i.name)}</span><span class="amount">${esc(i.amount)}</span></div>`)
    .join("");
  if (rest > 0) html += `<div><span>+ ${rest} malzeme daha</span><span class="amount">uygulamada</span></div>`;
  return html;
}

function writeOutput(dir: string, png: string, result: CaptionResult): void {
  const caption = `${result.caption}\n\n${result.hashtags.join(" ")}\n\n---\nAlt metin önerisi: ${result.alt_text}\n`;
  writeFileSync(path.join(dir, "caption.txt"), caption);
  console.log(`✓ ${png}`);
  console.log(`  caption: ${result.caption.slice(0, 80)}…`);
}

async function generateOne(type: ContentType, date: Date): Promise<void> {
  const state = loadState();
  const dateKey = date.toISOString().slice(0, 10);

  let html: string;
  let slug: string;
  let captions: CaptionResult;

  if (type === "recipe") {
    const recipe = pickRecipe(state);
    slug = `tarif-${slugify(recipe.title)}`;
    captions = await recipeCaption(recipe);
    html = fillTemplate("recipe-card.html", {
      title: recipe.title,
      time: formatTime(recipe.cookingTimeMinutes),
      servings: String(recipe.servings),
      calories: String(Math.round(recipe.caloriesPerServingKcal)),
      ingredients_html: ingredientsHtml(recipe),
      handle: HANDLE,
    });
  } else if (type === "suggestion") {
    const recipe = pickRecipe(state);
    const seriesNo = nextSeriesNo(state);
    slug = `nepisirsem-${slugify(recipe.title)}`;
    const result = await suggestionCaption(recipe);
    captions = result;
    html = fillTemplate("suggestion.html", {
      title: recipe.title,
      time: formatTime(recipe.cookingTimeMinutes),
      servings: String(recipe.servings),
      series_no: `#${seriesNo}`,
      hook: result.hook,
      handle: HANDLE,
    });
  } else {
    const topic = pickTipTopic(state);
    const result = await tipContent(topic);
    captions = result;
    slug = `ipucu-${slugify(result.tip_title)}`;
    html = fillTemplate("tip-card.html", {
      tip_title: result.tip_title,
      tip_body: result.tip_body,
      anne_notu: result.anne_notu,
      handle: HANDLE,
    });
  }

  const outDir = path.join(REPO_ROOT, "content-drafts", `${dateKey}-${slug}`);
  mkdirSync(outDir, { recursive: true });
  const pngPath = path.join(outDir, "post.png");
  await renderToPng(html, pngPath);
  writeOutput(outDir, pngPath, captions);
  saveState(state);
}

// ── CLI ────────────────────────────────────────────────────────────────────
const args = process.argv.slice(2);
const typeArg = args.includes("--type") ? (args[args.indexOf("--type") + 1] as ContentType) : null;
const count = args.includes("--count") ? Number(args[args.indexOf("--count") + 1]) : 1;

const today = new Date();
const type = typeArg ?? typeForToday(today);

if (!type) {
  console.log("Bugün (Pazar) planlı içerik yok — --type ile zorlayabilirsin.");
  process.exit(0);
}
if (!["recipe", "suggestion", "tip"].includes(type)) {
  console.error(`Bilinmeyen tür: ${type} (recipe | suggestion | tip)`);
  process.exit(1);
}

for (let i = 0; i < count; i++) {
  await generateOne(type, today);
}
