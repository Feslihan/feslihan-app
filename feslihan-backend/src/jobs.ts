// Durable background-job queue backed by Postgres.
//
// Bulk / fire-and-forget work must not run inside request handlers: it blocks
// responses, does writes in GET handlers, and (on serverless) is simply lost
// when the function returns. Instead handlers enqueue a row in `background_jobs`
// and return immediately; a worker claims pending rows and runs the registered
// handler, retrying on failure. Because the queue lives in the database the work
// survives process restarts and cold-starts.
import { eq, sql } from "drizzle-orm";
import { db } from "./db.js";
import { backgroundJobs, type BackgroundJob } from "./schema.js";

export type JobHandler = (payload: any, job: BackgroundJob) => Promise<void>;

const handlers = new Map<string, JobHandler>();

export function registerJobHandler(type: string, handler: JobHandler): void {
  handlers.set(type, handler);
}

export type EnqueueOptions = { maxAttempts?: number; delayMs?: number };

// Durably enqueue a job. Returns the new job id. Safe to call from any handler;
// it does a single INSERT and never runs the work inline.
export async function enqueueJob(
  type: string,
  payload: unknown = {},
  opts: EnqueueOptions = {}
): Promise<string> {
  const runAt = opts.delayMs
    ? new Date(Date.now() + opts.delayMs)
    : new Date();
  const [row] = await db
    .insert(backgroundJobs)
    .values({
      type,
      payload: payload as any,
      runAt,
      ...(opts.maxAttempts != null ? { maxAttempts: opts.maxAttempts } : {}),
    })
    .returning({ id: backgroundJobs.id });
  console.log(`[Jobs] Enqueued ${type} (${row.id})`);
  return row.id;
}

// Atomically claim the oldest due pending job. FOR UPDATE SKIP LOCKED lets
// multiple workers / instances pull from the same queue without double-running.
async function claimNextJob(): Promise<BackgroundJob | null> {
  const result = await db.execute(sql`
    UPDATE background_jobs
    SET status = 'running', attempts = attempts + 1, updated_at = now()
    WHERE id = (
      SELECT id FROM background_jobs
      WHERE status = 'pending' AND run_at <= now()
      ORDER BY run_at
      FOR UPDATE SKIP LOCKED
      LIMIT 1
    )
    RETURNING *;
  `);
  const rows = (result as any).rows as any[];
  if (!rows || rows.length === 0) return null;
  const r = rows[0];
  // node-postgres returns snake_case columns; map to the camelCase job shape.
  return {
    id: r.id,
    type: r.type,
    payload: r.payload,
    status: r.status,
    attempts: r.attempts,
    maxAttempts: r.max_attempts,
    lastError: r.last_error,
    runAt: r.run_at,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

async function runJob(job: BackgroundJob): Promise<void> {
  const handler = handlers.get(job.type);
  if (!handler) {
    await db
      .update(backgroundJobs)
      .set({ status: "failed", lastError: `No handler for type "${job.type}"`, updatedAt: new Date() })
      .where(eq(backgroundJobs.id, job.id));
    console.error(`[Jobs] No handler for ${job.type} (${job.id})`);
    return;
  }

  try {
    await handler(job.payload, job);
    await db
      .update(backgroundJobs)
      .set({ status: "done", lastError: null, updatedAt: new Date() })
      .where(eq(backgroundJobs.id, job.id));
    console.log(`[Jobs] Completed ${job.type} (${job.id})`);
  } catch (err: any) {
    const message = err?.message || String(err);
    const exhausted = job.attempts >= job.maxAttempts;
    // Exhausted → leave failed; otherwise re-arm as pending with backoff so the
    // worker retries on a later tick.
    await db
      .update(backgroundJobs)
      .set({
        status: exhausted ? "failed" : "pending",
        lastError: message,
        runAt: exhausted ? job.runAt : new Date(Date.now() + 30_000 * job.attempts),
        updatedAt: new Date(),
      })
      .where(eq(backgroundJobs.id, job.id));
    console.error(
      `[Jobs] ${exhausted ? "Failed" : "Retrying"} ${job.type} (${job.id}) attempt ${job.attempts}/${job.maxAttempts}: ${message}`
    );
  }
}

// Drain all currently-due jobs (one at a time to avoid thundering the DB /
// external APIs). Returns the number of jobs processed.
export async function processDueJobs(): Promise<number> {
  let processed = 0;
  for (;;) {
    const job = await claimNextJob();
    if (!job) break;
    await runJob(job);
    processed++;
  }
  return processed;
}

let workerTimer: ReturnType<typeof setInterval> | null = null;
let draining = false;

// Start a polling worker. On a long-running server this processes the queue
// continuously; on serverless, `processDueJobs` can instead be invoked from a
// scheduled trigger — either way the durable rows guarantee the work runs.
export function startJobWorker(intervalMs = 5_000): void {
  if (workerTimer) return;
  workerTimer = setInterval(async () => {
    if (draining) return; // never overlap ticks
    draining = true;
    try {
      await processDueJobs();
    } catch (err: any) {
      console.error("[Jobs] Worker tick failed:", err?.message || err);
    } finally {
      draining = false;
    }
  }, intervalMs);
  // Don't keep the event loop alive solely for the poller.
  if (typeof workerTimer.unref === "function") workerTimer.unref();
  console.log(`[Jobs] Worker started (every ${intervalMs}ms)`);
}
