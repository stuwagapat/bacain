/// Menebak batas bab dari halaman teks polos.
///
/// Dipakai bersama oleh impor PDF dan hasil pindaian kamera: keduanya sampai
/// di titik yang sama — setumpuk halaman teks tanpa daftar isi. EPUB tidak
/// memerlukannya karena daftar isinya eksplisit.
library;

import '../model/book.dart';
import 'normalizer.dart';

/// Pola judul bab yang lazim di buku Indonesia dan Inggris.
final _heading = RegExp(
  r'^\s*(?:'
  r'BAB\s+[IVXLCDM\d]+'
  r'|Bab\s+[IVXLCDM\d]+'
  r'|BAGIAN\s+[IVXLCDM\d]+'
  r'|Bagian\s+[IVXLCDM\d]+'
  r'|CHAPTER\s+\d+'
  r'|Chapter\s+\d+'
  r')\b\.?\s*',
);

class ChapterFinder {
  const ChapterFinder({this.normalizer = const Normalizer()});

  final Normalizer normalizer;

  /// Di atas panjang ini sebuah baris dianggap kalimat isi, bukan judul.
  /// "Bab 4 menjelaskan bahwa..." adalah kalimat, bukan awal bab baru.
  static const _maxHeadingLength = 80;

  /// Teks sebelum bab pertama baru dijadikan bab pembuka kalau isinya cukup
  /// berarti — bukan sekadar halaman judul.
  static const _minPrefaceLength = 400;

  List<Chapter> fromPages(List<String> pages) =>
      fromText(normalizer.cleanPages(pages));

  List<Chapter> fromText(String full) {
    final lines = full.split('\n');

    final starts = <({int line, String title})>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.length > _maxHeadingLength) continue;
      if (!_heading.hasMatch(lines[i])) continue;
      starts.add((line: i, title: line));
    }

    if (starts.isEmpty) {
      final text = full.trim();
      return text.isEmpty ? const [] : [Chapter(index: 0, title: '', text: text)];
    }

    final out = <Chapter>[];
    final pre = lines.sublist(0, starts.first.line).join('\n').trim();
    if (pre.length > _minPrefaceLength) {
      out.add(Chapter(index: 0, title: 'Pembuka', text: pre));
    }

    for (var i = 0; i < starts.length; i++) {
      final from = starts[i].line;
      final to = i + 1 < starts.length ? starts[i + 1].line : lines.length;
      final text = lines.sublist(from, to).join('\n').trim();
      if (text.isEmpty) continue;
      out.add(Chapter(index: out.length, title: starts[i].title, text: text));
    }
    return out;
  }
}
