import { eq } from "drizzle-orm";
import { db } from "./db.js";
import { users } from "./schema.js";

/**
 * Server-side usage metering for the paid AI features.
 *
 * The schema has always had `recipesUsedThisMonth` / `usageResetMonth`, but
 * nothing enforced them — the only quota check lived client-side
 * (SubscriptionService.swift) and reset on reinstall. That let anyone drive
 * unlimited 8–16K-token Claude calls (cost-DoS). This module enforces the same
 * per-plan limits on the server, atomically.
 *
 * Two meters share one monthly window (`usageResetMonth`):
 *  - recipe scans: new-to-catalog AI analyses (cache hits never pass through)
 *  - meal plans: weekly plan generations
 */

// Monthly allowance of new-to-catalog AI recipe scans per plan. Mirrors
// FeslihanPlan.monthlyRecipeLimit in the iOS app. `null` = unlimited.
export const PLAN_LIMITS: Record<string, number | null> = {
  free: 3,
  plus: 20,
  pro: null,
};

// Monthly allowance of AI meal plan generations per plan. Mirrors
// FeslihanPlan.monthlyMealPlanLimit in the iOS app. `null` = unlimited.
export const MEAL_PLAN_LIMITS: Record<string, number | null> = {
  free: 0,
  plus: 2,
  pro: null,
};

export class QuotaError extends Error {
  constructor(
    message: string,
    readonly statusCode: number,
    readonly code: string
  ) {
    super(message);
    this.name = "QuotaError";
  }
}

// Current billing month as "YYYY-MM" (server clock, UTC).
function currentMonth(): string {
  return new Date().toISOString().slice(0, 7);
}

// Days of unlimited (effective-pro) access granted to brand-new users.
// Set NEW_USER_UNLIMITED_DAYS=0 to disable the trial for new signups.
const NEW_USER_UNLIMITED_DAYS = Number(process.env.NEW_USER_UNLIMITED_DAYS ?? "30");

/**
 * Expiry timestamp for a new user's unlimited trial, or null when the trial
 * is disabled. Used here and by POST /users/sync when creating user rows.
 */
export function newUserTrialEnd(): Date | null {
  if (!Number.isFinite(NEW_USER_UNLIMITED_DAYS) || NEW_USER_UNLIMITED_DAYS <= 0) return null;
  return new Date(Date.now() + NEW_USER_UNLIMITED_DAYS * 24 * 60 * 60 * 1000);
}

/**
 * Load the user's EFFECTIVE plan — `pro` while an unlimited grant (trial,
 * promo, comped account) is active, the stored subscription plan otherwise.
 * Creates a default row (with the new-user trial) if the user has never
 * synced.
 */
async function ensureUserPlan(userId: string): Promise<string> {
  const rows = await db
    .select({ plan: users.subscriptionPlan, unlimitedUntil: users.unlimitedUntil })
    .from(users)
    .where(eq(users.clerkId, userId))
    .limit(1);
  if (rows.length > 0) {
    const { plan, unlimitedUntil } = rows[0];
    if (unlimitedUntil && unlimitedUntil.getTime() > Date.now()) return "pro";
    return plan;
  }

  // No row yet (user hit an AI route before /users/sync). Create a minimal
  // one, including the new-user trial so both creation paths behave the same.
  const trialEnd = newUserTrialEnd();
  await db
    .insert(users)
    .values({ clerkId: userId, unlimitedUntil: trialEnd })
    .onConflictDoNothing();
  return trialEnd ? "pro" : "free";
}

type Meter = "recipes" | "mealPlans";

const METER_CONFIG: Record<
  Meter,
  { limits: Record<string, number | null>; exceededCode: string; exceededMessage: (limit: number) => string }
> = {
  recipes: {
    limits: PLAN_LIMITS,
    exceededCode: "quota_exceeded",
    exceededMessage: (limit) => `Monthly recipe limit reached (${limit})`,
  },
  mealPlans: {
    limits: MEAL_PLAN_LIMITS,
    exceededCode: "meal_plan_quota_exceeded",
    exceededMessage: (limit) => `Monthly meal plan limit reached (${limit})`,
  },
};

/**
 * Reserve one unit on the given meter BEFORE the expensive Claude call, so a
 * caller can never fire the request without holding a slot. Rolls BOTH monthly
 * counters over when the month changes. Throws {@link QuotaError} (402) when
 * the plan's limit is already reached.
 *
 * Runs in a transaction with a row lock so concurrent requests can't both slip
 * past the limit.
 */
async function reserveQuota(userId: string, meter: Meter): Promise<void> {
  const plan = await ensureUserPlan(userId);
  const config = METER_CONFIG[meter];
  const limit = plan in config.limits ? config.limits[plan] : config.limits.free;
  const month = currentMonth();

  await db.transaction(async (tx) => {
    const rows = await tx
      .select()
      .from(users)
      .where(eq(users.clerkId, userId))
      .for("update")
      .limit(1);

    if (rows.length === 0) {
      // Should not happen (ensureUserPlan just created it) but fail closed.
      throw new QuotaError("User not found", 404, "user_not_found");
    }

    const user = rows[0];
    // Roll over both counters if we've crossed into a new month.
    const sameMonth = user.usageResetMonth === month;
    const recipesUsed = sameMonth ? user.recipesUsedThisMonth : 0;
    const mealPlansUsed = sameMonth ? user.mealPlansUsedThisMonth : 0;
    const used = meter === "recipes" ? recipesUsed : mealPlansUsed;

    if (limit !== null && used >= limit) {
      // A zero limit means the plan has no access to this feature at all —
      // tell the client it's an upgrade situation, not a this-month situation.
      if (limit === 0) {
        throw new QuotaError(
          "This feature requires a Feslihan+ or Pro subscription",
          402,
          "premium_required"
        );
      }
      throw new QuotaError(config.exceededMessage(limit), 402, config.exceededCode);
    }

    await tx
      .update(users)
      .set({
        recipesUsedThisMonth: meter === "recipes" ? recipesUsed + 1 : recipesUsed,
        mealPlansUsedThisMonth: meter === "mealPlans" ? mealPlansUsed + 1 : mealPlansUsed,
        usageResetMonth: month,
      })
      .where(eq(users.clerkId, userId));
  });
}

/**
 * Return a previously-reserved slot when the downstream work fails, so a failed
 * generation doesn't burn the user's quota. Never lets the counter go negative
 * and only refunds within the same billing month.
 */
async function refundQuota(userId: string, meter: Meter): Promise<void> {
  const month = currentMonth();
  try {
    await db.transaction(async (tx) => {
      const rows = await tx
        .select()
        .from(users)
        .where(eq(users.clerkId, userId))
        .for("update")
        .limit(1);
      if (rows.length === 0) return;
      const user = rows[0];
      if (user.usageResetMonth !== month) return;
      const used = meter === "recipes" ? user.recipesUsedThisMonth : user.mealPlansUsedThisMonth;
      if (used <= 0) return;
      await tx
        .update(users)
        .set(
          meter === "recipes"
            ? { recipesUsedThisMonth: used - 1 }
            : { mealPlansUsedThisMonth: used - 1 }
        )
        .where(eq(users.clerkId, userId));
    });
  } catch (err) {
    // A failed refund is not worth failing the request over; just log it.
    console.warn("[quota] refund failed:", err);
  }
}

export const reserveRecipeQuota = (userId: string) => reserveQuota(userId, "recipes");
export const refundRecipeQuota = (userId: string) => refundQuota(userId, "recipes");
export const reserveMealPlanQuota = (userId: string) => reserveQuota(userId, "mealPlans");
export const refundMealPlanQuota = (userId: string) => refundQuota(userId, "mealPlans");

export interface QuotaStatus {
  plan: string;
  used: number;
  /** null = unlimited */
  limit: number | null;
  /** null = unlimited */
  remaining: number | null;
  meal_plans_used: number;
  /** null = unlimited */
  meal_plan_limit: number | null;
  /** null = unlimited */
  meal_plans_remaining: number | null;
  /** ISO timestamp while an unlimited grant (trial/promo) is active, else null */
  unlimited_until: string | null;
  month: string;
}

/**
 * Read-only quota snapshot for the client (scan sheet, paywall, settings).
 * Quota only meters new-to-catalog AI scans and meal plan generations —
 * cached recipe saves are free and never pass through here.
 */
export async function getQuotaStatus(userId: string): Promise<QuotaStatus> {
  const plan = await ensureUserPlan(userId);
  const limit = plan in PLAN_LIMITS ? PLAN_LIMITS[plan] : PLAN_LIMITS.free;
  const mealPlanLimit = plan in MEAL_PLAN_LIMITS ? MEAL_PLAN_LIMITS[plan] : MEAL_PLAN_LIMITS.free;
  const month = currentMonth();

  const rows = await db
    .select({
      used: users.recipesUsedThisMonth,
      mealPlansUsed: users.mealPlansUsedThisMonth,
      resetMonth: users.usageResetMonth,
      unlimitedUntil: users.unlimitedUntil,
    })
    .from(users)
    .where(eq(users.clerkId, userId))
    .limit(1);

  const sameMonth = rows.length > 0 && rows[0].resetMonth === month;
  const used = sameMonth ? rows[0].used : 0;
  const mealPlansUsed = sameMonth ? rows[0].mealPlansUsed : 0;
  const unlimitedUntil = rows.length > 0 ? rows[0].unlimitedUntil : newUserTrialEnd();
  const unlimitedActive = unlimitedUntil != null && unlimitedUntil.getTime() > Date.now();
  return {
    plan,
    used,
    limit,
    remaining: limit === null ? null : Math.max(0, limit - used),
    meal_plans_used: mealPlansUsed,
    meal_plan_limit: mealPlanLimit,
    meal_plans_remaining:
      mealPlanLimit === null ? null : Math.max(0, mealPlanLimit - mealPlansUsed),
    unlimited_until: unlimitedActive ? unlimitedUntil.toISOString() : null,
    month,
  };
}
