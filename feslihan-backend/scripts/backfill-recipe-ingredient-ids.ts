// Ensure every recipes.ingredients_with_measures entry is mapped to a row in
// the ingredients table. Entries with an empty (or dangling) ingredient_id are
// re-resolved in three steps:
//   1. exact match after measure/qualifier normalization (normalizeForMatch)
//   2. fuzzy match via findBestMatch (product-form gated, dice > 0.8)
//   3. create a new ingredient row from the cleaned core name
// Creation uses the measure-stripped name (splitAmountFromName), never the raw
// display line, so no "Adet Limon"-style junk rows.
//
// Usage:
//   npx tsx scripts/backfill-recipe-ingredient-ids.ts           # dry run
//   npx tsx scripts/backfill-recipe-ingredient-ids.ts --apply   # execute
//
// Reads DATABASE_URL from env (or .env via dotenv).

import "dotenv/config";
import pg from "pg";
import {
  normalizeForMatch,
  findBestMatch,
  fixTurkish,
} from "../src/ingredient-matching.js";

const APPLY = process.argv.includes("--apply");
const url = process.env.DATABASE_URL;
if (!url) {
  console.error("DATABASE_URL is required");
  process.exit(1);
}

type Entry = { name?: string; amount?: string; section?: string; ingredient_id?: string };

async function main() {
  const client = new pg.Client({ connectionString: url });
  await client.connect();
  await client.query(`SET search_path TO public`);

  const { rows: ings } = await client.query<{ id: string; name: string }>(
    `SELECT id, name FROM ingredients`
  );
  const allIngredients = ings.map((i) => ({ id: i.id, name: i.name }));
  const validIds = new Set(ings.map((i) => i.id));
  const byNorm = new Map<string, { id: string; name: string }>();
  for (const i of ings) {
    const norm = normalizeForMatch(i.name);
    const prev = byNorm.get(norm);
    if (!prev || i.name.length < prev.name.length) byNorm.set(norm, i);
  }

  const { rows: recipes } = await client.query<{
    id: string;
    title: string;
    ingredients_with_measures: Entry[];
  }>(
    `SELECT id, title, ingredients_with_measures FROM recipes
     WHERE EXISTS (
       SELECT 1 FROM jsonb_array_elements(ingredients_with_measures) elem
       WHERE COALESCE(elem->>'ingredient_id', '') = ''
          OR NOT EXISTS (SELECT 1 FROM ingredients i WHERE i.id::text = elem->>'ingredient_id')
     )`
  );
  console.log(`${recipes.length} recipes with unmapped entries (${APPLY ? "APPLY" : "DRY RUN"})\n`);

  // Names we decide to create, shared across recipes so duplicates collapse.
  // Keyed by normalizeForMatch so "Galeta Unu" / "galeta unu" create one row.
  const toCreate = new Map<string, string>(); // norm -> canonical name
  let exactFixed = 0;
  let fuzzyFixed = 0;
  let createNeeded = 0;

  type PendingEntry = { entry: Entry; recipeTitle: string; resolved?: string; createNorm?: string };
  const updates: { id: string; entries: PendingEntry[] }[] = [];

  for (const r of recipes) {
    const entries: PendingEntry[] = r.ingredients_with_measures.map((e) => {
      const iid = e.ingredient_id ?? "";
      if (iid && validIds.has(iid)) return { entry: e, recipeTitle: r.title };

      const rawName = (e.name ?? "").trim();
      if (!rawName) return { entry: e, recipeTitle: r.title };
      const norm = normalizeForMatch(fixTurkish(rawName));

      const exact = byNorm.get(norm);
      if (exact) {
        console.log(`  EXACT  [${r.title}] "${rawName}" → ${exact.name}`);
        exactFixed++;
        return { entry: e, recipeTitle: r.title, resolved: exact.id };
      }

      const fuzzy = findBestMatch(rawName, allIngredients);
      if (fuzzy) {
        console.log(`  FUZZY  [${r.title}] "${rawName}" → ${fuzzy.name}`);
        fuzzyFixed++;
        return { entry: e, recipeTitle: r.title, resolved: fuzzy.id };
      }

      // "Tereyağı veya Sıvı Yağ" (incl. glued "Tereyağıveya ...") — map to the
      // first alternative when it resolves to an existing ingredient.
      if (/veya/i.test(norm)) {
        const first = norm.split(/\s*veya\s*|(?<=\S)veya\b/i)[0]?.trim();
        const alt = first ? byNorm.get(normalizeForMatch(fixTurkish(first))) : undefined;
        if (alt) {
          console.log(`  VEYA   [${r.title}] "${rawName}" → ${alt.name}`);
          exactFixed++;
          return { entry: e, recipeTitle: r.title, resolved: alt.id };
        }
      }

      if (!toCreate.has(norm)) toCreate.set(norm, fixTurkish(norm));
      console.log(`  CREATE [${r.title}] "${rawName}" → new row "${toCreate.get(norm)}"`);
      createNeeded++;
      return { entry: e, recipeTitle: r.title, createNorm: norm };
    });
    updates.push({ id: r.id, entries });
  }

  console.log(
    `\n${exactFixed} exact, ${fuzzyFixed} fuzzy, ${createNeeded} entries need ${toCreate.size} new ingredient rows`
  );
  if (toCreate.size > 0) {
    console.log(`New rows: ${[...toCreate.values()].sort().join(", ")}`);
  }

  if (!APPLY) {
    console.log("\nDry run only — rerun with --apply to execute.");
    await client.end();
    return;
  }

  await client.query("BEGIN");
  try {
    // Create missing ingredient rows (name has a unique constraint; on
    // conflict re-select so concurrent/NFC-equal names still resolve).
    const createdIds = new Map<string, string>(); // norm -> id
    for (const [norm, name] of toCreate) {
      const ins = await client.query<{ id: string }>(
        `INSERT INTO ingredients (name) VALUES ($1)
         ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name
         RETURNING id`,
        [name]
      );
      createdIds.set(norm, ins.rows[0].id);
    }

    for (const u of updates) {
      const finalEntries: Entry[] = u.entries.map((p) => {
        if (p.resolved) return { ...p.entry, ingredient_id: p.resolved };
        if (p.createNorm) return { ...p.entry, ingredient_id: createdIds.get(p.createNorm) ?? "" };
        return p.entry;
      });
      await client.query(
        `UPDATE recipes SET ingredients_with_measures = $1::jsonb WHERE id = $2::uuid`,
        [JSON.stringify(finalEntries), u.id]
      );
    }
    await client.query("COMMIT");
    console.log(`\nApplied: ${toCreate.size} ingredients created, ${updates.length} recipes updated.`);
  } catch (err) {
    await client.query("ROLLBACK");
    console.error("\nRolled back:", err);
    process.exitCode = 1;
  }
  await client.end();
}

main();
