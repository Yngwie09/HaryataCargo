import express from "express";
import cors from "cors";
import helmet from "helmet";
import { rateLimit } from "express-rate-limit";
import { randomUUID } from "node:crypto";
import { pool, transaction, migrate } from "./db.js";
import {
  ApiError,
  requireValue,
  validPassword,
  validEmail,
  hashPassword,
  verifyPassword,
  publicUser,
  authenticate,
  bootstrapAdmin,
  createSession,
  admin,
} from "./auth.js";
import {
  readRecord,
  queryRecords,
  commitRecords,
  writeLock,
  stamp,
  idOk,
  text,
  audit,
} from "./records.js";
import validation from "./validation.cjs";
import { preparePhoto } from "./photos.js";
import { registerMaintenance } from "./maintenance.js";
import { registerTracking } from "./tracking.js";
export const app = express();
app.disable("x-powered-by");
app.set("trust proxy", 1);
app.use(helmet());
const origins = (process.env.CORS_ORIGINS || "")
  .split(",")
  .map((x) => x.trim())
  .filter(Boolean);
app.use(
  cors({
    origin(origin, cb) {
      cb(
        null,
        !origin ||
          origins.includes(origin) ||
          /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin),
      );
    },
  }),
);
app.use(express.json({ limit: "8mb" }));
app.use(
  "/v1",
  rateLimit({
    windowMs: 60000,
    limit: 1000,
    standardHeaders: "draft-8",
    legacyHeaders: false,
  }),
);
app.get("/health", async (req, res) => {
  const result = await pool.query(
    "SELECT max(version)::integer AS version FROM schema_migrations",
  );
  res.json({
    status: "ok",
    database: "postgresql",
    schema: result.rows[0].version,
    storage: "postgresql-bytea",
    version: "1.3.0",
  });
});
app.post(
  "/v1/auth/login",
  rateLimit({
    windowMs: 60000,
    limit: 20,
    standardHeaders: "draft-8",
    legacyHeaders: false,
  }),
  async (req, res) => {
    const { email, password } = req.body || {};
    requireValue(
      validEmail(email) && validPassword(password),
      "Email atau kata sandi tidak sesuai.",
      "invalid-credential",
      401,
    );
    const user = (
      await pool.query("SELECT * FROM app_users WHERE lower(email)=$1", [
        email.trim().toLowerCase(),
      ])
    ).rows[0];
    if (
      !user ||
      !user.active ||
      !(await verifyPassword(password, user.password_hash))
    )
      throw new ApiError(
        401,
        "invalid-credential",
        "Email atau kata sandi tidak sesuai.",
      );
    res.json(await createSession(user));
  },
);
app.use("/v1", authenticate);
registerMaintenance(app);
registerTracking(app, pool);
app.get("/v1/auth/me", (req, res) => res.json({ user: publicUser(req.user) }));
app.get("/v1/dashboard", async (req, res) => {
  const filter = req.user.role === "admin" ? "" : " WHERE courier_id=$1";
  const rows = (
    await pool.query(
      "SELECT status,count(*)::integer AS count FROM shipments" +
        filter +
        " GROUP BY status",
      req.user.role === "admin" ? [] : [req.user.id],
    )
  ).rows;
  const counts = Object.fromEntries(
    ["Pending", "Proses", "Tertunda", "Selesai", "Retur", "Batal"].map(
      (status) => [status, 0],
    ),
  );
  for (const row of rows) counts[row.status] = row.count;
  res.json({ counts, updatedAt: stamp() });
});
app.post("/v1/auth/logout", async (req, res) => {
  await transaction(async (db) => {
    const user = await writeLock(db, req.user);
    if (user.role === "kurir")
      requireValue(
        (
          await db.query(
            "SELECT id FROM shipments WHERE courier_id=$1 AND status='Proses' LIMIT 1",
            [user.id],
          )
        ).rowCount === 0,
        "Masih ada pengantaran aktif. Selesaikan atau tunda tugas sebelum keluar.",
        "failed-precondition",
        409,
      );
    await db.query("DELETE FROM sessions WHERE token_hash=$1", [
      req.sessionHash,
    ]);
  });
  res.json({ ok: true });
});
app.post("/v1/auth/change-password", async (req, res) => {
  const { currentPassword, password } = req.body || {};
  requireValue(validPassword(password), "Isi kata sandi baru.");
  const hash = await hashPassword(password);
  await transaction(async (db) => {
    const user = await writeLock(db, req.user);
    requireValue(
      await verifyPassword(currentPassword, user.password_hash),
      "Kata sandi saat ini tidak sesuai.",
      "invalid-credential",
      401,
    );
    await db.query(
      "UPDATE app_users SET password_hash=$2,updated_at=now(),revision=revision+1 WHERE id=$1",
      [user.id, hash],
    );
    await db.query("DELETE FROM sessions WHERE user_id=$1 AND token_hash<>$2", [
      user.id,
      req.sessionHash,
    ]);
  });
  res.json({ ok: true });
});
app.post("/v1/query", async (req, res) =>
  res.json({ docs: await queryRecords(pool, req.user, req.body || {}) }),
);
app.post("/v1/record", async (req, res) =>
  res.json({ doc: await readRecord(pool, req.user, req.body?.path) }),
);
app.post("/v1/transactions", async (req, res) =>
  res.json(
    await transaction((db) => commitRecords(db, req.user, req.body || {})),
  ),
);
app.post("/v1/actions/createCourier", async (req, res) => {
  admin(req.user);
  let input;
  try {
    input = validation.validateCourier(req.body);
  } catch (e) {
    throw new ApiError(400, "invalid-argument", e.message);
  }
  const hash = await hashPassword(input.password),
    uid = randomUUID();
  await transaction(async (db) => {
    admin(await writeLock(db, req.user));
    await db.query(
      "INSERT INTO app_users(id,email,name,phone,role,password_hash) VALUES($1,$2,$3,$4,'kurir',$5)",
      [uid, input.email.toLowerCase(), input.name, input.phone, hash],
    );
  });
  res.status(201).json({ uid });
});
app.post("/v1/actions/setCourierActive", async (req, res) => {
  admin(req.user);
  const { uid, active } = req.body || {};
  requireValue(
    idOk(uid) && typeof active === "boolean",
    "Data akun tidak valid.",
  );
  await transaction(async (db) => {
    admin(await writeLock(db, req.user));
    const user = (
      await db.query(
        "SELECT * FROM app_users WHERE id=$1 AND role='kurir' FOR UPDATE",
        [uid],
      )
    ).rows[0];
    requireValue(user, "Kurir tidak ditemukan.", "not-found", 404);
    if (!active)
      requireValue(
        (
          await db.query(
            "SELECT id FROM shipments WHERE courier_id=$1 AND status IN ('Pending','Proses') LIMIT 1",
            [uid],
          )
        ).rowCount === 0,
        "Selesaikan atau alihkan paket Pending/Proses sebelum menonaktifkan kurir.",
        "failed-precondition",
        409,
      );
    await db.query(
      "UPDATE app_users SET active=$2,updated_at=now(),revision=revision+1 WHERE id=$1",
      [uid, active],
    );
    if (!active) await db.query("DELETE FROM sessions WHERE user_id=$1", [uid]);
  });
  res.json({ active });
});
app.post("/v1/actions/resetCourierPassword", async (req, res) => {
  admin(req.user);
  const { uid, password } = req.body || {};
  requireValue(idOk(uid), "ID kurir tidak valid.");
  const hash = await hashPassword(password);
  await transaction(async (db) => {
    admin(await writeLock(db, req.user));
    const changed = await db.query(
      "UPDATE app_users SET password_hash=$2,updated_at=now(),revision=revision+1 WHERE id=$1 AND role='kurir' RETURNING id",
      [uid, hash],
    );
    requireValue(
      changed.rowCount === 1,
      "Kurir tidak ditemukan.",
      "not-found",
      404,
    );
    await db.query("DELETE FROM sessions WHERE user_id=$1", [uid]);
  });
  res.json({ ok: true });
});
// Owner/admin maintenance: reauthenticate before an atomic login-account change.
app.post("/v1/actions/updateLoginAccounts", async (req, res) => {
  admin(req.user);
  const { currentPassword, updates } = req.body || {};
  requireValue(
    Array.isArray(updates) && updates.length > 0 && updates.length <= 20,
    "Daftar perubahan akun tidak valid.",
  );
  requireValue(
    new Set(updates.map((u) => u?.uid)).size === updates.length,
    "Akun tidak boleh diulang.",
  );
  const prepared = [];
  for (const u of updates) {
    requireValue(
      u && idOk(u.uid) && validEmail(u.email) && validPassword(u.password),
      "Email atau kata sandi akun tidak valid.",
    );
    prepared.push({
      uid: u.uid,
      email: u.email.trim().toLowerCase(),
      hash: await hashPassword(u.password),
    });
  }
  const changed = await transaction(async (db) => {
    const owner = await writeLock(db, req.user);
    admin(owner);
    requireValue(
      await verifyPassword(currentPassword, owner.password_hash),
      "Kata sandi admin saat ini tidak sesuai.",
      "invalid-credential",
      401,
    );
    const result = [];
    for (const u of prepared) {
      const before = (
        await db.query("SELECT * FROM app_users WHERE id=$1 FOR UPDATE", [
          u.uid,
        ])
      ).rows[0];
      requireValue(before, "Akun tidak ditemukan.", "not-found", 404);
      requireValue(
        before.role === "kurir" || before.id === owner.id,
        "Admin hanya dapat mengubah akun adminnya sendiri.",
        "permission-denied",
        403,
      );
      await db.query(
        "UPDATE app_users SET email=$2,password_hash=$3,updated_at=now(),revision=revision+1 WHERE id=$1",
        [u.uid, u.email, u.hash],
      );
      if (before.role === "kurir") {
        await db.query(
          "UPDATE shipments SET data=jsonb_set(data,'{courierEmail}',to_jsonb($2::text)),updated_at=now(),revision=revision+1 WHERE courier_id=$1",
          [u.uid, u.email],
        );
        await db.query(
          "UPDATE courier_locations SET data=jsonb_set(data,'{email}',to_jsonb($2::text)),revision=revision+1 WHERE courier_id=$1",
          [u.uid, u.email],
        );
      }
      await db.query("DELETE FROM sessions WHERE user_id=$1", [u.uid]);
      result.push({
        uid: u.uid,
        email: u.email,
        role: before.role,
        active: before.active,
      });
    }
    return result;
  });
  res.json({ updated: changed });
});
app.post("/v1/actions/finalizeDelivery", async (req, res) => {
  requireValue(
    req.user.role === "kurir",
    "Hanya kurir yang dapat menyelesaikan pengiriman.",
    "permission-denied",
    403,
  );
  let input;
  try {
    input = validation.validateProof(req.body, req.user.id);
  } catch (e) {
    throw new ApiError(400, "invalid-argument", e.message);
  }
  await transaction(async (db) => {
    const user = await writeLock(db, req.user),
      record = await readRecord(
        db,
        user,
        `shipments/${input.shipmentId}`,
        true,
      ),
      before = record?.data;
    requireValue(
      before && before.courierId === user.id,
      "Pengiriman bukan tugas Anda.",
      "permission-denied",
      403,
    );
    if (before.status === "Selesai") {
      requireValue(
        ["receipt", "recipient", "parcel"].every(
          (k) => before.proof?.photos?.[k] === input.proof.photos[k],
        ),
        "Pengiriman sudah selesai; bukti tidak dapat diganti.",
        "failed-precondition",
        409,
      );
      return;
    }
    requireValue(
      before.status === "Proses",
      "Pengiriman tidak sedang dalam pengantaran.",
      "failed-precondition",
      409,
    );
    const photos = (
      await db.query(
        "SELECT path,courier_id,shipment_id FROM proof_photos WHERE path=ANY($1::text[])",
        [Object.values(input.proof.photos)],
      )
    ).rows;
    requireValue(
      photos.length === 3 &&
        photos.every(
          (p) => p.courier_id === user.id && p.shipment_id === input.shipmentId,
        ),
      "Tiga foto belum lengkap di database.",
      "failed-precondition",
      409,
    );
    const now = stamp(),
      after = {
        ...before,
        proof: input.proof,
        status: "Selesai",
        completedAt: now,
        updatedAt: now,
        updatedBy: user.id,
      };
    await db.query(
      "UPDATE shipments SET status='Selesai',data=$2,updated_at=$3,revision=revision+1 WHERE id=$1",
      [input.shipmentId, after, now],
    );
    await audit(db, user, input.shipmentId, before, after, now);
  });
  res.json({ status: "Selesai" });
});
function photoPath(path, user) {
  const p =
    typeof path === "string" &&
    path.match(
      /^proofs\/([A-Za-z0-9_-]{1,128})\/([A-Za-z0-9_-]{1,128})\/[0-9]{1,25}\/(receipt|recipient|parcel)\.(jpg|png)$/,
    );
  requireValue(
    p && p[1] === user.id && user.role === "kurir",
    "Path foto tidak valid atau bukan milik Anda.",
    "permission-denied",
    403,
  );
  return p;
}
app.post(
  "/v1/photos/upload",
  rateLimit({
    windowMs: 60000,
    limit: 30,
    standardHeaders: "draft-8",
    legacyHeaders: false,
  }),
  async (req, res) => {
    const { path, contentType, base64 } = req.body || {},
      parts = photoPath(path, req.user);
    requireValue(
      typeof base64 === "string" &&
        base64.length <= 6990512 &&
        /^[A-Za-z0-9+/]*={0,2}$/.test(base64) &&
        base64.length % 4 === 0,
      "Data foto tidak valid.",
    );
    let bytes = Buffer.from(base64, "base64");
    requireValue(
      bytes.length > 0 && bytes.length <= 5242880,
      "Foto maksimal 5 MB.",
    );
    const jpeg = bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255,
      png = bytes
        .subarray(0, 8)
        .equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
    requireValue(
      (jpeg && contentType === "image/jpeg" && parts[4] === "jpg") ||
        (png && contentType === "image/png" && parts[4] === "png"),
      "Isi foto harus JPG atau PNG yang sesuai.",
    );
    bytes = await preparePhoto(bytes, contentType);
    await transaction(async (db) => {
      const user = await writeLock(db, req.user),
        record = await readRecord(db, user, `shipments/${parts[2]}`, true);
      requireValue(
        record?.data?.courierId === user.id,
        "Pengiriman bukan tugas Anda.",
        "permission-denied",
        403,
      );
      const old = (
        await db.query(
          "SELECT bytes,content_type FROM proof_photos WHERE path=$1",
          [path],
        )
      ).rows[0];
      if (old) {
        requireValue(
          old.content_type === contentType && old.bytes.equals(bytes),
          "Foto pada path tersebut tidak dapat ditimpa.",
          "already-exists",
          409,
        );
        return;
      }
      requireValue(
        record.data.status === "Proses",
        "Foto hanya dapat diunggah saat pengantaran aktif.",
        "failed-precondition",
        409,
      );
      await db.query(
        "INSERT INTO proof_photos(path,shipment_id,courier_id,kind,content_type,bytes) VALUES($1,$2,$3,$4,$5,$6)",
        [path, parts[2], user.id, parts[3], contentType, bytes],
      );
    });
    res.status(201).json({ path, size: bytes.length });
  },
);
app.get("/v1/photos", async (req, res) => {
  const path = req.query.path;
  requireValue(
    typeof path === "string" && path.length < 500,
    "Path foto tidak valid.",
  );
  const row = (
    await pool.query(
      "SELECT p.bytes,p.content_type,s.courier_id FROM proof_photos p JOIN shipments s ON s.id=p.shipment_id WHERE p.path=$1",
      [path],
    )
  ).rows[0];
  requireValue(row, "Foto tidak ditemukan.", "not-found", 404);
  requireValue(
    req.user.role === "admin" || row.courier_id === req.user.id,
    "Akses foto ditolak.",
    "permission-denied",
    403,
  );
  res.set("Cache-Control", "no-store").type(row.content_type).send(row.bytes);
});
app.use((req, res) =>
  res
    .status(404)
    .json({ code: "not-found", message: "Endpoint tidak ditemukan." }),
);
app.use((e, req, res, next) => {
  if (res.headersSent) return next(e);
  if (e.code === "23505")
    return res.status(409).json({
      code: "already-exists",
      message: "Resi atau email sudah digunakan.",
    });
  if (e.type === "entity.too.large")
    return res.status(413).json({
      code: "invalid-argument",
      message: "Ukuran unggahan terlalu besar.",
    });
  if (e instanceof SyntaxError && e.status === 400)
    return res
      .status(400)
      .json({ code: "invalid-argument", message: "Format JSON tidak valid." });
  const status = e.status || 500;
  if (status >= 500) console.error("API failure:", e.code || e.name);
  res.status(status).json({
    code: e.code || "internal",
    message:
      status >= 500
        ? "Server belum dapat memproses permintaan. Coba lagi."
        : e.message,
  });
});
export async function start() {
  if (!process.env.DATABASE_URL) throw new Error("DATABASE_URL wajib diisi.");
  await migrate();
  await bootstrapAdmin();
  const server = app.listen(Number(process.env.PORT || 3000), "0.0.0.0", () =>
    console.log("Haryata Cargo PostgreSQL API ready"),
  );
  let stopping = false;
  const stop = () => {
    if (stopping) return;
    stopping = true;
    server.close(async () => {
      await pool.end();
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10000).unref();
  };
  process.on("SIGTERM", stop);
  process.on("SIGINT", stop);
  return server;
}
if (process.env.NODE_ENV !== "test")
  start().catch((e) => {
    console.error("Startup failed:", e.code || e.message);
    process.exit(1);
  });
