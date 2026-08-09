/// Membaca buku dari PDF.
///
/// Hanya menangani PDF yang PUNYA LAPISAN TEKS. PDF hasil pindaian — yang
/// isinya cuma foto halaman — dikenali lalu ditolak dengan pesan yang jujur,
/// bukan dibiarkan masuk sebagai buku kosong. Jalur OCR untuk berkas seperti
/// itu ditangani lewat pemindaian kamera.
///
/// Bab dicari dua tahap: daftar penanda (bookmark/outline) PDF-nya dulu kalau
/// ada, karena itu keterangan dari penerbitnya sendiri; kalau tidak ada, baru
/// menebak dari pola judul bab di dalam teks.
library;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../model/book.dart';
import '../text/normalizer.dart';

class PdfException implements Exception {
  final String message;
  PdfException(this.message);
  @override
  String toString() => 'PdfException: $message';
}

/// Pola judul bab yang lazim di buku Indonesia dan Inggris. Dipakai hanya
/// kalau PDF-nya tidak punya daftar penanda.
final _chapterHeading = RegExp(
  r'^\s*(?:'
  r'BAB\s+[IVXLCDM\d]+'
  r'|Bab\s+[IVXLCDM\d]+'
  r'|BAGIAN\s+[IVXLCDM\d]+'
  r'|Bagian\s+[IVXLCDM\d]+'
  r'|CHAPTER\s+\d+'
  r'|Chapter\s+\d+'
  r')\b\.?\s*(.*)$',
);

class PdfReader {
  const PdfReader({this.normalizer = const Normalizer()});

  final Normalizer normalizer;

  /// Di bawah ini sebuah halaman dianggap tidak punya teks sungguhan —
  /// biasanya cuma sisa nomor halaman dari lapisan teks yang nyaris kosong.
  static const _minCharsPerPage = 100;

  Book read(List<int> bytes, {required String id, String? filename}) {
    PdfDocument doc;
    try {
      doc = PdfDocument(inputBytes: bytes);
    } catch (e) {
      throw PdfException(
          'Berkas PDF ini tidak bisa dibuka. Mungkin rusak atau terkunci '
          'kata sandi.');
    }

    try {
      final pages = _extractPages(doc);
      _rejectIfScanned(pages);

      final chapters = _fromBookmarks(doc, pages) ?? _fromHeadings(pages);
      if (chapters.isEmpty) {
        throw PdfException('PDF ini terbaca kosong.');
      }

      return Book(
        id: id,
        title: _title(doc, filename),
        author: _author(doc),
        chapters: chapters,
      );
    } finally {
      doc.dispose();
    }
  }

  List<String> _extractPages(PdfDocument doc) {
    final extractor = PdfTextExtractor(doc);
    final out = <String>[];
    for (var i = 0; i < doc.pages.count; i++) {
      try {
        out.add(extractor.extractText(startPageIndex: i, endPageIndex: i));
      } catch (_) {
        // Satu halaman gagal dibaca tidak boleh menjatuhkan seluruh buku.
        out.add('');
      }
    }
    return out;
  }

  /// PDF hasil pindaian punya halaman tapi nyaris tanpa teks. Menerimanya
  /// diam-diam akan menghasilkan "buku" kosong yang membingungkan.
  void _rejectIfScanned(List<String> pages) {
    if (pages.isEmpty) throw PdfException('PDF ini tidak punya halaman.');
    final total = pages.fold<int>(0, (a, p) => a + p.trim().length);
    if (total ~/ pages.length < _minCharsPerPage) {
      throw PdfException(
          'PDF ini sepertinya hasil pindaian — halamannya berupa gambar, '
          'bukan teks. Coba foto bukunya lewat menu "Foto buku fisik".');
    }
  }

  /// Bab dari daftar penanda PDF. Mengembalikan null kalau tidak ada penanda
  /// yang bisa dipetakan ke halaman — supaya pemanggil tahu harus menebak.
  List<Chapter>? _fromBookmarks(PdfDocument doc, List<String> pages) {
    final marks = <({String title, int page})>[];
    try {
      final root = doc.bookmarks;
      for (var i = 0; i < root.count; i++) {
        final b = root[i];
        final page = b.destination?.page;
        if (page == null) continue;
        final index = doc.pages.indexOf(page);
        if (index < 0) continue;
        marks.add((title: b.title.trim(), page: index));
      }
    } catch (_) {
      return null;
    }

    if (marks.length < 2) return null;
    marks.sort((a, b) => a.page.compareTo(b.page));

    final out = <Chapter>[];
    for (var i = 0; i < marks.length; i++) {
      final start = marks[i].page;
      final end = i + 1 < marks.length ? marks[i + 1].page : pages.length;
      if (start >= pages.length) continue;
      final text = normalizer.cleanPages(
          pages.sublist(start, end.clamp(start + 1, pages.length)));
      if (text.trim().isEmpty) continue;
      out.add(Chapter(
        index: out.length,
        title: marks[i].title,
        text: text,
      ));
    }
    return out.isEmpty ? null : out;
  }

  /// Tebakan dari pola judul bab. Kalau tidak ketemu satu pun, seluruh buku
  /// jadi satu bab — pemecah harian tetap bisa membaginya per paragraf.
  List<Chapter> _fromHeadings(List<String> pages) {
    final full = normalizer.cleanPages(pages);
    final lines = full.split('\n');

    final starts = <({int line, String title})>[];
    for (var i = 0; i < lines.length; i++) {
      final m = _chapterHeading.firstMatch(lines[i]);
      if (m == null) continue;
      // Judul bab berdiri sendiri di satu baris pendek. Kalimat isi yang
      // kebetulan diawali "Bab 4 menjelaskan..." jauh lebih panjang.
      if (lines[i].trim().length > 80) continue;
      final extra = (m.group(1) ?? '').trim();
      final head = lines[i].trim();
      starts.add((line: i, title: extra.isEmpty ? head : head));
    }

    if (starts.isEmpty) {
      final text = full.trim();
      return text.isEmpty
          ? const []
          : [Chapter(index: 0, title: '', text: text)];
    }

    final out = <Chapter>[];
    // Teks sebelum bab pertama (kata pengantar, halaman judul) ikut sebagai
    // bab pembuka kalau isinya cukup berarti.
    final pre = lines.sublist(0, starts.first.line).join('\n').trim();
    if (pre.length > 400) {
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

  String _title(PdfDocument doc, String? filename) {
    final meta = doc.documentInformation.title.trim();
    if (meta.isNotEmpty) return meta;
    if (filename == null || filename.isEmpty) return 'Tanpa judul';
    return filename.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
  }

  String _author(PdfDocument doc) => doc.documentInformation.author.trim();
}
