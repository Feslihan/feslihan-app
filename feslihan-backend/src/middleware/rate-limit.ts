import type { RequestHandler } from "express";

/**
 * Small in-memory fixed-window rate limiter, keyed by authenticated user id.
 *
 * This is burst protection for the expensive AI routes — it stops a single
 * client from firing dozens of Claude calls per second. The durable per-plan
 * cap lives in quota.ts (DB-backed); this just smooths the rate.
 *
 * NOTE: state is per-process. On a single long-running server that's exactly
 * right. On multi-instance / serverless deployments each instance keeps its own
 * window, so the effective limit is (limit × instances) — still a meaningful
 * ceiling, with the DB quota as the hard backstop.
 */
export interface RateLimitOptions {
  windowMs: number;
  max: number;
  name?: string;
}

interface Counter {
  count: number;
  resetAt: number;
}

export function rateLimit(options: RateLimitOptions): RequestHandler {
  const { windowMs, max, name = "rate" } = options;
  const hits = new Map<string, Counter>();

  // Periodically drop expired entries so the map can't grow unbounded.
  const sweep = setInterval(() => {
    const now = Date.now();
    for (const [key, counter] of hits) {
      if (counter.resetAt <= now) hits.delete(key);
    }
  }, windowMs);
  // Don't keep the event loop alive just for the sweeper.
  if (typeof sweep.unref === "function") sweep.unref();

  return (req, res, next) => {
    // Keyed by verified identity; falls back to IP for any unauthenticated
    // route this is ever mounted on.
    const key = req.auth?.userId ?? req.ip ?? "anonymous";
    const now = Date.now();
    const counter = hits.get(key);

    if (!counter || counter.resetAt <= now) {
      hits.set(key, { count: 1, resetAt: now + windowMs });
      next();
      return;
    }

    if (counter.count >= max) {
      const retryAfter = Math.ceil((counter.resetAt - now) / 1000);
      res.setHeader("Retry-After", String(retryAfter));
      res.status(429).json({
        error: "Too many requests. Please slow down.",
        code: `${name}_rate_limited`,
        retryAfter,
      });
      return;
    }

    counter.count += 1;
    next();
  };
}
