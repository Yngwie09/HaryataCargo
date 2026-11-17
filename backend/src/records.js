import { randomUUID } from "node:crypto";
import { ApiError, requireValue, admin } from "./auth.js";
export const idOk = (id) =>
  typeof id === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(id);
export const text = (v, min, max) =>
  typeof v === "string" && v.trim().length >= min && v.length <= max;
export const stamp = () => new Date().toISOString();
export async function writeLock(db, user) {
  await db.query("SELECT pg_advisory_xact_lock(48127632)");
  const { rows } = await db.query(
    "SELECT * FROM app_users WHERE id=$1 FOR UPDATE",
    [user.id],
  );
  if (!rows[0]?.active)
    throw new ApiError(401, "unauthenticated", "Akun sudah tidak aktif.");
  return rows[0];
}
export function normalize(value, now) {
  if (Array.isArray(value)) return value.map((v) => normalize(v, now));
  if (value && typeof value === "object") {
    if (value.$serverTimestamp === true) return now;
    if (typeof value.$date === "string") {
      requireValue(
        Number.isFinite(Date.parse(value.$date)),
        "Tanggal tidak valid.",
      );
      return new Date(value.$date).toISOString();
    }
    return Object.fromEntries(
      Object.entries(value).map(([k, v]) => [k, normalize(v, now)]),
    );
  }
  return value;
}
function parsePath(path) {
  requireValue(
    typeof path === "string" && path.length < 500,
    "Path tidak valid.",
  );
  const p = path.split("/");
  requireValue(p.every(idOk), "Path tidak valid.");
  requireValue(
    ["users", "shipments", "courier_locations", "resi_index"].includes(p[0]),
    "Koleksi tidak dikenal.",
  );
  requireValue(
    p.length <= 2 ||
      (p.length <= 4 && p[0] === "shipments" && p[2] === "events"),
    "Path tidak didukung.",
  );
  return p;
}
function view(kind, row) {
  if (!row) return null;
  let data;
  if (kind === "users")
    data = {
      email: row.email,
      name: row.name,
      phone: row.phone,
      role: row.role,
      active: row.active,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString(),
    };
  else if (kind === "shipments")
    data = {
      ...row.data,
      resi: row.resi,
      courierId: row.courier_id,
      status: row.status,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString(),
    };
  else data = { ...row.data };
  return {
    id: row.id || row.courier_id,
    data,
    version: String(row.revision || 1),
  };
}
async function shipmentAccess(db, user, id, lock = false) {
  const { rows } = await db.query(
    `SELECT * FROM shipments WHERE id=$1 ${lock ? "FOR UPDATE" : ""}`,
    [id],
  );
  const row = rows[0];
  if (row && user.role !== "admin" && row.courier_id !== user.id)
    throw new ApiError(
      403,
      "permission-denied",
      "Pengiriman bukan tugas Anda.",
    );
  return row;
}
export async function readRecord(db, user, path, lock = false) {
  const p = parsePath(path);
  requireValue(p.length === 2 || p.length === 4, "ID dokumen wajib diisi.");
  const suffix = lock ? " FOR UPDATE" : "";
  if (p[0] === "users") {
    if (user.role !== "admin" && p[1] !== user.id)
      throw new ApiError(403, "permission-denied", "Akses profil ditolak.");
    return view(
      "users",
      (await db.query("SELECT * FROM app_users WHERE id=$1" + suffix, [p[1]]))
        .rows[0],
    );
  }
  if (p[0] === "courier_locations") {
    if (user.role !== "admin" && p[1] !== user.id)
      throw new ApiError(403, "permission-denied", "Akses lokasi ditolak.");
    return view(
      "courier_locations",
      (
        await db.query(
          "SELECT * FROM courier_locations WHERE courier_id=$1" + suffix,
          [p[1]],
        )
      ).rows[0],
    );
  }
  if (p[0] === "resi_index") {
    admin(user);
    const row = (
      await db.query("SELECT id FROM shipments WHERE resi=$1" + suffix, [p[1]])
    ).rows[0];
    return row
      ? { id: p[1], data: { shipmentId: row.id }, version: "1" }
      : null;
  }
  const shipment = await shipmentAccess(db, user, p[1], lock);
  if (p.length === 2) return view("shipments", shipment);
  if (!shipment) return null;
  return view(
    "events",
    (
      await db.query(
        "SELECT * FROM shipment_events WHERE shipment_id=$1 AND id=$2" + suffix,
        [p[1], p[3]],
      )
    ).rows[0],
  );
}
export async function queryRecords(db, user, input) {
  const p = parsePath(input.path),
    filters = input.filters || [],
    order = input.order || [];
  requireValue(
    p.length === 1 || (p.length === 3 && p[2] === "events"),
    "Kueri koleksi tidak valid.",
  );
  requireValue(
    Array.isArray(filters) &&
      filters.length <= 8 &&
      Array.isArray(order) &&
      order.length <= 2,
    "Kueri terlalu kompleks.",
  );
  const limit = input.limit ?? 50;
  requireValue(
    Number.isInteger(limit) && limit >= 1 && limit <= 5000,
    "Batas kueri 1–5000.",
  );
  const values = [],
    where = [],
    bind = (v) => {
      values.push(v);
      return "$" + values.length;
    };
  let table,
    kind = p[0],
    fields;
  if (kind === "users") {
    admin(user);
    table = "app_users";
    fields = {
      role: "role",
      active: "active",
      email: "email",
      name: "name",
      createdAt: "created_at",
    };
  } else if (kind === "shipments") {
    table = "shipments";
    fields = {
      resi: "resi",
      courierId: "courier_id",
      status: "status",
      createdAt: "created_at",
      completedAt: "NULLIF(data->>'completedAt','')::timestamptz",
    };
    if (user.role !== "admin") where.push("courier_id=" + bind(user.id));
  } else if (kind === "courier_locations") {
    table = "courier_locations";
    fields = { courierId: "courier_id", updatedAt: "updated_at" };
    if (user.role !== "admin") where.push("courier_id=" + bind(user.id));
  } else
    throw new ApiError(
      403,
      "permission-denied",
      "Koleksi tidak dapat didaftar.",
    );
  if (p.length === 3) {
    requireValue(
      await shipmentAccess(db, user, p[1]),
      "Pengiriman tidak ditemukan.",
      "not-found",
      404,
    );
    table = "shipment_events";
    kind = "events";
    fields = { createdAt: "created_at" };
    where.length = 0;
    values.length = 0;
    where.push("shipment_id=" + bind(p[1]));
  }
  for (const f of filters) {
    requireValue(
      Array.isArray(f) && f.length === 3 && Object.hasOwn(fields, f[0]),
      "Kolom filter tidak didukung.",
    );
    const op = { eq: "=", gte: ">=", lt: "<" }[f[1]];
    requireValue(op, "Operator tidak didukung.");
    const v = normalize(f[2], stamp());
    requireValue(
      typeof v === "string" || typeof v === "boolean" || typeof v === "number",
      "Nilai filter tidak valid.",
    );
    where.push(`${fields[f[0]]} ${op} ${bind(v)}`);
  }
  const sorts = order.map((o) => {
    requireValue(
      Array.isArray(o) &&
        Object.hasOwn(fields, o[0]) &&
        typeof o[1] === "boolean",
      "Urutan tidak valid.",
    );
    return fields[o[0]] + (o[1] ? " DESC" : " ASC") + " NULLS LAST";
  });
  const sql = `SELECT * FROM ${table}${where.length ? " WHERE " + where.join(" AND ") : ""}${sorts.length ? " ORDER BY " + sorts.join(",") : ""} LIMIT ${bind(limit)}`;
  return (await db.query(sql, values)).rows.map((r) => view(kind, r));
}
function onlyFields(data, allowed) {
  requireValue(
    Object.keys(data).every((k) => allowed.includes(k)),
    "Perubahan kolom tidak diizinkan.",
    "permission-denied",
    403,
  );
}
const editable = [
  "penerima",
  "phone",
  "alamat",
  "sender",
  "weight",
  "pieces",
  "notes",
  "courierId",
  "courierEmail",
];
async function validShipment(db, d) {
  requireValue(
    text(d.penerima, 1, 120) &&
      text(d.alamat, 1, 1000) &&
      text(d.sender, 1, 120) &&
      text(d.notes, 0, 1000),
    "Informasi pengiriman belum lengkap.",
  );
  requireValue(
    typeof d.phone === "string" && /^\+?[0-9 ()-]{8,20}$/.test(d.phone),
    "Telepon tidak valid.",
  );
  requireValue(
    Number.isFinite(d.weight) &&
      d.weight > 0 &&
      d.weight <= 100000 &&
      Number.isInteger(d.pieces) &&
      d.pieces > 0 &&
      d.pieces <= 10000,
    "Berat atau koli tidak valid.",
  );
  const courier = (
    await db.query(
      "SELECT * FROM app_users WHERE id=$1 AND role='kurir' AND active=true FOR UPDATE",
      [d.courierId],
    )
  ).rows[0];
  requireValue(courier, "Pilih kurir yang aktif.");
  d.courierEmail = courier.email;
}
export async function audit(db, user, id, before, after, now) {
  const note = !before
    ? "Pengiriman dibuat dan ditugaskan"
    : before.status !== after.status
      ? {
          Pending: "Pengantaran ulang: " + (after.resolutionNote || ""),
          Proses: "Kurir memulai pengantaran",
          Tertunda: "Pengantaran ditunda: " + (after.issue || ""),
          Retur: "Barang diretur: " + (after.resolutionNote || ""),
          Selesai: "Barang diserahterimakan kepada penerima",
          Batal: "Dibatalkan: " + (after.cancelReason || ""),
        }[after.status]
      : "Informasi / penugasan pengiriman diperbarui";
  const data = {
    status: after.status,
    note,
    actorId: user.id,
    actorEmail: user.email,
    createdAt: now,
  };
  await db.query(
    "INSERT INTO shipment_events(id,shipment_id,actor_id,data,created_at) VALUES($1,$2,$3,$4,$5)",
    [randomUUID(), id, user.id, data, now],
  );
}
async function writeRecord(db, user, w, now) {
  const p = parsePath(w.path);
  requireValue(
    p.length === 2 && ["set", "update"].includes(w.kind),
    "Operasi tulis tidak valid.",
  );
  const d = normalize(w.data, now);
  requireValue(
    d && typeof d === "object" && !Array.isArray(d),
    "Data tidak valid.",
  );
  if (p[0] === "resi_index") {
    admin(user);
    return;
  }
  if (p[0] === "users") {
    admin(user);
    onlyFields(d, ["name", "phone", "updatedAt"]);
    const before = (
      await db.query(
        "SELECT * FROM app_users WHERE id=$1 AND role='kurir' FOR UPDATE",
        [p[1]],
      )
    ).rows[0];
    requireValue(before, "Kurir tidak ditemukan.", "not-found", 404);
    requireValue(
      text(d.name ?? before.name, 2, 120) &&
        /^\+?[0-9 ()-]{8,20}$/.test(d.phone ?? before.phone),
      "Nama atau telepon tidak valid.",
    );
    await db.query(
      "UPDATE app_users SET name=$2,phone=$3,updated_at=$4,revision=revision+1 WHERE id=$1",
      [p[1], d.name ?? before.name, d.phone ?? before.phone, now],
    );
    return;
  }
  if (p[0] === "courier_locations") {
    requireValue(
      user.role === "kurir" && p[1] === user.id,
      "Lokasi bukan milik Anda.",
      "permission-denied",
      403,
    );
    onlyFields(d, [
      "courierId",
      "email",
      "latitude",
      "longitude",
      "accuracy",
      "heading",
      "speed",
      "fixAt",
      "updatedAt",
      "isTracking",
      "stoppedAt",
    ]);
    const old = (
      await db.query(
        "SELECT * FROM courier_locations WHERE courier_id=$1 FOR UPDATE",
        [user.id],
      )
    ).rows[0];
    let data;
    if (d.isTracking === true) {
      requireValue(
        Number.isFinite(d.latitude) &&
          Math.abs(d.latitude) <= 90 &&
          Number.isFinite(d.longitude) &&
          Math.abs(d.longitude) <= 180 &&
          Number.isFinite(d.accuracy) &&
          d.accuracy >= 0,
        "Koordinat atau akurasi tidak valid.",
      );
      const fix = Date.parse(d.fixAt);
      requireValue(
        Number.isFinite(fix) && fix <= Date.parse(now) + 120000,
        "Waktu GPS tidak valid.",
      );
      if (old?.data?.fixAt && fix < Date.parse(old.data.fixAt))
        throw new ApiError(
          409,
          "stale-location",
          "Sampel GPS lama diabaikan; tunggu posisi terbaru.",
        );
      requireValue(
        (
          await db.query(
            "SELECT id FROM shipments WHERE courier_id=$1 AND status='Proses' LIMIT 1",
            [user.id],
          )
        ).rowCount > 0,
        "Tidak ada pengantaran aktif.",
        "failed-precondition",
        409,
      );
      data = { ...d, courierId: user.id, email: user.email, updatedAt: now };
    } else {
      requireValue(d.isTracking === false, "Status GPS tidak valid.");
      onlyFields(d, ["courierId", "isTracking", "stoppedAt"]);
      data = {
        ...(old?.data || {}),
        courierId: user.id,
        isTracking: false,
        stoppedAt: now,
      };
    }
    await db.query(
      "INSERT INTO courier_locations(courier_id,latitude,longitude,data,updated_at) VALUES($1,$2,$3,$4,$5) ON CONFLICT(courier_id) DO UPDATE SET latitude=excluded.latitude,longitude=excluded.longitude,data=excluded.data,updated_at=excluded.updated_at,revision=courier_locations.revision+1",
      [user.id, data.latitude ?? null, data.longitude ?? null, data, now],
    );
    return;
  }
  requireValue(
    p[0] === "shipments",
    "Koleksi hanya dapat dibaca.",
    "permission-denied",
    403,
  );
  const old = await shipmentAccess(db, user, p[1], true),
    before = old ? view("shipments", old).data : null;
  const after = { ...(before || {}), ...d, updatedBy: user.id, updatedAt: now };
  if (!old) {
    admin(user);
    requireValue(
      w.kind === "set",
      "Pengiriman tidak ditemukan.",
      "not-found",
      404,
    );
    onlyFields(d, [
      "resi",
      ...editable,
      "status",
      "createdBy",
      "createdAt",
      "updatedAt",
      "updatedBy",
    ]);
    requireValue(
      typeof d.resi === "string" &&
        /^[A-Z0-9-]{4,40}$/.test(d.resi) &&
        d.status === "Pending",
      "Resi atau status awal tidak valid.",
    );
    await validShipment(db, after);
    after.createdAt = now;
    after.createdBy = user.id;
    await db.query(
      "INSERT INTO shipments(id,resi,courier_id,status,data,created_at,updated_at) VALUES($1,$2,$3,$4,$5,$6,$6)",
      [p[1], d.resi, after.courierId, "Pending", after, now],
    );
  } else {
    requireValue(
      w.kind === "update",
      "Pengiriman sudah tersedia.",
      "already-exists",
      409,
    );
    if (user.role === "admin") {
      if (before.status === "Pending" && after.status === "Pending") {
        onlyFields(d, [...editable, "updatedAt", "updatedBy"]);
        await validShipment(db, after);
      } else if (before.status === "Pending" && after.status === "Batal") {
        onlyFields(d, ["status", "cancelReason", "updatedAt", "updatedBy"]);
        requireValue(
          text(after.cancelReason, 5, 1000),
          "Alasan pembatalan minimal 5 karakter.",
        );
      } else if (
        ["Proses", "Tertunda"].includes(before.status) &&
        ["Pending", "Retur"].includes(after.status)
      ) {
        onlyFields(d, [
          "status",
          "courierId",
          "courierEmail",
          "startedAt",
          "issue",
          "resolutionNote",
          "issueResolvedAt",
          "updatedAt",
          "updatedBy",
        ]);
        requireValue(
          text(after.resolutionNote, 5, 1000),
          "Catatan tindak lanjut minimal 5 karakter.",
        );
        after.issueResolvedAt = now;
        if (after.status === "Pending") {
          await validShipment(db, after);
          after.startedAt = null;
          after.issue = "";
        } else
          onlyFields(d, [
            "status",
            "resolutionNote",
            "issueResolvedAt",
            "updatedAt",
            "updatedBy",
          ]);
      } else
        throw new ApiError(
          409,
          "failed-precondition",
          "Status pengiriman telah berubah atau tindakan tidak diizinkan.",
        );
    } else {
      requireValue(
        before.courierId === user.id,
        "Pengiriman bukan tugas Anda.",
        "permission-denied",
        403,
      );
      if (before.status === "Pending" && after.status === "Proses") {
        onlyFields(d, ["status", "startedAt", "updatedAt", "updatedBy"]);
        after.startedAt = now;
      } else if (
        before.status === "Proses" &&
        ["Proses", "Tertunda"].includes(after.status)
      ) {
        onlyFields(d, ["status", "issue", "updatedAt", "updatedBy"]);
        requireValue(
          text(after.issue, 5, 1000),
          "Catatan kendala minimal 5 karakter.",
        );
      } else
        throw new ApiError(
          409,
          "failed-precondition",
          "Status tidak dapat diubah. Gunakan bukti foto untuk penyelesaian.",
        );
    }
    await db.query(
      "UPDATE shipments SET courier_id=$2,status=$3,data=$4,updated_at=$5,revision=revision+1 WHERE id=$1",
      [p[1], after.courierId, after.status, after, now],
    );
  }
  await audit(db, user, p[1], before, after, now);
}
export async function commitRecords(db, user, input) {
  user = await writeLock(db, user);
  requireValue(
    Array.isArray(input.reads) &&
      input.reads.length <= 20 &&
      Array.isArray(input.writes) &&
      input.writes.length <= 20,
    "Transaksi tidak valid.",
  );
  requireValue(
    input.reads.every(
      (r) =>
        r &&
        typeof r.path === "string" &&
        (r.version == null || typeof r.version === "string"),
    ) && input.writes.every((w) => w && typeof w.path === "string"),
    "Isi transaksi tidak valid.",
  );
  for (const read of [...input.reads].sort((a, b) =>
    a.path.localeCompare(b.path),
  )) {
    const actual = await readRecord(db, user, read.path, true);
    if ((actual?.version ?? null) !== (read.version ?? null))
      throw new ApiError(
        409,
        "conflict",
        "Data berubah. Muat ulang lalu coba lagi.",
      );
  }
  const now = stamp();
  // Resi uniqueness is enforced by PostgreSQL, not by a client-owned index.
  for (const write of input.writes) await writeRecord(db, user, write, now);
  return { committed: true };
}
