import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:bacain/app_state.dart';
import 'package:bacain/core/pdf/pdf_reader.dart';
import 'package:bacain/core/store/library_store.dart';
import 'package:bacain/core/store/settings_store.dart';
import 'package:bacain/core/tts/segment_player.dart';
import 'package:bacain/core/tts/speech_engine.dart';

/// PDF contoh dibuat di sini juga, supaya uji ini berdiri sendiri tanpa
/// berkas contoh yang harus ikut disimpan di repo.
Future<List<int>> buildPdf(
  List<List<String>> pages, {
  String? title,
  String? author,
  List<String>? bookmarks, // satu judul per halaman, null = tanpa penanda
}) async {
  final doc = PdfDocument();
  if (title != null) doc.documentInformation.title = title;
  if (author != null) doc.documentInformation.author = author;

  final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
  final added = <PdfPage>[];

  for (final lines in pages) {
    final page = doc.pages.add();
    added.add(page);
    var y = 40.0;
    for (final line in lines) {
      page.graphics.drawString(
        line,
        font,
        bounds: Rect.fromLTWH(40, y, 500, 20),
      );
      y += 22;
    }
  }

  if (bookmarks != null) {
    for (var i = 0; i < bookmarks.length && i < added.length; i++) {
      final b = doc.bookmarks.add(bookmarks[i]);
      b.destination = PdfDestination(added[i]);
    }
  }

  final bytes = await doc.save();
  doc.dispose();
  return bytes;
}

/// Satu halaman berisi kalimat yang cukup panjang supaya tidak dikira
/// halaman pindaian tanpa teks.
List<String> prosa(String penanda) => [
      '$penanda Ia menutup buku itu dan membiarkannya di meja.',
      'Cahaya sore masuk lewat jendela yang setengah terbuka.',
      'Tidak ada yang mendesaknya untuk menyelesaikan bacaan itu.',
      'Besok pun rasanya masih sempat, pikirnya sambil berdiri.',
    ];

void main() {
  const reader = PdfReader();

  test('PDF berbab lewat daftar penanda jadi bab terpisah', () async {
    final bytes = await buildPdf(
      [prosa('Satu.'), prosa('Dua.'), prosa('Tiga.')],
      title: 'Filosofi Teras',
      author: 'Henry Manampiring',
      bookmarks: ['Sebuah Undangan', 'Sekelumit Filsafat', 'Hidup Selaras'],
    );

    final book = reader.read(bytes, id: 'b1', filename: 'x.pdf');
    expect(book.title, 'Filosofi Teras');
    expect(book.author, 'Henry Manampiring');
    expect(book.chapters.length, 3);
    expect(book.chapters.first.title, 'Sebuah Undangan');
    expect(book.chapters[1].text, contains('Dua.'));
    // Indeks bab berurutan tanpa lompatan.
    for (var i = 0; i < book.chapters.length; i++) {
      expect(book.chapters[i].index, i);
    }
  });

  test('tanpa penanda, bab ditebak dari pola judul', () async {
    final bytes = await buildPdf([
      ['BAB I', ...prosa('Awal.')],
      ['BAB II', ...prosa('Tengah.')],
    ]);

    final book = reader.read(bytes, id: 'b2', filename: 'y.pdf');
    expect(book.chapters.length, 2);
    expect(book.chapters.first.title, startsWith('BAB I'));
    expect(book.chapters.first.text, contains('Awal.'));
    expect(book.chapters.last.text, contains('Tengah.'));
  });

  test('kalimat yang kebetulan menyebut "Bab" tidak dikira judul', () async {
    final bytes = await buildPdf([
      [
        'Bab 4 menjelaskan bahwa sebagian hal berada di luar kendali kita, '
            'dan itu bukan alasan untuk berhenti mencoba sama sekali.',
        ...prosa('Isi.'),
      ],
    ]);

    final book = reader.read(bytes, id: 'b3', filename: 'z.pdf');
    // Satu bab utuh — bukan terpotong di tengah kalimat isi.
    expect(book.chapters.length, 1);
  });

  test('PDF tanpa pola bab jadi satu bab utuh', () async {
    final bytes = await buildPdf([prosa('Alfa.'), prosa('Beta.')]);
    final book = reader.read(bytes, id: 'b4', filename: 'w.pdf');
    expect(book.chapters.length, 1);
    expect(book.chapters.first.text, contains('Alfa.'));
    expect(book.chapters.first.text, contains('Beta.'));
  });

  test('PDF hasil pindaian ditolak dengan pesan yang bisa dimengerti',
      () async {
    // Halaman yang nyaris tanpa teks — persis seperti hasil pindaian yang
    // lapisan teksnya cuma berisi nomor halaman.
    final bytes = await buildPdf([['1'], ['2'], ['3']]);

    expect(
      () => reader.read(bytes, id: 'b5', filename: 'pindaian.pdf'),
      throwsA(isA<PdfException>().having(
          (e) => e.message, 'pesan', contains('pindaian'))),
    );
  });

  test('berkas rusak memberi pesan, bukan crash', () {
    expect(
      () => reader.read(
          List<int>.filled(400, 65), id: 'b6', filename: 'rusak.pdf'),
      throwsA(isA<PdfException>()),
    );
  });

  test('PDF bernama .epub tetap terbaca sebagai PDF', () async {
    // Orang sering menyimpan berkas dengan ekstensi yang keliru. Kalau
    // dikenali dari nama, ini akan berujung "berkas rusak" yang menyesatkan.
    final bytes = await buildPdf([prosa('Isi.')], title: 'Salah Ekstensi');
    expect(AppState.looksLikePdf(bytes), isTrue);

    final state = AppState(
      store: MemoryLibraryStore(),
      settingsStore: MemorySettingsStore(),
      player: SegmentPlayer(engine: FakeSpeechEngine()),
    );
    final book = await state.parseFile(bytes, filename: 'buku.epub');
    expect(book, isNotNull);
    expect(book!.title, 'Salah Ekstensi');
    expect(state.error, isNull);
  });

  test('judul jatuh ke nama berkas kalau metadata kosong', () async {
    final bytes = await buildPdf([prosa('Isi.')]);
    final book = reader.read(bytes, id: 'b7', filename: 'Sapiens.pdf');
    expect(book.title, 'Sapiens');
  });
}
