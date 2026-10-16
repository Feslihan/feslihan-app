import {
  pgTable,
  uuid,
  varchar,
  text,
  integer,
  real,
  jsonb,
  timestamp,
  pgEnum,
  boolean,
  uniqueIndex,
} from "drizzle-orm/pg-core";

export const subscriptionPlanEnum = pgEnum("subscription_plan", [
  "free",
  "plus",
  "pro",
]);

export const users = pgTable("users", {
  clerkId: varchar("clerk_id", { length: 255 }).primaryKey(),
  email: varchar("email", { length: 255 }),
  name: varchar("name", { length: 255 }),
  avatarUrl: text("avatar_url"),
  subscriptionPlan: subscriptionPlanEnum("subscription_plan").notNull().default("free"),
  // While this is in the future, the user is treated as `pro` regardless of
  // subscriptionPlan (new-user trial / promo / comped account).
  unlimitedUntil: timestamp("unlimited_until", { withTimezone: true }),
  recipesUsedThisMonth: integer("recipes_used_this_month").notNull().default(0),
  mealPlansUsedThisMonth: integer("meal_plans_used_this_month").notNull().default(0),
  usageResetMonth: varchar("usage_reset_month", { length: 7 }),
  friendCode: varchar("friend_code", { length: 12 }).unique(),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date()),
});

export type User = typeof users.$inferSelect;
export type NewUser = typeof users.$inferInsert;

export const platformEnum = pgEnum("platform_type", [
  "instagram",
  "tiktok",
  "x",
  "nefisyemektarifleri",
  "other",
]);

export const difficultyEnum = pgEnum("difficulty_type", [
  "low",
  "medium",
  "high",
]);

export const priceTierEnum = pgEnum("price_tier", [
  "cheap",
  "neutral",
  "expensive",
]);

export const availabilityEnum = pgEnum("availability", [
  "easy",
  "neutral",
  "rare",
]);

export const platformCreators = pgTable("platform_creators", {
  username: varchar("username", { length: 255 }).primaryKey(),
  platform: platformEnum("platform").notNull(),
  displayName: varchar("display_name", { length: 255 }),
  profilePictureUrl: text("profile_picture_url"),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date()),
});

export const recipes = pgTable("recipes", {
  id: uuid("id").primaryKey().defaultRandom(),

  // Source info
  platform: platformEnum("platform").notNull(),
  platformUser: varchar("platform_user", { length: 255 }).notNull().references(() => platformCreators.username),
  url: text("url").notNull().unique(),
  likesCount: integer("likes_count").notNull().default(0),
  commentsCount: integer("comments_count").notNull().default(0),
  caption: text("caption"),

  // Recipe content
  title: varchar("title", { length: 500 }).notNull(),
  description: text("description").notNull(),
  ingredientsWithMeasures: jsonb("ingredients_with_measures")
    .notNull()
    .default([]),
  ingredientsWithoutMeasures: jsonb("ingredients_without_measures")
    .notNull()
    .default([]),
  thumbnailUrl: text("thumbnail_url"),
  servings: integer("servings"),

  // Nutrition
  caloriesTotalKcal: real("calories_total_kcal"),
  caloriesTotalJoules: real("calories_total_joules"),
  caloriesPerServingKcal: real("calories_per_serving_kcal"),
  proteinGrams: real("protein_grams"),
  carbsGrams: real("carbs_grams"),
  fatGrams: real("fat_grams"),
  fiberGrams: real("fiber_grams"),

  // Classification
  tags: jsonb("tags").notNull().default([]),
  cookingTimeMinutes: integer("cooking_time_minutes").notNull(),
  cuisine: varchar("cuisine", { length: 50 }),
  difficulty: difficultyEnum("difficulty"),
  freezerFriendly: boolean("freezer_friendly").notNull().default(false),
  healthScore: real("health_score"),

  // Tracking
  saveCount: integer("save_count").notNull().default(0),
  requestedBy: varchar("requested_by", { length: 255 }).notNull(),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date()),
});

export const ingredients = pgTable("ingredients", {
  id: uuid("id").primaryKey().defaultRandom(),
  name: varchar("name", { length: 255 }).notNull().unique(),
  priceTier: priceTierEnum("price_tier"),
  availability: availabilityEnum("availability"),
  pricePerUnit: real("price_per_unit"),
  priceUnit: varchar("price_unit", { length: 20 }),
  priceUpdatedAt: timestamp("price_updated_at", { withTimezone: true }),
  // Unit conversions
  defaultUnit: varchar("default_unit", { length: 10 }),  // 'g', 'ml', 'adet'
  densityGMl: real("density_g_ml"),                       // grams per ml (for volume→weight)
  gramPerAdet: real("gram_per_adet"),                     // grams per 1 piece (for countable items)
  alternativeIds: jsonb("alternative_ids").notNull().default([]), // IDs of alternative/substitute ingredients
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export const tags = pgTable("tags", {
  id: uuid("id").primaryKey().defaultRandom(),
  name: varchar("name", { length: 100 }).notNull().unique(),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export const userFolders = pgTable("user_folders", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: varchar("user_id", { length: 255 })
    .notNull()
    .references(() => users.clerkId),
  name: varchar("name", { length: 255 }).notNull(),
  emoji: varchar("emoji", { length: 10 }),
  sortOrder: integer("sort_order").notNull().default(0),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date()),
});

export const userRecipes = pgTable("user_recipes", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: varchar("user_id", { length: 255 })
    .notNull()
    .references(() => users.clerkId),
  recipeId: uuid("recipe_id")
    .notNull()
    .references(() => recipes.id),
  folderId: uuid("folder_id")
    .references(() => userFolders.id),
  isFavorite: boolean("is_favorite").notNull().default(false),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export const mealPlans = pgTable("meal_plans", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: varchar("user_id", { length: 255 })
    .notNull()
    .references(() => users.clerkId),
  name: varchar("name", { length: 255 }).notNull(),
  plan: jsonb("plan").notNull(),
  recipeIds: jsonb("recipe_ids").notNull().default([]),
  shoppingList: jsonb("shopping_list").notNull().default([]),
  shoppingIngredientIds: jsonb("shopping_ingredient_ids").notNull().default([]),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export const userPantry = pgTable("user_pantry", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: varchar("user_id", { length: 255 })
    .notNull()
    .references(() => users.clerkId),
  ingredientId: uuid("ingredient_id")
    .notNull()
    .references(() => ingredients.id),
  addedAt: timestamp("added_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export const userShoppingList = pgTable("user_shopping_list", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: varchar("user_id", { length: 255 })
    .notNull()
    .references(() => users.clerkId),
  ingredientId: uuid("ingredient_id")
    .notNull()
    .references(() => ingredients.id),
  isChecked: boolean("is_checked").notNull().default(false),
  addedAt: timestamp("added_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export const recipeReviews = pgTable("recipe_reviews", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: varchar("user_id", { length: 255 })
    .notNull()
    .references(() => users.clerkId),
  recipeId: uuid("recipe_id")
    .notNull()
    .references(() => recipes.id),
  rating: integer("rating").notNull(),
  comment: text("comment"),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

// Mutual-follow connections. A row is a directed request (requester → addressee);
// accepting flips status to "accepted" and the pair counts as friends in both
// directions. Declining deletes the row so a fresh request is always possible.
export const connectionStatusEnum = pgEnum("connection_status", [
  "pending",
  "accepted",
]);

export const connections = pgTable(
  "connections",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    requesterId: varchar("requester_id", { length: 255 })
      .notNull()
      .references(() => users.clerkId),
    addresseeId: varchar("addressee_id", { length: 255 })
      .notNull()
      .references(() => users.clerkId),
    status: connectionStatusEnum("status").notNull().default("pending"),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    respondedAt: timestamp("responded_at", { withTimezone: true }),
  },
  (t) => [uniqueIndex("connections_pair_uq").on(t.requesterId, t.addresseeId)]
);

export const shareStatusEnum = pgEnum("share_status", [
  "pending",
  "accepted",
  "dismissed",
]);

// A recipe sent from one friend to another. Accepting inserts a user_recipes
// row for the recipient (recipes themselves are global).
export const recipeShares = pgTable("recipe_shares", {
  id: uuid("id").primaryKey().defaultRandom(),
  senderId: varchar("sender_id", { length: 255 })
    .notNull()
    .references(() => users.clerkId),
  recipientId: varchar("recipient_id", { length: 255 })
    .notNull()
    .references(() => users.clerkId),
  recipeId: uuid("recipe_id")
    .notNull()
    .references(() => recipes.id),
  message: text("message"),
  status: shareStatusEnum("status").notNull().default("pending"),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  respondedAt: timestamp("responded_at", { withTimezone: true }),
});

export type Connection = typeof connections.$inferSelect;
export type RecipeShare = typeof recipeShares.$inferSelect;

// APNs device tokens for server→device push. Token is the PK: a device that
// switches accounts is simply re-pointed at the new user on upsert.
export const deviceTokens = pgTable("device_tokens", {
  token: varchar("token", { length: 200 }).primaryKey(),
  userId: varchar("user_id", { length: 255 })
    .notNull()
    .references(() => users.clerkId),
  // "sandbox" (Xcode builds) or "production" (TestFlight/App Store) — picks
  // the APNs host; a token only works against its own environment.
  environment: varchar("environment", { length: 12 }).notNull().default("production"),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date()),
});

export type DeviceToken = typeof deviceTokens.$inferSelect;

// Durable background-job queue. Rows survive process restarts / serverless
// cold-starts so fire-and-forget work (classification, price fetches, bulk
// admin mappings, meal-plan backfills) is never lost. A worker claims pending
// rows with FOR UPDATE SKIP LOCKED and retries on failure.
export const jobStatusEnum = pgEnum("job_status", [
  "pending",
  "running",
  "done",
  "failed",
]);

export const backgroundJobs = pgTable("background_jobs", {
  id: uuid("id").primaryKey().defaultRandom(),
  type: varchar("type", { length: 100 }).notNull(),
  payload: jsonb("payload").notNull().default({}),
  status: jobStatusEnum("status").notNull().default("pending"),
  attempts: integer("attempts").notNull().default(0),
  maxAttempts: integer("max_attempts").notNull().default(3),
  lastError: text("last_error"),
  runAt: timestamp("run_at", { withTimezone: true }).notNull().defaultNow(),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export type BackgroundJob = typeof backgroundJobs.$inferSelect;

export type Recipe = typeof recipes.$inferSelect;
export type NewRecipe = typeof recipes.$inferInsert;
export type IngredientRow = typeof ingredients.$inferSelect;
export type TagRow = typeof tags.$inferSelect;
export type PlatformCreator = typeof platformCreators.$inferSelect;
