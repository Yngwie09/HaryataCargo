import '../services/backend_client.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ProofPhoto extends StatefulWidget {
  const ProofPhoto({super.key, required this.path, required this.label});
  final String path, label;
  @override
  State<ProofPhoto> createState() => _ProofPhotoState();
}

class _ProofPhotoState extends State<ProofPhoto> {
  late Future<Uint8List?> _image;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _image = _download();
  }

  Future<Uint8List> _download() async {
    final bytes = await CargoFiles.instance
        .ref(widget.path)
        .getData(5 * 1024 * 1024);
    if (bytes == null || bytes.isEmpty) throw StateError('Foto belum tersedia');
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1600);
    try {
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } finally {
      codec.dispose();
    }
    return bytes;
  }

  @override
  void didUpdateWidget(ProofPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _load();
  }

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            widget.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        FutureBuilder<Uint8List?>(
          future: _image,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return SizedBox(
                height: 160,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.image_not_supported_outlined),
                        const SizedBox(height: 8),
                        const Text(
                          'Foto belum dapat ditampilkan',
                          textAlign: TextAlign.center,
                        ),
                        TextButton.icon(
                          onPressed: () => setState(_load),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Semantics(
              label: 'Perbesar ${widget.label}',
              button: true,
              child: InkWell(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => Dialog.fullscreen(
                    child: Scaffold(
                      appBar: AppBar(title: Text(widget.label)),
                      body: Center(
                        child: InteractiveViewer(
                          minScale: .5,
                          maxScale: 5,
                          child: Image.memory(snapshot.data!),
                        ),
                      ),
                    ),
                  ),
                ),
                child: Image.memory(
                  snapshot.data!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  cacheWidth: 1200,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 180,
                    child: Center(child: Text('Foto tidak dapat dibaca')),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}
