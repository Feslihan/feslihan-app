import express from "express";
import { db } from "../db.js";
import {
  users,
  recipes,
  userRecipes,
  connections,
  recipeShares,
} from "../schema.js";
import { eq, and, or, desc, sql } from "drizzle-orm";
import { rateLimit } from "../middleware/rate-limit.js";

// Social graph routes: friend codes, mutual-follow requests, friend recipe
// browsing, and friend-to-friend recipe shares. These are the only routes that
// deliberately read another user's data — every cross-user read is gated on an
// accepted connection between the caller and the target.

interface SocialDeps {
  toSnake: (obj: any) => any;
  enrichRecipes: (recipes: any[]) => Promise<any[]>;
  rewriteThumbnail: (obj: any) => any;
}

// No I/L/O/0/1 — codes get read aloud over the phone to mom.
const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

function randomCode(length: number): string {
  let code = "";
  for (let i = 0; i < length; i++) {
    code += CODE_ALPHABET[Math.floor(Math.random() * CODE_ALPHABET.length)];
  }
  return `FES-${code}`;
}

const PUBLIC_USER_FIELDS = {
  clerkId: users.clerkId,
  name: users.name,
  avatarUrl: users.avatarUrl,
};

// Accepted connection between two users, in either direction.
async function findConnection(a: string, b: string) {
  const rows = await db
    .select()
    .from(connections)
    .where(
      or(
        and(eq(connections.requesterId, a), eq(connections.addresseeId, b)),
        and(eq(connections.requesterId, b), eq(connections.addresseeId, a))
      )
    )
    .limit(1);
  return rows[0] ?? null;
}

async function areFriends(a: string, b: string): Promise<boolean> {
  const row = await findConnection(a, b);
  return row?.status === "accepted";
}

export function createSocialRouter(deps: SocialDeps): express.Router {
  const { toSnake, enrichRecipes, rewriteThumbnail } = deps;
  const router = express.Router();

  const socialWriteLimit = rateLimit({ windowMs: 60_000, max: 20, name: "social" });
  // Stricter: the lookup endpoint can probe whether an email has an account.
  const lookupLimit = rateLimit({ windowMs: 60_000, max: 15, name: "social_lookup" });

  // ── Profile ─────────────────────────────────────────────────────────────

  router.get("/social/me", async (req, res) => {
    const me = req.auth!.userId;

    // The users row may not exist yet if /users/sync hasn't run.
    await db.insert(users).values({ clerkId: me }).onConflictDoNothing();

    let [profile] = await db
      .select({ friendCode: users.friendCode })
      .from(users)
      .where(eq(users.clerkId, me))
      .limit(1);

    // Lazy friend-code backfill: generate on first visit, retrying on the
    // (astronomically unlikely) unique collision and widening after 5 tries.
    let friendCode = profile?.friendCode ?? null;
    if (!friendCode) {
      for (let attempt = 0; attempt < 8 && !friendCode; attempt++) {
        const candidate = randomCode(attempt < 5 ? 4 : 5);
        try {
          await db
            .update(users)
            .set({ friendCode: candidate })
            .where(eq(users.clerkId, me));
          friendCode = candidate;
        } catch (err: any) {
          if (err?.code !== "23505") throw err; // not a unique violation
        }
      }
      if (!friendCode) {
        res.status(500).json({ error: "Arkadaş kodu oluşturulamadı" });
        return;
      }
    }

    const [[incoming], [pendingShares]] = await Promise.all([
      db
        .select({ count: sql<number>`count(*)::int` })
        .from(connections)
        .where(and(eq(connections.addresseeId, me), eq(connections.status, "pending"))),
      db
        .select({ count: sql<number>`count(*)::int` })
        .from(recipeShares)
        .where(and(eq(recipeShares.recipientId, me), eq(recipeShares.status, "pending"))),
    ]);

    res.json({
      friend_code: friendCode,
      incoming_request_count: incoming?.count ?? 0,
      pending_share_count: pendingShares?.count ?? 0,
    });
  });

  // ── Lookup ──────────────────────────────────────────────────────────────

  router.get("/social/lookup", lookupLimit, async (req, res) => {
    const me = req.auth!.userId;
    const code = typeof req.query.code === "string" ? req.query.code.trim().toUpperCase() : null;
    const email = typeof req.query.email === "string" ? req.query.email.trim().toLowerCase() : null;

    if (!code && !email) {
      res.status(400).json({ error: "code veya email gerekli" });
      return;
    }

    const condition = code
      ? eq(users.friendCode, code)
      : sql`lower(${users.email}) = ${email}`;

    const [found] = await db
      .select(PUBLIC_USER_FIELDS)
      .from(users)
      .where(condition)
      .limit(1);

    if (!found) {
      res.status(404).json({ error: "Kullanıcı bulunamadı" });
      return;
    }

    let relationship = "none";
    if (found.clerkId === me) {
      relationship = "self";
    } else {
      const conn = await findConnection(me, found.clerkId);
      if (conn?.status === "accepted") relationship = "friends";
      else if (conn?.status === "pending") {
        relationship = conn.requesterId === me ? "pending_outgoing" : "pending_incoming";
      }
    }

    res.json({ user: toSnake(found), relationship });
  });

  // ── Follow requests ─────────────────────────────────────────────────────

  router.post("/social/requests", socialWriteLimit, async (req, res) => {
    const me = req.auth!.userId;
    const toUserId = req.body?.to_user_id;

    if (!toUserId || typeof toUserId !== "string") {
      res.status(400).json({ error: "to_user_id gerekli" });
      return;
    }
    if (toUserId === me) {
      res.status(400).json({ error: "Kendini ekleyemezsin" });
      return;
    }

    const [target] = await db
      .select({ clerkId: users.clerkId })
      .from(users)
      .where(eq(users.clerkId, toUserId))
      .limit(1);
    if (!target) {
      res.status(404).json({ error: "Kullanıcı bulunamadı" });
      return;
    }

    const existing = await findConnection(me, toUserId);
    if (existing) {
      if (existing.status === "accepted") {
        res.status(409).json({ error: "Zaten arkadaşsınız", code: "already_friends" });
        return;
      }
      if (existing.requesterId === me) {
        res.status(409).json({ error: "İstek zaten gönderildi", code: "request_pending" });
        return;
      }
      // They already requested us — both tapped "add", so auto-accept.
      const [accepted] = await db
        .update(connections)
        .set({ status: "accepted", respondedAt: new Date() })
        .where(eq(connections.id, existing.id))
        .returning();
      res.json(toSnake(accepted));
      return;
    }

    const [created] = await db
      .insert(connections)
      .values({ requesterId: me, addresseeId: toUserId })
      .returning();
    res.status(201).json(toSnake(created));
  });

  router.get("/social/requests", async (req, res) => {
    const me = req.auth!.userId;

    const [incoming, outgoing] = await Promise.all([
      db
        .select({
          id: connections.id,
          createdAt: connections.createdAt,
          user: PUBLIC_USER_FIELDS,
        })
        .from(connections)
        .innerJoin(users, eq(users.clerkId, connections.requesterId))
        .where(and(eq(connections.addresseeId, me), eq(connections.status, "pending")))
        .orderBy(desc(connections.createdAt)),
      db
        .select({
          id: connections.id,
          createdAt: connections.createdAt,
          user: PUBLIC_USER_FIELDS,
        })
        .from(connections)
        .innerJoin(users, eq(users.clerkId, connections.addresseeId))
        .where(and(eq(connections.requesterId, me), eq(connections.status, "pending")))
        .orderBy(desc(connections.createdAt)),
    ]);

    res.json({ incoming: toSnake(incoming), outgoing: toSnake(outgoing) });
  });

  router.post("/social/requests/:id/accept", socialWriteLimit, async (req, res) => {
    const me = req.auth!.userId;
    const [updated] = await db
      .update(connections)
      .set({ status: "accepted", respondedAt: new Date() })
      .where(
        and(
          eq(connections.id, String(req.params.id)),
          eq(connections.addresseeId, me),
          eq(connections.status, "pending")
        )
      )
      .returning();

    if (!updated) {
      res.status(404).json({ error: "İstek bulunamadı" });
      return;
    }
    res.json(toSnake(updated));
  });

  // Decline (as addressee) or cancel (as requester). Deleting the row keeps
  // re-requesting possible without extra statuses.
  router.delete("/social/requests/:id", socialWriteLimit, async (req, res) => {
    const me = req.auth!.userId;
    const deleted = await db
      .delete(connections)
      .where(
        and(
          eq(connections.id, String(req.params.id)),
          eq(connections.status, "pending"),
          or(eq(connections.addresseeId, me), eq(connections.requesterId, me))
        )
      )
      .returning();

    if (deleted.length === 0) {
      res.status(404).json({ error: "İstek bulunamadı" });
      return;
    }
    res.status(204).send();
  });

  // ── Friends ─────────────────────────────────────────────────────────────

  router.get("/social/friends", async (req, res) => {
    const me = req.auth!.userId;

    // Two directional queries so we can join the counterpart's profile.
    const [asRequester, asAddressee] = await Promise.all([
      db
        .select({ connectedAt: connections.respondedAt, user: PUBLIC_USER_FIELDS })
        .from(connections)
        .innerJoin(users, eq(users.clerkId, connections.addresseeId))
        .where(and(eq(connections.requesterId, me), eq(connections.status, "accepted"))),
      db
        .select({ connectedAt: connections.respondedAt, user: PUBLIC_USER_FIELDS })
        .from(connections)
        .innerJoin(users, eq(users.clerkId, connections.requesterId))
        .where(and(eq(connections.addresseeId, me), eq(connections.status, "accepted"))),
    ]);

    const friends = [...asRequester, ...asAddressee].sort((a, b) => {
      const ta = a.connectedAt ? new Date(a.connectedAt).getTime() : 0;
      const tb = b.connectedAt ? new Date(b.connectedAt).getTime() : 0;
      return tb - ta;
    });

    res.json(toSnake(friends));
  });

  router.delete("/social/friends/:userId", socialWriteLimit, async (req, res) => {
    const me = req.auth!.userId;
    const them = String(req.params.userId);

    const deleted = await db
      .delete(connections)
      .where(
        and(
          eq(connections.status, "accepted"),
          or(
            and(eq(connections.requesterId, me), eq(connections.addresseeId, them)),
            and(eq(connections.requesterId, them), eq(connections.addresseeId, me))
          )
        )
      )
      .returning();

    if (deleted.length === 0) {
      res.status(404).json({ error: "Arkadaş bulunamadı" });
      return;
    }

    // Pending shares between the pair no longer make sense once unfriended.
    await db
      .delete(recipeShares)
      .where(
        and(
          eq(recipeShares.status, "pending"),
          or(
            and(eq(recipeShares.senderId, me), eq(recipeShares.recipientId, them)),
            and(eq(recipeShares.senderId, them), eq(recipeShares.recipientId, me))
          )
        )
      );

    res.status(204).send();
  });

  // The one deliberate cross-user read: a friend's saved recipes. Folder and
  // favorite flags stay private — only the recipes themselves are shared.
  router.get("/social/friends/:userId/recipes", async (req, res) => {
    const me = req.auth!.userId;
    const them = String(req.params.userId);

    if (!(await areFriends(me, them))) {
      res.status(403).json({ error: "Bu kullanıcıyla bağlantınız yok" });
      return;
    }

    const result = await db
      .select({ recipe: recipes })
      .from(userRecipes)
      .innerJoin(recipes, eq(recipes.id, userRecipes.recipeId))
      .where(eq(userRecipes.userId, them))
      .orderBy(desc(recipes.createdAt));

    res.json(await enrichRecipes(result.map((r) => r.recipe)));
  });

  // ── Recipe shares ───────────────────────────────────────────────────────

  router.post("/social/shares", socialWriteLimit, async (req, res) => {
    const me = req.auth!.userId;
    const toUserId = req.body?.to_user_id;
    const recipeId = req.body?.recipe_id;
    const rawMessage = typeof req.body?.message === "string" ? req.body.message.trim() : "";
    const message = rawMessage ? rawMessage.slice(0, 500) : null;

    if (!toUserId || !recipeId) {
      res.status(400).json({ error: "to_user_id ve recipe_id gerekli" });
      return;
    }
    if (!(await areFriends(me, toUserId))) {
      res.status(403).json({ error: "Bu kullanıcıyla bağlantınız yok" });
      return;
    }

    const [recipe] = await db
      .select({ id: recipes.id })
      .from(recipes)
      .where(eq(recipes.id, recipeId))
      .limit(1);
    if (!recipe) {
      res.status(404).json({ error: "Tarif bulunamadı" });
      return;
    }

    const [recipientMapping] = await db
      .select({ id: userRecipes.id })
      .from(userRecipes)
      .where(and(eq(userRecipes.userId, toUserId), eq(userRecipes.recipeId, recipeId)))
      .limit(1);
    const recipientHasRecipe = Boolean(recipientMapping);

    // Idempotent on an identical pending share — re-tapping "Gönder" is a no-op.
    const [existing] = await db
      .select()
      .from(recipeShares)
      .where(
        and(
          eq(recipeShares.senderId, me),
          eq(recipeShares.recipientId, toUserId),
          eq(recipeShares.recipeId, recipeId),
          eq(recipeShares.status, "pending")
        )
      )
      .limit(1);
    if (existing) {
      res.json({ ...toSnake(existing), recipient_has_recipe: recipientHasRecipe });
      return;
    }

    const [created] = await db
      .insert(recipeShares)
      .values({ senderId: me, recipientId: toUserId, recipeId, message })
      .returning();

    res.status(201).json({ ...toSnake(created), recipient_has_recipe: recipientHasRecipe });
  });

  router.get("/social/shares/inbox", async (req, res) => {
    const me = req.auth!.userId;
    const status = typeof req.query.status === "string" ? req.query.status : "pending";
    if (!["pending", "accepted", "dismissed"].includes(status)) {
      res.status(400).json({ error: "Geçersiz status" });
      return;
    }

    const rows = await db
      .select({
        id: recipeShares.id,
        message: recipeShares.message,
        status: recipeShares.status,
        createdAt: recipeShares.createdAt,
        sender: PUBLIC_USER_FIELDS,
        recipe: {
          id: recipes.id,
          title: recipes.title,
          thumbnailUrl: recipes.thumbnailUrl,
          cookingTimeMinutes: recipes.cookingTimeMinutes,
          platform: recipes.platform,
        },
      })
      .from(recipeShares)
      .innerJoin(users, eq(users.clerkId, recipeShares.senderId))
      .innerJoin(recipes, eq(recipes.id, recipeShares.recipeId))
      .where(
        and(
          eq(recipeShares.recipientId, me),
          eq(recipeShares.status, status as "pending" | "accepted" | "dismissed")
        )
      )
      .orderBy(desc(recipeShares.createdAt));

    res.json(
      toSnake(rows).map((row: any) => ({
        ...row,
        recipe: rewriteThumbnail(row.recipe),
      }))
    );
  });

  router.post("/social/shares/:id/accept", socialWriteLimit, async (req, res) => {
    const me = req.auth!.userId;

    const [share] = await db
      .select()
      .from(recipeShares)
      .where(
        and(
          eq(recipeShares.id, String(req.params.id)),
          eq(recipeShares.recipientId, me),
          eq(recipeShares.status, "pending")
        )
      )
      .limit(1);
    if (!share) {
      res.status(404).json({ error: "Paylaşım bulunamadı" });
      return;
    }

    // user_recipes has no unique constraint on (userId, recipeId) — check first.
    const [existingMapping] = await db
      .select({ id: userRecipes.id })
      .from(userRecipes)
      .where(and(eq(userRecipes.userId, me), eq(userRecipes.recipeId, share.recipeId)))
      .limit(1);
    const alreadySaved = Boolean(existingMapping);

    if (!alreadySaved) {
      await db.insert(userRecipes).values({ userId: me, recipeId: share.recipeId });
    }

    await db
      .update(recipeShares)
      .set({ status: "accepted", respondedAt: new Date() })
      .where(eq(recipeShares.id, share.id));

    res.json({ ok: true, already_saved: alreadySaved });
  });

  router.post("/social/shares/:id/dismiss", socialWriteLimit, async (req, res) => {
    const me = req.auth!.userId;

    const [updated] = await db
      .update(recipeShares)
      .set({ status: "dismissed", respondedAt: new Date() })
      .where(
        and(
          eq(recipeShares.id, String(req.params.id)),
          eq(recipeShares.recipientId, me),
          eq(recipeShares.status, "pending")
        )
      )
      .returning();

    if (!updated) {
      res.status(404).json({ error: "Paylaşım bulunamadı" });
      return;
    }
    res.json({ ok: true });
  });

  return router;
}
