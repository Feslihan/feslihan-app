import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { PLATFORM_RECIPES, type SeedRecipe } from "../../feslihan-backend/src/platform-recipes-data.js";

export type ContentType = "recipe" | "suggestion" | "tip";

const STATE_PATH = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "state.json");

interface State {
  recentRecipeSlugs: string[];
  recentTipTopics: string[];
  suggestionSeriesNo: number;
}

/** Kitchen-tip topics the tip cards rotate through (Claude writes the body). */
export const TIP_TOPICS = [
  "soğan doğrarken göz yaşarmasını önlemek",
  "pirinç pilavının tane tane olması",
  "etin mühürlenmesi ve suyunu kaybetmemesi",
  "maydanoz ve yeşillikleri taze saklamak",
  "limonu daha verimli sıkmak",
  "yemeğin tuzunu fazla kaçırınca kurtarmak",
  "hamurun ele yapışmaması",
  "kekin kabarıp çökmemesi",
  "sarımsağın kokusunu elden çıkarmak",
  "zeytinyağlıların renkli ve parlak kalması",
  "köftenin dağılmaması",
  "patatesin kararmasını önlemek",
  "baklagilleri gaz yapmadan pişirmek",
  "yoğurdun çorbada kesilmemesi",
  "tavuğun kuru olmaması",
  "dondurucuda yemek saklama süreleri",
  "balığın kokusunu azaltmak",
  "sütlü tatlıların dibinin tutmaması",
  "biberin acısını dengelemek",
  "bayat ekmeği değerlendirmek",
  "salçanın yanmadan kavrulması",
  "mercimeğin lapa olmaması",
  "kaşar peynirinin güzel erimesi",
  "menemenin sulu olmaması",
] as const;

function loadState(): State {
  if (!existsSync(STATE_PATH)) {
    return { recentRecipeSlugs: [], recentTipTopics: [], suggestionSeriesNo: 0 };
  }
  return JSON.parse(readFileSync(STATE_PATH, "utf8"));
}

export function saveState(state: State): void {
  writeFileSync(STATE_PATH, JSON.stringify(state, null, 2) + "\n");
}

/** Weekday rotation (TR time assumed by caller): Sun has no scheduled post. */
export function typeForToday(date = new Date()): ContentType | null {
  switch (date.getDay()) {
    case 1: case 4: case 6: return "recipe";     // Pzt, Per, Cmt
    case 2: case 5: return "suggestion";          // Sal, Cum
    case 3: return "tip";                          // Çar
    default: return null;                          // Paz
  }
}

/** Least-recently-used pick over the recipe catalog. */
export function pickRecipe(state: State): SeedRecipe {
  const fresh = PLATFORM_RECIPES.filter((r) => !state.recentRecipeSlugs.includes(r.slug));
  const pool = fresh.length > 0 ? fresh : PLATFORM_RECIPES;
  const pick = pool[Math.floor(Math.random() * pool.length)];
  state.recentRecipeSlugs = [...state.recentRecipeSlugs, pick.slug].slice(-12);
  return pick;
}

export function pickTipTopic(state: State): string {
  const fresh = TIP_TOPICS.filter((t) => !state.recentTipTopics.includes(t));
  const pool = fresh.length > 0 ? fresh : [...TIP_TOPICS];
  const pick = pool[Math.floor(Math.random() * pool.length)];
  state.recentTipTopics = [...state.recentTipTopics, pick].slice(-16);
  return pick;
}

export function nextSeriesNo(state: State): number {
  state.suggestionSeriesNo += 1;
  return state.suggestionSeriesNo;
}

export { loadState };
