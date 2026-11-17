'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { validateProof, validateCourier } = require('../validation');
const proof = () => ({ shipmentId: 'SHIP1', proof: { receivedBy: 'Penerima', consent: true, note: '', latitude: -5.1, longitude: 119.4, accuracy: 10,
  photos: Object.fromEntries(['receipt','recipient','parcel'].map(slot => [slot, `proofs/kurir1/SHIP1/123456/${slot}.jpg`])) } });
test('proof valid menerima tiga foto dan lokasi', () => { assert.equal(validateProof(proof(), 'kurir1').proof.receivedBy, 'Penerima'); });
test('proof menolak foto kurir lain', () => { assert.throws(() => validateProof(proof(), 'kurir2')); });
test('proof menolak foto pengiriman lain', () => { const p = proof(); p.shipmentId = 'SHIP2'; assert.throws(() => validateProof(p, 'kurir1')); });
test('proof menolak kategori kurang', () => { const p = proof(); delete p.proof.photos.parcel; assert.throws(() => validateProof(p, 'kurir1')); });
test('proof menolak lokasi tidak valid', () => { for (const latitude of [NaN, 100, '5', null]) { const p = proof(); p.proof.latitude = latitude; assert.throws(() => validateProof(p, 'kurir1')); } });
test('proof mewajibkan persetujuan', () => { const p = proof(); p.proof.consent = false; assert.throws(() => validateProof(p, 'kurir1')); });
test('proof menolak path traversal', () => { const p = proof(); p.proof.photos.parcel = 'proofs/kurir1/SHIP1/../parcel.jpg'; assert.throws(() => validateProof(p, 'kurir1')); });
test('proof menghapus field tidak diizinkan dari payload', () => { const p = proof(); p.proof.role = 'admin'; assert.equal(validateProof(p, 'kurir1').proof.role, undefined); });
test('kurir membutuhkan password kuat dan email valid', () => {
  const p = { name: 'Kurir Satu', email: 'KURIR@example.com', phone: '081234567890', password: 'StrongCargo2026' };
  assert.equal(validateCourier(p).email, 'kurir@example.com');
  assert.throws(() => validateCourier({...p, password:'123456'}));
  assert.throws(() => validateCourier({...p, email:'bad'}));
});
