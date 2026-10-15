import { drizzle } from "drizzle-orm/node-postgres";
import pg from "pg";
import * as schema from "./schema.js";

// SSL is on for hosted databases (Neon). A local/CI database opts out by
// appending ?sslmode=disable to DATABASE_URL.
const url = process.env.DATABASE_URL;
const useSsl = Boolean(url) && !url!.includes("sslmode=disable");

const pool = new pg.Pool({
  connectionString: url || "postgresql://localhost/feslihan",
  ssl: useSsl ? { rejectUnauthorized: false } : false,
});

export const db = drizzle(pool, { schema });
