import type { Request, RequestHandler } from "express";
import { verifyToken } from "@clerk/backend";

// Make the verified identity available on the request object.
declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      auth?: { userId: string };
    }
  }
}

const SECRET_KEY = process.env.CLERK_SECRET_KEY;

// Comma-separated list of Clerk user ids allowed to hit admin/destructive routes.
const ADMIN_IDS = new Set(
  (process.env.ADMIN_CLERK_IDS || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean)
);

function bearerToken(req: Request): string | null {
  const header = req.headers.authorization;
  if (!header) return null;
  const [scheme, token] = header.split(" ");
  if (scheme?.toLowerCase() !== "bearer" || !token) return null;
  return token.trim();
}

/**
 * Verifies the Clerk session JWT on the Authorization header and attaches
 * `req.auth = { userId }`. Fails closed: any missing/invalid token → 401,
 * and a missing CLERK_SECRET_KEY → 500 (never silently open the API).
 */
export const requireAuth: RequestHandler = async (req, res, next) => {
  if (!SECRET_KEY) {
    console.error("[auth] CLERK_SECRET_KEY is not set — refusing all requests");
    res.status(500).json({ error: "server auth misconfigured" });
    return;
  }

  const token = bearerToken(req);
  if (!token) {
    res.status(401).json({ error: "unauthorized" });
    return;
  }

  try {
    const payload = await verifyToken(token, { secretKey: SECRET_KEY });
    if (!payload.sub) {
      res.status(401).json({ error: "unauthorized" });
      return;
    }
    req.auth = { userId: payload.sub };
    next();
  } catch (err: any) {
    console.warn("[auth] token verification failed:", err?.message || err);
    res.status(401).json({ error: "unauthorized" });
  }
};

/**
 * Restricts a route to admins. Must run after requireAuth (which is mounted
 * globally). Any authenticated user not in ADMIN_CLERK_IDS → 403.
 */
export const requireAdmin: RequestHandler = (req, res, next) => {
  const userId = req.auth?.userId;
  if (!userId || !ADMIN_IDS.has(userId)) {
    res.status(403).json({ error: "forbidden" });
    return;
  }
  next();
};
