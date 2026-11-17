"use strict";
function validateCourier(data) {
  if (
    !data ||
    typeof data.name !== "string" ||
    data.name.trim().length < 2 ||
    data.name.length > 120
  )
    throw new Error("Nama kurir tidak valid.");
  if (
    typeof data.email !== "string" ||
    data.email.length > 254 ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.email.trim())
  )
    throw new Error("Email tidak valid.");
  if (
    typeof data.phone !== "string" ||
    !/^\+?[0-9 ()-]{8,20}$/.test(data.phone.trim())
  )
    throw new Error("Telepon tidak valid.");
  if (
    typeof data.password !== "string" ||
    data.password.length === 0 ||
    data.password.length > 4096
  )
    throw new Error("Isi kata sandi.");
  return {
    name: data.name.trim(),
    email: data.email.trim().toLowerCase(),
    phone: data.phone.trim(),
    password: data.password,
  };
}
function validateProof(data, uid) {
  const id = data?.shipmentId,
    p = data?.proof;
  if (typeof id !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(id))
    throw new Error("ID pengiriman tidak valid.");
  if (
    !p ||
    typeof p.receivedBy !== "string" ||
    p.receivedBy.trim().length < 2 ||
    p.receivedBy.length > 120 ||
    p.consent !== true
  )
    throw new Error("Nama dan persetujuan penerima wajib diisi.");
  if (typeof p.note !== "string" || p.note.length > 1000)
    throw new Error("Catatan maksimal 1.000 karakter.");
  if (
    !Number.isFinite(p.latitude) ||
    p.latitude < -90 ||
    p.latitude > 90 ||
    !Number.isFinite(p.longitude) ||
    p.longitude < -180 ||
    p.longitude > 180 ||
    !Number.isFinite(p.accuracy) ||
    p.accuracy < 0
  )
    throw new Error("Lokasi serah terima tidak valid.");
  const photos = {};
  const escape = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  for (const slot of ["receipt", "recipient", "parcel"]) {
    const path = p.photos?.[slot];
    if (
      typeof path !== "string" ||
      !new RegExp(
        `^proofs/${escape(uid)}/${escape(id)}/[0-9]+/${slot}\\.(jpg|png)$`,
      ).test(path)
    )
      throw new Error(
        "Ketiga foto wajib berasal dari pengiriman dan kurir yang sama.",
      );
    photos[slot] = path;
  }
  return {
    shipmentId: id,
    proof: {
      receivedBy: p.receivedBy.trim(),
      note: p.note.trim(),
      consent: true,
      latitude: p.latitude,
      longitude: p.longitude,
      accuracy: p.accuracy,
      photos,
    },
  };
}
module.exports = { validateProof, validateCourier };
