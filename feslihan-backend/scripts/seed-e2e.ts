/**
 * Seeds the database for iOS end-to-end UI tests.
 *
 * Prerequisites: migrations applied (npm run db:migrate) and the server booted
 * at least once so seedTags()/seedPlatformRecipes() have populated tags,
 * platform recipes, and ingredients. Run it AFTER the backend is up:
 *
 *   E2E_CLERK_USER_ID=user_xxx node --env-file=.env --import tsx/esm scripts/seed-e2e.ts
 *
 * What it does (idempotent):
 *   1. Upserts the Clerk test user with subscription_plan = 'pro' so the
 *      meal-plan premium gate and AI quota never block tests.
 *   2. Maps all platform recipes to the user (Tariflerim content). This
 *      mirrors what POST /users/sync does for brand-new users — we pre-create
 *      the user row, so that path would otherwise be skipped.
 *   3. Fills the pantry with 35 ingredients so the 30-item pantry gate in the
 *      app is satisfied.
 */
import { db } from "../src/db.js";
import { users, ingredients, userPantry } from "../src/schema.js";
import { mapPlatformRecipesToUser } from "../src/seed-recipes.js";
import { asc, eq } from "drizzle-orm";

const PANTRY_TARGET = 35;

async function main() {
  const clerkUserId = process.env.E2E_CLERK_USER_ID;
  if (!clerkUserId) {
    console.error("E2E_CLERK_USER_ID is required (the Clerk user id of the test account)");
    process.exit(1);
  }
  const email = process.env.E2E_CLERK_EMAIL ?? null;

  // 1. Test user with pro plan.
  await db
    .insert(users)
    .values({
      clerkId: clerkUserId,
      email,
      name: "E2E Test",
      subscriptionPlan: "pro",
    })
    .onConflictDoUpdate({
      target: users.clerkId,
      set: { subscriptionPlan: "pro", recipesUsedThisMonth: 0 },
    });
  console.log(`[seed-e2e] User ${clerkUserId} upserted with plan=pro`);

  // 2. Platform recipes → user's collection.
  const mapped = await mapPlatformRecipesToUser(clerkUserId);
  console.log(`[seed-e2e] Mapped ${mapped} platform recipes to the test user`);

  // 3. Pantry: top up to PANTRY_TARGET items.
  const existing = await db
    .select({ ingredientId: userPantry.ingredientId })
    .from(userPantry)
    .where(eq(userPantry.userId, clerkUserId));
  const have = new Set(existing.map((r) => r.ingredientId));

  if (have.size < PANTRY_TARGET) {
    const candidates = await db
      .select({ id: ingredients.id, name: ingredients.name })
      .from(ingredients)
      .orderBy(asc(ingredients.name))
      .limit(PANTRY_TARGET + have.size);

    const toAdd = candidates.filter((c) => !have.has(c.id)).slice(0, PANTRY_TARGET - have.size);
    if (toAdd.length === 0) {
      console.error(
        "[seed-e2e] No ingredients available to seed the pantry — did the server boot (seedPlatformRecipes) run against this database?"
      );
      process.exit(1);
    }

    await db
      .insert(userPantry)
      .values(toAdd.map((c) => ({ userId: clerkUserId, ingredientId: c.id })));
    console.log(`[seed-e2e] Added ${toAdd.length} pantry items (${have.size} already present)`);
  } else {
    console.log(`[seed-e2e] Pantry already has ${have.size} items`);
  }

  const total = await db
    .select({ ingredientId: userPantry.ingredientId })
    .from(userPantry)
    .where(eq(userPantry.userId, clerkUserId));
  if (total.length < 30) {
    console.error(`[seed-e2e] Pantry has only ${total.length} items; the app's 30-item gate will block tests`);
    process.exit(1);
  }

  console.log(`[seed-e2e] Done — pantry has ${total.length} items`);
  process.exit(0);
}

main().catch((err) => {
  console.error("[seed-e2e] Failed:", err);
  process.exit(1);
});
