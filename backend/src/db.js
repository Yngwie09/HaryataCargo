import pg from "pg";
import { readFile, readdir } from "node:fs/promises";
export const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
  max: 5,
  connectionTimeoutMillis: 15000,
  idleTimeoutMillis: 30000,
  ...(process.env.PGSSL === "true"
    ? { ssl: { rejectUnauthorized: true } }
    : {}),
});
pool.on("error", (e) =>
  console.error("PostgreSQL pool error:", e.code || "connection-error"),
);
export async function transaction(work) {
  const db = await pool.connect();
  try {
    await db.query("BEGIN");
    const value = await work(db);
    await db.query("COMMIT");
    return value;
  } catch (e) {
    await db.query("ROLLBACK");
    throw e;
  } finally {
    db.release();
  }
}
export async function migrate() {
  await transaction(async (db) => {
    await db.query("SELECT pg_advisory_xact_lock(48127631)");
    const directory = new URL("../migrations/", import.meta.url);
    const migrations = (await readdir(directory))
      .filter((name) => /^\d+_.+\.sql$/.test(name))
      .sort();
    for (const name of migrations) {
      await db.query(await readFile(new URL(name, directory), "utf8"));
    }
  });
}
