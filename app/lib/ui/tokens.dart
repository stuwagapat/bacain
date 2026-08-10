/// Lapisan tipis di atas `tokens.g.dart`.
///
/// **Tidak ada satu pun nilai hex di file ini.** Semua warna, ukuran, dan gaya
/// huruf berasal dari `design/tokens.json` lewat `python3 tools/gen_tokens.py`.
/// Kalau sebuah warna terasa kurang pas, yang diubah adalah tokens.json —
/// bukan file ini. Yang tinggal di sini cuma widget buatan tangan, yang tidak
/// pernah disentuh generator.
library;

import 'package:flutter/material.dart';

import 'tokens.g.dart';

export 'tokens.g.dart';

/// Palet yang sedang berlaku. **Tema bawaan gelap** — app ini didengarkan
/// malam hari dan menjelang tidur, jadi terang adalah pengecualian, bukan
/// keadaan awal.
///
/// Semua layar membaca warna lewat satu pintu ini supaya mode terang nanti
/// jadi pergantian nilai, bukan penulisan ulang tiap layar. `AppColors.light`
/// sudah ikut dihasilkan dan nilainya masuk akal, tapi belum pernah ditata di
/// layar mana pun — jangan dinyalakan sebelum didesain. Mode terang bukan
/// pembalikan warna: `readingHighlightBg` di gelap sengaja jauh lebih redup
/// daripada padanannya di terang.
const warna = AppColors.dark;

/// Judul layar. Serif, karena yang dibaca user adalah buku — batas antara
/// antarmuka dan bacaan jadi terasa tanpa perlu garis pemisah.
TextStyle get titleStyle => AppType.uiHeadline.copyWith(color: warna.textPrimary);

/// Teks penjelas. Selalu sekunder: kalau sebuah kalimat perlu tampil sekuat
/// judul, ia bukan penjelas.
TextStyle get bodyStyle => AppType.uiBody.copyWith(color: warna.textSecondary);

/// Teks bacaan di pemutar. Ukuran ikut pilihan "huruf besar" di Pengaturan.
TextStyle readingStyle({bool besar = false, bool a11y = false}) {
  final dasar = besar ? AppType.readingBodyLarge : AppType.readingBody;
  return a11y ? dasar.copyWith(fontFamily: AppType.a11yFamily) : dasar;
}

/// Tombol utama. Satu bentuk dipakai di semua layar supaya aksi utamanya
/// selalu terbaca sama.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const PrimaryButton(this.label, {super.key, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: warna.brandPrimary,
          // foregroundColor WAJIB ditulis. Tanpa ini warnanya jatuh ke
          // colorScheme.onPrimary, yang tidak ikut dihitung ulang saat
          // `primary` ditimpa di fromSeed — hasilnya label bisa tak terlihat.
          //
          // Nilainya brandOnPrimary, tidak pernah putih: putih di atas coral
          // cuma 3,0:1 dan gagal WCAG AA. Ambang 4,5:1 wajib di sini —
          // aksesibilitas adalah salah satu klaim produk ini.
          foregroundColor: warna.brandOnPrimary,
          disabledBackgroundColor: warna.bgSurfaceVariant,
          disabledForegroundColor: warna.textDisabled,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: AppType.uiLabel.copyWith(fontSize: 15.5)),
            if (icon != null) ...[
              const SizedBox(width: AppSpacing.space2),
              Icon(icon, size: 19),
            ],
          ],
        ),
      );
}

class QuietButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const QuietButton(this.label, {super.key, this.onPressed});

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(foregroundColor: warna.textSecondary),
        child: Text(label, style: AppType.uiLabel),
      );
}

/// Sisa jatah hari ini. Ditulis dalam menit, bukan karakter — batas yang
/// terasa seperti ritme, bukan tagihan.
class QuotaBar extends StatelessWidget {
  final int remainingMinutes;
  final int totalMinutes;
  const QuotaBar(
      {super.key, required this.remainingMinutes, required this.totalMinutes});

  @override
  Widget build(BuildContext context) {
    final ratio = totalMinutes == 0
        ? 0.0
        : (remainingMinutes / totalMinutes).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Sisa hari ini',
                style: AppType.uiCaption.copyWith(color: warna.textSecondary)),
            const Spacer(),
            Text(
              remainingMinutes <= 0 ? 'habis' : '$remainingMinutes menit',
              style: AppType.uiCaption.copyWith(
                fontWeight: FontWeight.w700,
                color: remainingMinutes <= 0
                    ? warna.quotaFilled
                    : warna.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: ratio.toDouble(),
            minHeight: 4,
            backgroundColor: warna.quotaTrack,
            valueColor: AlwaysStoppedAnimation(warna.quotaFilled),
          ),
        ),
      ],
    );
  }
}
