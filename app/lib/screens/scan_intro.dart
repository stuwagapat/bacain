/// Panduan sebelum kamera pertama kali dibuka. Muncul **sekali saja**.
///
/// Layar ini memikul beban terberat dari jalan tengah yang dipilih: kamera
/// yang dipakai adalah pemindai bawaan Google, dan pemindai itu tidak bisa
/// kita beri panduan apa pun. Jadi semua yang perlu diketahui user harus
/// disampaikan di sini, sebelum ia masuk.
///
/// Yang ketiga paling penting: **potretnya otomatis.** Tanpa diberi tahu,
/// user akan menekan tombol rana berkali-kali dan menghasilkan halaman
/// kembar yang harus dibuang satu per satu nanti.
library;

import 'package:flutter/material.dart';

import '../ui/tokens.dart';

class ScanIntroPage extends StatelessWidget {
  const ScanIntroPage({super.key});

  static const _panduan = [
    (
      Icons.table_restaurant_outlined,
      'Letakkan di permukaan datar',
      'Meja atau lantai. Buku yang dipegang cenderung goyang, dan goyang '
          'sedikit saja sudah cukup membuat hurufnya kabur.',
    ),
    (
      Icons.crop_free,
      'Pastikan seluruh halaman masuk',
      'Bingkai akan menyala saat halaman terbaca penuh. Sudut yang terpotong '
          'berarti kalimat yang hilang.',
    ),
    (
      Icons.auto_awesome_outlined,
      'Kami potret otomatis',
      'Begitu gambarnya diam sebentar. Tombolnya tetap ada kalau kamu mau '
          'memotret sendiri.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('scan-intro-close'),
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 8, 26, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 24),
                    Text('Foto halamannya satu per satu.',
                        key: const Key('scan-intro-title'),
                        style: AppType.uiDisplay
                            .copyWith(color: warna.textPrimary)),
                    const SizedBox(height: 12),
                    Text(
                      'Tidak perlu buru-buru — kamu bisa berhenti dan lanjut '
                      'lagi kapan saja. Satu bab saja sudah cukup untuk jatah '
                      'dengar beberapa hari.',
                      style: bodyStyle,
                    ),
                    const SizedBox(height: 32),
                    for (final (ikon, judul, isi) in _panduan)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: warna.bgSurfaceVariant,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm + 5),
                              ),
                              child: Icon(ikon,
                                  size: 20, color: warna.textPrimary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(judul,
                                      style: AppType.uiTitleSmall
                                          .copyWith(color: warna.textPrimary)),
                                  const SizedBox(height: 3),
                                  Text(isi,
                                      style: bodyStyle.copyWith(
                                          fontSize: 13, height: 1.5)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              PrimaryButton(
                'Mulai memotret',
                key: const Key('scan-intro-start'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
              Center(
                child: QuietButton(
                  'Nanti saja',
                  key: const Key('scan-intro-later'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
