/// Mengubah hasil pindaian halaman jadi buku.
///
/// Murni: masuknya teks per halaman, keluarnya `Book`. Tidak tahu-menahu soal
/// kamera maupun OCR, jadi seluruh aturannya bisa diuji tanpa perangkat.
///
/// Bedanya dengan EPUB: tidak ada daftar isi sama sekali, jadi bab hanya bisa
/// ditebak dari pola judul. Dan bedanya dengan PDF: teksnya datang dari OCR,
/// yang tidak akan pernah 100% benar — karena itu ada layar tinjau sebelum
/// halaman-halaman ini sampai ke sini.
library;

import '../model/book.dart';
import '../text/chapter_finder.dart';

class ScanException implements Exception {
  final String message;
  ScanException(this.message);
  @override
  String toString() => 'ScanException: $message';
}

class ScanImport {
  const ScanImport({this.chapters = const ChapterFinder()});

  final ChapterFinder chapters;

  /// Di bawah ini seluruh hasil pindaian dianggap gagal terbaca — biasanya
  /// foto terlalu buram, terlalu gelap, atau bukan halaman berteks.
  static const _minTotalChars = 200;

  Book build(
    List<String> pages, {
    required String id,
    required String title,
    String author = '',
  }) {
    final terisi = pages.where((p) => p.trim().isNotEmpty).toList();
    if (terisi.isEmpty) {
      throw ScanException('Tidak ada teks yang terbaca dari foto-foto itu.');
    }

    final total = terisi.fold<int>(0, (a, p) => a + p.trim().length);
    if (total < _minTotalChars) {
      throw ScanException(
          'Teks yang terbaca terlalu sedikit. Coba foto ulang dengan cahaya '
          'lebih terang dan halaman yang rata.');
    }

    final found = chapters.fromPages(terisi);
    if (found.isEmpty) {
      throw ScanException('Tidak ada teks yang terbaca dari foto-foto itu.');
    }

    return Book(
      id: id,
      title: title.trim().isEmpty ? 'Buku hasil foto' : title.trim(),
      author: author,
      chapters: found,
    );
  }
}
