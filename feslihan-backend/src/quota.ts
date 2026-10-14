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
 */

// Monthly AI-recipe allowance per plan. Mirrors FeslihanPlan.monthlyRecipeLimit
// in the iOS app. `null` = unlimited.
export const PLAN_LIMITS: Record<string, number | null> = {
  free: 10,
  plus: 30,
  pro: null,
};

// Plans allowed to use premium-only AI features (meal planning).
const PREMIUM_PLANS = new Set(["plus", "pro"]);

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

/**
 * Load the user's plan, creating a default `free` row if the user has never
 * synced. Returns the plan string.
 */
async function ensureUserPlan(userId: string): Promise<string> {
  const rows = await db
    .select({ plan: users.subscriptionPlan })
    .from(users)
    .where(eq(users.clerkId, userId))
    .limit(1);
  if (rows.length > 0) return rows[0].plan;

  // No row yet (user hit an AI route before /users/sync). Create a minimal one.
  await db
    .insert(users)
    .values({ clerkId: userId })
    .onConflictDoNothing();
  return "free";
}

/**
 * Reserve one recipe generation against the user's monthly quota BEFORE the
 * expensive Claude call, so a caller can never fire the request without holding
 * a slot. Rolls the monthly counter over when the month changes. Throws
 * {@link QuotaError} (402) when the plan's limit is already reached.
 *
 * Runs in a transaction with a row lock so concurrent requests can't both slip
 * past the limit.
 */
export async function reserveRecipeQuota(userId: string): Promise<void> {
  const plan = await ensureUserPlan(userId);
  const limit = plan in PLAN_LIMITS ? PLAN_LIMITS[plan] : PLAN_LIMITS.free;
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
    // Roll over the counter if we've crossed into a new month.
    const used = user.usageResetMonth === month ? user.recipesUsedThisMonth : 0;

    if (limit !== null && used >= limit) {
      throw new QuotaError(
        `Monthly recipe limit reached (${limit})`,
        402,
        "quota_exceeded"
      );
    }

    await tx
      .update(users)
      .set({ recipesUsedThisMonth: used + 1, usageResetMonth: month })
      .where(eq(users.clerkId, userId));
  });
}

/**
 * Return a previously-reserved slot when the downstream work fails, so a failed
 * generation doesn't burn the user's quota. Never lets the counter go negative
 * and only refunds within the same billing month.
 */
export async function refundRecipeQuota(userId: string): Promise<void> {
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
      if (user.usageResetMonth !== month || user.recipesUsedThisMonth <= 0) return;
      await tx
        .update(users)
        .set({ recipesUsedThisMonth: user.recipesUsedThisMonth - 1 })
        .where(eq(users.clerkId, userId));
    });
  } catch (err) {
    // A failed refund is not worth failing the request over; just log it.
    console.warn("[quota] refund failed:", err);
  }
}

/**
 * Assert the user is on a premium plan (for meal planning and other
 * premium-only AI features). Throws {@link QuotaError} (402) otherwise.
 */
export async function requirePremiumPlan(userId: string): Promise<void> {
  const plan = await ensureUserPlan(userId);
  if (!PREMIUM_PLANS.has(plan)) {
    throw new QuotaError(
      "This feature requires a Feslihan+ or Pro subscription",
      402,
      "premium_required"
    );
  }
}
