import "dotenv/config";
import express from "express";
import https from "https";
import { db } from "./db.js";
import { recipes, ingredients, tags, platformCreators, userRecipes, userFolders, users, mealPlans, userPantry, userShoppingList, recipeReviews, connections, recipeShares, deviceTokens } from "./schema.js";
import { createSocialRouter } from "./routes/social.js";
import { createLegalRouter } from "./routes/legal.js";
import { createWebhooksRouter } from "./routes/webhooks.js";
import { uploadImage, s3KeyFromUrl, getImage } from "./s3.js";
import { analyzeRecipe, analyzeNutrition, generateMealPlan, classifyIngredients, classifyFreezerFriendly, findAlternativeIngredients } from "./ai.js";
import { eq, desc, inArray, and, or, sql, isNull, lt } from "drizzle-orm";
import { seedPlatformRecipes, mapPlatformRecipesToUser } from "./seed-recipes.js";
import { requireAuth, requireAdmin } from "./middleware/auth.js";
import { createClerkClient } from "@clerk/backend";
import { safeFetchText, UrlNotAllowedError } from "./security/ssrf.js";
import { rateLimit } from "./middleware/rate-limit.js";
import { reserveRecipeQuota, refundRecipeQuota, reserveMealPlanQuota, refundMealPlanQuota, getQuotaStatus, newUserTrialEnd, PLAN_LIMITS, MEAL_PLAN_LIMITS, QuotaError } from "./quota.js";
import { enqueueJob, registerJobHandler, startJobWorker } from "./jobs.js";
import { fixTurkish, findBestMatch, splitAmountFromName } from "./ingredient-matching.js";

// Burst protection for the expensive AI routes (per authenticated user).
const aiRateLimit = rateLimit({ windowMs: 60_000, max: 10, name: "ai" });

const app = express();

// Body-size caps, applied before parsing so oversized payloads are rejected
// (413) without buffering the full body. The AI routes are capped well below
// the global 50MB: /ai/meal-plan is pure JSON, and /ai/analyze only needs room
// for base64 frames + audio. Recipe uploads elsewhere still allow 50MB thumbs.
const jsonGlobal = express.json({ limit: "50mb" });
const jsonAiAnalyze = express.json({ limit: "12mb" });
const jsonAiMealPlan = express.json({ limit: "256kb" });
app.use((req, res, next) => {
  if (req.path === "/ai/analyze") return jsonAiAnalyze(req, res, next);
  if (req.path === "/ai/meal-plan") return jsonAiMealPlan(req, res, next);
  return jsonGlobal(req, res, next);
});

const PREDEFINED_TAGS = [
  "meze",
  "tatlı",
  "tuzlu",
  "atıştırmalık",
  "ana yemek",
  "çorba",
  "salata",
  "kahvaltı",
  "aperatif",
  "içecek",
  "hamur işi",
  "kek",
  "kurabiye",
  "pilav",
  "makarna",
  "et",
  "tavuk",
  "balık",
  "deniz ürünü",
  "vegan",
  "vejetaryen",
  "glutensiz",
  "hafif",
  "doyurucu",
  "pratik",
  "tek kişilik",
  "misafirler için",
  "çocuklar için",
  "diyet",
  "sağlıklı",
  "sokak lezzeti",
  "fast food",
  "geleneksel",
  "fırın",
  "ızgara",
  "kızartma",
];

// Request logging
app.use((req, _res, next) => {
  const body = req.body;
  const bodySize = JSON.stringify(body || {}).length;
  console.log(`[${new Date().toLocaleTimeString()}] ${req.method} ${req.path} (${(bodySize / 1024).toFixed(1)}KB)`);
  if (body && req.method === "POST") {
    console.log(`  title: ${body.title || "-"}`);
    console.log(`  url: ${body.url || "-"}`);
    console.log(`  thumbnail_base64: ${body.thumbnail_base64 ? `${(body.thumbnail_base64.length / 1024).toFixed(0)}KB` : "MISSING"}`);
    console.log(`  cuisine: ${body.cuisine || "-"}, difficulty: ${body.difficulty || "-"}, cooking_time: ${body.cooking_time || "-"}`);
    console.log(`  calories: ${body.calories_total_kcal || "-"}, servings: ${body.servings || "-"}`);
    console.log(`  ingredients: ${body.ingredients_without_measures?.length || 0} base items`);
  }
  next();
});

// Public routes that do not require authentication:
// - image serving (fetched by AsyncImage / plain GETs that cannot carry a token)
// - legal pages (linked from the sign-up screen and App Store listing)
// - RevenueCat webhook (authenticated by its own shared secret in the handler)
function isPublicRoute(req: express.Request): boolean {
  if (req.method === "POST" && req.path === "/webhooks/revenuecat") return true;
  if (req.method !== "GET") return false;
  if (/^\/images\/[^/]+\/[^/]+$/.test(req.path)) return true;
  return ["/kosullar", "/gizlilik", "/kvkk"].includes(req.path);
}

// CORS for the browser-based admin panel ONLY. The iOS app never needs CORS;
// no other web origin is allowed. Must run before the auth gate because
// preflight OPTIONS requests carry no bearer token.
const ALLOWED_WEB_ORIGINS = new Set(
  [
    "https://admin.feslihan.com.tr",
    "https://feslihan-admin.vercel.app", // canonical Vercel URL (pre-DNS fallback)
    "http://localhost:3000", // admin panel local dev
    ...(process.env.ADMIN_CORS_ORIGINS || "").split(",").map((s) => s.trim()),
  ].filter(Boolean)
);

app.use((req, res, next) => {
  const origin = req.headers.origin;
  if (origin && ALLOWED_WEB_ORIGINS.has(origin)) {
    res.setHeader("Access-Control-Allow-Origin", origin);
    res.setHeader("Vary", "Origin");
    res.setHeader("Access-Control-Allow-Headers", "Authorization, Content-Type");
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
    res.setHeader("Access-Control-Max-Age", "86400");
  }
  if (req.method === "OPTIONS") {
    res.status(204).end();
    return;
  }
  next();
});

// Global authentication gate: every request except the public allowlist must
// carry a valid Clerk session JWT. Identity is derived from the token (req.auth).
app.use((req, res, next) => {
  if (isPublicRoute(req)) {
    next();
    return;
  }
  requireAuth(req, res, next);
});

// Social graph: friend codes, follow requests, friend recipes, recipe shares.
// Mounted behind the global auth gate like every other route.
app.use(createSocialRouter({ toSnake, enrichRecipes, rewriteThumbnail }));

// Public legal pages (Kullanım Koşulları, Gizlilik, KVKK).
app.use(createLegalRouter());

// RevenueCat webhook (shared-secret auth; keeps subscription_plan in sync).
app.use(createWebhooksRouter());

function toSnake(obj: any): any {
  if (Array.isArray(obj)) return obj.map(toSnake);
  if (obj !== null && typeof obj === "object" && !(obj instanceof Date)) {
    return Object.fromEntries(
      Object.entries(obj).map(([k, v]) => [
        k.replace(/[A-Z]/g, (c) => `_${c.toLowerCase()}`),
        v instanceof Date ? v.toISOString() : toSnake(v),
      ])
    );
  }
  return obj;
}

function rewriteThumbnail(obj: any): any {
  if (Array.isArray(obj)) return obj.map(rewriteThumbnail);
  if (obj && typeof obj === "object" && obj.thumbnail_url) {
    const key = s3KeyFromUrl(obj.thumbnail_url);
    if (key) {
      return { ...obj, thumbnail_url: `/images/${key}` };
    }
  }
  return obj;
}

function parseCookingTime(str: string | null | undefined): number | null {
  if (!str) return null;
  const lower = str.toLowerCase().trim();
  let total = 0;
  // "1 sa 15 dk" or "1.5 sa 30 dk"
  const hourMatch = lower.match(/([\d.,]+)\s*sa/);
  if (hourMatch) total += Math.round(parseFloat(hourMatch[1].replace(",", ".")) * 60);
  const minMatch = lower.match(/([\d.,]+)\s*dk/);
  if (minMatch) total += Math.round(parseFloat(minMatch[1].replace(",", ".")));
  if (total > 0) return total;
  // Plain number -> assume minutes
  const num = parseFloat(lower);
  if (!isNaN(num)) return Math.round(num);
  return null;
}

function parseCount(str: string): number | null {
  if (!str) return null;
  const lower = str.toLowerCase().replace(/,/g, "");
  const num = parseFloat(lower);
  if (isNaN(num)) return null;
  if (lower.endsWith("k")) return Math.round(num * 1000);
  if (lower.endsWith("m")) return Math.round(num * 1000000);
  return Math.round(num);
}

function parseCaptionMeta(caption: string | null | undefined) {
  if (!caption) return { likesCount: null, commentsCount: null, platformUser: null };

  let likesCount: number | null = null;
  let commentsCount: number | null = null;
  let platformUser: string | null = null;

  // Instagram: "27K likes, 540 comments - username on ..."
  const likesMatch = caption.match(/^([\d.,]+[KkMm]?)\s+likes?/i);
  if (likesMatch) likesCount = parseCount(likesMatch[1]);

  const commentsMatch = caption.match(/([\d.,]+[KkMm]?)\s+comments?/i);
  if (commentsMatch) commentsCount = parseCount(commentsMatch[1]);

  const userMatch = caption.match(/comments?\s*-\s*(\S+)\s+on\s/i)
    || caption.match(/^(\S+)\s+on\s+\w+\s+\d/i);
  if (userMatch) platformUser = userMatch[1];

  // TikTok: caption often contains "@username" or "username on TikTok"
  if (!platformUser) {
    const tiktokMatch = caption.match(/@(\w[\w.]+)/);
    if (tiktokMatch) platformUser = tiktokMatch[1];
  }

  return { likesCount, commentsCount, platformUser };
}

function extractUserFromURL(url: string): string | null {
  // TikTok: tiktok.com/@username/video/...
  const tiktokMatch = url.match(/tiktok\.com\/@([^/]+)/i);
  if (tiktokMatch) return tiktokMatch[1];

  // X/Twitter: x.com/username/status/...
  const xMatch = url.match(/(?:x\.com|twitter\.com)\/([^/]+)\/status/i);
  if (xMatch) return xMatch[1];

  return null;
}

// Cached ingredient list — refreshed per request batch
let _cachedIngredients: { id: string; name: string }[] | null = null;
let _cacheTime = 0;

async function getAllIngredients(): Promise<{ id: string; name: string }[]> {
  const now = Date.now();
  if (_cachedIngredients && now - _cacheTime < 10_000) return _cachedIngredients;
  _cachedIngredients = await db.select({ id: ingredients.id, name: ingredients.name }).from(ingredients);
  _cacheTime = now;
  return _cachedIngredients;
}

async function saveUserRecipe(userId: string, recipeId: string) {
  const inserted = await db
    .insert(userRecipes)
    .values({ userId, recipeId })
    .onConflictDoNothing()
    .returning();
  if (inserted.length > 0) {
    await db.update(recipes).set({ saveCount: sql`${recipes.saveCount} + 1` }).where(eq(recipes.id, recipeId));
  }
}

function invalidateIngredientCache() {
  _cachedIngredients = null;
}

// Classify ingredients missing price_tier/availability — runs in background, non-blocking
async function classifyNewIngredients(ids: string[]) {
  if (ids.length === 0) return;
  try {
    const rows = await db
      .select({ id: ingredients.id, name: ingredients.name, priceTier: ingredients.priceTier, availability: ingredients.availability })
      .from(ingredients)
      .where(inArray(ingredients.id, ids));

    const unclassified = rows.filter((r) => !r.priceTier || !r.availability);
    if (unclassified.length === 0) return;

    const names = unclassified.map((r) => r.name);
    console.log(`[Classify] Auto-classifying ${names.length} ingredients: ${names.join(", ")}`);

    const results = await classifyIngredients(names);
    for (const item of results) {
      const match = unclassified.find((r) => r.name.toLocaleLowerCase("tr-TR") === item.name.toLocaleLowerCase("tr-TR"));
      if (!match) continue;

      const updates: Record<string, string> = {};
      if (!match.priceTier && ["cheap", "neutral", "expensive"].includes(item.price_tier)) {
        updates.priceTier = item.price_tier;
      }
      if (!match.availability && ["easy", "neutral", "rare"].includes(item.availability)) {
        updates.availability = item.availability;
      }
      if (Object.keys(updates).length > 0) {
        await db.update(ingredients).set(updates).where(eq(ingredients.id, match.id));
      }
    }
    console.log(`[Classify] Done classifying ${unclassified.length} ingredients`);
  } catch (err: any) {
    console.error("[Classify] Auto-classify failed (non-blocking):", err.message || err);
  }
}

// Resolve ingredient names to IDs — exact + fuzzy match only, never creates new rows
async function lookupIngredientMap(names: string[]): Promise<Map<string, string>> {
  const nameToId = new Map<string, string>();
  if (!names || names.length === 0) return nameToId;

  const normalized = names.map((n) => fixTurkish(n)).filter(Boolean);
  if (normalized.length === 0) return nameToId;

  const unique = [...new Set(normalized)];

  // Step 1: Try exact match
  const existing = await db
    .select({ id: ingredients.id, name: ingredients.name })
    .from(ingredients)
    .where(inArray(ingredients.name, unique));

  for (const r of existing) nameToId.set(r.name, r.id);
  const unmatched = unique.filter((n) => !nameToId.has(n));

  // Step 2: Fuzzy match against all existing ingredients
  if (unmatched.length > 0) {
    const allIngs = await getAllIngredients();
    for (const name of unmatched) {
      const match = findBestMatch(name, allIngs);
      if (match) {
        nameToId.set(name, match.id);
        console.log(`[Ingredient] Fuzzy matched "${name}" → "${match.name}"`);
      }
    }
  }

  return nameToId;
}

// Resolve ingredient names to IDs — creates new rows for truly unknown ingredients
async function resolveIngredientMap(names: string[]): Promise<Map<string, string>> {
  const nameToId = await lookupIngredientMap(names);

  const normalized = names.map((n) => fixTurkish(n)).filter(Boolean);
  const unique = [...new Set(normalized)];
  const stillNew = unique.filter((n) => !nameToId.has(n));

  if (stillNew.length > 0) {
    const inserted = await db
      .insert(ingredients)
      .values(stillNew.map((name) => ({ name })))
      .onConflictDoNothing()
      .returning();
    for (const row of inserted) {
      nameToId.set(row.name, row.id);
    }
    invalidateIngredientCache();
    console.log(`[Ingredient] Created ${stillNew.length} new: ${stillNew.join(", ")}`);
  }

  // Classify any unclassified ingredients via a durable job (don't block the
  // response, and don't lose the work on a serverless cold-start).
  const allResolvedIds = [...nameToId.values()];
  if (allResolvedIds.length > 0) {
    await enqueueJob("classify-ingredients", { ids: allResolvedIds }).catch((err) =>
      console.error("[Classify] Failed to enqueue:", err?.message || err)
    );
  }

  return nameToId;
}

async function resolveIngredientIds(names: string[]): Promise<string[]> {
  if (!names || names.length === 0) return [];
  const normalized = names.map((n) => fixTurkish(n)).filter(Boolean);
  const nameToId = await resolveIngredientMap(names);
  return normalized.map((n) => nameToId.get(n)).filter(Boolean) as string[];
}

type ShoppingListItem = { name: string; amount: string; ingredient_id: string };

async function buildShoppingListFromRecipes(recipeIds: string[]): Promise<ShoppingListItem[]> {
  if (!recipeIds || recipeIds.length === 0) return [];

  const recipeRows = await db
    .select({
      ingredientsWithMeasures: recipes.ingredientsWithMeasures,
    })
    .from(recipes)
    .where(inArray(recipes.id, recipeIds));

  // Aggregate ingredients, dedup by name
  const map = new Map<string, { displayName: string; amounts: string[] }>();
  const order: string[] = [];

  for (const row of recipeRows) {
    const ings = row.ingredientsWithMeasures as { name: string; amount: string }[] ?? [];
    for (const ing of ings) {
      const name = (ing.name ?? "").trim();
      const amount = (ing.amount ?? "").trim();
      if (!name) continue;
      const key = name.toLocaleLowerCase("tr-TR");
      if (!map.has(key)) {
        order.push(key);
        map.set(key, { displayName: name, amounts: [] });
      }
      if (amount) {
        map.get(key)!.amounts.push(amount);
      }
    }
  }

  // Resolve ingredient IDs — lookup only: display names may carry measure
  // words ("1 çay kaşığı tuz") and must never create ingredient rows.
  const displayNames = order.map((k) => map.get(k)!.displayName);
  const idMap = await lookupIngredientMap(displayNames);

  return order.map((key) => {
    const entry = map.get(key)!;
    const fixedName = fixTurkish(entry.displayName);
    const amounts = entry.amounts;
    const amount =
      amounts.length === 0 ? "" :
      amounts.length === 1 ? amounts[0] :
      amounts.join(" + ");
    return {
      name: entry.displayName,
      amount,
      ingredient_id: idMap.get(fixedName) ?? "",
    };
  }).filter((item) => item.ingredient_id);
}

async function resolveIngredientNames(ids: string[]): Promise<string[]> {
  if (!ids || ids.length === 0) return [];
  // Filter out any non-UUID values (legacy string names)
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const validIds = ids.filter((id) => uuidPattern.test(id));
  if (validIds.length === 0) return ids; // already names, return as-is

  const rows = await db
    .select({ id: ingredients.id, name: ingredients.name })
    .from(ingredients)
    .where(inArray(ingredients.id, validIds));

  const idToName = new Map(rows.map((r) => [r.id, r.name]));
  return ids.map((id) => idToName.get(id) ?? id);
}

async function resolveTagIds(names: string[]): Promise<string[]> {
  if (!names || names.length === 0) return [];
  const unique = [...new Set(names)];

  const existing = await db
    .select({ id: tags.id, name: tags.name })
    .from(tags)
    .where(inArray(tags.name, unique));

  const nameToId = new Map(existing.map((r) => [r.name, r.id]));
  return names.map((n) => nameToId.get(n)).filter(Boolean) as string[];
}

async function resolveTagNames(ids: string[]): Promise<string[]> {
  if (!ids || ids.length === 0) return [];
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const validIds = ids.filter((id) => uuidPattern.test(id));
  if (validIds.length === 0) return ids; // already names, return as-is

  const rows = await db
    .select({ id: tags.id, name: tags.name })
    .from(tags)
    .where(inArray(tags.id, validIds));

  const idToName = new Map(rows.map((r) => [r.id, r.name]));
  return ids.map((id) => idToName.get(id) ?? id);
}

// Attach the canonical ingredient name to each ingredients_with_measures
// entry as base_name. Clients must use this (not positional pairing with
// ingredients_without_measures) for pantry/shopping-list matching.
function attachBaseNames(entries: any[], idToName: Map<string, string>): any[] {
  return entries.map((e) => {
    const name = e?.ingredient_id ? idToName.get(e.ingredient_id) : undefined;
    return name ? { ...e, base_name: name } : e;
  });
}

async function enrichRecipe(recipe: any): Promise<any> {
  const obj = rewriteThumbnail(toSnake(recipe));
  if (obj.ingredients_without_measures && Array.isArray(obj.ingredients_without_measures)) {
    obj.ingredients_without_measures = await resolveIngredientNames(obj.ingredients_without_measures);
  }
  if (Array.isArray(obj.ingredients_with_measures)) {
    const ids = [...new Set(
      obj.ingredients_with_measures.map((e: any) => e?.ingredient_id).filter(Boolean)
    )] as string[];
    if (ids.length > 0) {
      const rows = await db
        .select({ id: ingredients.id, name: ingredients.name })
        .from(ingredients)
        .where(inArray(ingredients.id, ids));
      obj.ingredients_with_measures = attachBaseNames(
        obj.ingredients_with_measures,
        new Map(rows.map((r) => [r.id, r.name]))
      );
    }
  }
  if (obj.tags && Array.isArray(obj.tags)) {
    obj.tags = await resolveTagNames(obj.tags);
  }
  return obj;
}

async function enrichRecipes(recipes: any[]): Promise<any[]> {
  // Batch resolve all IDs at once for efficiency
  const allIngIds = new Set<string>();
  const allTagIds = new Set<string>();
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  for (const r of recipes) {
    const ings = (r.ingredientsWithoutMeasures ?? r.ingredients_without_measures) as string[] | null;
    if (ings) ings.filter((id: string) => uuidPattern.test(id)).forEach((id: string) => allIngIds.add(id));
    const withMeasures = (r.ingredientsWithMeasures ?? r.ingredients_with_measures) as any[] | null;
    if (withMeasures) {
      withMeasures
        .map((e) => e?.ingredient_id)
        .filter((id: string) => id && uuidPattern.test(id))
        .forEach((id: string) => allIngIds.add(id));
    }
    const ts = (r.tags ?? r.tags) as string[] | null;
    if (ts) ts.filter((id: string) => uuidPattern.test(id)).forEach((id: string) => allTagIds.add(id));
  }

  let ingIdToName = new Map<string, string>();
  if (allIngIds.size > 0) {
    const rows = await db
      .select({ id: ingredients.id, name: ingredients.name })
      .from(ingredients)
      .where(inArray(ingredients.id, [...allIngIds]));
    ingIdToName = new Map(rows.map((r) => [r.id, r.name]));
  }

  let tagIdToName = new Map<string, string>();
  if (allTagIds.size > 0) {
    const rows = await db
      .select({ id: tags.id, name: tags.name })
      .from(tags)
      .where(inArray(tags.id, [...allTagIds]));
    tagIdToName = new Map(rows.map((r) => [r.id, r.name]));
  }

  return recipes.map((r) => {
    const obj = rewriteThumbnail(toSnake(r));
    if (obj.ingredients_without_measures && Array.isArray(obj.ingredients_without_measures)) {
      obj.ingredients_without_measures = obj.ingredients_without_measures.map(
        (id: string) => ingIdToName.get(id) ?? id
      );
    }
    if (Array.isArray(obj.ingredients_with_measures)) {
      obj.ingredients_with_measures = attachBaseNames(obj.ingredients_with_measures, ingIdToName);
    }
    if (obj.tags && Array.isArray(obj.tags)) {
      obj.tags = obj.tags.map(
        (id: string) => tagIdToName.get(id) ?? id
      );
    }
    return obj;
  });
}

async function ensureCreator(
  username: string | null | undefined,
  platform: "instagram" | "tiktok" | "x" | "nefisyemektarifleri" | "other",
  creatorProfilePicBase64?: string
) {
  if (!username) return;
  const trimmed = username.trim().toLowerCase();
  if (!trimmed) return;

  const existing = await db
    .select()
    .from(platformCreators)
    .where(eq(platformCreators.username, trimmed))
    .limit(1);

  if (existing.length > 0 && existing[0].profilePictureUrl) return;

  let profilePictureUrl: string | null = null;
  let displayName: string | null = null;

  // Use profile pic provided by the client (fetched on-device where requests succeed)
  if (creatorProfilePicBase64) {
    try {
      profilePictureUrl = await uploadImage(creatorProfilePicBase64);
    } catch {}
  }

  if (profilePictureUrl) {
    console.log(`Saved profile picture for @${trimmed} (${platform}) from client`);
  }

  if (existing.length > 0) {
    const updates: Record<string, any> = {};
    if (profilePictureUrl) updates.profilePictureUrl = profilePictureUrl;
    if (displayName) updates.displayName = displayName;
    if (Object.keys(updates).length > 0) {
      await db.update(platformCreators).set(updates).where(eq(platformCreators.username, trimmed));
    }
  } else {
    await db
      .insert(platformCreators)
      .values({ username: trimmed, platform, displayName, profilePictureUrl })
      .onConflictDoNothing();
  }
}

// Check if recipe already exists for this URL
app.get("/recipes/lookup", async (req, res) => {
  const url = req.query.url as string;
  if (!url) {
    res.status(400).json({ error: "url query parameter required" });
    return;
  }

  const result = await db
    .select()
    .from(recipes)
    .where(eq(recipes.url, url))
    .limit(1);

  if (result.length === 0) {
    res.json(null);
    return;
  }

  res.json(await enrichRecipe(result[0]));
});

// Save a new recipe
app.post("/recipes", async (req, res) => {
  const data = req.body;
  const userId = req.auth!.userId;

  // Return existing if URL already saved
  const existing = await db
    .select()
    .from(recipes)
    .where(eq(recipes.url, data.url))
    .limit(1);

  if (existing.length > 0) {
    // Recipe already processed — just add user mapping
    await saveUserRecipe(userId, existing[0].id);
    console.log(`  -> Already exists, added mapping for user ${userId}`);
    res.json(await enrichRecipe(existing[0]));
    return;
  }

  const meta = parseCaptionMeta(data.caption);
  console.log(`  -> Parsed caption: user=${meta.platformUser}, likes=${meta.likesCount}, comments=${meta.commentsCount}`);

  // Upload thumbnail to S3 if provided
  let thumbnailUrl: string | null = null;
  if (data.thumbnail_base64) {
    try {
      thumbnailUrl = await uploadImage(data.thumbnail_base64);
      console.log(`Uploaded thumbnail: ${thumbnailUrl}`);
    } catch (err) {
      console.error("S3 upload failed:", err);
    }
  }

  // Ensure instagram user exists before inserting recipe (FK)
  const creatorUsername = data.platform_user || meta.platformUser || extractUserFromURL(data.url) || "unknown";
  await ensureCreator(creatorUsername, data.platform, data.creator_profile_pic_base64);

  // Resolve base ingredients first — this is the only path allowed to create
  // new ingredient rows (the AI prompt constrains these to core names).
  const ingredientsWithoutMeasures = await resolveIngredientIds(data.ingredients_without_measures ?? []);

  // Then resolve IDs for ingredients_with_measures — lookup only: these
  // display names may carry measure words ("1 çay kaşığı tuz") and must
  // never create ingredient rows.
  const ingWithMeasures: { name: string; amount: string; section?: string; ingredient_id: string }[] = (data.ingredients_with_measures ?? []).map(
    (i: any) => ({
      name: fixTurkish((i.name ?? "").replace(/\s{2,}/g, " ").trim()),
      amount: (i.amount ?? "").replace(/\s{2,}/g, " ").trim(),
      ...(i.section ? { section: i.section } : {}),
      ingredient_id: "",
    })
  );
  if (ingWithMeasures.length > 0) {
    const nameToId = await lookupIngredientMap(ingWithMeasures.map((i) => i.name));
    for (const ing of ingWithMeasures) {
      ing.ingredient_id = nameToId.get(ing.name) ?? nameToId.get(fixTurkish(ing.name)) ?? "";
    }
  }

  const result = await db
    .insert(recipes)
    .values({
      platform: data.platform,
      platformUser: data.platform_user || meta.platformUser || extractUserFromURL(data.url) || "unknown",
      url: data.url,
      likesCount: data.likes_count || meta.likesCount || 0,
      commentsCount: data.comments_count || meta.commentsCount || 0,
      caption: data.caption,
      title: data.title,
      description: data.description,
      ingredientsWithMeasures: ingWithMeasures,
      ingredientsWithoutMeasures,
      thumbnailUrl,
      servings: data.servings,
      caloriesTotalKcal: data.calories_total_kcal,
      caloriesTotalJoules: data.calories_total_joules,
      caloriesPerServingKcal: data.calories_per_serving_kcal,
      proteinGrams: data.protein_grams,
      carbsGrams: data.carbs_grams,
      fatGrams: data.fat_grams,
      fiberGrams: data.fiber_grams,
      tags: await resolveTagIds((data.tags ?? []).filter((t: string) => PREDEFINED_TAGS.includes(t))),
      cookingTimeMinutes: data.cooking_time_minutes ?? parseCookingTime(data.cooking_time) ?? 30,
      cuisine: data.cuisine,
      difficulty: data.difficulty,
      freezerFriendly: data.freezer_friendly ?? false,
      healthScore: data.health_score,
      requestedBy: userId,
    })
    .returning();

  // Add user-recipe mapping
  await saveUserRecipe(userId, result[0].id);

  console.log(`  -> Saved: ${result[0].title} (thumbnail: ${thumbnailUrl ? "YES" : "NO"})`);
  res.status(201).json(toSnake(result[0]));
});

// List recipes (optional filters: requested_by, platform)
app.get("/recipes", async (req, res) => {
  let query = db.select().from(recipes);

  const conditions = [];
  if (req.query.requested_by) {
    conditions.push(eq(recipes.requestedBy, req.query.requested_by as string));
  }
  if (req.query.platform) {
    conditions.push(
      eq(recipes.platform, req.query.platform as "instagram" | "tiktok" | "x" | "nefisyemektarifleri" | "other")
    );
  }

  const result = conditions.length > 0
    ? await query.where(conditions[0]).orderBy(desc(recipes.createdAt))
    : await query.orderBy(desc(recipes.createdAt));

  res.json(await enrichRecipes(result));
});

// Get recipes for a user (includes folder info)
app.get("/users/:userId/recipes", async (req, res) => {
  const mappings = await db
    .select({
      recipeId: userRecipes.recipeId,
      folderId: userRecipes.folderId,
      isFavorite: userRecipes.isFavorite,
    })
    .from(userRecipes)
    .where(eq(userRecipes.userId, req.auth!.userId));

  if (mappings.length === 0) {
    res.json([]);
    return;
  }

  const recipeIds = mappings.map((m) => m.recipeId);
  const result = await db
    .select()
    .from(recipes)
    .where(inArray(recipes.id, recipeIds))
    .orderBy(desc(recipes.createdAt));

  // Attach folder_id and is_favorite to each recipe
  const folderMap = new Map(mappings.map((m) => [m.recipeId, m.folderId]));
  const favoriteMap = new Map(mappings.map((m) => [m.recipeId, m.isFavorite]));
  const enriched = result.map((r) => ({
    ...r,
    folderId: folderMap.get(r.id) ?? null,
    isFavorite: favoriteMap.get(r.id) ?? false,
  }));

  res.json(await enrichRecipes(enriched));
});

// Get single recipe
app.get("/recipes/:id", async (req, res) => {
  const result = await db
    .select()
    .from(recipes)
    .where(eq(recipes.id, req.params.id))
    .limit(1);

  if (result.length === 0) {
    res.status(404).json({ error: "Tarif bulunamadı" });
    return;
  }

  res.json(await enrichRecipe(result[0]));
});

// Backfill missing metadata from captions
app.post("/recipes/backfill", requireAdmin, async (_req, res) => {
  const all = await db.select().from(recipes);
  let updated = 0;

  for (const recipe of all) {
    const meta = parseCaptionMeta(recipe.caption);
    const updates: Record<string, any> = {};

    if (!recipe.platformUser && meta.platformUser) updates.platformUser = meta.platformUser;
    if (!recipe.likesCount && meta.likesCount) updates.likesCount = meta.likesCount;
    if (!recipe.commentsCount && meta.commentsCount) updates.commentsCount = meta.commentsCount;

    if (Object.keys(updates).length > 0) {
      await db.update(recipes).set(updates).where(eq(recipes.id, recipe.id));
      updated++;
    }
  }

  // Also resolve ingredient IDs from existing recipes
  for (const recipe of all) {
    const ings = recipe.ingredientsWithoutMeasures as string[] | null;
    if (ings && ings.length > 0) {
      const ids = await resolveIngredientIds(ings);
      await db.update(recipes).set({ ingredientsWithoutMeasures: ids }).where(eq(recipes.id, recipe.id));
    }
  }

  res.json({ backfilled: updated, total: all.length });
});

// Backfill freezer_friendly for existing recipes using AI
app.post("/recipes/backfill-freezer", requireAdmin, async (_req, res) => {
  const all = await db.select().from(recipes);
  const enriched = await enrichRecipes(all);

  const toClassify = enriched.map((r: any) => ({
    id: r.id,
    title: r.title,
    tags: (r.tags as string[]) || [],
    ingredients: (r.ingredients_without_measures as string[]) || [],
  }));

  if (toClassify.length === 0) {
    res.json({ updated: 0, total: 0 });
    return;
  }

  console.log(`[Freezer] Classifying ${toClassify.length} recipes...`);

  try {
    // Process in batches of 20
    let updated = 0;
    for (let i = 0; i < toClassify.length; i += 20) {
      const batch = toClassify.slice(i, i + 20);
      const results = await classifyFreezerFriendly(batch);

      for (const item of results) {
        await db
          .update(recipes)
          .set({ freezerFriendly: item.freezer_friendly })
          .where(eq(recipes.id, item.id));
        updated++;
      }

      console.log(`[Freezer] Batch ${Math.floor(i / 20) + 1}: ${results.length} classified`);
    }

    console.log(`[Freezer] Updated ${updated}/${toClassify.length} recipes`);
    res.json({ updated, total: toClassify.length });
  } catch (err: any) {
    console.error("[Freezer]", err.message || err);
    res.status(500).json({ error: "Freezer classification failed", detail: err.message });
  }
});

// Sync Clerk user to local DB
app.post("/users/sync", async (req, res) => {
  // Identity comes from the verified token, never from the request body.
  const clerk_id = req.auth!.userId;
  const { email, name, avatar_url } = req.body;

  const existing = await db
    .select()
    .from(users)
    .where(eq(users.clerkId, clerk_id))
    .limit(1);

  const isNewUser = existing.length === 0;

  if (isNewUser) {
    // New users start with the unlimited trial (effective-pro for
    // NEW_USER_UNLIMITED_DAYS, default 30).
    await db
      .insert(users)
      .values({ clerkId: clerk_id, email, name, avatarUrl: avatar_url, unlimitedUntil: newUserTrialEnd() });
  } else {
    await db
      .update(users)
      .set({ email, name, avatarUrl: avatar_url })
      .where(eq(users.clerkId, clerk_id));
  }

  // Map platform recipes to new users so they start with content
  if (isNewUser) {
    const mapped = await mapPlatformRecipesToUser(clerk_id);
    if (mapped > 0) {
      console.log(`[Sync] Mapped ${mapped} platform recipes to new user ${clerk_id}`);
    }
  }

  res.json({ ok: true });
});

// Register (or re-point) an APNs device token for the authenticated user.
// Token is the PK: a device that switches accounts just moves to the new
// user. environment picks the APNs host (sandbox = Xcode builds).
app.post("/devices", async (req, res) => {
  const userId = req.auth!.userId;
  const { token, environment } = req.body ?? {};

  if (!token || typeof token !== "string" || token.length > 200) {
    res.status(400).json({ error: "token gerekli" });
    return;
  }
  const env = environment === "sandbox" ? "sandbox" : "production";

  await db
    .insert(deviceTokens)
    .values({ token, userId, environment: env })
    .onConflictDoUpdate({
      target: deviceTokens.token,
      set: { userId, environment: env, updatedAt: new Date() },
    });

  res.json({ ok: true });
});

// Quota snapshot for the scan sheet / paywall: plan, scans used this month,
// and what's left. Quota only meters new-to-catalog AI scans; cached saves
// are always free and unlimited.
app.get("/users/me/quota", async (req, res) => {
  try {
    res.json(await getQuotaStatus(req.auth!.userId));
  } catch (err: any) {
    console.error("[Quota] status failed:", err.message || err);
    res.status(500).json({ error: "Failed to load quota" });
  }
});

// KVKK: export all personal data held for the authenticated user as JSON.
// Identity comes from the verified token, never from the request.
app.get("/users/me/export", async (req, res) => {
  const clerk_id = req.auth!.userId;

  const [
    profile,
    folders,
    savedRecipes,
    plans,
    pantry,
    shoppingList,
    reviews,
    userConnections,
    userShares,
  ] = await Promise.all([
    db.select().from(users).where(eq(users.clerkId, clerk_id)).limit(1),
    db.select().from(userFolders).where(eq(userFolders.userId, clerk_id)),
    db.select().from(userRecipes).where(eq(userRecipes.userId, clerk_id)),
    db.select().from(mealPlans).where(eq(mealPlans.userId, clerk_id)),
    db.select().from(userPantry).where(eq(userPantry.userId, clerk_id)),
    db.select().from(userShoppingList).where(eq(userShoppingList.userId, clerk_id)),
    db.select().from(recipeReviews).where(eq(recipeReviews.userId, clerk_id)),
    db
      .select()
      .from(connections)
      .where(or(eq(connections.requesterId, clerk_id), eq(connections.addresseeId, clerk_id))),
    db
      .select()
      .from(recipeShares)
      .where(or(eq(recipeShares.senderId, clerk_id), eq(recipeShares.recipientId, clerk_id))),
  ]);

  if (profile.length === 0) {
    res.status(404).json({ error: "User not found" });
    return;
  }

  res.json(
    toSnake({
      exportedAt: new Date(),
      profile: profile[0],
      folders,
      savedRecipes,
      mealPlans: plans,
      pantry,
      shoppingList,
      reviews,
      connections: userConnections,
      recipeShares: userShares,
    })
  );
});

// KVKK: permanently delete the authenticated user and all of their data.
// Runs in a single transaction so the purge is all-or-nothing: a mid-sequence
// failure never leaves a half-deleted account. Deletions run in FK-safe order
// (child rows before the users row). Shared global content (recipes requested
// by the user) is retained, as it is no longer tied to the user's identity
// after deletion. The user's quota counter lives on the users row, so it is
// removed with it.
app.delete("/users/me", async (req, res) => {
  const clerk_id = req.auth!.userId;

  await db.transaction(async (tx) => {
  // user_recipes references user_folders (folder_id), so it must go first.
  await db.delete(userRecipes).where(eq(userRecipes.userId, clerk_id));
  await db.delete(userFolders).where(eq(userFolders.userId, clerk_id));
  await db.delete(mealPlans).where(eq(mealPlans.userId, clerk_id));
  await db.delete(userPantry).where(eq(userPantry.userId, clerk_id));
  await db.delete(userShoppingList).where(eq(userShoppingList.userId, clerk_id));
  await db.delete(recipeReviews).where(eq(recipeReviews.userId, clerk_id));
  await db
    .delete(connections)
    .where(or(eq(connections.requesterId, clerk_id), eq(connections.addresseeId, clerk_id)));
  await db
    .delete(recipeShares)
    .where(or(eq(recipeShares.senderId, clerk_id), eq(recipeShares.recipientId, clerk_id)));
  await db.delete(deviceTokens).where(eq(deviceTokens.userId, clerk_id));
  await db.delete(users).where(eq(users.clerkId, clerk_id));
  });

  res.status(204).send();
});

// List all known ingredients (with price tier and price)
app.get("/ingredients", async (_req, res) => {
  const result = await db
    .select()
    .from(ingredients)
    .orderBy(ingredients.name);
  res.json(result.map((r) => ({
    name: r.name,
    price_tier: r.priceTier,
    availability: r.availability,
    price_per_unit: r.pricePerUnit,
    price_unit: r.priceUnit,
    price_updated_at: r.priceUpdatedAt,
    default_unit: r.defaultUnit,
    density_g_ml: r.densityGMl,
    gram_per_adet: r.gramPerAdet,
    alternative_ids: r.alternativeIds,
  })));
});

// Update price tier for an ingredient
app.put("/ingredients/:name/price-tier", requireAdmin, async (req, res) => {
  const name = req.params.name as string;
  const { price_tier } = req.body;
  if (!["cheap", "neutral", "expensive"].includes(price_tier)) {
    res.status(400).json({ error: "price_tier must be cheap, neutral, or expensive" });
    return;
  }

  const result = await db
    .update(ingredients)
    .set({ priceTier: price_tier })
    .where(eq(ingredients.name, name))
    .returning();

  if (result.length === 0) {
    res.status(404).json({ error: "Ingredient not found" });
    return;
  }

  res.json({ name: result[0].name, price_tier: result[0].priceTier, availability: result[0].availability });
});

// Update availability for an ingredient
app.put("/ingredients/:name/availability", requireAdmin, async (req, res) => {
  const name = req.params.name as string;
  const { availability } = req.body;
  if (!["easy", "neutral", "rare"].includes(availability)) {
    res.status(400).json({ error: "availability must be easy, neutral, or rare" });
    return;
  }

  const result = await db
    .update(ingredients)
    .set({ availability })
    .where(eq(ingredients.name, name))
    .returning();

  if (result.length === 0) {
    res.status(404).json({ error: "Ingredient not found" });
    return;
  }

  res.json({ name: result[0].name, price_tier: result[0].priceTier, availability: result[0].availability });
});

// Classify all unclassified ingredients using Claude
app.post("/ingredients/classify", requireAdmin, async (_req, res) => {
  // Fetch ingredients missing price_tier or availability
  const all = await db.select().from(ingredients).orderBy(ingredients.name);
  const unclassified = all.filter((r) => !r.priceTier || !r.availability);

  if (unclassified.length === 0) {
    res.json({ classified: 0, total: all.length, message: "All ingredients already classified" });
    return;
  }

  const names = unclassified.map((r) => r.name);
  console.log(`[Classify] Sending ${names.length} ingredients to Claude...`);

  try {
    const results = await classifyIngredients(names);
    let updated = 0;

    for (const item of results) {
      const match = unclassified.find((r) => r.name.toLowerCase() === item.name.toLowerCase());
      if (!match) continue;

      const updates: Record<string, string> = {};
      if (!match.priceTier && ["cheap", "neutral", "expensive"].includes(item.price_tier)) {
        updates.priceTier = item.price_tier;
      }
      if (!match.availability && ["easy", "neutral", "rare"].includes(item.availability)) {
        updates.availability = item.availability;
      }

      if (Object.keys(updates).length > 0) {
        await db.update(ingredients).set(updates).where(eq(ingredients.name, match.name));
        updated++;
      }
    }

    console.log(`[Classify] Updated ${updated}/${names.length} ingredients`);
    res.json({ classified: updated, total: all.length, sent: names.length });
  } catch (err: any) {
    console.error("[Classify]", err.message || err);
    res.status(500).json({ error: "Classification failed", detail: err.message });
  }
});

// Find and populate alternative ingredients using Claude
app.post("/ingredients/find-alternatives", requireAdmin, async (_req, res) => {
  try {
    const all = await db.select({ id: ingredients.id, name: ingredients.name }).from(ingredients).orderBy(ingredients.name);
    const names = all.map((r) => r.name);
    const nameToId = new Map(all.map((r) => [r.name.toLowerCase(), r.id]));

    console.log(`[Alternatives] Sending ${names.length} ingredients to Claude...`);

    // Process in batches of 200 to avoid token limits
    const batchSize = 200;
    const allResults: { name: string; alternatives: string[] }[] = [];
    for (let i = 0; i < names.length; i += batchSize) {
      const batch = names.slice(i, i + batchSize);
      const results = await findAlternativeIngredients(batch);
      allResults.push(...results);
    }

    // Build a map: ingredient ID → set of alternative IDs (one-way)
    const altMap = new Map<string, Set<string>>();
    for (const item of allResults) {
      const id = nameToId.get(item.name.toLowerCase());
      if (!id) continue;

      if (!altMap.has(id)) altMap.set(id, new Set());
      for (const altName of item.alternatives) {
        const altId = nameToId.get(altName.toLowerCase());
        if (altId && altId !== id) {
          altMap.get(id)!.add(altId);
        }
      }
    }

    // Update DB
    let updated = 0;
    for (const [id, altIds] of altMap) {
      await db.update(ingredients).set({ alternativeIds: [...altIds] }).where(eq(ingredients.id, id));
      updated++;
    }

    console.log(`[Alternatives] Updated ${updated} ingredients with alternatives`);
    res.json({ updated, total: all.length });
  } catch (err: any) {
    console.error("[Alternatives]", err.message || err);
    res.status(500).json({ error: "Finding alternatives failed", detail: err.message });
  }
});

// Helper: merge duplicate ingredient rows into a single "keep" row, updating all references
async function mergeIngredientRows(
  keep: { id: string; name: string; priceTier: string | null; availability: string | null; pricePerUnit: number | null },
  dupes: { id: string; name: string }[],
  canonicalName: string
) {
  const dupeIds = dupes.map((d) => d.id);

  // Update references in userPantry — delete rows where user already has the keep ingredient, update the rest
  for (const dupeId of dupeIds) {
    await db.execute(sql`
      DELETE FROM user_pantry
      WHERE ingredient_id = ${dupeId}::uuid
        AND user_id IN (
          SELECT user_id FROM user_pantry WHERE ingredient_id = ${keep.id}::uuid
        )
    `);
  }
  await db.update(userPantry)
    .set({ ingredientId: keep.id })
    .where(inArray(userPantry.ingredientId, dupeIds));

  // Update references in userShoppingList — same dedup logic
  for (const dupeId of dupeIds) {
    await db.execute(sql`
      DELETE FROM user_shopping_list
      WHERE ingredient_id = ${dupeId}::uuid
        AND user_id IN (
          SELECT user_id FROM user_shopping_list WHERE ingredient_id = ${keep.id}::uuid
        )
    `);
  }
  await db.update(userShoppingList)
    .set({ ingredientId: keep.id })
    .where(inArray(userShoppingList.ingredientId, dupeIds));

  // Update jsonb arrays in recipes.ingredients_without_measures and ingredientsWithMeasures
  for (const dupe of dupes) {
    // ingredients_without_measures: array of ID strings
    await db.execute(sql`
      UPDATE recipes
      SET ingredients_without_measures = (
        SELECT jsonb_agg(
          CASE WHEN elem = ${dupe.id}::text THEN ${keep.id}::text ELSE elem END
        )
        FROM jsonb_array_elements_text(ingredients_without_measures) AS elem
      )
      WHERE ingredients_without_measures::text LIKE ${"%" + dupe.id + "%"}
    `);

    // ingredients_with_measures: array of objects with ingredient_id field
    await db.execute(sql`
      UPDATE recipes
      SET ingredients_with_measures = (
        SELECT jsonb_agg(
          CASE
            WHEN elem->>'ingredient_id' = ${dupe.id} THEN jsonb_set(elem, '{ingredient_id}', to_jsonb(${keep.id}::text))
            ELSE elem
          END
        )
        FROM jsonb_array_elements(ingredients_with_measures) AS elem
      )
      WHERE ingredients_with_measures::text LIKE ${"%" + dupe.id + "%"}
    `);

    // meal_plans.shopping_ingredient_ids: array of ID strings
    await db.execute(sql`
      UPDATE meal_plans
      SET shopping_ingredient_ids = (
        SELECT jsonb_agg(
          CASE WHEN elem = ${dupe.id}::text THEN ${keep.id}::text ELSE elem END
        )
        FROM jsonb_array_elements_text(shopping_ingredient_ids) AS elem
      )
      WHERE shopping_ingredient_ids::text LIKE ${"%" + dupe.id + "%"}
    `);

    // meal_plans.shopping_list: array of objects with ingredient_id field
    await db.execute(sql`
      UPDATE meal_plans
      SET shopping_list = (
        SELECT jsonb_agg(
          CASE
            WHEN elem->>'ingredient_id' = ${dupe.id} THEN jsonb_set(elem, '{ingredient_id}', to_jsonb(${keep.id}::text))
            ELSE elem
          END
        )
        FROM jsonb_array_elements(shopping_list) AS elem
      )
      WHERE shopping_list::text LIKE ${"%" + dupe.id + "%"}
    `);

    // ingredients.alternative_ids: array of ID strings (drop self-references)
    await db.execute(sql`
      UPDATE ingredients
      SET alternative_ids = (
        SELECT COALESCE(jsonb_agg(DISTINCT new_elem), '[]'::jsonb)
        FROM (
          SELECT CASE WHEN elem = ${dupe.id}::text THEN ${keep.id}::text ELSE elem END AS new_elem
          FROM jsonb_array_elements_text(alternative_ids) AS elem
        ) sub
        WHERE new_elem <> ingredients.id::text
      )
      WHERE alternative_ids::text LIKE ${"%" + dupe.id + "%"}
    `);
  }

  // Delete duplicates
  await db.delete(ingredients).where(inArray(ingredients.id, dupeIds));

  // Rename the kept one if needed
  if (keep.name !== canonicalName) {
    await db.update(ingredients).set({ name: canonicalName }).where(eq(ingredients.id, keep.id));
  }
}

// Consolidate ingredients: exact + fuzzy dedup
app.post("/ingredients/consolidate", requireAdmin, async (req, res) => {
  const dryRun = req.query.dry_run === "true";
  try {
    const all = await db.select().from(ingredients).orderBy(ingredients.name);
    console.log(`[Consolidate] Processing ${all.length} ingredients (dry_run=${dryRun})...`);

    // Phase 1: Group by exact match after stripping leading measure words
    // ("Adet Limon" → "Limon") and fixTurkish normalization
    const groups = new Map<string, typeof all>();
    for (const row of all) {
      const canonical = fixTurkish(splitAmountFromName(row.name).name);
      if (!groups.has(canonical)) groups.set(canonical, []);
      groups.get(canonical)!.push(row);
    }

    let renamed = 0;
    let exactMerged = 0;

    for (const [canonical, rows] of groups) {
      if (rows.length === 1) {
        if (rows[0].name !== canonical) {
          if (!dryRun) await db.update(ingredients).set({ name: canonical }).where(eq(ingredients.id, rows[0].id));
          console.log(`  Renamed: "${rows[0].name}" -> "${canonical}"`);
          renamed++;
        }
      } else {
        const sorted = rows.sort((a, b) => {
          const aScore = (a.priceTier ? 1 : 0) + (a.availability ? 1 : 0) + (a.pricePerUnit ? 1 : 0);
          const bScore = (b.priceTier ? 1 : 0) + (b.availability ? 1 : 0) + (b.pricePerUnit ? 1 : 0);
          return bScore - aScore;
        });
        const keep = sorted[0];
        const dupes = sorted.slice(1);

        console.log(`  Exact merge: [${rows.map((r) => `"${r.name}"`).join(", ")}] -> "${canonical}"`);
        if (!dryRun) await mergeIngredientRows(keep, dupes, canonical);
        exactMerged += dupes.length;
      }
    }

    // Phase 2: Fuzzy matching across remaining ingredients
    const remaining = dryRun
      ? all // in dry run, just show what would happen
      : await db.select().from(ingredients).orderBy(ingredients.name);

    // Build fuzzy groups: for each ingredient, find its best match among earlier ones
    const fuzzyGroups = new Map<string, typeof remaining>(); // keepId -> [dupes]
    const assigned = new Set<string>(); // IDs already assigned to a group

    for (let i = 0; i < remaining.length; i++) {
      if (assigned.has(remaining[i].id)) continue;

      const candidates = remaining.slice(i + 1).filter((r) => !assigned.has(r.id));
      const matches: typeof remaining = [];

      for (const candidate of candidates) {
        const match = findBestMatch(candidate.name, [remaining[i]]);
        if (match) {
          matches.push(candidate);
        }
      }

      if (matches.length > 0) {
        fuzzyGroups.set(remaining[i].id, matches);
        assigned.add(remaining[i].id);
        for (const m of matches) assigned.add(m.id);
      }
    }

    let fuzzyMerged = 0;
    const fuzzyLog: { keep: string; merged: string[] }[] = [];

    for (const [keepId, dupes] of fuzzyGroups) {
      const keepRow = remaining.find((r) => r.id === keepId)!;
      const allInGroup = [keepRow, ...dupes];

      // Pick the one with most classification data, then shortest name (most canonical)
      const sorted = allInGroup.sort((a, b) => {
        const aScore = (a.priceTier ? 1 : 0) + (a.availability ? 1 : 0) + (a.pricePerUnit ? 1 : 0);
        const bScore = (b.priceTier ? 1 : 0) + (b.availability ? 1 : 0) + (b.pricePerUnit ? 1 : 0);
        if (bScore !== aScore) return bScore - aScore;
        return a.name.length - b.name.length; // prefer shorter (more canonical) name
      });

      const keep = sorted[0];
      const toMerge = sorted.slice(1);
      const canonical = fixTurkish(splitAmountFromName(keep.name).name);

      console.log(`  Fuzzy merge: [${allInGroup.map((r) => `"${r.name}"`).join(", ")}] -> "${canonical}"`);
      fuzzyLog.push({ keep: canonical, merged: toMerge.map((d) => d.name) });

      if (!dryRun) await mergeIngredientRows(keep, toMerge, canonical);
      fuzzyMerged += toMerge.length;
    }

    if (!dryRun) invalidateIngredientCache();

    const finalCount = dryRun ? all.length - exactMerged - fuzzyMerged : (await db.select({ id: ingredients.id }).from(ingredients)).length;

    console.log(`[Consolidate] Done: ${renamed} renamed, ${exactMerged} exact-merged, ${fuzzyMerged} fuzzy-merged`);
    res.json({
      dry_run: dryRun,
      renamed,
      exact_merged: exactMerged,
      fuzzy_merged: fuzzyMerged,
      total_before: all.length,
      total_after: finalCount,
      fuzzy_matches: fuzzyLog,
    });
  } catch (err: any) {
    console.error("[Consolidate]", err.message || err);
    res.status(500).json({ error: "Consolidation failed", detail: err.message });
  }
});

// Fetch real prices from marketfiyati.org.tr for all ingredients
// Uses https module directly because the TUBITAK SSL cert isn't in Node's trust store
const marketAgent = new https.Agent({ rejectUnauthorized: false });

function marketFetch(keyword: string): Promise<any> {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({ keywords: keyword, pages: 0, size: 10 });
    const req = https.request(
      {
        hostname: "api.marketfiyati.org.tr",
        path: "/api/v2/search",
        method: "POST",
        agent: marketAgent,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Origin": "https://marketfiyati.org.tr",
          "Referer": "https://marketfiyati.org.tr/",
          "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
          "Content-Length": Buffer.byteLength(body),
        },
      },
      (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          if (res.statusCode !== 200) return reject(new Error(`HTTP ${res.statusCode}`));
          try { resolve(JSON.parse(data)); } catch { reject(new Error("Invalid JSON")); }
        });
      }
    );
    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

async function searchMarketPrice(keyword: string): Promise<{ pricePerUnit: number; priceUnit: string } | null> {
  try {
    const data = await marketFetch(keyword);
    if (!data.content?.length) return null;

    // Find cheapest unit price across all results
    let bestPrice = Infinity;
    let bestUnit = "Kg";

    for (const product of data.content) {
      for (const depot of product.productDepotInfoList ?? []) {
        if (depot.unitPriceValue && depot.unitPriceValue < bestPrice) {
          bestPrice = depot.unitPriceValue;
          // Extract unit from "56,43 ₺/Kg" -> "Kg"
          const unitMatch = depot.unitPrice?.match(/₺\/(.+)/);
          bestUnit = unitMatch?.[1] ?? "Kg";
        }
      }
    }

    if (bestPrice === Infinity) return null;
    return { pricePerUnit: Math.round(bestPrice * 100) / 100, priceUnit: bestUnit };
  } catch (err: any) {
    console.log(`    [API] ${keyword}: ${err.message}`);
    return null;
  }
}

// The actual price fetch (sequential, 500ms/item to avoid 403) runs as a durable
// background job — never inside the request handler.
async function fetchPricesJob(forceAll: boolean) {
  const all = await db.select().from(ingredients).orderBy(ingredients.name);
  const toFetch = forceAll ? all : all.filter((r) => !r.pricePerUnit);
  if (toFetch.length === 0) {
    console.log("[Prices] Nothing to fetch — all ingredients already have prices");
    return;
  }

  let updated = 0;
  let failed = 0;
  console.log(`[Prices] Fetching prices for ${toFetch.length}/${all.length} ingredients from marketfiyati.org.tr...`);

  for (const ing of toFetch) {
    const result = await searchMarketPrice(ing.name);
    if (result) {
      await db
        .update(ingredients)
        .set({
          pricePerUnit: result.pricePerUnit,
          priceUnit: result.priceUnit,
          priceUpdatedAt: new Date(),
        })
        .where(eq(ingredients.id, ing.id));
      updated++;
      console.log(`  ${ing.name}: ${result.pricePerUnit} ₺/${result.priceUnit}`);
    } else {
      failed++;
      console.log(`  ${ing.name}: not found`);
    }

    // Rate limit: delay between requests to avoid 403
    await new Promise((r) => setTimeout(r, 500));
  }

  console.log(`[Prices] Updated ${updated}/${toFetch.length} (${failed} not found)`);
}

app.post("/ingredients/fetch-prices", requireAdmin, async (req, res) => {
  const forceAll = req.query.force === "true";
  const all = await db.select({ id: ingredients.id, pricePerUnit: ingredients.pricePerUnit }).from(ingredients);
  const pending = forceAll ? all.length : all.filter((r) => !r.pricePerUnit).length;

  if (pending === 0) {
    res.json({ enqueued: false, total: all.length, message: "All ingredients already have prices" });
    return;
  }

  const jobId = await enqueueJob("fetch-prices", { forceAll });
  res.status(202).json({ enqueued: true, job_id: jobId, total: all.length, to_fetch: pending });
});

// Estimate cost of a recipe based on ingredient prices
app.get("/recipes/:id/cost", async (req, res) => {
  const recipe = await db
    .select()
    .from(recipes)
    .where(eq(recipes.id, req.params.id))
    .limit(1);

  if (recipe.length === 0) {
    res.status(404).json({ error: "Tarif bulunamadı" });
    return;
  }

  const ingredientIds = recipe[0].ingredientsWithoutMeasures as string[] | null;
  const recipeIngsWithMeasures = recipe[0].ingredientsWithMeasures as { name: string; amount: string }[] | null;

  if (!ingredientIds || ingredientIds.length === 0) {
    res.json({ estimated_cost: null, ingredients: [] });
    return;
  }

  // Fetch ingredients by ID (they're UUIDs now)
  const priced = await db
    .select()
    .from(ingredients)
    .where(inArray(ingredients.id, ingredientIds));

  const priceMap = new Map(priced.map((p) => [p.id, p]));
  let totalCost = 0;
  let pricedCount = 0;

  const breakdown = ingredientIds.map((id, i) => {
    const ing = priceMap.get(id);
    const measure = recipeIngsWithMeasures?.[i]?.amount ?? null;
    const name = ing?.name ?? id;

    if (ing?.pricePerUnit) {
      pricedCount++;
      const isPerAdet = ing.priceUnit === "Adet";
      // Estimate quantity in price_unit from measure string
      let estimatedQty = isPerAdet ? 1 : 0.15; // default: 1 unit or 150g
      if (measure) {
        const lower = measure.toLowerCase();
        // Handle fractions like "1/2", "1/4"
        let val = 1;
        const fracMatch = lower.match(/([\d.,]+)\s*\/\s*([\d.,]+)/);
        const numMatch = lower.match(/([\d.,]+)/);
        if (fracMatch) {
          val = parseFloat(fracMatch[1].replace(",", ".")) / parseFloat(fracMatch[2].replace(",", "."));
        } else if (numMatch) {
          val = parseFloat(numMatch[1].replace(",", "."));
        }

        if (lower.includes("kg")) estimatedQty = val;
        else if (lower.includes("gr") || lower.includes("gram") || /\d+\s*g\b/.test(lower)) estimatedQty = val / 1000;
        else if (lower.includes("lt") || lower.includes("litre")) estimatedQty = val;
        else if (lower.includes("ml")) estimatedQty = val / 1000;
        else if (lower.includes("su bardağı") || lower.includes("su bardagi")) estimatedQty = val * 0.2; // ~200ml
        else if (lower.includes("çay bardağı")) estimatedQty = val * 0.1;
        else if (lower.includes("bardak")) estimatedQty = val * 0.2;
        else if (lower.includes("çay kaşığı") || lower.includes("tatlı kaşığı")) estimatedQty = val * 0.005;
        else if (lower.includes("yemek kaşığı") || lower.includes("kaşık")) estimatedQty = val * 0.015;
        else if (lower.includes("tutam") || lower.includes("çimdik")) estimatedQty = val * 0.002;
        else if (lower.includes("adet") || lower.includes("tane") || lower.includes("diş") || lower.includes("dal") || lower.includes("demet") || lower.includes("dilim")) {
          estimatedQty = isPerAdet ? val : val * 0.05;
        } else {
          estimatedQty = isPerAdet ? val : (val > 10 ? val / 1000 : val * 0.05);
        }
      }
      const cost = Math.round(ing.pricePerUnit * estimatedQty * 100) / 100;
      totalCost += cost;
      return { name, measure, price_per_unit: ing.pricePerUnit, price_unit: ing.priceUnit, estimated_qty: estimatedQty, estimated_cost: cost };
    }
    return { name, measure, price_per_unit: null, price_unit: null, estimated_qty: null, estimated_cost: null };
  });

  res.json({
    estimated_cost: Math.round(totalCost * 100) / 100,
    currency: "TRY",
    priced_count: pricedCount,
    total_count: ingredientIds.length,
    ingredients: breakdown,
  });
});

// Proxy S3 images
app.get("/images/:folder/:file", async (req, res) => {
  const key = `${req.params.folder}/${req.params.file}`;
  const data = await getImage(key);
  if (!data) {
    res.status(404).json({ error: "Image not found" });
    return;
  }
  res.setHeader("Content-Type", "image/jpeg");
  res.setHeader("Cache-Control", "public, max-age=86400");
  res.send(data);
});

// Delete recipe
app.delete("/recipes/:id", requireAdmin, async (req, res) => {
  const id = req.params.id as string;
  const result = await db
    .delete(recipes)
    .where(eq(recipes.id, id))
    .returning();

  if (result.length === 0) {
    res.status(404).json({ error: "Tarif bulunamadı" });
    return;
  }

  res.status(204).send();
});

// Fix Turkish characters in existing ingredients and recipes
app.post("/recipes/fix-turkish", requireAdmin, async (_req, res) => {
  // 1. Fix ingredients table
  const allIngs = await db.select().from(ingredients);
  let ingFixed = 0;
  for (const ing of allIngs) {
    const fixed = fixTurkish(ing.name);
    if (fixed !== ing.name) {
      // Check if the fixed name already exists
      const existing = await db
        .select()
        .from(ingredients)
        .where(eq(ingredients.name, fixed))
        .limit(1);

      if (existing.length > 0) {
        // Fixed name already exists, delete the old one
        await db.delete(ingredients).where(eq(ingredients.id, ing.id));
      } else {
        await db
          .update(ingredients)
          .set({ name: fixed })
          .where(eq(ingredients.id, ing.id));
      }
      ingFixed++;
    }
  }

  // 2. Re-resolve ingredient IDs in recipes (in case names changed)
  const allRecipes = await db.select().from(recipes);
  let recipeFixed = 0;
  for (const recipe of allRecipes) {
    const ings = recipe.ingredientsWithoutMeasures as string[] | null;
    if (!ings || ings.length === 0) continue;

    // Skip if already UUIDs
    const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-/i;
    if (ings[0] && uuidPattern.test(ings[0])) continue;

    const ids = await resolveIngredientIds(ings);
    if (ids.length > 0) {
      await db
        .update(recipes)
        .set({ ingredientsWithoutMeasures: ids })
        .where(eq(recipes.id, recipe.id));
      recipeFixed++;
    }
  }

  console.log(`Fixed Turkish: ${ingFixed} ingredients, ${recipeFixed} recipes`);
  res.json({ ingredientsFixed: ingFixed, recipesFixed: recipeFixed });
});

// Get creator info
app.get("/creators/:username", async (req, res) => {
  const result = await db
    .select()
    .from(platformCreators)
    .where(eq(platformCreators.username, req.params.username.toLowerCase()))
    .limit(1);

  if (result.length === 0) {
    res.status(404).json({ error: "Creator not found" });
    return;
  }

  let user = result[0];

  // If creator has no profile picture, fetch it before responding
  if (!user.profilePictureUrl) {
    try {
      await ensureCreator(user.username, user.platform);
      // Re-fetch to get the updated profile picture URL
      const updated = await db
        .select()
        .from(platformCreators)
        .where(eq(platformCreators.username, req.params.username.toLowerCase()))
        .limit(1);
      if (updated.length > 0) {
        user = updated[0];
      }
    } catch {}
  }

  res.json({
    username: user.username,
    platform: user.platform,
    display_name: user.displayName,
    profile_picture_url: user.profilePictureUrl
      ? s3KeyFromUrl(user.profilePictureUrl)
        ? `/images/${s3KeyFromUrl(user.profilePictureUrl)}`
        : user.profilePictureUrl
      : null,
  });
});

// --- Folders ---

// List user's folders with recipe counts
app.get("/users/:userId/folders", async (req, res) => {
  const folders = await db
    .select()
    .from(userFolders)
    .where(eq(userFolders.userId, req.auth!.userId))
    .orderBy(userFolders.sortOrder);

  // Get recipe counts per folder
  const mappings = await db
    .select({ folderId: userRecipes.folderId, recipeId: userRecipes.recipeId })
    .from(userRecipes)
    .where(eq(userRecipes.userId, req.auth!.userId));

  const countMap = new Map<string, number>();
  for (const m of mappings) {
    if (m.folderId) {
      countMap.set(m.folderId, (countMap.get(m.folderId) || 0) + 1);
    }
  }

  const result = folders.map((f) => ({
    ...toSnake(f),
    recipe_count: countMap.get(f.id) || 0,
  }));

  res.json(result);
});

// Create folder
app.post("/folders", async (req, res) => {
  const user_id = req.auth!.userId;
  const { name, emoji } = req.body;
  if (!name) {
    res.status(400).json({ error: "name required" });
    return;
  }

  // Get max sort order
  const existing = await db
    .select({ sortOrder: userFolders.sortOrder })
    .from(userFolders)
    .where(eq(userFolders.userId, user_id))
    .orderBy(desc(userFolders.sortOrder))
    .limit(1);

  const nextOrder = (existing[0]?.sortOrder ?? -1) + 1;

  const result = await db
    .insert(userFolders)
    .values({ userId: user_id, name, emoji: emoji || null, sortOrder: nextOrder })
    .returning();

  res.status(201).json({ ...toSnake(result[0]), recipe_count: 0 });
});

// Update folder
app.put("/folders/:id", async (req, res) => {
  const { name, emoji, sort_order } = req.body;
  const updates: Record<string, any> = {};
  if (name !== undefined) updates.name = name;
  if (emoji !== undefined) updates.emoji = emoji;
  if (sort_order !== undefined) updates.sortOrder = sort_order;

  const result = await db
    .update(userFolders)
    .set(updates)
    .where(and(eq(userFolders.id, req.params.id), eq(userFolders.userId, req.auth!.userId)))
    .returning();

  if (result.length === 0) {
    res.status(404).json({ error: "Folder not found" });
    return;
  }

  res.json(toSnake(result[0]));
});

// Delete folder (recipes become unfoldered, not deleted)
app.delete("/folders/:id", async (req, res) => {
  const userId = req.auth!.userId;

  // Only the folder's owner may delete it.
  const deleted = await db
    .delete(userFolders)
    .where(and(eq(userFolders.id, req.params.id), eq(userFolders.userId, userId)))
    .returning();

  if (deleted.length === 0) {
    res.status(404).json({ error: "Folder not found" });
    return;
  }

  // Unfolder this user's recipes that pointed at the deleted folder.
  await db
    .update(userRecipes)
    .set({ folderId: null })
    .where(and(eq(userRecipes.folderId, req.params.id), eq(userRecipes.userId, userId)));

  res.status(204).send();
});

// Delete recipe from user's collection (keeps global recipe)
app.delete("/users/:userId/recipes/:recipeId", async (req, res) => {
  const result = await db
    .delete(userRecipes)
    .where(
      and(
        eq(userRecipes.userId, req.auth!.userId),
        eq(userRecipes.recipeId, req.params.recipeId)
      )
    )
    .returning();

  if (result.length === 0) {
    res.status(404).json({ error: "User recipe not found" });
    return;
  }

  res.status(204).send();
});

// Move recipe to folder (or remove from folder with folder_id: null)
app.put("/users/:userId/recipes/:recipeId/folder", async (req, res) => {
  const { folder_id } = req.body;

  // If moving into a folder, it must belong to the auth user.
  if (folder_id) {
    const folder = await db
      .select({ id: userFolders.id })
      .from(userFolders)
      .where(and(eq(userFolders.id, folder_id), eq(userFolders.userId, req.auth!.userId)))
      .limit(1);
    if (folder.length === 0) {
      res.status(404).json({ error: "Folder not found" });
      return;
    }
  }

  const result = await db
    .update(userRecipes)
    .set({ folderId: folder_id || null })
    .where(
      and(
        eq(userRecipes.userId, req.auth!.userId),
        eq(userRecipes.recipeId, req.params.recipeId)
      )
    )
    .returning();

  if (result.length === 0) {
    res.status(404).json({ error: "User recipe not found" });
    return;
  }

  res.json({ ok: true });
});

// Toggle favorite
app.put("/users/:userId/recipes/:recipeId/favorite", async (req, res) => {
  const { is_favorite } = req.body;

  const result = await db
    .update(userRecipes)
    .set({ isFavorite: is_favorite ?? false })
    .where(
      and(
        eq(userRecipes.userId, req.auth!.userId),
        eq(userRecipes.recipeId, req.params.recipeId)
      )
    )
    .returning();

  if (result.length === 0) {
    res.status(404).json({ error: "User recipe not found" });
    return;
  }

  res.json({ ok: true, is_favorite: result[0].isFavorite });
});

// Save a meal plan
app.post("/meal-plans", async (req, res) => {
  const user_id = req.auth!.userId;
  const { name, plan, recipe_ids, shopping_list } = req.body;
  if (!plan) {
    res.status(400).json({ error: "plan required" });
    return;
  }

  // Build shopping list from recipes if not explicitly provided
  const resolvedShoppingList: ShoppingListItem[] = shopping_list && shopping_list.length > 0
    ? shopping_list
    : await buildShoppingListFromRecipes(recipe_ids ?? []);

  const result = await db
    .insert(mealPlans)
    .values({
      userId: user_id,
      name: name || "Yemek Planı",
      plan,
      recipeIds: recipe_ids ?? [],
      shoppingList: resolvedShoppingList,
      shoppingIngredientIds: [],
    })
    .returning();

  res.status(201).json(toSnake(result[0]));
});

// Does this stored meal plan still need its recipe_ids / shopping_list backfilled?
function mealPlanNeedsBackfill(plan: { plan: any; shoppingList: any }): boolean {
  const planData = plan.plan as any;
  const shoppingListCol = plan.shoppingList as any[];
  // Needs migration if shopping_list is empty (but the plan has days) or is in
  // the old string[] format.
  const isOldFormat = shoppingListCol?.length > 0 && typeof shoppingListCol[0] === "string";
  return ((!shoppingListCol || shoppingListCol.length === 0) && planData?.days) || isOldFormat;
}

// Backfill one meal plan: create missing recipes, rebuild recipe_ids, and
// regenerate the shopping list. This does writes, so it only ever runs inside a
// background job — never in the GET handler.
async function backfillMealPlan(userId: string, plan: { id: string; plan: any; recipeIds: any; shoppingList: any }) {
  const planData = plan.plan as any;
  const recipeIdsCol = plan.recipeIds as string[];

  // Ensure feslihan creator exists
  await db
    .insert(platformCreators)
    .values({ username: "feslihan", platform: "other", displayName: "Feslihan AI" })
    .onConflictDoNothing();

  // Build titleToId for existing user recipes
  const mappings = await db
    .select({ recipeId: userRecipes.recipeId })
    .from(userRecipes)
    .where(eq(userRecipes.userId, userId));
  const existingRecipeRows = mappings.length > 0
    ? await db.select().from(recipes).where(inArray(recipes.id, mappings.map(m => m.recipeId)))
    : [];
  const titleToId: Record<string, string> = {};
  for (const r of existingRecipeRows) {
    titleToId[r.title] = r.id;
  }

  // Create missing recipes and resolve IDs (only for plans that need recipe creation)
  if (!recipeIdsCol || recipeIdsCol.length === 0) {
    for (const day of planData.days ?? []) {
      for (const meal of day.meals ?? []) {
        if (!meal.name) continue;
        const parts = (meal.name as string).split("+").map((s: string) => s.trim());
        for (const title of parts) {
          if (titleToId[title]) continue;
          const ingNames: string[] = (meal.ingredients ?? []).map(
            (i: string) => i.charAt(0).toUpperCase() + i.slice(1)
          );
          const ingIds = await resolveIngredientIds(ingNames);
          const url = `ai://meal-plan/${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
          const [created] = await db
            .insert(recipes)
            .values({
              platform: "other",
              platformUser: "feslihan",
              url,
              title,
              description: meal.description ?? "",
              ingredientsWithMeasures: ingNames.map((n: string) => ({ name: n, amount: "" })),
              ingredientsWithoutMeasures: ingIds,
              caloriesTotalKcal: meal.calories ?? null,
              cookingTimeMinutes: 30,
              tags: [],
              requestedBy: userId,
            })
            .returning();
          titleToId[title] = created.id;
          await saveUserRecipe(userId, created.id);
        }
      }
    }
  }

  // Rebuild plan with recipe_ids
  const newDays = (planData.days ?? []).map((day: any) => ({
    day_name: day.day_name,
    meals: (day.meals ?? []).map((meal: any) => {
      if (meal.recipe_ids) return { meal_type: meal.meal_type, recipe_ids: meal.recipe_ids };
      const parts = (meal.name as string || "").split("+").map((s: string) => s.trim());
      const ids = parts.map((t: string) => titleToId[t]).filter(Boolean);
      return { meal_type: meal.meal_type, recipe_ids: ids };
    }),
  }));

  const allIds = recipeIdsCol?.length > 0
    ? recipeIdsCol
    : Object.values(titleToId);
  const newPlan = { days: newDays, avg_calories_per_day: planData.avg_calories_per_day };

  // Build shopping list from recipe ingredients
  const newShoppingList = await buildShoppingListFromRecipes(allIds);

  // Update DB
  await db
    .update(mealPlans)
    .set({
      plan: newPlan,
      recipeIds: allIds,
      shoppingList: newShoppingList,
    })
    .where(eq(mealPlans.id, plan.id));
}

// Get user's meal plans. Read-only: old plans missing recipe_ids/shopping_list
// are backfilled by a durable background job, not inside this handler. The first
// fetch returns the un-backfilled rows; a subsequent fetch returns the migrated
// rows once the job has run.
app.get("/users/:userId/meal-plans", async (req, res) => {
  const userId = req.auth!.userId;
  const result = await db
    .select()
    .from(mealPlans)
    .where(eq(mealPlans.userId, userId))
    .orderBy(desc(mealPlans.createdAt));

  if (result.some((plan) => mealPlanNeedsBackfill(plan))) {
    await enqueueJob("meal-plan-backfill", { userId }).catch((err) =>
      console.error("[meal-plans] Failed to enqueue backfill:", err?.message || err)
    );
  }

  res.json(toSnake(result));
});

// Update a meal plan
app.put("/meal-plans/:id", async (req, res) => {
  try {
    const { name, plan, recipe_ids, shopping_list } = req.body;
    const updates: Record<string, any> = {};
    if (name !== undefined) updates.name = name;
    if (plan !== undefined) updates.plan = plan;
    if (recipe_ids !== undefined) updates.recipeIds = recipe_ids;
    if (shopping_list !== undefined) updates.shoppingList = shopping_list;

    // Auto-rebuild shopping list from recipes when recipe_ids change but no explicit shopping_list
    if (recipe_ids !== undefined && shopping_list === undefined) {
      updates.shoppingList = await buildShoppingListFromRecipes(recipe_ids);
    }

    if (Object.keys(updates).length === 0) {
      res.status(400).json({ error: "No fields to update" });
      return;
    }

    const result = await db
      .update(mealPlans)
      .set(updates)
      .where(and(eq(mealPlans.id, req.params.id), eq(mealPlans.userId, req.auth!.userId)))
      .returning();

    if (result.length === 0) {
      res.status(404).json({ error: "Plan not found" });
      return;
    }

    res.json(toSnake(result[0]));
  } catch (err) {
    console.error("[meal-plans PUT] Error:", err);
    res.status(500).json({ error: "Failed to update plan" });
  }
});

// Delete a meal plan
app.delete("/meal-plans/:id", async (req, res) => {
  await db
    .delete(mealPlans)
    .where(and(eq(mealPlans.id, req.params.id), eq(mealPlans.userId, req.auth!.userId)));
  res.status(204).send();
});

// ── Recipe Reviews ─────────────────────────────────────────────────────

app.post("/recipes/:recipeId/reviews", async (req, res) => {
  try {
    const user_id = req.auth!.userId;
    const { rating, comment } = req.body;
    if (!rating || rating < 1 || rating > 5) {
      res.status(400).json({ error: "rating (1-5) required" });
      return;
    }
    const result = await db.insert(recipeReviews).values({
      userId: user_id,
      recipeId: req.params.recipeId,
      rating,
      comment: comment || null,
    }).returning();
    res.json(toSnake(result[0]));
  } catch (err) {
    console.error("[reviews POST]", err);
    res.status(500).json({ error: "Failed to save review" });
  }
});

// Public board: every review on a recipe, with the author's name/avatar.
// LEFT JOIN so reviews survive a missing users row (client shows a fallback
// name). Extra keys are additive — shipped clients decoding the old shape
// keep working.
app.get("/recipes/:recipeId/reviews", async (req, res) => {
  const limit = Math.min(Math.max(parseInt(req.query.limit as string) || 50, 1), 100);
  const offset = Math.max(parseInt(req.query.offset as string) || 0, 0);

  const result = await db
    .select({
      id: recipeReviews.id,
      userId: recipeReviews.userId,
      recipeId: recipeReviews.recipeId,
      rating: recipeReviews.rating,
      comment: recipeReviews.comment,
      createdAt: recipeReviews.createdAt,
      userName: users.name,
      userAvatarUrl: users.avatarUrl,
    })
    .from(recipeReviews)
    .leftJoin(users, eq(users.clerkId, recipeReviews.userId))
    .where(eq(recipeReviews.recipeId, req.params.recipeId))
    .orderBy(desc(recipeReviews.createdAt))
    .limit(limit)
    .offset(offset);
  res.json(toSnake(result));
});

// Get all recipes a user has tried (with their reviews)
app.get("/users/:userId/reviews", async (req, res) => {
  const result = await db
    .select()
    .from(recipeReviews)
    .where(eq(recipeReviews.userId, req.auth!.userId))
    .orderBy(desc(recipeReviews.createdAt));
  res.json(toSnake(result));
});

// Delete a review
app.delete("/reviews/:reviewId", async (req, res) => {
  const user_id = req.auth!.userId;
  const result = await db
    .delete(recipeReviews)
    .where(
      and(
        eq(recipeReviews.id, req.params.reviewId),
        eq(recipeReviews.userId, user_id)
      )
    )
    .returning();
  if (result.length === 0) {
    res.status(404).json({ error: "Review not found" });
    return;
  }
  res.json({ ok: true });
});

// ── Pantry ──────────────────────────────────────────────────────────────

app.get("/users/:userId/pantry", async (req, res) => {
  const rows = await db
    .select({
      id: userPantry.id,
      ingredient_id: ingredients.id,
      ingredient_name: ingredients.name,
      price_tier: ingredients.priceTier,
      availability: ingredients.availability,
      added_at: userPantry.addedAt,
    })
    .from(userPantry)
    .innerJoin(ingredients, eq(userPantry.ingredientId, ingredients.id))
    .where(eq(userPantry.userId, req.auth!.userId))
    .orderBy(desc(userPantry.addedAt));
  res.json(rows);
});

app.post("/users/:userId/pantry", async (req, res) => {
  const { ingredient_names } = req.body as { ingredient_names: string[] };
  if (!ingredient_names?.length) {
    return res.status(400).json({ error: "ingredient_names required" });
  }

  // Resolve names to IDs using fuzzy matching
  const nameToId = await lookupIngredientMap(ingredient_names);
  const ingredientIds = [...new Set(nameToId.values())];
  if (ingredientIds.length === 0) {
    return res.status(201).json({ added: 0 });
  }

  // Filter out ingredients already in pantry
  const existing = await db
    .select({ ingredientId: userPantry.ingredientId })
    .from(userPantry)
    .where(
      and(
        eq(userPantry.userId, req.auth!.userId),
        inArray(userPantry.ingredientId, ingredientIds)
      )
    );
  const existingIds = new Set(existing.map((e) => e.ingredientId));
  const newIds = ingredientIds.filter((id) => !existingIds.has(id));

  if (newIds.length > 0) {
    await db.insert(userPantry).values(
      newIds.map((id) => ({
        userId: req.auth!.userId,
        ingredientId: id,
      }))
    );
  }
  res.status(201).json({ added: newIds.length });
});

app.delete("/users/:userId/pantry/:ingredientId", async (req, res) => {
  await db
    .delete(userPantry)
    .where(
      and(
        eq(userPantry.userId, req.auth!.userId),
        eq(userPantry.ingredientId, req.params.ingredientId)
      )
    );
  res.status(204).send();
});

// ── Shopping List ───────────────────────────────────────────────────────

app.get("/users/:userId/shopping-list", async (req, res) => {
  const rows = await db
    .select({
      id: userShoppingList.id,
      ingredient_id: ingredients.id,
      ingredient_name: ingredients.name,
      price_tier: ingredients.priceTier,
      availability: ingredients.availability,
      is_checked: userShoppingList.isChecked,
      added_at: userShoppingList.addedAt,
      alternative_ids: ingredients.alternativeIds,
    })
    .from(userShoppingList)
    .innerJoin(ingredients, eq(userShoppingList.ingredientId, ingredients.id))
    .where(eq(userShoppingList.userId, req.auth!.userId))
    .orderBy(desc(userShoppingList.addedAt));

  // Check which shopping list items have alternatives in the user's pantry
  const pantryRows = await db
    .select({ ingredientId: userPantry.ingredientId })
    .from(userPantry)
    .where(eq(userPantry.userId, req.auth!.userId));
  const pantryIds = new Set(pantryRows.map((r) => r.ingredientId));

  // Collect all alternative IDs we need to resolve names for
  const altIdsToResolve = new Set<string>();
  for (const row of rows) {
    for (const altId of (row.alternative_ids as string[]) ?? []) {
      if (pantryIds.has(altId)) altIdsToResolve.add(altId);
    }
  }

  // Fetch names for matched alternatives
  const altNames = new Map<string, string>();
  if (altIdsToResolve.size > 0) {
    const altRows = await db
      .select({ id: ingredients.id, name: ingredients.name })
      .from(ingredients)
      .where(inArray(ingredients.id, [...altIdsToResolve]));
    for (const r of altRows) altNames.set(r.id, r.name);
  }

  res.json(rows.map((r) => {
    const pantryAlt = ((r.alternative_ids as string[]) ?? []).find((id) => pantryIds.has(id));
    return {
      id: r.id,
      ingredient_id: r.ingredient_id,
      ingredient_name: r.ingredient_name,
      price_tier: r.price_tier,
      availability: r.availability,
      is_checked: r.is_checked,
      added_at: r.added_at,
      pantry_alternative: pantryAlt ? altNames.get(pantryAlt) ?? null : null,
    };
  }));
});

app.post("/users/:userId/shopping-list", async (req, res) => {
  const { ingredient_names } = req.body as { ingredient_names: string[] };
  if (!ingredient_names?.length) {
    return res.status(400).json({ error: "ingredient_names required" });
  }

  // UUID-shaped values are ingredient IDs (clients send them when they have
  // the resolved reference); everything else resolves by name with the same
  // fuzzy logic as recipe saving.
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const idLike = ingredient_names.filter((n) => uuidPattern.test(n.trim()));
  const nameLike = ingredient_names.filter((n) => !uuidPattern.test(n.trim()));

  const nameToId = await lookupIngredientMap(nameLike);
  const resolved = new Set(nameToId.values());
  if (idLike.length > 0) {
    const validRows = await db
      .select({ id: ingredients.id })
      .from(ingredients)
      .where(inArray(ingredients.id, idLike.map((n) => n.trim())));
    for (const r of validRows) resolved.add(r.id);
  }
  const ingredientIds = [...resolved];
  if (ingredientIds.length === 0) {
    return res.status(201).json({ added: 0 });
  }

  // Filter out ingredients already in shopping list
  const existing = await db
    .select({ ingredientId: userShoppingList.ingredientId })
    .from(userShoppingList)
    .where(
      and(
        eq(userShoppingList.userId, req.auth!.userId),
        inArray(userShoppingList.ingredientId, ingredientIds)
      )
    );
  const existingIds = new Set(existing.map((e) => e.ingredientId));
  const newIds = ingredientIds.filter((id) => !existingIds.has(id));

  if (newIds.length > 0) {
    await db.insert(userShoppingList).values(
      newIds.map((id) => ({
        userId: req.auth!.userId,
        ingredientId: id,
      }))
    );
  }
  res.status(201).json({ added: newIds.length });
});

app.put("/users/:userId/shopping-list/:itemId/check", async (req, res) => {
  const { is_checked } = req.body as { is_checked: boolean };
  await db
    .update(userShoppingList)
    .set({ isChecked: is_checked })
    .where(
      and(
        eq(userShoppingList.id, req.params.itemId),
        eq(userShoppingList.userId, req.auth!.userId)
      )
    );
  res.json({ ok: true });
});

app.delete("/users/:userId/shopping-list/:itemId", async (req, res) => {
  await db
    .delete(userShoppingList)
    .where(
      and(
        eq(userShoppingList.id, req.params.itemId),
        eq(userShoppingList.userId, req.auth!.userId)
      )
    );
  res.status(204).send();
});

// List all predefined tags
app.get("/tags", async (_req, res) => {
  const result = await db.select().from(tags).orderBy(tags.name);
  res.json(result.map((r) => r.name));
});

// Scrape recipe from nefisyemektarifleri.com
app.post("/recipes/scrape-web", aiRateLimit, async (req, res) => {
  const userId = req.auth!.userId;
  const { url } = req.body;
  let reserved = false;

  // Cache check BEFORE quota + Claude: a URL already in the catalog is served
  // from the DB at zero AI cost and does not consume a scan credit. The client
  // normally checks /recipes/lookup first, but enforcing it here guarantees a
  // cache hit is free regardless of client behavior.
  if (typeof url === "string" && url.length > 0) {
    const cachedRows = await db
      .select()
      .from(recipes)
      .where(eq(recipes.url, url))
      .limit(1);
    if (cachedRows.length > 0) {
      await saveUserRecipe(userId, cachedRows[0].id);
      res.json({ ...(await enrichRecipe(cachedRows[0])), cached: true });
      return;
    }
  }

  let html: string;
  try {
    // SSRF guard: parse the URL, enforce the host allowlist, block
    // private/link-local addresses, and re-validate every redirect hop.
    const result = await safeFetchText(url, {
      headers: {
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Accept": "text/html,application/xhtml+xml",
        "Accept-Language": "tr-TR,tr;q=0.9",
      },
    });
    html = result.text;
  } catch (err) {
    if (err instanceof UrlNotAllowedError) {
      res.status(err.statusCode).json({ error: err.message });
      return;
    }
    console.error("[scrape-web] fetch failed:", err);
    res.status(502).json({ error: "Failed to fetch page" });
    return;
  }

  try {
    // Reserve a quota slot BEFORE the expensive Claude call so a caller can't
    // loop this endpoint for unbounded Anthropic spend. Refunded below if the
    // nutrition analysis (or anything before it) fails.
    await reserveRecipeQuota(userId);
    reserved = true;

    // Parse title from <h1>
    const titleMatch = html.match(/<h1[^>]*>([^<]+)<\/h1>/i);
    const title = titleMatch ? decodeHTMLEntities(titleMatch[1].trim()) : "";

    // Parse servings & cooking time from article list items
    const servingsMatch = html.match(/([\d]+(?:-\d+)?)\s*Kişilik/i);
    const servings = servingsMatch ? parseInt(servingsMatch[1].split("-").pop()!) : null;

    const timeMatch = html.match(/([\d]+)dk\s*Hazırlık(?:,?\s*([\d]+)dk\s*Pişirme)?/i);
    let cookingTimeMinutes = 30;
    if (timeMatch) {
      cookingTimeMinutes = parseInt(timeMatch[1]) + (timeMatch[2] ? parseInt(timeMatch[2]) : 0);
    }

    // Parse ingredients: find all <li> inside the ingredients section
    const ingredientSectionMatch = html.match(
      /Malzemeler<\/h2>([\s\S]*?)<h2[^>]*>.*?Nasıl Yapılır/i
    );
    const ingredientsWithMeasures: { name: string; amount: string; ingredient_id: string }[] = [];
    const baseIngredients: string[] = [];
    if (ingredientSectionMatch) {
      const ingSection = ingredientSectionMatch[1];
      const liRegex = /<li[^>]*>([^<]+)<\/li>/gi;
      let match;
      while ((match = liRegex.exec(ingSection)) !== null) {
        const raw = decodeHTMLEntities(match[1].trim());
        const parts = parseIngredientLine(raw);
        ingredientsWithMeasures.push({ ...parts, ingredient_id: "" });
        baseIngredients.push(parts.name.toLocaleLowerCase("tr-TR"));
      }

      // Resolve ingredient IDs — lookup only; rows are created from
      // base_ingredients when the recipe is saved, never from display names.
      const nameToId = await lookupIngredientMap(ingredientsWithMeasures.map((i) => i.name));
      for (const ing of ingredientsWithMeasures) {
        const fixed = fixTurkish(ing.name);
        ing.ingredient_id = nameToId.get(fixed) ?? "";
      }
    }

    // Parse instructions: find all <li> inside the "Nasıl Yapılır" section
    const instructionSectionMatch = html.match(
      /Nasıl Yapılır\??\s*<\/h2>([\s\S]*?)(?:<h2|<div[^>]+class="[^"]*sharing)/i
    );
    let instructions = "";
    if (instructionSectionMatch) {
      const instSection = instructionSectionMatch[1];
      const liRegex = /<li[^>]*>([^<]+)<\/li>/gi;
      const steps: string[] = [];
      let match;
      while ((match = liRegex.exec(instSection)) !== null) {
        steps.push(decodeHTMLEntities(match[1].trim()));
      }
      instructions = steps.map((s, i) => `${i + 1}. ${s}`).join("\n");
    }

    // Parse thumbnail from og:image
    const ogImageMatch = html.match(/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i)
      ?? html.match(/<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i);
    const thumbnailUrl = ogImageMatch ? ogImageMatch[1].replace(/&amp;/g, "&") : null;

    // Parse author
    const authorMatch = html.match(/<a[^>]+class="[^"]*author[^"]*"[^>]*>([^<]+)<\/a>/i)
      ?? html.match(/<link[^>]+rel=["']author["'][^>]+href=["'][^"']*\/u\/([^/]+)\//i);
    // For nefisyemektarifleri: extract username from post-author-section /u/username/ link
    const nytAuthorMatch = !authorMatch
      ? html.match(/<section[^>]+post-author-section[\s\S]*?\/u\/([^/]+)\//i)
      : null;
    const platformUser = authorMatch
      ? decodeHTMLEntities(authorMatch[1].trim())
      : nytAuthorMatch
        ? decodeURIComponent(nytAuthorMatch[1].trim())
        : null;

    // Parse tags from breadcrumb
    const tagMatches: string[] = [];
    const breadcrumbRegex = /kategori\/tarifler\/([^/"]+)/gi;
    let bMatch;
    while ((bMatch = breadcrumbRegex.exec(html)) !== null) {
      const tag = decodeURIComponent(bMatch[1]).replace(/-tarifleri$/i, "").replace(/-/g, " ");
      const mapped = PREDEFINED_TAGS.find((t) => tag.includes(t));
      if (mapped && !tagMatches.includes(mapped)) tagMatches.push(mapped);
    }

    // Determine difficulty based on cooking time and ingredient count
    const difficulty = cookingTimeMinutes <= 20 && ingredientsWithMeasures.length <= 8
      ? "low"
      : cookingTimeMinutes >= 60 || ingredientsWithMeasures.length >= 15
        ? "high"
        : "medium";

    // Build recipe text for Claude nutrition estimation
    const recipeText = `${title}\n${servings} kişilik\nMalzemeler:\n${ingredientsWithMeasures.map((i) => `${i.amount} ${i.name}`).join("\n")}\n\nYapılış:\n${instructions}`;

    // Use Claude for nutrition estimation
    let nutrition: any = {};
    try {
      nutrition = await analyzeNutrition(recipeText);
    } catch (err) {
      console.error("[Scrape] Nutrition estimation failed:", err);
      // AI call failed — refund so the user isn't charged a quota slot for it.
      if (reserved) {
        await refundRecipeQuota(userId);
        reserved = false;
      }
    }

    // Determine freezer-friendliness from tags and title
    const freezerKeywords = ["mantı", "börek", "köfte", "dolma", "sarma", "çorba", "güveç", "pilav"];
    const freezerFriendly = freezerKeywords.some((kw) =>
      title.toLowerCase().includes(kw) || tagMatches.some((t) => t.includes(kw))
    );

    const result = {
      is_recipe: true,
      title,
      ingredients: ingredientsWithMeasures,
      base_ingredients: baseIngredients,
      instructions,
      cooking_time_minutes: cookingTimeMinutes,
      servings,
      calories_total_kcal: nutrition.calories_total_kcal ?? null,
      calories_per_serving_kcal: nutrition.calories_per_serving_kcal ?? null,
      protein_grams: nutrition.protein_grams ?? null,
      carbs_grams: nutrition.carbs_grams ?? null,
      fat_grams: nutrition.fat_grams ?? null,
      fiber_grams: nutrition.fiber_grams ?? null,
      difficulty,
      cuisine: "turkish",
      tags: tagMatches,
      freezer_friendly: freezerFriendly,
      platform_user: platformUser,
      thumbnail_url: thumbnailUrl,
      likes_count: 0,
      comments_count: 0,
    };

    console.log(`[Scrape] Parsed: ${title} (${ingredientsWithMeasures.length} ingredients, ${cookingTimeMinutes}dk)`);
    res.json(result);
  } catch (err: any) {
    if (reserved) await refundRecipeQuota(userId);
    if (err instanceof QuotaError) {
      res.status(err.statusCode).json({ error: err.message, code: err.code });
      return;
    }
    console.error("[Scrape] Error:", err.message || err);
    res.status(500).json({ error: "Scraping failed", detail: err.message });
  }
});

function decodeHTMLEntities(str: string): string {
  return str
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, " ")
    .replace(/&#(\d+);/g, (_m, code) => String.fromCharCode(parseInt(code)))
    .replace(/&#x([0-9a-fA-F]+);/g, (_m, code) => String.fromCharCode(parseInt(code, 16)));
}

function parseIngredientLine(raw: string): { name: string; amount: string } {
  // Patterns: "4 su bardağı un", "3-4 kaşık zeytinyağı", "yarım demet
  // maydanoz", "bir adet limon", "Sarımsaklı yoğurt"
  const { amount, name } = splitAmountFromName(raw);
  return { amount, name: cleanIngredientName(name) };
}

function cleanIngredientName(name: string): string {
  // Remove parenthetical notes: "nişasta ( yarım çay bardağı suda çözdürülmüş)" → "nişasta"
  let cleaned = name.replace(/\s*\([^)]*\)\s*/g, "").trim();
  // Collapse double spaces
  cleaned = cleaned.replace(/\s{2,}/g, " ");
  // Apply Turkish fixes and capitalize
  return fixTurkish(cleaned);
}

// Analyze recipe from video content
app.post("/ai/analyze", aiRateLimit, async (req, res) => {
  const userId = req.auth!.userId;
  let reserved = false;
  try {
    // Reserve a quota slot BEFORE the expensive Claude call so a caller can't
    // fire the request without holding one. Refunded below if analysis fails.
    await reserveRecipeQuota(userId);
    reserved = true;

    // Fetch existing ingredient names so Claude picks from them
    const allIngs = await getAllIngredients();
    const existingNames = allIngs.map((i) => i.name);

    const result = await analyzeRecipe({
      ...req.body,
      existing_ingredients: existingNames,
    });
    res.json(result);
  } catch (err: any) {
    if (reserved) await refundRecipeQuota(userId);
    if (err instanceof QuotaError) {
      res.status(err.statusCode).json({ error: err.message, code: err.code });
      return;
    }
    console.error("[AI Analyze]", err.stack || err.message || err);
    res.status(500).json({ error: "AI analysis failed", detail: err.message });
  }
});

// Generate meal plan
app.post("/ai/meal-plan", aiRateLimit, async (req, res) => {
  // Identity comes from the verified token, never from the request body.
  const authUserId = req.auth!.userId;
  let reserved = false;
  try {
    // Meal plans are metered per plan (free: none, plus: 2/month, pro:
    // unlimited). Reserve BEFORE the expensive Claude call, server-side —
    // trusting the client is where cost-DoS came from. Refunded on failure.
    await reserveMealPlanQuota(authUserId);
    reserved = true;
    // Fetch the user's recipes to seed the plan.
    let availableRecipes: any[] = [];
    // Build title→id map for resolving recipe names to IDs
    const titleToId: Record<string, string> = {};
    {
      const mappings = await db
        .select({ recipeId: userRecipes.recipeId })
        .from(userRecipes)
        .where(eq(userRecipes.userId, authUserId));

      if (mappings.length > 0) {
        const recipeIds = mappings.map((m) => m.recipeId);
        const userRecipeRows = await db
          .select()
          .from(recipes)
          .where(inArray(recipes.id, recipeIds));

        const resolvedRecipes = await enrichRecipes(userRecipeRows);
        for (const r of resolvedRecipes) {
          titleToId[(r as any).title] = (r as any).id;
        }
        availableRecipes = resolvedRecipes.map((r: any) => ({
          title: r.title,
          tags: r.tags as string[],
          cooking_time_minutes: r.cooking_time_minutes ?? 30,
          cuisine: r.cuisine,
          ingredients: r.ingredients_without_measures || [],
          freezer_friendly: r.freezer_friendly ?? false,
        }));
      }
    }

    const result = await generateMealPlan({
      ...req.body,
      available_recipes: availableRecipes,
    });

    // Shopping list will be built from saved recipes after they're created

    // Ensure "feslihan" platform creator exists for AI-generated recipes
    await db
      .insert(platformCreators)
      .values({ username: "feslihan", platform: "other", displayName: "Feslihan AI" })
      .onConflictDoNothing();

    // Collect all unique recipe titles from the AI plan
    const allMealEntries: { title: string; meal: any }[] = [];
    for (const day of result.days ?? []) {
      for (const meal of day.meals ?? []) {
        const parts = (meal.name as string).split("+").map((s: string) => s.trim());
        for (const title of parts) {
          if (!allMealEntries.find((e) => e.title === title)) {
            allMealEntries.push({ title, meal });
          }
        }
      }
    }

    // Resolve all ingredient names in one batch
    const allIngNames = new Set<string>();
    for (const entry of allMealEntries) {
      for (const ing of entry.meal.ingredients ?? []) {
        allIngNames.add(ing.charAt(0).toUpperCase() + ing.slice(1));
      }
    }
    const allIngIds = await resolveIngredientIds([...allIngNames]);

    // Create missing recipes in one batch
    const userId = authUserId;
    const newRecipeEntries = allMealEntries.filter((e) => !titleToId[e.title]);

    if (newRecipeEntries.length > 0) {
      const newRecipeValues = newRecipeEntries.map((entry) => {
        const ingNames: string[] = (entry.meal.ingredients ?? []).map(
          (ing: string) => ing.charAt(0).toUpperCase() + ing.slice(1)
        );
        return {
          platform: "other" as const,
          platformUser: "feslihan",
          url: `ai://meal-plan/${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
          title: entry.title,
          description: entry.meal.description ?? "",
          ingredientsWithMeasures: ingNames.map((n: string) => ({ name: n, amount: "" })),
          ingredientsWithoutMeasures: ingNames,
          caloriesTotalKcal: entry.meal.calories ?? null,
          cookingTimeMinutes: 30,
          tags: [],
          requestedBy: userId,
        };
      });

      const created = await db.insert(recipes).values(newRecipeValues).returning();

      for (let i = 0; i < created.length; i++) {
        titleToId[newRecipeEntries[i].title] = created[i].id;
      }

      // Link all new recipes to user
      // Ensure user exists
      await db
        .insert(users)
        .values({ clerkId: authUserId })
        .onConflictDoNothing();
      for (const r of created) {
        try {
          await saveUserRecipe(authUserId, r.id);
        } catch { /* ignore duplicates */ }
      }
    }

    // Build response with real recipe IDs
    const allRecipeIds: string[] = [];
    const leanDays = (result.days ?? []).map((day: any) => ({
      day_name: day.day_name,
      meals: (day.meals ?? []).map((meal: any) => {
        const parts = (meal.name as string).split("+").map((s: string) => s.trim());
        const ids = parts
          .map((title: string) => titleToId[title])
          .filter(Boolean) as string[];
        for (const id of ids) {
          if (!allRecipeIds.includes(id)) allRecipeIds.push(id);
        }
        return { meal_type: meal.meal_type, recipe_ids: ids };
      }),
    }));

    // Build shopping list from saved recipe ingredients
    const shoppingList = await buildShoppingListFromRecipes(allRecipeIds);

    res.json({
      days: leanDays,
      shopping_list: shoppingList,
      avg_calories_per_day: result.avg_calories_per_day ?? null,
      recipe_ids: allRecipeIds,
    });
  } catch (err: any) {
    // Give the slot back on any failure after it was reserved, so a failed
    // generation doesn't burn one of the month's plans.
    if (reserved) await refundMealPlanQuota(authUserId);
    if (err instanceof QuotaError) {
      res.status(err.statusCode).json({ error: err.message, code: err.code });
      return;
    }
    console.error("[AI MealPlan] ERROR:", err.stack || err.message || err);
    res.status(500).json({ error: "Meal plan generation failed", detail: err.message });
  }
});

// Quota overview for the admin panel: every user with their effective plan
// and this month's scan / meal-plan usage.
app.get("/admin/users/quota", requireAdmin, async (_req, res) => {
  const rows = await db.select().from(users).orderBy(desc(users.createdAt));
  const month = new Date().toISOString().slice(0, 7);
  const now = Date.now();

  // Saved-recipe count per user (one grouped query, not N queries).
  const recipeCountRows = await db
    .select({ userId: userRecipes.userId, count: sql<number>`count(*)::int` })
    .from(userRecipes)
    .groupBy(userRecipes.userId);
  const recipeCountByUser = new Map(recipeCountRows.map((r) => [r.userId, r.count]));

  // Activity from Clerk (last active / last sign-in / member-since) — best
  // effort: if Clerk is unreachable the panel still renders the DB columns.
  const activityByUser = new Map<string, { lastActiveAt: number | null; lastSignInAt: number | null }>();
  try {
    const clerk = createClerkClient({ secretKey: process.env.CLERK_SECRET_KEY });
    const list = await clerk.users.getUserList({ limit: 500 });
    for (const u of list.data) {
      activityByUser.set(u.id, {
        lastActiveAt: u.lastActiveAt ?? null,
        lastSignInAt: u.lastSignInAt ?? null,
      });
    }
  } catch (err) {
    console.error("[admin/quota] Clerk activity fetch failed:", err);
  }

  res.json(
    rows.map((u) => {
      const activity = activityByUser.get(u.clerkId);
      const unlimitedActive = u.unlimitedUntil != null && u.unlimitedUntil.getTime() > now;
      const plan = unlimitedActive ? "pro" : u.subscriptionPlan;
      const scanLimit = plan in PLAN_LIMITS ? PLAN_LIMITS[plan] : PLAN_LIMITS.free;
      const mealPlanLimit = plan in MEAL_PLAN_LIMITS ? MEAL_PLAN_LIMITS[plan] : MEAL_PLAN_LIMITS.free;
      // A stale reset month means the user simply hasn't used anything this month.
      const sameMonth = u.usageResetMonth === month;
      const scansUsed = sameMonth ? u.recipesUsedThisMonth : 0;
      const mealPlansUsed = sameMonth ? u.mealPlansUsedThisMonth : 0;
      return {
        clerk_id: u.clerkId,
        email: u.email,
        name: u.name,
        plan: u.subscriptionPlan,
        effective_plan: plan,
        unlimited_until: unlimitedActive ? u.unlimitedUntil!.toISOString() : null,
        scans_used: scansUsed,
        scan_limit: scanLimit,
        scans_remaining: scanLimit === null ? null : Math.max(0, scanLimit - scansUsed),
        meal_plans_used: mealPlansUsed,
        meal_plan_limit: mealPlanLimit,
        meal_plans_remaining:
          mealPlanLimit === null ? null : Math.max(0, mealPlanLimit - mealPlansUsed),
        recipe_count: recipeCountByUser.get(u.clerkId) ?? 0,
        last_active_at: activity?.lastActiveAt ? new Date(activity.lastActiveAt).toISOString() : null,
        last_sign_in_at: activity?.lastSignInAt ? new Date(activity.lastSignInAt).toISOString() : null,
        created_at: u.createdAt.toISOString(),
      };
    })
  );
});

// Grant one user unlimited (effective-pro) access for N days — comped
// accounts, support gestures, re-running an expired trial.
app.post("/admin/users/:clerkId/unlimited", requireAdmin, async (req, res) => {
  const clerkId = String(req.params.clerkId);
  const days = Number(req.body?.days ?? 30);
  if (!Number.isFinite(days) || days <= 0 || days > 365) {
    res.status(400).json({ error: "days must be between 1 and 365" });
    return;
  }

  const until = new Date(Date.now() + days * 24 * 60 * 60 * 1000);
  await db
    .insert(users)
    .values({ clerkId, unlimitedUntil: until })
    .onConflictDoUpdate({ target: users.clerkId, set: { unlimitedUntil: until } });

  console.log(`[Admin] Granted unlimited to ${clerkId} until ${until.toISOString()}`);
  res.json({ clerk_id: clerkId, unlimited_until: until.toISOString() });
});

// Grant ALL existing users unlimited access for N days (launch promo).
// Only extends: users whose current grant already reaches further keep it.
app.post("/admin/grant-unlimited-all", requireAdmin, async (req, res) => {
  const days = Number(req.body?.days ?? 30);
  if (!Number.isFinite(days) || days <= 0 || days > 365) {
    res.status(400).json({ error: "days must be between 1 and 365" });
    return;
  }

  const until = new Date(Date.now() + days * 24 * 60 * 60 * 1000);
  const updated = await db
    .update(users)
    .set({ unlimitedUntil: until })
    .where(or(isNull(users.unlimitedUntil), lt(users.unlimitedUntil, until)))
    .returning({ clerkId: users.clerkId });

  console.log(`[Admin] Granted unlimited to ${updated.length} users until ${until.toISOString()}`);
  res.json({ granted: updated.length, unlimited_until: until.toISOString() });
});

// Copy one user's recipes to all other users
app.post("/admin/share-recipes", requireAdmin, async (req, res) => {
  const { source_user_id } = req.body;
  if (!source_user_id) {
    res.status(400).json({ error: "source_user_id required" });
    return;
  }

  // Get all recipe IDs for the source user
  const sourceRecipes = await db
    .select({ recipeId: userRecipes.recipeId })
    .from(userRecipes)
    .where(eq(userRecipes.userId, source_user_id));

  if (sourceRecipes.length === 0) {
    res.status(404).json({ error: "No recipes found for source user" });
    return;
  }

  const recipeIds = sourceRecipes.map((r) => r.recipeId);

  // Get all users except the source
  const allUsers = await db.select({ clerkId: users.clerkId }).from(users);
  const targetUsers = allUsers.filter((u) => u.clerkId !== source_user_id);

  // The O(users×recipes) mapping loop runs as a durable background job.
  const jobId = await enqueueJob("share-recipes", { source_user_id });
  res.status(202).json({
    enqueued: true,
    job_id: jobId,
    source_user: source_user_id,
    recipes_count: recipeIds.length,
    target_users_count: targetUsers.length,
  });
});

// Map ALL recipes to ALL users
app.post("/admin/map-all-recipes", requireAdmin, async (_req, res) => {
  const [{ count: recipesCount }] = await db.select({ count: sql<number>`count(*)::int` }).from(recipes);
  const [{ count: usersCount }] = await db.select({ count: sql<number>`count(*)::int` }).from(users);

  // The O(users×recipes) mapping loop runs as a durable background job.
  const jobId = await enqueueJob("map-all-recipes", {});
  res.status(202).json({
    enqueued: true,
    job_id: jobId,
    recipes_count: recipesCount,
    users_count: usersCount,
  });
});

// Fill missing profile pictures for all platform creators
app.post("/admin/fill-creator-pictures", requireAdmin, async (_req, res) => {
  const creators = await db
    .select()
    .from(platformCreators)
    .where(isNull(platformCreators.profilePictureUrl));

  console.log(`[Admin] Found ${creators.length} creators without profile pictures`);

  let filled = 0;
  let failed = 0;
  for (const creator of creators) {
    try {
      await ensureCreator(creator.username, creator.platform);
      // Check if it was actually filled
      const updated = await db
        .select({ profilePictureUrl: platformCreators.profilePictureUrl })
        .from(platformCreators)
        .where(eq(platformCreators.username, creator.username))
        .limit(1);
      if (updated[0]?.profilePictureUrl) {
        filled++;
        console.log(`  [OK] ${creator.username}`);
      } else {
        failed++;
        console.log(`  [SKIP] ${creator.username} - no picture found`);
      }
    } catch (err) {
      failed++;
      console.log(`  [ERR] ${creator.username} - ${err}`);
    }
  }

  console.log(`[Admin] Done: ${filled} filled, ${failed} failed out of ${creators.length}`);
  res.json({ total: creators.length, filled, failed });
});

// Map platform recipes to all existing users (retroactive)
app.post("/admin/map-platform-recipes", requireAdmin, async (_req, res) => {
  const [{ count: usersCount }] = await db.select({ count: sql<number>`count(*)::int` }).from(users);

  // The per-user mapping loop runs as a durable background job.
  const jobId = await enqueueJob("map-platform-recipes", {});
  res.status(202).json({ enqueued: true, job_id: jobId, users_count: usersCount });
});

// Get Instagram creators missing profile pictures (for client-side backfill)
app.get("/creators/missing-pictures", async (_req, res) => {
  const creators = await db
    .select({ username: platformCreators.username, platform: platformCreators.platform })
    .from(platformCreators)
    .where(isNull(platformCreators.profilePictureUrl));
  res.json(creators);
});

// Upload a profile picture for a creator (called by iOS client during backfill)
app.put("/creators/:username/picture", async (req, res) => {
  const { base64 } = req.body;
  if (!base64) { res.status(400).json({ error: "base64 required" }); return; }

  const username = req.params.username.toLowerCase();
  try {
    const url = await uploadImage(base64);
    await db.update(platformCreators)
      .set({ profilePictureUrl: url })
      .where(eq(platformCreators.username, username));
    res.json({ ok: true });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// Seed predefined tags on startup
async function seedTags() {
  const existing = await db.select({ name: tags.name }).from(tags);
  const existingNames = new Set(existing.map((r) => r.name));
  const newTags = PREDEFINED_TAGS.filter((t) => !existingNames.has(t));

  if (newTags.length > 0) {
    await db
      .insert(tags)
      .values(newTags.map((name) => ({ name })))
      .onConflictDoNothing();
    console.log(`Seeded ${newTags.length} new tag(s): ${newTags.join(", ")}`);
  }
}

const PORT = 3000;
// Clean an ingredient name: strip alternatives, parentheticals, trailing qualifiers
function cleanIngredientNameFull(raw: string): string {
  let name = raw;
  // Remove parenthetical notes: "Nişasta ( Yarım Çay Bardağı...)" → "Nişasta"
  name = name.replace(/\s*\([^)]*\)\s*/g, "").trim();
  // Split on " veya ", " ya da ", " / " — keep first part
  name = name.split(/\s+veya\s+/i)[0];
  name = name.split(/\s+ya\s+da\s+/i)[0];
  name = name.split(/\s*\/\s*/)[0];
  // Strip trailing comma-phrases: "Yeşil Biber, Doğranmış" → "Yeşil Biber"
  name = name.split(",")[0];
  // Collapse spaces and capitalize
  return fixTurkish(name.trim());
}

// Fix ingredient names in all recipes: capitalize, fix Turkish chars, collapse spaces
app.post("/admin/fix-ingredient-names", requireAdmin, async (_req, res) => {
  try {
    const allRecipes = await db.select({ id: recipes.id, ingredientsWithMeasures: recipes.ingredientsWithMeasures }).from(recipes);
    let fixed = 0;

    for (const recipe of allRecipes) {
      const ings = recipe.ingredientsWithMeasures as { name: string; amount: string; section?: string; ingredient_id?: string }[] ?? [];
      if (ings.length === 0) continue;

      let changed = false;
      const updated = ings.map((ing) => {
        const cleanName = fixTurkish((ing.name ?? "").replace(/\s{2,}/g, " ").trim());
        const cleanAmount = (ing.amount ?? "").replace(/\s{2,}/g, " ").trim();
        if (cleanName !== ing.name || cleanAmount !== ing.amount) changed = true;
        return { ...ing, name: cleanName, amount: cleanAmount };
      });

      if (changed) {
        await db.update(recipes).set({ ingredientsWithMeasures: updated }).where(eq(recipes.id, recipe.id));
        fixed++;
      }
    }

    // Also fix ingredient table names
    const allIngs = await db.select().from(ingredients);
    let ingFixed = 0;
    for (const ing of allIngs) {
      const clean = fixTurkish(ing.name);
      if (clean !== ing.name) {
        // Check if the clean name already exists
        const existing = allIngs.find((other) => other.id !== ing.id && fixTurkish(other.name) === clean);
        if (!existing) {
          await db.update(ingredients).set({ name: clean }).where(eq(ingredients.id, ing.id));
          ingFixed++;
        }
      }
    }

    console.log(`[Fix Names] Fixed ${fixed} recipes, ${ingFixed} ingredients`);
    res.json({ recipes_fixed: fixed, ingredients_fixed: ingFixed, total_recipes: allRecipes.length });
  } catch (err: any) {
    console.error("[Fix Names]", err.message || err);
    res.status(500).json({ error: "Failed", detail: err.message });
  }
});

// Clean dirty ingredient names (veya, commas, slashes, parens) and merge into existing
app.post("/admin/clean-ingredient-names", requireAdmin, async (req, res) => {
  const dryRun = req.query.dry_run === "true";
  try {
    const all = await db.select().from(ingredients).orderBy(ingredients.name);
    const dirtyPattern = /veya|ya da|\/|,|\(/i;
    const dirty = all.filter((r) => dirtyPattern.test(r.name));

    const actions: { old: string; new: string; action: string }[] = [];

    for (const row of dirty) {
      const cleaned = cleanIngredientNameFull(row.name);
      if (cleaned === row.name) continue;

      // Check if the cleaned name already exists
      const existing = all.find((other) => other.id !== row.id && fixTurkish(other.name) === cleaned);

      if (existing) {
        // Merge into existing
        actions.push({ old: row.name, new: existing.name, action: "merge" });
        if (!dryRun) {
          await mergeIngredientRows(existing, [row], existing.name);
        }
      } else {
        // Just rename
        actions.push({ old: row.name, new: cleaned, action: "rename" });
        if (!dryRun) {
          await db.update(ingredients).set({ name: cleaned }).where(eq(ingredients.id, row.id));
        }
      }
    }

    // Also clean ingredient names inside recipes
    if (!dryRun) {
      const allRecipes = await db.select({ id: recipes.id, ingredientsWithMeasures: recipes.ingredientsWithMeasures }).from(recipes);
      let recipesFixed = 0;
      for (const recipe of allRecipes) {
        const ings = recipe.ingredientsWithMeasures as { name: string; amount: string; section?: string; ingredient_id?: string }[] ?? [];
        if (ings.length === 0) continue;
        let changed = false;
        const updated = ings.map((ing) => {
          const cleanName = cleanIngredientNameFull(ing.name);
          if (cleanName !== ing.name) changed = true;
          return { ...ing, name: cleanName };
        });
        if (changed) {
          await db.update(recipes).set({ ingredientsWithMeasures: updated }).where(eq(recipes.id, recipe.id));
          recipesFixed++;
        }
      }
      invalidateIngredientCache();
      console.log(`[Clean Names] Also fixed ${recipesFixed} recipes`);
    }

    console.log(`[Clean Names] ${actions.length} ingredients cleaned (dry_run=${dryRun})`);
    res.json({ dry_run: dryRun, cleaned: actions.length, actions });
  } catch (err: any) {
    console.error("[Clean Names]", err.message || err);
    res.status(500).json({ error: "Failed", detail: err.message });
  }
});

// ── Background job handlers ────────────────────────────────────────────
// Bulk / fire-and-forget work enqueued by request handlers is processed here by
// the durable worker. Keeping the logic alongside the helpers it depends on
// avoids circular imports with jobs.ts.
function registerJobHandlers() {
  registerJobHandler("classify-ingredients", async (payload) => {
    await classifyNewIngredients(payload.ids ?? []);
  });

  registerJobHandler("fetch-prices", async (payload) => {
    await fetchPricesJob(!!payload.forceAll);
  });

  registerJobHandler("share-recipes", async (payload) => {
    const sourceUserId = payload.source_user_id as string;
    const sourceRecipes = await db
      .select({ recipeId: userRecipes.recipeId })
      .from(userRecipes)
      .where(eq(userRecipes.userId, sourceUserId));
    const recipeIds = sourceRecipes.map((r) => r.recipeId);
    const allUsers = await db.select({ clerkId: users.clerkId }).from(users);
    const targetUsers = allUsers.filter((u) => u.clerkId !== sourceUserId);
    let created = 0;
    for (const user of targetUsers) {
      for (const recipeId of recipeIds) {
        await saveUserRecipe(user.clerkId, recipeId);
        created++;
      }
    }
    console.log(`[Admin] Shared ${recipeIds.length} recipes from ${sourceUserId} to ${targetUsers.length} users (${created} mappings)`);
  });

  registerJobHandler("map-all-recipes", async () => {
    const allRecipes = await db.select({ id: recipes.id }).from(recipes);
    const allUsers = await db.select({ clerkId: users.clerkId }).from(users);
    let created = 0;
    for (const user of allUsers) {
      for (const recipe of allRecipes) {
        await saveUserRecipe(user.clerkId, recipe.id);
        created++;
      }
    }
    console.log(`[Admin] Mapped ${allRecipes.length} recipes to ${allUsers.length} users (${created} mappings)`);
  });

  registerJobHandler("map-platform-recipes", async () => {
    const allUsers = await db.select({ clerkId: users.clerkId }).from(users);
    let totalMapped = 0;
    for (const user of allUsers) {
      totalMapped += await mapPlatformRecipesToUser(user.clerkId);
    }
    console.log(`[Admin] Mapped platform recipes to ${allUsers.length} users (${totalMapped} new mappings)`);
  });

  registerJobHandler("meal-plan-backfill", async (payload) => {
    const userId = payload.userId as string;
    const plans = await db.select().from(mealPlans).where(eq(mealPlans.userId, userId));
    for (const plan of plans) {
      if (!mealPlanNeedsBackfill(plan)) continue;
      try {
        await backfillMealPlan(userId, plan);
      } catch (err) {
        console.error(`[meal-plans backfill] Error for plan ${plan.id}:`, err);
      }
    }
  });
}

app.listen(PORT, async () => {
  await seedTags();
  await seedPlatformRecipes();
  registerJobHandlers();
  startJobWorker();
  console.log(`Feslihan API running on http://localhost:${PORT}`);
});
