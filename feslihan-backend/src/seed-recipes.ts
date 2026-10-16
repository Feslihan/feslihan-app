import { db } from "./db.js";
import { recipes, ingredients, tags, platformCreators, userRecipes, users } from "./schema.js";
import { eq, sql, inArray } from "drizzle-orm";

const FESLIHAN_CREATOR = {
  username: "feslihan",
  platform: "other" as const,
  displayName: "Feslihan",
  profilePictureUrl: null,
};

import { PLATFORM_RECIPES } from "./platform-recipes-data.js";
export { PLATFORM_RECIPES } from "./platform-recipes-data.js";

// Helper: resolve ingredient names to IDs, creating new ones if needed
async function resolveIngredientIds(
  names: string[]
): Promise<Map<string, string>> {
  const map = new Map<string, string>();
  if (names.length === 0) return map;

  const unique = [...new Set(names)];

  const existing = await db
    .select({ id: ingredients.id, name: ingredients.name })
    .from(ingredients)
    .where(inArray(ingredients.name, unique));

  for (const r of existing) map.set(r.name, r.id);

  const missing = unique.filter((n) => !map.has(n));
  if (missing.length > 0) {
    const inserted = await db
      .insert(ingredients)
      .values(missing.map((name) => ({ name })))
      .onConflictDoNothing()
      .returning();
    for (const r of inserted) map.set(r.name, r.id);

    const stillMissing = missing.filter((n) => !map.has(n));
    if (stillMissing.length > 0) {
      const refetched = await db
        .select({ id: ingredients.id, name: ingredients.name })
        .from(ingredients)
        .where(inArray(ingredients.name, stillMissing));
      for (const r of refetched) map.set(r.name, r.id);
    }
  }

  return map;
}

async function resolveTagIds(names: string[]): Promise<string[]> {
  if (names.length === 0) return [];
  const rows = await db
    .select({ id: tags.id, name: tags.name })
    .from(tags)
    .where(inArray(tags.name, names));
  const nameToId = new Map(rows.map((r) => [r.name, r.id]));
  return names.map((n) => nameToId.get(n)).filter(Boolean) as string[];
}

export async function seedPlatformRecipes(): Promise<void> {
  await db
    .insert(platformCreators)
    .values(FESLIHAN_CREATOR)
    .onConflictDoNothing();

  const existingUrls = await db
    .select({ url: recipes.url })
    .from(recipes)
    .where(sql`${recipes.url} LIKE 'feslihan://%'`);
  const existingSet = new Set(existingUrls.map((r) => r.url));

  const toInsert = PLATFORM_RECIPES.filter(
    (r) => !existingSet.has(`feslihan://${r.slug}`)
  );

  if (toInsert.length === 0) {
    console.log(`[Seed] All ${PLATFORM_RECIPES.length} platform recipes already exist`);
    return;
  }

  const allIngNames = new Set<string>();
  for (const r of toInsert) {
    for (const i of r.ingredientsWithMeasures) allIngNames.add(i.name);
  }
  const ingMap = await resolveIngredientIds([...allIngNames]);

  for (const r of toInsert) {
    const tagIds = await resolveTagIds(r.tags);
    const ingWithMeasures = r.ingredientsWithMeasures.map((i) => ({
      name: i.name,
      amount: i.amount,
      ...(i.section ? { section: i.section } : {}),
      ingredient_id: ingMap.get(i.name) ?? "",
    }));
    const ingWithoutMeasures = r.ingredientsWithMeasures
      .map((i) => ingMap.get(i.name))
      .filter(Boolean) as string[];

    await db.insert(recipes).values({
      platform: "other",
      platformUser: "feslihan",
      url: `feslihan://${r.slug}`,
      title: r.title,
      description: r.description,
      ingredientsWithMeasures: ingWithMeasures,
      ingredientsWithoutMeasures: [...new Set(ingWithoutMeasures)],
      tags: tagIds,
      cookingTimeMinutes: r.cookingTimeMinutes,
      servings: r.servings,
      cuisine: r.cuisine,
      difficulty: r.difficulty,
      caloriesTotalKcal: r.caloriesTotalKcal,
      caloriesPerServingKcal: r.caloriesPerServingKcal,
      proteinGrams: r.proteinGrams,
      carbsGrams: r.carbsGrams,
      fatGrams: r.fatGrams,
      fiberGrams: r.fiberGrams,
      freezerFriendly: r.freezerFriendly,
      requestedBy: "system",
      saveCount: 0,
    });
  }

  console.log(`[Seed] Inserted ${toInsert.length} platform recipes`);
}

export async function getPlatformRecipeIds(): Promise<string[]> {
  const rows = await db
    .select({ id: recipes.id })
    .from(recipes)
    .where(sql`${recipes.url} LIKE 'feslihan://%'`);
  return rows.map((r) => r.id);
}

export async function mapPlatformRecipesToUser(userId: string): Promise<number> {
  const recipeIds = await getPlatformRecipeIds();
  if (recipeIds.length === 0) return 0;

  let mapped = 0;
  for (const recipeId of recipeIds) {
    const inserted = await db
      .insert(userRecipes)
      .values({ userId, recipeId })
      .onConflictDoNothing()
      .returning();
    if (inserted.length > 0) mapped++;
  }

  return mapped;
}
