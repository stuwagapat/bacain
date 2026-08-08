import 'package:flutter/material.dart';

/// Warna diambil dari aset desain (ornamen & logo). Rupa akhirnya menyusul —
/// tahap ini soal fungsi dan alur.
const paper = Color(0xFFEFECE7);
const surface = Color(0xFFFFFFFF);
const green = Color(0xFF2D6B2D);
const greenDeep = Color(0xFF184818);
const orange = Color(0xFFF06C3C);
const apricot = Color(0xFFFCB46C);
const ink = Color(0xFF161616);
const ink2 = Color(0xFF5A5A54);
const ink3 = Color(0xFFA6A29A);
const rule = Color(0xFFDDD8CE);

TextStyle get titleStyle => const TextStyle(
    fontSize: 23,
    fontWeight: FontWeight.w800,
    fontStyle: FontStyle.italic,
    color: green,
    height: 1.25);

TextStyle get bodyStyle =>
    const TextStyle(fontSize: 15, color: ink2, height: 1.55);

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
          backgroundColor: green,
          // foregroundColor WAJIB ditulis. Tanpa ini warnanya jatuh ke
          // colorScheme.onPrimary, yang tidak ikut dihitung ulang saat
          // `primary` ditimpa di fromSeed — hasilnya label bisa tak terlihat.
          foregroundColor: Colors.white,
          disabledBackgroundColor: ink3,
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w700)),
            if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 19)],
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
        style: TextButton.styleFrom(foregroundColor: ink2),
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
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
            const Text('Sisa hari ini',
                style: TextStyle(fontSize: 12.5, color: ink2)),
            const Spacer(),
            Text(
              remainingMinutes <= 0 ? 'habis' : '$remainingMinutes menit',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: remainingMinutes <= 0 ? orange : ink),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio.toDouble(),
            minHeight: 4,
            backgroundColor: rule,
            valueColor: const AlwaysStoppedAnimation(orange),
          ),
        ),
      ],
    );
  }
}
