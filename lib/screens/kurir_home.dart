import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'kurir_settings_page.dart';
import 'shipment_detail_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/courier_location_service.dart';

class KurirHome extends StatefulWidget {
  const KurirHome({super.key});

  @override
  State<KurirHome> createState() => _KurirHomeState();
}

class _KurirHomeState extends State<KurirHome> {
  String _searchQuery = '';
  final _locationService = CourierLocationService.instance;

  @override
  void initState() {
    super.initState();
    _locationService.onError = (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui lokasi: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    };
    _resumeTrackingIfNeeded();
  }

  Future<void> _resumeTrackingIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final shipments = await FirebaseFirestore.instance
          .collection('shipments')
          .where('courierId', isEqualTo: user.uid)
          .get();
      final hasActiveShipment = shipments.docs.any(
        (doc) => doc.data()['status'] == 'Proses',
      );

      if (hasActiveShipment) {
        await _locationService.start(
          courierId: user.uid,
          email: user.email ?? '',
        );
      } else {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.data()?['isTracking'] == true) {
          await _locationService.stop(courierId: user.uid);
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memulihkan pelacakan lokasi: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final shipments = await FirebaseFirestore.instance
            .collection('shipments')
            .where('courierId', isEqualTo: user.uid)
            .get();
        final hasActiveShipment = shipments.docs.any(
          (doc) => doc.data()['status'] == 'Proses',
        );
        if (hasActiveShipment) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Selesaikan pengantaran aktif sebelum keluar agar pelacakan tetap berjalan.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tidak dapat memeriksa tugas aktif: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  Future<void> _updateStatus(String docId, String statusBaru) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    var statusDisimpan = false;
    try {
      final update = <String, dynamic>{'status': statusBaru};
      if (statusBaru == 'Proses') {
        update.addAll({
          'courierId': user.uid,
          'courierEmail': user.email,
          'startedAt': FieldValue.serverTimestamp(),
        });
      } else if (statusBaru == 'Selesai') {
        update['completedAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('shipments')
          .doc(docId)
          .update(update);
      statusDisimpan = true;

      final courierRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      if (statusBaru == 'Proses') {
        await courierRef.update({
          'activeShipmentIds': FieldValue.arrayUnion([docId]),
        });
        await _locationService.start(
          courierId: user.uid,
          email: user.email ?? '',
        );
      } else if (statusBaru == 'Selesai') {
        await courierRef.update({
          'activeShipmentIds': FieldValue.arrayRemove([docId]),
        });
        final shipments = await FirebaseFirestore.instance
            .collection('shipments')
            .where('courierId', isEqualTo: user.uid)
            .get();
        final hasActiveShipment = shipments.docs.any(
          (doc) => doc.data()['status'] == 'Proses',
        );
        if (!hasActiveShipment) {
          await _locationService.stop(courierId: user.uid);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status berhasil diubah menjadi $statusBaru'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            statusDisimpan
                ? 'Status tersimpan, tetapi pelacakan gagal diperbarui: $e'
                : 'Gagal memperbarui status: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Dashboard Kurir Haryata',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
            tooltip: 'Keluar',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Pengaturan Profil Kurir (Tombol Cepat)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const KurirSettingsPage(),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.manage_accounts, size: 48, color: Colors.white),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profil & Pengaturan Akun',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Ketuk di sini untuk melihat info akun & tentang aplikasi.',
                          style: TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white70,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          // Kolom Pencarian Tugas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase().trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Cari resi atau nama penerima tugas...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF2563EB)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Daftar Tugas Pengiriman',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // StreamBuilder Daftar Tugas
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('shipments')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Colors.blue.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Belum ada tugas pengiriman masuk.',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final resi = (data['resi'] ?? '').toString().toLowerCase();
                  final penerima = (data['penerima'] ?? '')
                      .toString()
                      .toLowerCase();
                  return resi.contains(_searchQuery) ||
                      penerima.contains(_searchQuery);
                }).toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Tugas tidak ditemukan.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final docId = docs[index].id;
                    final data = docs[index].data() as Map<String, dynamic>;
                    final resi = data['resi'] ?? 'Tanpa Resi';
                    final penerima = data['penerima'] ?? 'Tanpa Nama';
                    final alamat = data['alamat'] ?? 'Tanpa Alamat';
                    final status = data['status'] ?? 'Pending';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.qr_code,
                                    size: 20,
                                    color: Color(0xFF2563EB),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    resi,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: status == 'Pending'
                                      ? Colors.orange.withValues(alpha: 0.1)
                                      : (status == 'Proses'
                                            ? Colors.blue.withValues(alpha: 0.1)
                                            : Colors.green.withValues(alpha: 0.1)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: status == 'Pending'
                                        ? Colors.orange[800]
                                        : (status == 'Proses'
                                              ? Colors.blue[700]
                                              : Colors.green[700]),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Text(
                            'Penerima: $penerima',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Alamat: $alamat',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ShipmentDetailPage(
                                        docId: docId,
                                        shipmentData: data,
                                      ),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1E3A8A),
                                  side: const BorderSide(
                                    color: Color(0xFF1E3A8A),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Detail'),
                              ),
                              OutlinedButton(
                                onPressed: () => _updateStatus(docId, 'Proses'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blue[700],
                                  side: const BorderSide(color: Colors.blue),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Proses'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () =>
                                    _updateStatus(docId, 'Selesai'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text('Selesai'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
