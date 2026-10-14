// One-off repair for recipes.ingredients_with_measures entries whose
// ingredient_id points at a deleted ingredient row (left behind by old
// merge/consolidate runs that didn't update this jsonb column).
//
// For each dangling entry the embedded display name is re-resolved against
// the current ingredients table (exact match after measure/qualifier
// normalization — never fuzzy, never creates rows). Unresolvable entries get
// ingredient_id "" so they stop pretending to reference something.
//
// Usage:
//   DATABASE_URL=postgres://... npx tsx scripts/repair-dangling-ingredient-refs.ts           # dry run
//   DATABASE_URL=postgres://... npx tsx scripts/repair-dangling-ingredient-refs.ts --apply   # execute

import pg from "pg";
import { splitAmountFromName, normalizeForMatch, fixTurkish } from "../src/ingredient-matching.js";

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
  const byNorm = new Map<string, { id: string; name: string }>();
  for (const i of ings) {
    const norm = normalizeForMatch(i.name);
    // Prefer the row whose name IS the normalized core (shortest canonical)
    const prev = byNorm.get(norm);
    if (!prev || i.name.length < prev.name.length) byNorm.set(norm, i);
  }
  const validIds = new Set(ings.map((i) => i.id));

  const { rows: recipes } = await client.query<{ id: string; title: string; ingredients_with_measures: Entry[] }>(
    `SELECT id, title, ingredients_with_measures FROM recipes
     WHERE EXISTS (
       SELECT 1 FROM jsonb_array_elements(ingredients_with_measures) elem
       WHERE COALESCE(elem->>'ingredient_id', '') <> ''
         AND NOT EXISTS (SELECT 1 FROM ingredients i WHERE i.id::text = elem->>'ingredient_id')
     )`
  );
  console.log(`${recipes.length} recipes with dangling ingredient refs (${APPLY ? "APPLY" : "DRY RUN"})\n`);

  let fixedEntries = 0;
  let clearedEntries = 0;
  const updates: { id: string; entries: Entry[] }[] = [];

  for (const r of recipes) {
    const entries = r.ingredients_with_measures.map((e) => {
      const iid = e.ingredient_id ?? "";
      if (!iid || validIds.has(iid)) return e;

      const rawName = (e.name ?? "").trim();
      const split = splitAmountFromName(rawName);
      const match = byNorm.get(normalizeForMatch(rawName));
      if (match) {
        const strippedWords = split.name === rawName ? "" : split.amount.toLocaleLowerCase("tr-TR");
        const amount = `${e.amount ?? ""} ${strippedWords}`.replace(/\s+/g, " ").trim();
        console.log(`  FIX   [${r.title}] "${rawName}" → "${fixTurkish(split.name)}" (${match.name})`);
        fixedEntries++;
        return { ...e, name: fixTurkish(split.name), amount, ingredient_id: match.id };
      }
      console.log(`  CLEAR [${r.title}] "${rawName}" (no match, ingredient_id → "")`);
      clearedEntries++;
      return { ...e, ingredient_id: "" };
    });
    updates.push({ id: r.id, entries });
  }

  console.log(`\n${fixedEntries} entries re-linked, ${clearedEntries} cleared across ${updates.length} recipes`);

  if (!APPLY) {
    console.log("\nDry run only — rerun with --apply to execute.");
    await client.end();
    return;
  }

  await client.query("BEGIN");
  try {
    for (const u of updates) {
      await client.query(
        `UPDATE recipes SET ingredients_with_measures = $1::jsonb WHERE id = $2::uuid`,
        [JSON.stringify(u.entries), u.id]
      );
    }
    await client.query("COMMIT");
    console.log("\nApplied and committed.");
  } catch (err) {
    await client.query("ROLLBACK");
    console.error("\nRolled back:", err);
    process.exitCode = 1;
  }
  await client.end();
}

main();
