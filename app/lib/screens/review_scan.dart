/// Layar tinjau hasil foto.
///
/// OCR tidak akan pernah 100% benar. Layar ini pengakuan jujur atas itu:
/// user bisa membandingkan foto aslinya dengan teks hasil bacaan, memperbaiki
/// yang meleset, dan membuang halaman yang gagal — bukan disuruh percaya lalu
/// baru sadar salah setelah mendengarnya dibacakan.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/scan/page_scanner.dart';
import '../ui/tokens.dart';

class ReviewScanPage extends StatefulWidget {
  final AppState state;
  final List<ScannedPage> pages;
  final void Function(List<ScannedPage> pages, String title) onDone;

  const ReviewScanPage({
    super.key,
    required this.state,
    required this.pages,
    required this.onDone,
  });

  @override
  State<ReviewScanPage> createState() => _ReviewScanPageState();
}

class _ReviewScanPageState extends State<ReviewScanPage> {
  late List<ScannedPage> _pages;
  late final TextEditingController _title;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pages = List.of(widget.pages);
    _title = TextEditingController(text: 'Buku hasil foto');
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _hapus() {
    if (_pages.length <= 1) return;
    setState(() {
      _pages.removeAt(_index);
      if (_index >= _pages.length) _index = _pages.length - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_index];
    // Kunci yang berubah mengikuti halaman memaksa kotak teks memuat ulang
    // isinya saat berpindah — tanpa itu teks halaman lama ikut terbawa.
    final key = ValueKey('teks-$_index-${page.imagePath}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Periksa hasil foto', style: AppType.uiTitleSmall),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('${_index + 1} dari ${_pages.length}',
                  style: AppType.uiCaption
                      .copyWith(color: warna.textSecondary)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          TextField(
            key: const Key('scan-title'),
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Judul buku',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),

          // Foto aslinya. Tanpa ini user tidak punya cara memeriksa apakah
          // teks di bawahnya benar.
          if (File(page.imagePath).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(page.imagePath),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 14),

          TextField(
            key: key,
            controller: TextEditingController(text: page.text),
            onChanged: (v) => _pages[_index] = page.copyWith(text: v),
            maxLines: null,
            minLines: 6,
            style: AppType.uiBody.copyWith(color: warna.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Teks yang terbaca',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),

          if (page.text.trim().isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Halaman ini tidak terbaca. Ketik sendiri, atau buang saja.',
                // Bersama penandaan kata yang diragukan OCR (belum ada), ini
                // satu-satunya tempat di seluruh app warna dipakai untuk
                // memberi arti — di mana pun selain di sini, warna cuma rupa.
                style: AppType.uiCaption.copyWith(color: warna.statusWarning),
              ),
            ),

          const SizedBox(height: 18),
          Row(
            children: [
              IconButton(
                key: const Key('scan-prev'),
                onPressed:
                    _index > 0 ? () => setState(() => _index--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              const Spacer(),
              TextButton.icon(
                key: const Key('scan-delete'),
                onPressed: _pages.length > 1 ? _hapus : null,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Buang halaman ini'),
                style:
                    TextButton.styleFrom(foregroundColor: warna.brandPrimary),
              ),
              const Spacer(),
              IconButton(
                key: const Key('scan-next'),
                onPressed: _index < _pages.length - 1
                    ? () => setState(() => _index++)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),

          const SizedBox(height: 20),
          PrimaryButton(
            'Lanjut',
            key: const Key('scan-done'),
            onPressed: () => widget.onDone(_pages, _title.text),
          ),
        ],
      ),
    );
  }
}
