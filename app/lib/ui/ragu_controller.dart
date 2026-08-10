/// Kotak teks yang menandai kata yang diragukan OCR — sambil tetap bisa
/// diketik.
///
/// Menandainya di dalam kotak isian, bukan di pratinjau terpisah, disengaja:
/// user memperbaiki di tempat yang sama dengan tempat ia melihat masalahnya.
/// Pratinjau yang harus ditukar ke mode edit menambah satu langkah pada
/// pekerjaan yang sudah membosankan.
library;

import 'package:flutter/material.dart';

import '../core/scan/ocr_doubt.dart';
import 'tokens.dart';

class RaguController extends TextEditingController {
  RaguController({required String text, required this.keyakinan})
      : super(text: text);

  /// Skor dari ML Kit, kalau perangkatnya memberi. Kosong itu wajar.
  final Map<String, double> keyakinan;

  /// Penandanya selalu `statusWarning`. Layar tinjau adalah satu-satunya
  /// tempat di seluruh app warna dipakai untuk memberi arti, jadi warnanya
  /// bagian dari maknanya — bukan sesuatu yang boleh diatur pemanggil.
  Color get penanda => warna.statusWarning;

  List<DoubtSpan> get ragu => cariKataRagu(text, keyakinan: keyakinan);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final spans = ragu;
    if (spans.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    final tanda = (style ?? const TextStyle()).copyWith(
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.dotted,
      decorationColor: penanda,
      decorationThickness: 2,
    );

    final anak = <TextSpan>[];
    var i = 0;
    for (final s in spans) {
      // Rentang yang lewat dari ujung teks bisa terjadi sepersekian detik
      // setelah user menghapus — jangan sampai menjatuhkan seluruh layar.
      if (s.start < i || s.end > text.length) continue;
      if (s.start > i) {
        anak.add(TextSpan(text: text.substring(i, s.start), style: style));
      }
      anak.add(TextSpan(text: text.substring(s.start, s.end), style: tanda));
      i = s.end;
    }
    if (i < text.length) {
      anak.add(TextSpan(text: text.substring(i), style: style));
    }
    return TextSpan(style: style, children: anak);
  }
}
