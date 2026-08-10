/// Memilih bagian PDF mana yang diimpor.
///
/// Sebelumnya PDF ditolak bulat-bulat begitu rata-rata hurufnya rendah, dengan
/// satu kalimat "ini hasil pindaian" dan tidak ada jalan keluar. Padahal buku
/// hasil pindaian jarang seragam: sampul dan halaman hak cipta berupa gambar,
/// badannya berteks — atau sebaliknya. Menolak seluruh berkas karena
/// rata-ratanya membuang bagian yang sebenarnya terbaca.
///
/// Layar ini menunjukkan apa yang benar-benar ada di dalam berkasnya, lalu
/// membiarkan user yang memutuskan. Rentang awalnya sudah ditebakkan ke
/// bentangan halaman berteks terpanjang — biasanya itu memang badan bukunya.
library;

import 'package:flutter/material.dart';

import '../core/pdf/pdf_reader.dart';
import '../ui/tokens.dart';

class PilihHalamanPdf extends StatefulWidget {
  final PdfInspection hasil;
  final String namaBerkas;

  const PilihHalamanPdf({
    super.key,
    required this.hasil,
    required this.namaBerkas,
  });

  @override
  State<PilihHalamanPdf> createState() => _PilihHalamanPdfState();
}

class _PilihHalamanPdfState extends State<PilihHalamanPdf> {
  late int _dari;
  late int _sampai;

  @override
  void initState() {
    super.initState();
    final tebakan = widget.hasil.longestTextRun;
    _dari = tebakan?.$1 ?? 1;
    _sampai = tebakan?.$2 ?? widget.hasil.pageCount;
  }

  /// Berapa halaman berteks yang benar-benar masuk dengan rentang ini.
  int get _berteksTerpilih => widget.hasil.textPages
      .where((h) => h >= _dari && h <= _sampai)
      .length;

  int get _gambarTerpilih => widget.hasil.imagePages
      .where((h) => h >= _dari && h <= _sampai)
      .length;

  @override
  Widget build(BuildContext context) {
    final h = widget.hasil;

    return Scaffold(
      appBar: AppBar(title: const Text('Pilih halaman', style: AppType.uiTitleSmall)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
        children: [
          Text(widget.namaBerkas,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.uiTitle.copyWith(color: warna.textPrimary)),
          const SizedBox(height: AppSpacing.space4),

          _Ringkas(hasil: h),

          const SizedBox(height: AppSpacing.space5),
          Text('DARI HALAMAN',
              style: AppType.uiCaption.copyWith(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: warna.textDisabled)),
          _geser(
            key: const Key('pdf-dari'),
            nilai: _dari,
            maks: h.pageCount,
            onChanged: (v) => setState(() {
              _dari = v;
              if (_sampai < _dari) _sampai = _dari;
            }),
          ),
          const SizedBox(height: AppSpacing.space3),
          Text('SAMPAI HALAMAN',
              style: AppType.uiCaption.copyWith(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: warna.textDisabled)),
          _geser(
            key: const Key('pdf-sampai'),
            nilai: _sampai,
            maks: h.pageCount,
            onChanged: (v) => setState(() {
              _sampai = v;
              if (_dari > _sampai) _dari = _sampai;
            }),
          ),

          const SizedBox(height: AppSpacing.space4),
          _PitaHalaman(hasil: h, dari: _dari, sampai: _sampai),

          const SizedBox(height: AppSpacing.space4),
          Text(
            _berteksTerpilih == 0
                ? 'Tidak ada halaman berteks di rentang ini. Geser sampai '
                    'batangnya berwarna.'
                : _gambarTerpilih == 0
                    ? '$_berteksTerpilih halaman siap dibaca.'
                    : '$_berteksTerpilih halaman siap dibaca. '
                        '$_gambarTerpilih halaman berupa gambar dan akan '
                        'dilewati — isinya tidak bisa dibacakan.',
            key: const Key('pdf-ringkasan-pilihan'),
            style: bodyStyle.copyWith(fontSize: 13.5),
          ),

          const SizedBox(height: AppSpacing.space5),
          PrimaryButton(
            'Impor halaman $_dari–$_sampai',
            key: const Key('pdf-impor'),
            onPressed: _berteksTerpilih == 0
                ? null
                : () => Navigator.of(context).pop((_dari, _sampai)),
          ),
          Center(
            child: QuietButton('Batal',
                onPressed: () => Navigator.of(context).pop()),
          ),
        ],
      ),
    );
  }

  Widget _geser({
    required Key key,
    required int nilai,
    required int maks,
    required ValueChanged<int> onChanged,
  }) =>
      Row(
        key: key,
        children: [
          Expanded(
            child: Slider(
              value: nilai.toDouble().clamp(1, maks.toDouble()),
              min: 1,
              max: maks.toDouble(),
              divisions: maks > 1 ? maks - 1 : null,
              activeColor: warna.brandPrimary,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          SizedBox(
            width: 46,
            child: Text('$nilai',
                textAlign: TextAlign.right,
                style: AppType.uiLabel.copyWith(color: warna.textPrimary)),
          ),
        ],
      );
}

class _Ringkas extends StatelessWidget {
  final PdfInspection hasil;
  const _Ringkas({required this.hasil});

  @override
  Widget build(BuildContext context) {
    final teks = hasil.textPages.length;
    final gambar = hasil.imagePages.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warna.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${hasil.pageCount} halaman di berkas ini',
              style: AppType.uiTitleSmall.copyWith(color: warna.textPrimary)),
          const SizedBox(height: 6),
          Text(
            gambar == 0
                ? 'Semuanya berteks.'
                : hasil.fullyScanned
                    ? 'Tidak ada satu pun yang berteks — seluruhnya foto '
                        'halaman. Teksnya memang tidak ada di dalam berkas '
                        'ini, jadi tidak ada yang bisa dibacakan darinya.'
                    : '$teks berteks, $gambar berupa gambar. Halaman gambar '
                        'tidak bisa dibacakan — teksnya memang tidak ada di '
                        'berkasnya, cuma foto halaman.',
            style: bodyStyle.copyWith(fontSize: 13, height: 1.5),
          ),
          if (hasil.fullyScanned) ...[
            const SizedBox(height: 10),
            Text(
              'Jalan keluarnya: foto bukunya langsung lewat "Foto buku '
              'fisik". Kamera membaca hurufnya di perangkat, dan itu justru '
              'yang tidak bisa dilakukan berkas ini.',
              style: bodyStyle.copyWith(fontSize: 13, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pita yang memperlihatkan sebaran halaman berteks di seluruh berkas.
///
/// Angka saja tidak cukup: "32 halaman gambar" bisa berarti sampul depan,
/// bisa juga berarti berselang-seling di sepanjang buku. Bentuknya yang
/// memberi tahu, dan itu yang menentukan rentang mana yang masuk akal.
class _PitaHalaman extends StatelessWidget {
  final PdfInspection hasil;
  final int dari;
  final int sampai;

  const _PitaHalaman({
    required this.hasil,
    required this.dari,
    required this.sampai,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: Row(
        children: [
          for (var i = 1; i <= hasil.pageCount; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.5),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _warna(i),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _warna(int halaman) {
    final terpilih = halaman >= dari && halaman <= sampai;
    final berteks = hasil.textPages.contains(halaman);
    if (!terpilih) return warna.bgSurfaceVariant;
    return berteks ? warna.brandPrimary : warna.statusWarning;
  }
}
