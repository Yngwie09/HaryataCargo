import { randomUUID } from "node:crypto";
import { hashPassword } from "./auth.js";

export const courierNames = [
  "princeugha",
  "chasy",
  "wonzz",
  "yngganz",
  "neoaja",
];

const recipients = [
  [
    "Michael Runtuwene",
    "Jl. Sam Ratulangi No. 18, Kota Manado, Sulawesi Utara",
    "Toko Sinar Selatan",
    "Perlengkapan kantor. Hubungi penerima sebelum tiba.",
  ],
  [
    "Claudia Wenas",
    "Jl. Piere Tendean No. 42, Kota Manado, Sulawesi Utara",
    "Butik Nusa",
    "Pakaian dalam kemasan. Hindarkan dari air.",
  ],
  [
    "Steven Warouw",
    "Jl. Ahmad Yani No. 10, Kota Manado, Sulawesi Utara",
    "CV Mandiri Teknik",
    "Suku cadang mesin. Periksa jumlah koli saat penyerahan.",
  ],
  [
    "Angelina Paat",
    "Jl. R. W. Monginsidi No. 75, Kota Manado, Sulawesi Utara",
    "Rumah Kriya",
    "Peralatan rumah tangga. Tangani dengan hati-hati.",
  ],
  [
    "Christian Mandagi",
    "Jl. 17 Agustus No. 120, Kota Manado, Sulawesi Utara",
    "Buku Cendekia",
    "Buku dan alat tulis. Serahkan di bagian penerimaan.",
  ],
  [
    "Nathania Lumentut",
    "Jl. Babe Palar No. 31, Kota Manado, Sulawesi Utara",
    "Dapur Nusantara",
    "Kemasan makanan kering. Simpan di tempat teduh.",
  ],
  [
    "Ricky Sumual",
    "Jl. Diponegoro No. 16, Kota Manado, Sulawesi Utara",
    "Toko Cahaya Elektronik",
    "Aksesori elektronik. Jangan ditumpuk dengan barang berat.",
  ],
  [
    "Jessica Tumbel",
    "Jl. D. I. Panjaitan No. 88, Kota Manado, Sulawesi Utara",
    "Karya Tekstil",
    "Bahan kain. Penerimaan melalui pintu samping.",
  ],
  [
    "Daniel Roring",
    "Jl. Sam Ratulangi No. 57, Kota Manado, Sulawesi Utara",
    "Sentra Olahraga",
    "Perlengkapan olahraga. Pastikan kemasan tetap utuh.",
  ],
  [
    "Gracia Mambu",
    "Jl. Pumorow No. 29, Kota Manado, Sulawesi Utara",
    "Mitra Kemasan",
    "Kemasan usaha. Konfirmasi jumlah saat diterima.",
  ],
  [
    "Andre Sondakh",
    "Jl. Tikala Ares No. 23, Kota Manado, Sulawesi Utara",
    "Bengkel Sejahtera",
    "Peralatan bengkel dalam dua koli.",
  ],
  [
    "Michelle Rantung",
    "Jl. Santiago No. 61, Kota Manado, Sulawesi Utara",
    "Griya Busana",
    "Pesanan pakaian. Jadwalkan penyerahan dengan penerima.",
  ],
  [
    "Kevin Waworuntu",
    "Jl. Yos Sudarso No. 37, Kota Manado, Sulawesi Utara",
    "Toko Media Utama",
    "Dokumen dan alat presentasi. Hubungi petugas penerimaan.",
  ],
  [
    "Gabriella Moniaga",
    "Jl. A. A. Maramis No. 12, Kota Manado, Sulawesi Utara",
    "Kreasi Rotan",
    "Produk kerajinan. Pertahankan posisi kemasan.",
  ],
  [
    "Samuel Pinontoan",
    "Jl. Ring Road No. 46, Kota Manado, Sulawesi Utara",
    "Mitra Bangunan",
    "Perlengkapan proyek dalam kemasan tertutup.",
  ],
];

/** Must run inside a transaction after operator reauthentication. */
export async function replaceCatalog(db, owner, password) {
  const hash = await hashPassword(password);
  await db.query("DELETE FROM shipments"); // Cascades to events and photo bytes.
  await db.query("DELETE FROM courier_locations");
  await db.query("DELETE FROM sessions");
  await db.query("DELETE FROM app_users WHERE role='kurir'");
  const users = [];
  for (const [i, name] of courierNames.entries()) {
    const user = {
      id: randomUUID(),
      name,
      email: i === 0 ? "kurir@gmail.com" : `${name}@gmail.com`,
    };
    await db.query(
      "INSERT INTO app_users(id,email,name,phone,role,password_hash) VALUES($1,$2,$3,$4,'kurir',$5)",
      [user.id, user.email, name, `08123456000${i + 1}`, hash],
    );
    users.push(user);
  }
  const now = new Date();
  for (const [i, [penerima, alamat, sender, notes]] of recipients.entries()) {
    const courier = users[i % 5],
      id = randomUUID();
    const status =
      i < 11 ? "Pending" : i < 13 ? "Tertunda" : i === 13 ? "Retur" : "Batal";
    const date = new Date(now.getTime() - (15 - i) * 600000).toISOString();
    const resi = `HC-${now.toISOString().slice(0, 10).replaceAll("-", "")}-${String(i + 1).padStart(4, "0")}`;
    const data = {
      resi,
      penerima,
      alamat,
      sender,
      notes,
      phone: `0812987600${String(i + 10)}`,
      weight: 1.5 + i * 0.5,
      pieces: (i % 3) + 1,
      courierId: courier.id,
      courierEmail: courier.email,
      status,
      createdBy: owner.id,
      updatedBy: owner.id,
      createdAt: date,
      updatedAt: date,
    };
    if (status === "Tertunda")
      data.issue =
        i === 11
          ? "Penerima sedang di luar lokasi. Menunggu konfirmasi jadwal pengantaran ulang."
          : "Akses menuju alamat sementara ditutup. Menunggu rute pengantaran alternatif.";
    if (status === "Retur")
      data.resolutionNote =
        "Penerima meminta pengembalian barang kepada pengirim setelah konfirmasi pesanan.";
    if (status === "Batal")
      data.cancelReason =
        "Pengirim membatalkan pengiriman sebelum paket diberangkatkan.";
    await db.query(
      "INSERT INTO shipments(id,resi,courier_id,status,data,created_at,updated_at) VALUES($1,$2,$3,$4,$5,$6,$6)",
      [id, resi, courier.id, status, data, date],
    );
    const statuses =
      status === "Pending"
        ? ["Pending"]
        : status === "Batal"
          ? ["Pending", "Batal"]
          : [
              "Pending",
              "Proses",
              "Tertunda",
              ...(status === "Retur" ? ["Retur"] : []),
            ];
    for (const [n, state] of statuses.entries()) {
      const at = new Date(Date.parse(date) + n * 1000).toISOString();
      const note = {
        Pending: "Pengiriman dibuat dan ditugaskan",
        Proses: "Kurir memulai pengantaran",
        Tertunda: data.issue || "Penerima meminta pengembalian barang",
        Retur: data.resolutionNote,
        Batal: data.cancelReason,
      }[state];
      await db.query(
        "INSERT INTO shipment_events(id,shipment_id,actor_id,data,created_at) VALUES($1,$2,$3,$4,$5)",
        [
          randomUUID(),
          id,
          owner.id,
          {
            status: state,
            note,
            actorEmail: owner.email,
            actorId: owner.id,
            createdAt: at,
          },
          at,
        ],
      );
    }
  }
  return { couriers: users, shipments: recipients.length };
}
