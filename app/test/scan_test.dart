import 'package:flutter_test/flutter_test.dart';

import 'package:bacain/app_state.dart';
import 'package:bacain/core/scan/page_scanner.dart';
import 'package:bacain/core/scan/scan_import.dart';
import 'package:bacain/core/store/library_store.dart';
import 'package:bacain/core/store/settings_store.dart';
import 'package:bacain/core/tts/segment_player.dart';
import 'package:bacain/core/tts/speech_engine.dart';

/// Sepadat halaman buku sungguhan. Halaman asli berisi ribuan karakter;
/// contoh yang terlalu pendek justru akan tertangkap sebagai pindaian gagal.
String halaman(String penanda) =>
    '$penanda Ia menutup buku itu dan membiarkannya di meja. '
    'Cahaya sore masuk lewat jendela yang setengah terbuka. '
    'Tidak ada yang mendesaknya untuk menyelesaikan bacaan itu. '
    'Ia sempat berpikir untuk melanjutkannya besok pagi. '
    'Tetapi besok pagi pun ada urusan lain yang menunggu. '
    'Begitulah buku itu berpindah dari meja ke rak, lalu tinggal di sana. '
    'Debunya menebal sedikit demi sedikit tanpa ada yang memperhatikan.';

ScannedPage foto(String text, [String path = '/tmp/x.jpg']) =>
    ScannedPage(imagePath: path, text: text);

void main() {
  const scan = ScanImport();

  group('menyusun buku dari hasil foto', () {
    test('halaman berpola bab jadi bab terpisah', () {
      final book = scan.build(
        ['BAB I\n${halaman("Awal.")}', 'BAB II\n${halaman("Tengah.")}'],
        id: 's1',
        title: 'Buku Fisik',
      );
      expect(book.chapters.length, 2);
      expect(book.title, 'Buku Fisik');
      expect(book.chapters.first.text, contains('Awal.'));
    });

    test('tanpa pola bab jadi satu bab utuh', () {
      final book = scan.build([halaman('Satu.'), halaman('Dua.')],
          id: 's2', title: 'X');
      expect(book.chapters.length, 1);
      expect(book.chapters.first.text, contains('Satu.'));
      expect(book.chapters.first.text, contains('Dua.'));
    });

    test('halaman kosong dilewati, bukan jadi bab hampa', () {
      final book = scan.build(['', '   ', halaman('Isi.')],
          id: 's3', title: 'X');
      expect(book.chapters.length, 1);
      expect(book.chapters.first.text, contains('Isi.'));
    });

    test('tanpa teks sama sekali ditolak dengan pesan', () {
      expect(
        () => scan.build(const ['', '  '], id: 's4', title: 'X'),
        throwsA(isA<ScanException>()),
      );
    });

    test('teks terlalu sedikit ditolak dan menyarankan foto ulang', () {
      expect(
        () => scan.build(const ['abc', 'def'], id: 's5', title: 'X'),
        throwsA(isA<ScanException>().having(
            (e) => e.message, 'pesan', contains('foto ulang'))),
      );
    });

    test('judul kosong diberi label cadangan, bukan dibiarkan hampa', () {
      final book = scan.build([halaman('Isi.')], id: 's6', title: '   ');
      expect(book.title, 'Buku hasil foto');
    });
  });

  group('lewat AppState', () {
    late AppState state;

    AppState buat(PageScanner scanner) => AppState(
          store: MemoryLibraryStore(),
          settingsStore: MemorySettingsStore(),
          player: SegmentPlayer(engine: FakeSpeechEngine()),
          scanner: scanner,
          clock: () => DateTime(2026, 8, 8, 9),
        );

    test('hasil foto jadi buku bersegmen', () async {
      state = buat(FakeScanner([
        foto('BAB I\n${halaman("Awal.")}'),
        foto('BAB II\n${halaman("Tengah.")}'),
      ]));
      final pages = await state.scanner.scan();
      final book = await state.buildScanned(pages, title: 'Buku Fisik');
      expect(book, isNotNull);
      expect(state.previewSegments(book!), isNotEmpty);
      expect(state.error, isNull);
    });

    test('foto yang gagal terbaca memberi pesan, bukan crash', () async {
      state = buat(FakeScanner([foto(''), foto('  ')]));
      final pages = await state.scanner.scan();
      final book = await state.buildScanned(pages, title: 'X');
      expect(book, isNull);
      expect(state.error, isNotNull);
    });

    test('pemindai tidak tersedia berarti daftar kosong, bukan error',
        () async {
      state = buat(UnavailableScanner());
      expect(state.scanner.available, isFalse);
      expect(await state.scanner.scan(), isEmpty);
      expect(state.error, isNull);
    });

    test('teks yang diperbaiki user yang dipakai, bukan hasil OCR asli',
        () async {
      state = buat(FakeScanner([foto('brtakan yg salah bca')]));
      final pages = await state.scanner.scan();
      final diperbaiki = [pages.first.copyWith(text: halaman('Diperbaiki.'))];

      final book = await state.buildScanned(diperbaiki, title: 'X');
      expect(book, isNotNull);
      expect(book!.chapters.first.text, contains('Diperbaiki.'));
      expect(book.chapters.first.text, isNot(contains('brtakan')));
    });
  });
}
