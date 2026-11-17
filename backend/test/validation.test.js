import test from "node:test";
import assert from "node:assert/strict";
import {
  hashPassword,
  verifyPassword,
  validPassword,
  validEmail,
  tokenHash,
} from "../src/auth.js";
import { normalize, queryRecords, readRecord } from "../src/records.js";
import validation from "../src/validation.cjs";
test("password disimpan sebagai scrypt dengan salt unik, bukan plaintext", async () => {
  const password = "SkripsiCargo2026!",
    a = await hashPassword(password),
    b = await hashPassword(password);
  assert.notEqual(a, b);
  assert.ok(!a.includes(password));
  assert.ok(await verifyPassword(password, a));
  assert.equal(await verifyPassword("SalahCargo2026!", a), false);
});
test("akun impor tanpa hash tidak dapat masuk", async () => {
  assert.equal(await verifyPassword("SkripsiCargo2026!", null), false);
});
test("sandi huruf kecil 12 karakter atau lebih diterima", async () => {
  const password = "hurufkecilsemua";
  assert.ok(validPassword(password));
  assert.ok(await verifyPassword(password, await hashPassword(password)));
});
test("sandi kosong atau melebihi batas input ditolak", async () => {
  assert.equal(validPassword(""), false);
  await assert.rejects(hashPassword("a".repeat(4097)));
  assert.equal(validEmail("admin@haryatacargo.local"), true);
  assert.equal(validEmail("bukan-email"), false);
});
test("token sesi hanya mempunyai digest di database", () => {
  const token = "contoh-token-rahasia";
  assert.equal(tokenHash(token).length, 64);
  assert.notEqual(tokenHash(token), token);
});
test("timestamp dari klien dinormalisasi dan server timestamp memakai jam server", () => {
  const now = "2026-10-31T08:00:00.000Z";
  assert.deepEqual(
    normalize(
      {
        updatedAt: { $serverTimestamp: true },
        fixAt: { $date: "2026-10-31T16:00:00+08:00" },
      },
      now,
    ),
    { updatedAt: now, fixAt: now },
  );
  assert.throws(() => normalize({ $date: "invalid" }, now));
});
test("kurir tidak dapat membaca profil kurir lain", async () => {
  let called = false;
  await assert.rejects(
    readRecord(
      {
        query() {
          called = true;
        },
      },
      { id: "k1", role: "kurir" },
      "users/k2",
    ),
    (e) => e.status === 403,
  );
  assert.equal(called, false);
});
test("kueri kurir selalu dibatasi ke penugasannya sendiri", async () => {
  let query, args;
  const db = {
    async query(sql, values) {
      query = sql;
      args = values;
      return { rows: [] };
    },
  };
  await queryRecords(
    db,
    { id: "k1", role: "kurir" },
    { path: "shipments", filters: [["status", "eq", "Proses"]], limit: 50 },
  );
  assert.match(query, /courier_id=\$1/);
  assert.deepEqual(args, ["k1", "Proses", 50]);
});
test("nama kolom dan prototype tidak dapat diinjeksi ke SQL", async () => {
  const db = {
    query() {
      throw new Error("SQL tidak boleh dijalankan");
    },
  };
  for (const field of [
    "status; DROP TABLE shipments",
    "__proto__",
    "constructor",
  ])
    await assert.rejects(
      queryRecords(
        db,
        { id: "a", role: "admin" },
        { path: "shipments", filters: [[field, "eq", "x"]] },
      ),
      (e) => e.status === 400,
    );
});
test("kurir tidak dapat mendaftar semua akun", async () => {
  await assert.rejects(
    queryRecords({}, { id: "k", role: "kurir" }, { path: "users" }),
    (e) => e.status === 403,
  );
});
test("proof mewajibkan tiga foto milik kurir dan pengiriman yang sama", () => {
  const uid = "k1",
    shipmentId = "s1",
    proof = {
      receivedBy: "Penerima Uji",
      note: "",
      consent: true,
      latitude: -5,
      longitude: 119,
      accuracy: 5,
      photos: {
        receipt: "proofs/k1/s1/123/receipt.png",
        recipient: "proofs/k1/s1/123/recipient.png",
        parcel: "proofs/k1/s1/123/parcel.png",
      },
    };
  assert.equal(
    validation.validateProof({ shipmentId, proof }, uid).shipmentId,
    shipmentId,
  );
  assert.throws(() =>
    validation.validateProof(
      {
        shipmentId,
        proof: {
          ...proof,
          photos: { ...proof.photos, parcel: "proofs/k2/s1/123/parcel.png" },
        },
      },
      uid,
    ),
  );
});

test("sandi satu karakter, spasi, simbol dan unicode diterima", async () => {
  for (const password of ["a", " ", "🔑", "12", "é!"]) {
    assert.ok(validPassword(password));
    assert.ok(await verifyPassword(password, await hashPassword(password)));
    validation.validateCourier({
      name: "Neo",
      email: "neo@example.com",
      phone: "08123456789",
      password,
    });
  }
});
test("riwayat kurir dibatasi lewat akses pengiriman, bukan kolom events", async () => {
  const queries = [];
  const db = {
    async query(sql, values) {
      queries.push({ sql, values });
      return {
        rows: sql.includes("FROM shipments")
          ? [{ id: "s1", courier_id: "k1" }]
          : [],
      };
    },
  };
  await queryRecords(
    db,
    { id: "k1", role: "kurir" },
    { path: "shipments/s1/events", order: [["createdAt", true]], limit: 100 },
  );
  assert.match(queries[1].sql, /FROM shipment_events WHERE shipment_id=/);
  assert.doesNotMatch(queries[1].sql, /courier_id/);
  assert.deepEqual(queries[1].values, ["s1", 100]);
  await assert.rejects(
    queryRecords(
      db,
      { id: "k2", role: "kurir" },
      { path: "shipments/s1/events" },
    ),
    (e) => e.status === 403,
  );
});
