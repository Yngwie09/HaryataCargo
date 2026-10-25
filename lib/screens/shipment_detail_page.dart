import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShipmentDetailPage extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> shipmentData;

  const ShipmentDetailPage({
    super.key,
    required this.docId,
    required this.shipmentData,
  });

  @override
  Widget build(BuildContext context) {
    final resi = shipmentData['resi'] ?? 'Tanpa Resi';
    final penerima = shipmentData['penerima'] ?? 'Tanpa Nama';
    final alamat = shipmentData['alamat'] ?? 'Tanpa Alamat';
    final status = shipmentData['status'] ?? 'Pending';
    final timestamp = shipmentData['createdAt'];

    // Format tanggal jika tersedia
    String tanggalBuat = 'Baru saja';
    if (timestamp != null && timestamp is Timestamp) {
      DateTime dt = timestamp.toDate();
      tanggalBuat = '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Detail Resi: $resi', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.blue.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Status Pengiriman', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: status == 'Pending' 
                              ? Colors.orange[800] 
                              : (status == 'Proses' ? Colors.blue[700] : Colors.green[700]),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_shipping, color: Color(0xFF1E3A8A), size: 28),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Informasi Utama Pengiriman
            const Text(
              'Informasi Kargo & Penerima',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.blue.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                children: [
                  _buildInfoRow(Icons.qr_code, 'Nomor Resi', resi),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.person, 'Nama Penerima', penerima),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.location_on, 'Alamat Tujuan', alamat),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.access_time, 'Waktu Dibuat', tanggalBuat),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Catatan Skripsi / Sistem
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF1E3A8A)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Data ini tersinkronisasi secara real-time melalui Firebase Firestore untuk peran Admin & Kurir.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1E3A8A)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF1E293B))),
            ],
          ),
        ),
      ],
    );
  }
}