/// Membatasi app ke lebar HP saat jendelanya jauh lebih lebar dari HP.
///
/// Ada karena prototipe web ini tugasnya **mewakili APK**, bukan jadi app
/// desktop. Dibiarkan melar selebar laptop, tata letaknya bukan lagi tata
/// letak yang akan dilihat orang: baris jadi terlalu panjang untuk dibaca,
/// kartu LANJUTKAN membentang aneh, dan rak dua kolom terlihat renggang.
/// Yang dinilai jadi bukan yang dikirim.
///
/// Di HP sungguhan ini tidak pernah aktif — jendelanya memang sudah sempit,
/// jadi APK-nya tidak terpengaruh sama sekali.
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

class BingkaiPonsel extends StatelessWidget {
  final Widget child;
  const BingkaiPonsel({super.key, required this.child});

  /// Artboard yang dipakai desain: 390 × 844 dp.
  static const lebar = 390.0;
  static const tinggi = 844.0;

  /// Di bawah ini, jendelanya memang sudah selebar HP — biarkan apa adanya.
  /// Ambangnya diberi jarak dari 390 supaya jendela yang cuma sedikit lebih
  /// lebar tidak tiba-tiba mendapat bingkai dan pinggiran kosong.
  static const ambang = 520.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth <= ambang) return child;

        final t = c.maxHeight < tinggi ? c.maxHeight : tinggi;
        final media = MediaQuery.of(context);

        return ColoredBox(
          color: warna.bgSurfaceVariant,
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: SizedBox(
                width: lebar,
                height: t,
                // MediaQuery ikut dipersempit, bukan cuma kotaknya. Tanpa ini
                // apa pun yang bertanya "selebar apa layarnya" akan dijawab
                // dengan lebar jendela laptop, dan jawabannya salah.
                child: MediaQuery(
                  data: media.copyWith(
                    size: Size(lebar, t),
                    padding: EdgeInsets.zero,
                    viewPadding: EdgeInsets.zero,
                    viewInsets: EdgeInsets.zero,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
