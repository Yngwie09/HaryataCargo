// Explicit opt-in integration test for the newly provisioned thesis database.
// Leaves clearly labelled demo shipments/accounts for the user's own APK test.
import assert from "node:assert/strict";
import sharp from "sharp";
import { preparePhoto } from "../src/photos.js";
if (process.env.LIVE_SMOKE_CONFIRM !== "RUN_HARYATA_CHECKS")
  throw new Error(
    "Set LIVE_SMOKE_CONFIRM=RUN_HARYATA_CHECKS untuk mengizinkan perubahan data integrasi.",
  );
import { readFile, writeFile } from "node:fs/promises";
import { randomBytes, randomUUID } from "node:crypto";
const base =
  process.env.TEST_API_URL || "https://haryata-api-production.up.railway.app";
const privateFile = new URL(
  "../../config/railway.private.json",
  import.meta.url,
);
const credentials = JSON.parse(await readFile(privateFile, "utf8"));
for (const key of ["courierPassword", "otherCourierPassword"])
  credentials[key] ||= "Cargo1!" + randomBytes(18).toString("base64url");
credentials.courierEmail ||= "kurir@haryatacargo.local";
credentials.otherCourierEmail ||= "kurir-uji@haryatacargo.local";
await writeFile(privateFile, JSON.stringify(credentials, null, 2) + "\n");
const passed = [];
const check = (name) => {
  passed.push(name);
  console.log("PASS " + name);
};
async function request(path, body, token, expected = 200, binary = false) {
  const response = await fetch(base + path, {
    method: body === undefined ? "GET" : "POST",
    headers: {
      ...(body === undefined ? {} : { "Content-Type": "application/json" }),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    signal: AbortSignal.timeout(30000),
  });
  assert.equal(
    response.status,
    expected,
    `${path}: status ${response.status}, expected ${expected}`,
  );
  return binary ? Buffer.from(await response.arrayBuffer()) : response.json();
}
const login = (email, password) =>
  request("/v1/auth/login", { email, password });
const record = (path, token) =>
  request("/v1/record", { path }, token).then((x) => x.doc);
const serverTime = { $serverTimestamp: true };
const commit = (token, writes, reads = []) =>
  request("/v1/transactions", { reads, writes }, token);
async function change(id, token, data, expected = 200) {
  const old = await record("shipments/" + id, token);
  return request(
    "/v1/transactions",
    {
      reads: [{ path: "shipments/" + id, version: old.version }],
      writes: [
        {
          path: "shipments/" + id,
          kind: "update",
          data: { ...data, updatedAt: serverTime },
        },
      ],
    },
    token,
    expected,
  );
}
const health = await request("/health");
assert.equal(health.database, "postgresql");
check("endpoint Railway menghubungkan PostgreSQL");
await request("/v1/query", { path: "shipments" }, null, 401);
check("akses tanpa login ditolak");
const a = await login(credentials.adminEmail, credentials.adminPassword),
  admin = a.token;
const adminProfile = await record("users/" + a.user.uid, admin);
assert.equal(adminProfile.data.role, "admin");
check("akun admin bootstrap dapat login dan membaca profil");
async function courier(email, password, name) {
  const result = await fetch(base + "/v1/actions/createCourier", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${admin}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ email, password, name, phone: "081200000000" }),
    signal: AbortSignal.timeout(30000),
  });
  assert.ok(
    [201, 409].includes(result.status),
    "pembuatan akun kurir harus berhasil atau sudah ada",
  );
  const users = await request(
    "/v1/query",
    { path: "users", filters: [["email", "eq", email]], limit: 1 },
    admin,
  );
  assert.equal(users.docs.length, 1);
  const uid = users.docs[0].id;
  await request("/v1/actions/setCourierActive", { uid, active: true }, admin);
  await request("/v1/actions/resetCourierPassword", { uid, password }, admin);
  return { uid, ...(await login(email, password)) };
}
const c = await courier(
  credentials.courierEmail,
  credentials.courierPassword,
  "Princeugha",
);
const other = await courier(
  credentials.otherCourierEmail,
  credentials.otherCourierPassword,
  "Chasy",
);
credentials.courierId = c.uid;
credentials.otherCourierId = other.uid;
await writeFile(privateFile, JSON.stringify(credentials, null, 2) + "\n");
await request("/v1/query", { path: "users" }, c.token, 403);
check("pembuatan kurir dan pembatasan menu admin");
const prefix = "HC-" + Date.now().toString(36).toUpperCase();
function fields(resi) {
  return {
    resi,
    penerima: "Michael Runtuwene",
    phone: "081200000000",
    alamat: "Jl. Sam Ratulangi No. 18, Kota Manado, Sulawesi Utara",
    sender: "Toko Sinar Selatan",
    weight: 1.5,
    pieces: 1,
    notes: "Perlengkapan kantor. Hubungi penerima sebelum tiba.",
    courierId: c.uid,
    courierEmail: credentials.courierEmail,
    status: "Pending",
    createdAt: serverTime,
    updatedAt: serverTime,
  };
}
async function create(resi, id = randomUUID()) {
  await commit(admin, [
    {
      path: "resi_index/" + resi,
      kind: "set",
      data: { shipmentId: id, createdAt: serverTime },
    },
    { path: "shipments/" + id, kind: "set", data: fields(resi) },
  ]);
  return id;
}
const shipment = await create(prefix + "-SELESAI");
const duplicateResi = prefix + "-PENDING",
  duplicateIds = [randomUUID(), randomUUID()];
const duplicateResults = await Promise.all(
  duplicateIds.map((id) =>
    fetch(base + "/v1/transactions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${admin}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        reads: [],
        writes: [
          { path: "shipments/" + id, kind: "set", data: fields(duplicateResi) },
        ],
      }),
    }).then((r) => r.status),
  ),
);
assert.deepEqual([...duplicateResults].sort(), [200, 409]);
check("transaksi PostgreSQL menolak resi duplikat bersamaan");
const own = await request(
  "/v1/query",
  {
    path: "shipments",
    filters: [["resi", "eq", prefix + "-SELESAI"]],
    limit: 1,
  },
  c.token,
);
assert.equal(own.docs[0].id, shipment);
const hidden = await request(
  "/v1/query",
  { path: "shipments", filters: [["resi", "eq", prefix + "-SELESAI"]] },
  other.token,
);
assert.equal(hidden.docs.length, 0);
await request(
  "/v1/record",
  { path: "shipments/" + shipment },
  other.token,
  403,
);
check("pencarian resi dan isolasi data antarkurir");
await change(shipment, c.token, { status: "Proses", startedAt: serverTime });
await request(
  "/v1/actions/setCourierActive",
  { uid: c.uid, active: false },
  admin,
  409,
);
await request("/v1/auth/logout", {}, c.token, 409);
check("pengantaran aktif mencegah logout dan penonaktifan kurir");
const fix = new Date().toISOString(),
  location = {
    courierId: c.uid,
    email: credentials.courierEmail,
    latitude: -5.1477,
    longitude: 119.4327,
    accuracy: 5,
    heading: 0,
    speed: 0,
    fixAt: { $date: fix },
    updatedAt: serverTime,
    isTracking: true,
  };
await commit(c.token, [
  { path: "courier_locations/" + c.uid, kind: "set", data: location },
]);
const locations = await request(
  "/v1/query",
  { path: "courier_locations" },
  admin,
);
assert.equal(
  locations.docs.find((x) => x.id === c.uid).data.latitude,
  location.latitude,
);
await request(
  "/v1/transactions",
  {
    reads: [],
    writes: [
      {
        path: "courier_locations/" + c.uid,
        kind: "set",
        data: {
          ...location,
          fixAt: { $date: new Date(Date.parse(fix) - 30000).toISOString() },
        },
      },
    ],
  },
  c.token,
  409,
);
await request(
  "/v1/transactions",
  {
    reads: [],
    writes: [
      {
        path: "courier_locations/" + c.uid,
        kind: "set",
        data: { ...location, latitude: 91 },
      },
    ],
  },
  c.token,
  400,
);
await request(
  "/v1/transactions",
  {
    reads: [],
    writes: [
      { path: "courier_locations/" + c.uid, kind: "set", data: location },
    ],
  },
  other.token,
  403,
);
check(
  "lokasi kurir tersimpan, tampil pada admin, dan menolak sampel lama/invalid/kurir lain",
);
const png = (
  await sharp({
    create: { width: 640, height: 480, channels: 3, background: "#123e52" },
  })
    .png()
    .toBuffer()
).toString("base64");
const batch = String(Date.now()),
  photos = Object.fromEntries(
    ["receipt", "recipient", "parcel"].map((k) => [
      k,
      `proofs/${c.uid}/${shipment}/${batch}/${k}.png`,
    ]),
  );
const proof = {
  photos,
  receivedBy: "Michael Runtuwene",
  note: "Barang diterima dalam keadaan baik.",
  latitude: location.latitude,
  longitude: location.longitude,
  accuracy: 5,
  consent: true,
};
await request(
  "/v1/actions/finalizeDelivery",
  { shipmentId: shipment, proof },
  c.token,
  409,
);
for (const path of Object.values(photos))
  await request(
    "/v1/photos/upload",
    { path, contentType: "image/png", base64: png },
    c.token,
    201,
  );
await request(
  "/v1/photos/upload",
  { path: photos.receipt, contentType: "image/png", base64: png },
  c.token,
  201,
);
await request(
  "/v1/actions/finalizeDelivery",
  { shipmentId: shipment, proof },
  c.token,
);
await request(
  "/v1/actions/finalizeDelivery",
  { shipmentId: shipment, proof },
  c.token,
);
const downloaded = await request(
  "/v1/photos?path=" + encodeURIComponent(photos.receipt),
  undefined,
  admin,
  200,
  true,
);
assert.ok(
  downloaded.equals(
    await preparePhoto(Buffer.from(png, "base64"), "image/png"),
  ),
);
await request(
  "/v1/photos?path=" + encodeURIComponent(photos.receipt),
  undefined,
  other.token,
  403,
);
await change(shipment, c.token, { status: "Pending" }, 409);
check(
  "tiga foto BYTEA dapat diunggah/dibaca, penyelesaian idempoten dan bukti dilindungi",
);
const issue = await create(prefix + "-RETUR");
await change(issue, c.token, { status: "Proses", startedAt: serverTime });
await change(issue, c.token, {
  status: "Tertunda",
  issue: "Penerima belum berada di lokasi",
});
await change(issue, admin, {
  status: "Pending",
  courierId: c.uid,
  courierEmail: credentials.courierEmail,
  startedAt: null,
  issue: "",
  resolutionNote: "Jadwal pengantaran ulang disepakati dengan penerima.",
  issueResolvedAt: serverTime,
});
await change(issue, c.token, { status: "Proses", startedAt: serverTime });
await change(issue, c.token, {
  status: "Tertunda",
  issue: "Penerima meminta barang diretur",
});
await change(issue, admin, {
  status: "Retur",
  resolutionNote:
    "Barang dikembalikan kepada pengirim sesuai permintaan penerima.",
  issueResolvedAt: serverTime,
});
const canceled = await create(prefix + "-BATAL");
await change(canceled, admin, {
  status: "Batal",
  cancelReason: "Pengirim membatalkan pesanan sebelum keberangkatan.",
});
check("tunda, pengantaran ulang, retur dan batal tersimpan dengan audit");
const courierEvents = await request(
  "/v1/query",
  {
    path: `shipments/${issue}/events`,
    order: [["createdAt", true]],
    limit: 50,
  },
  c.token,
);
assert.ok(courierEvents.docs.length >= 6);
const dashboard = await request("/v1/dashboard", undefined, admin);
assert.ok(dashboard.counts.Selesai >= 1);
const events = await request(
  "/v1/query",
  {
    path: `shipments/${issue}/events`,
    order: [["createdAt", true]],
    limit: 50,
  },
  admin,
);
assert.ok(events.docs.length >= 6);
const report = await request(
  "/v1/query",
  {
    path: "shipments",
    filters: [
      [
        "createdAt",
        "gte",
        { $date: new Date(Date.now() - 86400000).toISOString() },
      ],
    ],
    order: [["createdAt", true]],
    limit: 5000,
  },
  admin,
);
for (const status of ["Pending", "Selesai", "Retur", "Batal"])
  assert.ok(report.docs.some((d) => d.data.status === status));
check("laporan periode dan riwayat diambil dari PostgreSQL");
await commit(c.token, [
  {
    path: "courier_locations/" + c.uid,
    kind: "set",
    merge: true,
    data: { courierId: c.uid, isTracking: false, stoppedAt: serverTime },
  },
]);
const stopped = await record("courier_locations/" + c.uid, admin);
assert.equal(stopped.data.isTracking, false);
assert.equal(stopped.data.latitude, location.latitude);
check("menghentikan GPS mempertahankan koordinat terakhir tanpa label live");
await request(
  "/v1/actions/setCourierActive",
  { uid: other.uid, active: false },
  admin,
);
await request("/v1/auth/me", undefined, other.token, 401);
await request(
  "/v1/actions/setCourierActive",
  { uid: other.uid, active: true },
  admin,
);
check("penonaktifan akun mencabut sesi");
await request(
  "/v1/auth/change-password",
  {
    currentPassword: "KataSandiSalah123",
    password: credentials.courierPassword,
  },
  c.token,
  401,
);
await request("/v1/auth/me", undefined, c.token);
await request(
  "/v1/auth/change-password",
  {
    currentPassword: credentials.courierPassword,
    password: credentials.courierPassword,
  },
  c.token,
);
await request(
  "/v1/actions/resetCourierPassword",
  { uid: c.uid, password: credentials.courierPassword },
  admin,
);
await request("/v1/auth/me", undefined, c.token, 401);
const renewed = await login(
  credentials.courierEmail,
  credentials.courierPassword,
);
await request("/v1/auth/logout", {}, renewed.token);
check("ubah/reset sandi dan pencabutan token berfungsi");
await request("/v1/auth/logout", {}, admin);
const result = {
  at: new Date().toISOString(),
  endpoint: base,
  database: "postgresql",
  passed: passed.length,
  checks: passed,
  sampleResis: [
    prefix + "-SELESAI",
    duplicateResi,
    prefix + "-RETUR",
    prefix + "-BATAL",
  ],
  note: "Data contoh otomatis, koordinat bukan GPS fisik; status lokasi sudah berhenti.",
};
await writeFile(
  new URL("../../docs/POSTGRES-LIVE-TEST.json", import.meta.url),
  JSON.stringify(result, null, 2) + "\n",
);
console.log("LIVE POSTGRESQL CHECKS PASSED: " + passed.length);
