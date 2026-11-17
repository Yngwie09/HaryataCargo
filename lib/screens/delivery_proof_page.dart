import 'dart:ui' as ui;
import '../services/backend_client.dart';
import 'dart:async';
import '../services/drafts/draft_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/ui.dart';
import '../core/shipment_policy.dart';
import '../services/shipment_service.dart';
import '../services/courier_location_service.dart';

class DeliveryProofPage extends StatefulWidget {
  const DeliveryProofPage({
    super.key,
    required this.shipmentId,
    required this.resi,
    this.preview = false,
  });
  final String shipmentId, resi;
  final bool preview;
  @override
  State<DeliveryProofPage> createState() => _DeliveryProofPageState();
}

class _DeliveryProofPageState extends State<DeliveryProofPage>
    with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  final _recipient = TextEditingController(), _note = TextEditingController();
  final _photos = <String, Uint8List>{};
  final _uploadedPaths = <String, String>{};
  bool _busy = false,
      _consent = false,
      _restoring = false,
      _picking = false,
      _finished = false;
  String? _uid, _draftError;
  Timer? _saveTimer;
  String _draftStatus = 'Draft tersimpan otomatis di perangkat';
  double _progress = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!widget.preview) {
      _uid = CargoAuth.instance.currentUser?.uid;
      _restoring = true;
      _restoreDraft();
    }
  }

  Map<String, dynamic> _fields() => {
    'receivedBy': _recipient.text,
    'note': _note.text,
    'consent': _consent,
    'uploadedPaths': Map<String, String>.from(_uploadedPaths),
    'savedAt': DateTime.now().toIso8601String(),
  };
  Future<void> _persistFields() async {
    if (_uid == null || widget.preview || _finished) return;
    final fields = _fields();
    try {
      await deliveryDraftStore.saveFields(_uid!, widget.shipmentId, fields);
      if (mounted) {
        setState(() {
          _draftError = null;
          _draftStatus = 'Draft tersimpan di perangkat';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _draftError =
              'Draft belum tersimpan. Periksa ruang penyimpanan perangkat.',
        );
      }
    }
  }

  void _scheduleSave() {
    if (_restoring || _finished || widget.preview) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _persistFields);
  }

  Future<void> _restoreDraft() async {
    try {
      if (_uid == null) return;
      final draft = await deliveryDraftStore.read(_uid!, widget.shipmentId);
      if (!mounted) return;
      _recipient.text = draft.fields['receivedBy'] as String? ?? '';
      _note.text = draft.fields['note'] as String? ?? '';
      _consent = draft.fields['consent'] == true;
      _photos.addAll(draft.photos);
      final paths = draft.fields['uploadedPaths'];
      if (paths is Map) {
        for (final key in proofLabels.keys) {
          if (paths[key] is String && _photos.containsKey(key)) {
            _uploadedPaths[key] = paths[key] as String;
          }
        }
      }
      _draftStatus = draft.photos.isNotEmpty
          ? 'Draft dipulihkan: ${draft.photos.length} foto tersedia'
          : 'Draft tersimpan otomatis di perangkat';
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString('photoUid') == _uid &&
            prefs.getString('photoShipment') == widget.shipmentId) {
          final slot = prefs.getString('photoSlot');
          final response = await ImagePicker().retrieveLostData();
          if (slot != null &&
              proofLabels.containsKey(slot) &&
              response.files?.isNotEmpty == true) {
            await _accept(slot, response.files!.first);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _draftError =
            'Sebagian draft belum dapat dipulihkan. Tambahkan kembali foto yang belum tampil.';
      }
    } finally {
      if (mounted) {
        setState(() => _restoring = false);
        _recipient.addListener(_scheduleSave);
        _note.addListener(_scheduleSave);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    if (!_restoring && !_finished) _persistFields();
    _recipient.removeListener(_scheduleSave);
    _note.removeListener(_scheduleSave);
    _recipient.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_restoring && !_finished && state != AppLifecycleState.resumed) {
      _saveTimer?.cancel();
      _persistFields();
    }
  }

  Future<void> _accept(String key, XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      throw StateError(
        'Ukuran foto maksimal 5 MB. Ambil ulang dengan resolusi lebih rendah.',
      );
    }
    if (bytes.length < 4 ||
        !((bytes[0] == 0xff && bytes[1] == 0xd8) ||
            (bytes[0] == 0x89 && bytes[1] == 0x50))) {
      throw StateError('Gunakan foto JPG atau PNG.');
    }
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1600);
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
    } catch (_) {
      throw StateError(
        'Foto tidak dapat dibaca. Pilih atau ambil foto kembali.',
      );
    }
    if (!mounted || _uid == null) return;
    _uploadedPaths.remove(key);
    await _persistFields();
    if (_draftError != null) throw StateError(_draftError!);
    await deliveryDraftStore.savePhoto(_uid!, widget.shipmentId, key, bytes);
    if (mounted) {
      setState(() {
        _photos[key] = bytes;
        _uploadedPaths.remove(key);
      });
    }
  }

  Future<void> _pick(String key) async {
    if (_picking) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Ambil foto dengan kamera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _picking = true);
    try {
      _saveTimer?.cancel();
      await _persistFields();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('photoUid', _uid!);
      await prefs.setString('photoShipment', widget.shipmentId);
      await prefs.setString('photoSlot', key);
      if (!mounted) return;
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
        requestFullMetadata: false,
      );
      if (file != null) await _accept(key, file);
    } catch (e) {
      if (mounted) notify(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_consent || !proofLabels.keys.every(_photos.containsKey)) {
      notify(
        context,
        'Lengkapi ketiga foto dan konfirmasi penyerahan barang.',
        error: true,
      );
      return;
    }
    if (!await confirm(
      context,
      'Selesaikan pengiriman?',
      'Pastikan barang telah diterima. Bukti serah terima yang disimpan tidak dapat diubah.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      _saveTimer?.cancel();
      await _persistFields();
      final position = await CourierLocationService.instance.checkLocation();
      final uid = ShipmentService.user.uid;
      final batch = DateTime.now().microsecondsSinceEpoch.toString();
      final paths = <String, String>{};
      var done = 0;
      for (final entry in _photos.entries) {
        if (_uploadedPaths.containsKey(entry.key)) {
          paths[entry.key] = _uploadedPaths[entry.key]!;
          done++;
          if (mounted) setState(() => _progress = done / 3);
          continue;
        }
        final png = entry.value[0] == 0x89;
        final path =
            'proofs/$uid/${widget.shipmentId}/$batch/${entry.key}.${png ? 'png' : 'jpg'}';
        await CargoFiles.instance
            .ref(path)
            .putData(
              entry.value,
              UploadMetadata(contentType: png ? 'image/png' : 'image/jpeg'),
            );
        paths[entry.key] = path;
        _uploadedPaths[entry.key] = path;
        await _persistFields();
        done++;
        if (mounted) setState(() => _progress = done / 3);
      }
      await ShipmentService.transition(
        widget.shipmentId,
        'Selesai',
        proof: {
          'photos': paths,
          'receivedBy': _recipient.text.trim(),
          'note': _note.text.trim(),
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'consent': true,
        },
      );
      _finished = true;
      _saveTimer?.cancel();
      try {
        if (_uid != null) {
          await deliveryDraftStore.clear(_uid!, widget.shipmentId);
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('photoUid');
        await prefs.remove('photoShipment');
        await prefs.remove('photoSlot');
      } catch (_) {
        /* Server completion succeeded; local cleanup must not report delivery failure. */
      }
      if (mounted) {
        notify(
          context,
          'Pengiriman selesai. Bukti serah terima berhasil disimpan.',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) notify(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && !_picking && !_restoring,
    child: Scaffold(
      appBar: AppBar(title: const Text('Bukti serah terima')),
      body: PageBody(
        width: 760,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.resi,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Lengkapi nama penerima serta foto tanda terima, penerima, dan barang. Draft pada Android disimpan otomatis agar dapat dilanjutkan.',
              ),
              const SizedBox(height: 12),
              if (!widget.preview) ...[
                if (_restoring) const LinearProgressIndicator(),
                Text(
                  _draftError ?? _draftStatus,
                  style: TextStyle(
                    color: _draftError == null ? accent : Colors.deepOrange,
                    fontSize: 12,
                  ),
                ),
                if (kIsWeb)
                  const Text(
                    'Pada browser, tambahkan kembali foto setelah halaman dimuat ulang.',
                    style: TextStyle(fontSize: 12),
                  ),
              ],
              const SizedBox(height: 24),
              TextFormField(
                controller: _recipient,
                enabled: !_busy && !_restoring && !_picking && !widget.preview,
                decoration: const InputDecoration(
                  labelText: 'Nama orang yang menerima barang',
                ),
                maxLength: 120,
                validator: (v) => (v?.trim().length ?? 0) < 2
                    ? 'Nama penerima minimal 2 karakter'
                    : null,
              ),
              const SizedBox(height: 16),
              ...proofLabels.entries.map(
                (entry) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          entry.value,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        if (_photos.containsKey(entry.key))
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _photos[entry.key]!,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed:
                              _busy || _restoring || _picking || widget.preview
                              ? null
                              : () => _pick(entry.key),
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: Text(
                            _photos.containsKey(entry.key)
                                ? 'Ganti foto'
                                : 'Tambahkan foto',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _note,
                enabled: !_busy && !widget.preview,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Catatan serah terima (opsional)',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _consent,
                onChanged: _busy || _restoring || _picking || widget.preview
                    ? null
                    : (v) {
                        setState(() => _consent = v ?? false);
                        _scheduleSave();
                      },
                title: const Text(
                  'Saya telah menyerahkan barang dan memeriksa ketiga foto bukti.',
                ),
              ),
              if (_busy)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      LinearProgressIndicator(value: _progress),
                      const SizedBox(height: 8),
                      Text('Mengunggah bukti… ${(_progress * 100).round()}%'),
                    ],
                  ),
                ),
              FilledButton.icon(
                onPressed: _busy || _restoring || _picking || widget.preview
                    ? null
                    : _submit,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Simpan & selesaikan pengiriman'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}
