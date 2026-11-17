import { admin, requireValue, verifyPassword } from "./auth.js";
import { transaction } from "./db.js";
import { writeLock } from "./records.js";
import { replaceCatalog } from "./catalog.js";

export function registerMaintenance(app) {
  // Disabled unless an operator explicitly configures a temporary reset token.
  app.post("/v1/maintenance/reset-catalog", async (req, res) => {
    requireValue(
      process.env.MAINTENANCE_RESET_TOKEN &&
        req.headers["x-maintenance-token"] ===
          process.env.MAINTENANCE_RESET_TOKEN,
      "Endpoint tidak tersedia.",
      "not-found",
      404,
    );
    admin(req.user);
    requireValue(
      req.body?.confirmation === "REPLACE_HARYATA_DATA",
      "Konfirmasi tidak sesuai.",
    );
    const result = await transaction(async (db) => {
      const user = await writeLock(db, req.user);
      admin(user);
      requireValue(
        await verifyPassword(req.body.currentPassword, user.password_hash),
        "Kata sandi tidak sesuai.",
        "invalid-credential",
        401,
      );
      return replaceCatalog(db, user, req.body.currentPassword);
    });
    res.json(result);
  });
}
