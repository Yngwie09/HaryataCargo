String normalizeResi(String value) => value.trim().toUpperCase();
const shipmentStatuses = [
  'Pending',
  'Proses',
  'Tertunda',
  'Selesai',
  'Retur',
  'Batal',
];
bool validResi(String value) => RegExp(r'^[A-Z0-9-]{4,40}$').hasMatch(value);
bool canTransition(String from, String to) =>
    (from == 'Pending' && (to == 'Proses' || to == 'Batal')) ||
    (from == 'Proses' && (to == 'Selesai' || to == 'Tertunda')) ||
    (from == 'Tertunda' && (to == 'Pending' || to == 'Retur'));
const proofLabels = <String, String>{
  'receipt': 'Foto tanda terima',
  'recipient': 'Foto penerima',
  'parcel': 'Foto barang',
};
bool completeProof(Map<String, dynamic> proof) => proofLabels.keys.every(
  (key) => proof[key] is String && (proof[key] as String).isNotEmpty,
);
