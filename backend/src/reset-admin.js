import { pool, transaction } from "./db.js";
import { hashPassword, requireValue } from "./auth.js";
const email = process.env.ADMIN_EMAIL?.trim().toLowerCase(),
  password = process.env.ADMIN_PASSWORD;
requireValue(
  email && password,
  "ADMIN_EMAIL dan ADMIN_PASSWORD wajib tersedia pada lingkungan operator.",
);
const hash = await hashPassword(password);
await transaction(async (db) => {
  await db.query("SELECT pg_advisory_xact_lock(48127632)");
  const changed = await db.query(
    "UPDATE app_users SET password_hash=$2,active=true,updated_at=now(),revision=revision+1 WHERE lower(email)=$1 AND role='admin' RETURNING id",
    [email, hash],
  );
  requireValue(changed.rowCount === 1, "Akun admin tidak ditemukan.");
  await db.query("DELETE FROM sessions WHERE user_id=$1", [changed.rows[0].id]);
});
await pool.end();
console.log("Sandi admin diperbarui dan sesi lama dicabut.");
