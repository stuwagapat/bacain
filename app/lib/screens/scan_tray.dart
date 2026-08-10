/// Halaman yang sudah terkumpul, ditampilkan **sebelum** OCR jalan.
///
/// Ini layar pertama setelah kembali dari pemindai bawaan Google, dan tugas
/// pertamanya adalah memulihkan rasa "aku masih di dalam Bacain" — pemindai
/// itu tampilannya milik Google sepenuhnya.
///
/// Tugas keduanya lebih penting: **menandai halaman buram di sini, saat
/// memfoto ulang masih murah.** Kalau baru ketahuan di layar tinjau, bukunya
/// mungkin sudah ditutup dan dikembalikan ke rak, dan yang tersisa cuma
/// pilihan membetulkan teks kacau dengan mengetik.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../core/scan/page_scanner.dart';
import '../ui/tokens.dart';

class ScanTrayPage extends StatefulWidget {
  final List<ScannedPage> pages;

  /// Membuka pemindai lagi untuk menambah atau mengganti halaman.
  final Future<List<ScannedPage>> Function() onScanMore;

  const ScanTrayPage({
    super.key,
    required this.pages,
    required this.onScanMore,
  });

  @override
  State<ScanTrayPage> createState() => _ScanTrayPageState();
}

class _ScanTrayPageState extends State<ScanTrayPage> {
  late List<ScannedPage> _pages;

  @override
  void initState() {
    super.initState();
    _pages = List.of(widget.pages);
  }

  /// Halaman yang hampir tidak menghasilkan teks. Ambangnya sengaja rendah:
  /// menuduh halaman bagus sebagai buram membuat user memfoto ulang
  /// percuma, dan itu lebih menjengkelkan daripada melewatkan satu halaman.
  static const _ambangBuram = 40;

  List<int> get _buram => [
        for (var i = 0; i < _pages.length; i++)
          if (_pages[i].text.trim().length < _ambangBuram) i
      ];

  Future<void> _tambah() async {
    final baru = await widget.onScanMore();
    if (baru.isEmpty || !mounted) return;
    setState(() => _pages.addAll(baru));
  }

  void _buang(int i) {
    setState(() => _pages.removeAt(i));
  }

  void _pindah(int dari, int ke) {
    setState(() {
      if (ke > dari) ke -= 1;
      _pages.insert(ke, _pages.removeAt(dari));
    });
  }

  @override
  Widget build(BuildContext context) {
    final buram = _buram;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_pages.length} halaman', style: AppType.uiTitleSmall),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _pages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Semua halaman sudah dibuang. Foto lagi, atau '
                          'kembali dan pilih berkas.',
                          textAlign: TextAlign.center,
                          style: bodyStyle,
                        ),
                      ),
                    )
                  : ReorderableGridSempit(
                      onReorder: _pindah,
                      children: [
                        for (var i = 0; i < _pages.length; i++)
                          _Halaman(
                            key: ValueKey(_pages[i].imagePath),
                            nomor: i + 1,
                            page: _pages[i],
                            buram: buram.contains(i),
                            onBuang: () => _buang(i),
                          ),
                      ],
                    ),
            ),

            if (buram.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Row(
                  key: const Key('tray-buram'),
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 16, color: warna.statusWarning),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        buram.length == 1
                            ? 'Halaman ${buram.single + 1} hampir tidak '
                                'terbaca — buang dan foto ulang sekarang, '
                                'selagi bukunya masih terbuka.'
                            : '${buram.length} halaman hampir tidak terbaca — '
                                'buang dan foto ulang sekarang, selagi '
                                'bukunya masih terbuka.',
                        style: AppType.uiCaption
                            .copyWith(color: warna.statusWarning, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text('Tekan lama untuk mengubah urutan.',
                  style: AppType.uiCaption.copyWith(color: warna.textDisabled)),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                children: [
                  PrimaryButton(
                    _pages.isEmpty
                        ? 'Foto halaman'
                        : 'Proses ${_pages.length} halaman',
                    key: const Key('tray-process'),
                    onPressed: _pages.isEmpty
                        ? _tambah
                        : () => Navigator.of(context).pop(_pages),
                  ),
                  if (_pages.isNotEmpty)
                    Center(
                      child: QuietButton('Foto halaman lagi',
                          key: const Key('tray-more'), onPressed: _tambah),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu petak halaman: gambarnya, nomornya, dan penanda buram.
class _Halaman extends StatelessWidget {
  final int nomor;
  final ScannedPage page;
  final bool buram;
  final VoidCallback onBuang;

  const _Halaman({
    super.key,
    required this.nomor,
    required this.page,
    required this.buram,
    required this.onBuang,
  });

  @override
  Widget build(BuildContext context) {
    final berkas = File(page.imagePath);
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm + 1),
            child: Container(
              color: warna.bgSurfaceVariant,
              child: berkas.existsSync()
                  ? Image.file(berkas,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink())
                  : Center(
                      child: Icon(Icons.description_outlined,
                          color: warna.textDisabled, size: 22),
                    ),
            ),
          ),
        ),

        // Nomor urut: satu-satunya cara mengetahui halaman mana yang dimaksud
        // peringatan di bawah.
        Positioned(
          left: 5,
          bottom: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: warna.textPrimary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('$nomor',
                style: AppType.uiCaption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: warna.bgBase)),
          ),
        ),

        if (buram)
          Positioned(
            right: 5,
            top: 5,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: warna.statusWarning,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Icon(Icons.priority_high,
                  size: 12, color: warna.brandOnPrimary),
            ),
          ),

        Positioned(
          right: 1,
          bottom: 1,
          child: IconButton(
            key: Key('tray-buang-$nomor'),
            tooltip: 'Buang halaman $nomor',
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            icon: Icon(Icons.close, color: warna.textPrimary),
            onPressed: onBuang,
          ),
        ),
      ],
    );
  }
}

/// Grid tiga kolom yang bisa diurut ulang dengan tekan lama.
///
/// `ReorderableListView` bawaan Flutter cuma satu kolom, dan menariknya ke
/// dalam grid butuh paket tambahan. Tiga kolom di 360 dp adalah yang paling
/// padat yang masih memberi thumbnail cukup besar untuk menilai buram atau
/// tidak — dan menilai itulah gunanya layar ini.
class ReorderableGridSempit extends StatelessWidget {
  final List<Widget> children;
  final void Function(int dari, int ke) onReorder;

  const ReorderableGridSempit({
    super.key,
    required this.children,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 9,
        crossAxisSpacing: 9,
        childAspectRatio: 3 / 4,
      ),
      itemCount: children.length,
      itemBuilder: (context, i) => LongPressDraggable<int>(
        data: i,
        feedback: Opacity(
          opacity: .85,
          child: SizedBox(width: 96, height: 128, child: children[i]),
        ),
        childWhenDragging: Opacity(opacity: .25, child: children[i]),
        child: DragTarget<int>(
          onAcceptWithDetails: (d) => onReorder(d.data, i),
          builder: (context, kandidat, _) => DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm + 1),
              border: kandidat.isEmpty
                  ? null
                  : Border.all(color: warna.brandPrimary, width: 2),
            ),
            child: children[i],
          ),
        ),
      ),
    );
  }
}
