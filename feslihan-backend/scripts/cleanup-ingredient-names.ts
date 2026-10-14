// One-off cleanup for ingredient rows polluted with measure words
// ("Adet Limon", "1 çay kaşığı tuz", "Yarım Demet Maydanoz", ...).
//
// For every row whose name carries a leading amount/unit, the core name is
// computed with the same logic the server now uses (splitAmountFromName).
// If a row with the core name already exists, the bad row is merged into it
// (all references remapped, bad row deleted); otherwise the bad row is
// renamed to the core name.
//
// Usage:
//   DATABASE_URL=postgres://... npx tsx scripts/cleanup-ingredient-names.ts           # dry run
//   DATABASE_URL=postgres://... npx tsx scripts/cleanup-ingredient-names.ts --apply   # execute

import pg from "pg";
import { splitAmountFromName, fixTurkish, normalizeForMatch } from "../src/ingredient-matching.js";

const APPLY = process.argv.includes("--apply");
const url = process.env.DATABASE_URL;
if (!url) {
  console.error("DATABASE_URL is required");
  process.exit(1);
}

// Oddball rows the generic amount-stripper can't resolve (free-text notes,
// combined ingredient lists). Matched by prefix against the DB name.
const MANUAL_OVERRIDES: { prefix: string; core: string }[] = [
  // Combined list — references can only point at one ingredient; keep the first.
  { prefix: "Tuz, Karabiber, Toz Tatlı Biber", core: "Tuz" },
  { prefix: "Bamyalar Suda Bekletmek", core: "Üzüm Sirkesi" },
  { prefix: "Yarım Su Bardağı Öğütülmüş Fındık Yerine", core: "Fındık" },
  { prefix: "Yarım Su Bardağı Pekmez", core: "Pekmez" },
  { prefix: "Dan 1 Parmak Eksik Yoğurt", core: "Yoğurt" },
  { prefix: "Karabiber, Pul Biber", core: "Karabiber" },
  { prefix: "Kızartma için Zeytinyağı", core: "Zeytinyağı" },
  { prefix: "Organik Kavrulmuş Kıyılmış Yer Fıstığı", core: "Yer Fıstığı" },
];

type Row = {
  id: string;
  name: string;
  price_tier: string | null;
  availability: string | null;
  price_per_unit: number | null;
};

function coreNameFor(name: string): string {
  const override = MANUAL_OVERRIDES.find((o) => name.startsWith(o.prefix));
  if (override) return override.core;
  return fixTurkish(splitAmountFromName(name).name);
}

function classScore(r: Row): number {
  return (r.price_tier ? 1 : 0) + (r.availability ? 1 : 0) + (r.price_per_unit ? 1 : 0);
}

async function mergeInto(client: pg.ClientBase, keep: Row, dupe: Row) {
  // user_pantry / user_shopping_list: drop the dupe where the user already
  // has the keep ingredient, remap the rest
  for (const table of ["user_pantry", "user_shopping_list"]) {
    await client.query(
      `DELETE FROM ${table}
       WHERE ingredient_id = $1::uuid
         AND user_id IN (SELECT user_id FROM ${table} WHERE ingredient_id = $2::uuid)`,
      [dupe.id, keep.id]
    );
    await client.query(
      `UPDATE ${table} SET ingredient_id = $2::uuid WHERE ingredient_id = $1::uuid`,
      [dupe.id, keep.id]
    );
  }

  // recipes.ingredients_without_measures: array of ID strings
  await client.query(
    `UPDATE recipes
     SET ingredients_without_measures = (
       SELECT jsonb_agg(CASE WHEN elem = $1::text THEN $2::text ELSE elem END)
       FROM jsonb_array_elements_text(ingredients_without_measures) AS elem
     )
     WHERE ingredients_without_measures::text LIKE '%' || $1 || '%'`,
    [dupe.id, keep.id]
  );

  // recipes.ingredients_with_measures: remap ingredient_id AND repair the
  // embedded display name — the stripped measure words move into amount
  // (e.g. name "Adet Limon", amount "1" → name "Limon", amount "1 adet").
  const split = splitAmountFromName(dupe.name);
  const strippedWords = split.name === dupe.name ? "" : split.amount.toLocaleLowerCase("tr-TR");
  await client.query(
    `UPDATE recipes
     SET ingredients_with_measures = (
       SELECT jsonb_agg(
         CASE
           WHEN elem->>'ingredient_id' = $1 THEN
             elem || jsonb_build_object(
               'ingredient_id', $2::text,
               'name', $3::text,
               'amount', btrim(concat(elem->>'amount', ' ', $4::text))
             )
           ELSE elem
         END
       )
       FROM jsonb_array_elements(ingredients_with_measures) AS elem
     )
     WHERE ingredients_with_measures::text LIKE '%' || $1 || '%'`,
    [dupe.id, keep.id, keep.name, strippedWords]
  );

  // meal_plans.shopping_ingredient_ids: array of ID strings
  await client.query(
    `UPDATE meal_plans
     SET shopping_ingredient_ids = (
       SELECT jsonb_agg(CASE WHEN elem = $1::text THEN $2::text ELSE elem END)
       FROM jsonb_array_elements_text(shopping_ingredient_ids) AS elem
     )
     WHERE shopping_ingredient_ids::text LIKE '%' || $1 || '%'`,
    [dupe.id, keep.id]
  );

  // meal_plans.shopping_list: array of objects with ingredient_id
  await client.query(
    `UPDATE meal_plans
     SET shopping_list = (
       SELECT jsonb_agg(
         CASE
           WHEN elem->>'ingredient_id' = $1
             THEN jsonb_set(elem, '{ingredient_id}', to_jsonb($2::text))
           ELSE elem
         END
       )
       FROM jsonb_array_elements(shopping_list) AS elem
     )
     WHERE shopping_list::text LIKE '%' || $1 || '%'`,
    [dupe.id, keep.id]
  );

  // ingredients.alternative_ids: array of ID strings (drop self-references)
  await client.query(
    `UPDATE ingredients
     SET alternative_ids = (
       SELECT COALESCE(jsonb_agg(DISTINCT new_elem), '[]'::jsonb)
       FROM (
         SELECT CASE WHEN elem = $1::text THEN $2::text ELSE elem END AS new_elem
         FROM jsonb_array_elements_text(alternative_ids) AS elem
       ) sub
       WHERE new_elem <> ingredients.id::text
     )
     WHERE alternative_ids::text LIKE '%' || $1 || '%'`,
    [dupe.id, keep.id]
  );

  await client.query(`DELETE FROM ingredients WHERE id = $1::uuid`, [dupe.id]);
}

async function main() {
  const client = new pg.Client({ connectionString: url });
  await client.connect();
  // Neon's pooler sometimes hands out sessions with an empty search_path
  await client.query(`SET search_path TO public`);

  const { rows } = await client.query<Row>(
    `SELECT id, name, price_tier, availability, price_per_unit FROM ingredients ORDER BY name`
  );
  console.log(`Loaded ${rows.length} ingredients (${APPLY ? "APPLY" : "DRY RUN"})\n`);

  const byName = new Map(rows.map((r) => [r.name, r]));
  const plans: { bad: Row; core: string; action: "merge" | "rename"; target?: Row }[] = [];

  // Group bad rows by their core name
  const badByCore = new Map<string, Row[]>();
  for (const row of rows) {
    const core = coreNameFor(row.name);
    if (!core || core.length < 2) {
      console.log(`SKIP (empty core): "${row.name}"`);
      continue;
    }
    if (core === row.name) continue; // already clean
    if (!badByCore.has(core)) badByCore.set(core, []);
    badByCore.get(core)!.push(row);
  }

  const cleanRows = rows.filter((r) => coreNameFor(r.name) === r.name);

  for (const [core, badRows] of badByCore) {
    let target = byName.get(core);
    // Fallback for qualifier-only differences ("Haşlanmış Patates" →
    // "Patates"): exact match after prefix normalization — deliberately NOT
    // Dice similarity, which false-positives on pairs like "Kesme Şeker" /
    // "Esmer Şeker". Skipped for "Taze X" on either side — taze soğan/fasulye
    // are distinct vegetables, not qualified forms of soğan/fasulye.
    if (!target && !/^taze /i.test(core)) {
      const normCore = normalizeForMatch(core);
      const m = cleanRows.find((r) => !/^taze /i.test(r.name) && normalizeForMatch(r.name) === normCore);
      if (m) target = byName.get(m.name);
    }
    const sorted = badRows.sort((a, b) => classScore(b) - classScore(a));
    for (const bad of sorted) {
      if (target) {
        plans.push({ bad, core, action: "merge", target });
      } else {
        // No clean row with this name exists yet: rename the best bad row,
        // it becomes the merge target for the rest of the group.
        plans.push({ bad, core, action: "rename" });
        target = { ...bad, name: core };
        byName.set(core, target);
      }
    }
  }

  if (plans.length === 0) {
    console.log("Nothing to clean up.");
    await client.end();
    return;
  }

  for (const p of plans) {
    if (p.action === "merge") {
      console.log(`MERGE  "${p.bad.name}" → "${p.target!.name}" (${p.target!.id})`);
    } else {
      console.log(`RENAME "${p.bad.name}" → "${p.core}"`);
    }
  }
  console.log(`\n${plans.length} actions (${plans.filter((p) => p.action === "merge").length} merges, ${plans.filter((p) => p.action === "rename").length} renames)`);

  if (!APPLY) {
    console.log("\nDry run only — rerun with --apply to execute.");
    await client.end();
    return;
  }

  await client.query("BEGIN");
  try {
    for (const p of plans) {
      if (p.action === "rename") {
        await client.query(`UPDATE ingredients SET name = $1 WHERE id = $2::uuid`, [p.core, p.bad.id]);
        // Repair embedded display names in recipes for the renamed row too
        const split = splitAmountFromName(p.bad.name);
        const strippedWords = split.name === p.bad.name ? "" : split.amount.toLocaleLowerCase("tr-TR");
        await client.query(
          `UPDATE recipes
           SET ingredients_with_measures = (
             SELECT jsonb_agg(
               CASE
                 WHEN elem->>'ingredient_id' = $1 THEN
                   elem || jsonb_build_object(
                     'name', $2::text,
                     'amount', btrim(concat(elem->>'amount', ' ', $3::text))
                   )
                 ELSE elem
               END
             )
             FROM jsonb_array_elements(ingredients_with_measures) AS elem
           )
           WHERE ingredients_with_measures::text LIKE '%' || $1 || '%'`,
          [p.bad.id, p.core, strippedWords]
        );
      } else {
        await mergeInto(client, p.target!, p.bad);
      }
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
