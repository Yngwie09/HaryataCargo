import { pool, migrate } from "./db.js";
await migrate();
console.log("PostgreSQL schema siap.");
await pool.end();
