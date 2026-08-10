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
import '../ui/ragu_controller.dart';
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
  RaguController? _teks;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pages = List.of(widget.pages);
    _title = TextEditingController(text: 'Buku hasil foto');
    _pasangTeks();
  }

  /// Satu controller per halaman, dibuat ulang saat halamannya berganti.
  /// Sebelumnya ia dibuat di dalam `build`, jadi kursornya melompat ke awal
  /// tiap kali layar digambar ulang — tidak mungkin mengetik lebih dari
  /// sepatah kata.
  void _pasangTeks() {
    _teks?.dispose();
    final h = _pages[_index];
    _teks = RaguController(text: h.text, keyakinan: h.keyakinan)
      ..addListener(_teksBerubah);
  }

  void _teksBerubah() {
    final baru = _teks!.text;
    if (_pages[_index].text == baru) return;
    // setState supaya hitungan kata ragu di bawah ikut turun saat diperbaiki.
    setState(() => _pages[_index] = _pages[_index].copyWith(text: baru));
  }

  void _keHalaman(int i) {
    setState(() {
      _index = i;
      _pasangTeks();
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _teks?.dispose();
    super.dispose();
  }

  void _hapus() {
    if (_pages.length <= 1) return;
    setState(() {
      _pages.removeAt(_index);
      if (_index >= _pages.length) _index = _pages.length - 1;
      _pasangTeks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_index];
    final teks = _teks!;
    final ragu = teks.ragu.length;

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
            key: ValueKey('teks-$_index-${page.imagePath}'),
            controller: teks,
            maxLines: null,
            minLines: 6,
            style: AppType.uiBody.copyWith(color: warna.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Teks yang terbaca',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),

          // Yang ragu adalah KAMI, bukan katanya yang pasti salah. OCR yang
          // mengaku ragu masih bisa dipercaya; OCR yang berpura-pura yakin
          // tidak.
          if (ragu > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                key: const Key('scan-ragu'),
                children: [
                  Icon(Icons.error_outline,
                      size: 15, color: warna.statusWarning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Ada $ragu kata yang kami ragukan — ketuk untuk '
                      'memperbaiki',
                      style: AppType.uiCaption
                          .copyWith(color: warna.statusWarning),
                    ),
                  ),
                ],
              ),
            ),

          if (page.text.trim().isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Halaman ini tidak terbaca. Ketik sendiri, atau buang saja.',
                // Bersama penanda kata yang diragukan di atas, layar ini
                // satu-satunya tempat di seluruh app warna dipakai untuk
                // memberi arti. Di mana pun selain di sini, warna cuma rupa.
                style: AppType.uiCaption.copyWith(color: warna.statusWarning),
              ),
            ),

          const SizedBox(height: 18),
          Row(
            children: [
              IconButton(
                key: const Key('scan-prev'),
                onPressed: _index > 0 ? () => _keHalaman(_index - 1) : null,
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
                    ? () => _keHalaman(_index + 1)
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
