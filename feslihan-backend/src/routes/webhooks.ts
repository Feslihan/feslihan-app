import express from "express";
import { db } from "../db.js";
import { users } from "../schema.js";
import { eq } from "drizzle-orm";

// RevenueCat webhook → keeps users.subscription_plan in sync with real
// purchases. This is the bridge that makes the SERVER-side quota respect a
// paid subscription; without it only the client UI would know about a
// purchase. Configure the same Authorization header value in the RevenueCat
// dashboard (Project settings → Webhooks) and in REVENUECAT_WEBHOOK_AUTH.
//
// Payload reference: https://www.revenuecat.com/docs/integrations/webhooks
// { "api_version": "1.0", "event": { "type", "app_user_id",
//   "entitlement_ids": ["feslihan_pro"], ... } }

const PRO_ENTITLEMENT = "feslihan_pro";
const PLUS_ENTITLEMENT = "feslihan_plus";

/** Event types after which entitlement_ids reflect current access. */
const ACCESS_EVENTS = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",
  "UNCANCELLATION",
  "TRANSFER",
]);

function planFromEntitlements(entitlementIds: string[] | null | undefined): "free" | "plus" | "pro" {
  if (entitlementIds?.includes(PRO_ENTITLEMENT)) return "pro";
  if (entitlementIds?.includes(PLUS_ENTITLEMENT)) return "plus";
  return "free";
}

export function createWebhooksRouter(): express.Router {
  const router = express.Router();

  router.post("/webhooks/revenuecat", async (req, res) => {
    const expected = process.env.REVENUECAT_WEBHOOK_AUTH;
    if (!expected || req.headers.authorization !== expected) {
      res.status(401).json({ error: "unauthorized" });
      return;
    }

    const event = req.body?.event;
    const type: string = event?.type ?? "UNKNOWN";
    const appUserId: string | undefined = event?.app_user_id;

    // Acknowledge fast in every handled-but-ignored case — RevenueCat retries
    // non-2xx responses, and there is nothing a retry would fix here.
    if (type === "TEST") {
      console.log("[rc-webhook] TEST event received");
      res.json({ ok: true });
      return;
    }

    if (!appUserId || appUserId.startsWith("$RCAnonymousID:")) {
      console.log(`[rc-webhook] ${type} for anonymous/missing app_user_id — ignored`);
      res.json({ ok: true, ignored: true });
      return;
    }

    let plan: "free" | "plus" | "pro" | null = null;
    if (ACCESS_EVENTS.has(type)) {
      plan = planFromEntitlements(event?.entitlement_ids);
    } else if (type === "EXPIRATION") {
      plan = "free";
    }
    // CANCELLATION (auto-renew off, access continues until period end) and
    // BILLING_ISSUE intentionally change nothing — EXPIRATION downgrades.

    if (plan === null) {
      console.log(`[rc-webhook] ${type} for ${appUserId} — no plan change`);
      res.json({ ok: true, ignored: true });
      return;
    }

    try {
      const updated = await db
        .update(users)
        .set({ subscriptionPlan: plan })
        .where(eq(users.clerkId, appUserId))
        .returning({ clerkId: users.clerkId });

      if (updated.length === 0) {
        // User row may not exist yet (purchase before first /users/sync).
        await db
          .insert(users)
          .values({ clerkId: appUserId, subscriptionPlan: plan })
          .onConflictDoNothing();
      }
      console.log(`[rc-webhook] ${type}: ${appUserId} → ${plan}`);
      res.json({ ok: true, plan });
    } catch (err) {
      console.error("[rc-webhook] db update failed:", err);
      // 500 → RevenueCat retries, which IS what we want for transient DB errors.
      res.status(500).json({ error: "update failed" });
    }
  });

  return router;
}
