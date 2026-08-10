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
import '../text/chapter_finder.dart';
import '../text/normalizer.dart';

class PdfException implements Exception {
  final String message;
  PdfException(this.message);
  @override
  String toString() => 'PdfException: $message';
}

/// Ringkasan isi sebuah PDF, dilihat per halaman.
///
/// Dipakai supaya user bisa memilih, bukan cuma diberi tahu "tidak bisa".
/// Sebuah buku hasil pindaian sering bercampur: daftar isi dan kata pengantar
/// berupa teks, badannya berupa gambar — atau sebaliknya. Menolak seluruh
/// berkas karena rata-ratanya rendah membuang bagian yang sebenarnya terbaca.
class PdfInspection {
  /// Jumlah huruf yang terbaca di tiap halaman, urut dari halaman pertama.
  final List<int> charsPerPage;

  const PdfInspection(this.charsPerPage);

  int get pageCount => charsPerPage.length;

  /// Halaman yang punya teks sungguhan (nomor halaman mulai dari 1).
  List<int> get textPages => [
        for (var i = 0; i < charsPerPage.length; i++)
          if (charsPerPage[i] >= PdfReader.minCharsPerPage) i + 1
      ];

  /// Halaman yang nyaris tanpa teks — hampir selalu gambar hasil pindaian.
  List<int> get imagePages => [
        for (var i = 0; i < charsPerPage.length; i++)
          if (charsPerPage[i] < PdfReader.minCharsPerPage) i + 1
      ];

  bool get hasAnyText => textPages.isNotEmpty;
  bool get fullyScanned => textPages.isEmpty && pageCount > 0;
  bool get mixed => textPages.isNotEmpty && imagePages.isNotEmpty;

  /// Rentang halaman berteks yang paling panjang dan tak terputus. Ini
  /// tebakan awal yang paling masuk akal untuk "badan bukunya di mana":
  /// halaman gambar biasanya menumpuk di depan (sampul, halaman hak cipta)
  /// atau di belakang (indeks), bukan berselang-seling di tengah.
  (int, int)? get longestTextRun {
    int? mulaiTerbaik, panjangTerbaik, mulai;
    for (var i = 0; i <= charsPerPage.length; i++) {
      final berteks =
          i < charsPerPage.length && charsPerPage[i] >= PdfReader.minCharsPerPage;
      if (berteks) {
        mulai ??= i;
      } else if (mulai != null) {
        final panjang = i - mulai;
        if (panjangTerbaik == null || panjang > panjangTerbaik) {
          panjangTerbaik = panjang;
          mulaiTerbaik = mulai;
        }
        mulai = null;
      }
    }
    if (mulaiTerbaik == null) return null;
    return (mulaiTerbaik + 1, mulaiTerbaik + panjangTerbaik!);
  }
}

class PdfReader {
  const PdfReader({
    this.normalizer = const Normalizer(),
    this.chapters = const ChapterFinder(),
  });

  final Normalizer normalizer;
  final ChapterFinder chapters;

  /// Di bawah ini sebuah halaman dianggap tidak punya teks sungguhan —
  /// biasanya cuma sisa nomor halaman dari lapisan teks yang nyaris kosong.
  static const minCharsPerPage = 100;

  /// Melihat isi PDF tanpa menyusunnya jadi buku. Dipakai layar pemilih
  /// halaman supaya user tahu apa yang ada di dalam berkasnya sebelum
  /// memutuskan.
  PdfInspection inspect(List<int> bytes) {
    final doc = _open(bytes);
    try {
      return PdfInspection(
          [for (final t in _extractPages(doc)) t.trim().length]);
    } finally {
      doc.dispose();
    }
  }

  /// [fromPage] dan [toPage] dihitung mulai 1 dan inklusif. Kosongkan untuk
  /// mengambil seluruh berkas.
  Book read(
    List<int> bytes, {
    required String id,
    String? filename,
    int? fromPage,
    int? toPage,
  }) {
    final doc = _open(bytes);

    try {
      var pages = _extractPages(doc);

      if (fromPage != null || toPage != null) {
        final a = ((fromPage ?? 1) - 1).clamp(0, pages.length);
        final b = (toPage ?? pages.length).clamp(a, pages.length);
        pages = pages.sublist(a, b);
        if (pages.isEmpty) {
          throw PdfException('Rentang halaman itu kosong.');
        }
      }

      _rejectIfScanned(pages);

      // Penanda bab menunjuk ke nomor halaman di dokumen ASLI, jadi ia cuma
      // dipakai saat seluruh berkas diambil. Untuk sepotong rentang, babnya
      // dicari dari pola judul — kalau tidak, potongannya akan dipetakan ke
      // bab yang salah tanpa ada yang menyadari.
      final ambilSemua = fromPage == null && toPage == null;
      final found = (ambilSemua ? _fromBookmarks(doc, pages) : null) ??
          chapters.fromPages(pages);
      if (found.isEmpty) {
        throw PdfException('PDF ini terbaca kosong.');
      }

      return Book(
        id: id,
        title: _title(doc, filename),
        author: _author(doc),
        chapters: found,
      );
    } finally {
      doc.dispose();
    }
  }

  PdfDocument _open(List<int> bytes) {
    try {
      return PdfDocument(inputBytes: bytes);
    } catch (_) {
      throw PdfException(
          'Berkas PDF ini tidak bisa dibuka. Mungkin rusak atau terkunci '
          'kata sandi.');
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

  /// Ditolak HANYA kalau tidak ada satu halaman pun yang berteks.
  ///
  /// Dulu ambangnya rata-rata seluruh dokumen, jadi buku yang badannya
  /// terbaca tapi punya banyak halaman gambar — sampul, indeks, lampiran —
  /// ikut ditolak bulat-bulat. Yang benar: ambil yang bisa diambil, dan biar
  /// user yang memutuskan sisanya.
  void _rejectIfScanned(List<String> pages) {
    if (pages.isEmpty) throw PdfException('PDF ini tidak punya halaman.');
    final berteks =
        pages.where((p) => p.trim().length >= minCharsPerPage).length;
    if (berteks == 0) {
      throw PdfException(
          'Tidak ada satu halaman pun yang berisi teks — halamannya berupa '
          'gambar. Coba foto bukunya lewat "Foto buku fisik".');
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

  String _title(PdfDocument doc, String? filename) {
    final meta = doc.documentInformation.title.trim();
    if (meta.isNotEmpty) return meta;
    if (filename == null || filename.isEmpty) return 'Tanpa judul';
    return filename.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
  }

  String _author(PdfDocument doc) => doc.documentInformation.author.trim();
}
