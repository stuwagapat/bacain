import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:bacain/app_state.dart';
import 'package:bacain/core/model/book.dart';
import 'package:bacain/core/store/library_store.dart';
import 'package:bacain/core/tts/segment_player.dart';
import 'package:bacain/core/tts/speech_engine.dart';

import 'epub_test.dart' show buildEpub, doc;

String para(int words) => List.filled(words, 'kata').join(' ');

/// EPUB tiga bab, tiap bab cukup panjang untuk jadi satu jatah sendiri.
List<int> sampleEpub() => buildEpub(
      docs: [
        (file: 'a.xhtml', xhtml: doc('Bab Satu', para(1800))),
        (file: 'b.xhtml', xhtml: doc('Bab Dua', para(1800))),
        (file: 'c.xhtml', xhtml: doc('Bab Tiga', para(1800))),
      ],
      nav: [
        (href: 'a.xhtml', label: 'Bab Satu'),
        (href: 'b.xhtml', label: 'Bab Dua'),
        (href: 'c.xhtml', label: 'Bab Tiga'),
      ],
    );

void main() {
  late MemoryLibraryStore store;
  late FakeSpeechEngine engine;
  late AppState state;

  setUp(() {
    store = MemoryLibraryStore();
    engine = FakeSpeechEngine();
    state = AppState(store: store, player: SegmentPlayer(engine: engine));
  });

  group('memasukkan buku', () {
    test('EPUB jadi buku bersegmen dan tersimpan', () async {
      final book = await state.addEpub(sampleEpub(), filename: 'x.epub');
      expect(book, isNotNull);
      expect(book!.title, 'Filosofi Teras');
      expect(book.segments.length, 3);
      expect(state.books.length, 1);
      expect(store.saveCount, 1, reason: 'progres disimpan saat itu juga');
    });

    test('berkas rusak memberi pesan, bukan crash', () async {
      final book = await state.addEpub(utf8.encode('bukan epub'), filename: 'x');
      expect(book, isNull);
      expect(state.error, isNotNull);
      expect(state.books, isEmpty);
    });
  });

  group('penguncian segmen', () {
    late StoredBook book;

    setUp(() async {
      book = (await state.addEpub(sampleEpub(), filename: 'x.epub'))!;
      state.openBook(book);
    });

    test('hanya segmen berikutnya yang terbuka', () {
      expect(state.canOpen(book, 0), isTrue);
      expect(state.canOpen(book, 1), isFalse);
      expect(state.canOpen(book, 2), isFalse);
    });

    test('membuka segmen terkunci diabaikan', () async {
      await state.openSegment(2);
      expect(book.currentIndex, 0);
      expect(state.player.sentences, isEmpty);
    });

    test('menyelesaikan segmen membuka yang berikutnya dan tersimpan', () async {
      await state.openSegment(0);
      expect(state.player.sentences, isNotEmpty);

      final before = store.saveCount;
      state.player.play();
      await pumpEventQueue();
      // Habiskan semua kalimat.
      while (engine.isSpeaking) {
        engine.finishCurrent();
        await pumpEventQueue();
      }

      expect(state.player.status, PlayerStatus.finished);
      expect(book.lastFinishedIndex, 0);
      expect(state.canOpen(book, 1), isTrue);
      expect(state.canOpen(book, 2), isFalse);
      expect(store.saveCount, greaterThan(before));
    });

    test('mengulang segmen lama tidak memundurkan progres', () async {
      book.lastFinishedIndex = 1;
      await state.openSegment(0);
      state.player.play();
      await pumpEventQueue();
      while (engine.isSpeaking) {
        engine.finishCurrent();
        await pumpEventQueue();
      }
      expect(book.lastFinishedIndex, 1);
    });
  });

  group('ringkasan "sebelumnya"', () {
    test('tidak muncul sebelum ada yang selesai', () async {
      final book = (await state.addEpub(sampleEpub(), filename: 'x'))!;
      state.openBook(book);
      expect(state.needsRecap, isFalse);
    });

    test('tidak muncul kalau baru saja mendengar', () async {
      final book = (await state.addEpub(sampleEpub(), filename: 'x'))!;
      book.lastFinishedIndex = 0;
      book.lastListenedAt = DateTime.now().subtract(const Duration(minutes: 30));
      state.openBook(book);
      expect(state.needsRecap, isFalse);
    });

    test('muncul kalau jeda lebih dari sehari', () async {
      final book = (await state.addEpub(sampleEpub(), filename: 'x'))!;
      book.lastFinishedIndex = 0;
      book.lastListenedAt = DateTime.now().subtract(const Duration(days: 2));
      state.openBook(book);
      expect(state.needsRecap, isTrue);
    });
  });

  group('penyimpanan', () {
    test('buku bolak-balik lewat JSON tanpa kehilangan apa pun', () {
      final original = StoredBook(
        id: 'b1',
        title: 'Filosofi Teras',
        author: 'Henry Manampiring',
        currentIndex: 2,
        lastFinishedIndex: 1,
        lastListenedAt: DateTime.parse('2026-08-08T07:00:00.000'),
        segments: const [
          Segment(
              index: 0,
              title: 'Bab Satu',
              chapterIndex: 0,
              part: 1,
              partCount: 2,
              text: 'Isi satu.'),
          Segment(
              index: 1,
              title: 'Bab Satu (2/2)',
              chapterIndex: 0,
              part: 2,
              partCount: 2,
              text: 'Isi dua.'),
        ],
      );

      final back = StoredBook.fromJson(
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>);

      expect(back.id, original.id);
      expect(back.title, original.title);
      expect(back.currentIndex, 2);
      expect(back.lastFinishedIndex, 1);
      expect(back.lastListenedAt, original.lastListenedAt);
      expect(back.segments.length, 2);
      expect(back.segments[1].title, 'Bab Satu (2/2)');
      expect(back.segments[1].text, 'Isi dua.');
      expect(back.segments[1].partCount, 2);
    });

    test('sisa bagian dihitung dari yang sudah selesai', () async {
      final book = (await state.addEpub(sampleEpub(), filename: 'x'))!;
      expect(book.remainingCount, 3);
      book.lastFinishedIndex = 1;
      expect(book.remainingCount, 1);
      expect(book.isFinished, isFalse);
      book.lastFinishedIndex = 2;
      expect(book.isFinished, isTrue);
    });

    test('menghapus buku mengeluarkannya dari rak dan menyimpan', () async {
      final book = (await state.addEpub(sampleEpub(), filename: 'x'))!;
      state.openBook(book);
      await state.removeBook(book);
      expect(state.books, isEmpty);
      expect(state.active, isNull);
      expect(store.books, isEmpty);
    });
  });
}
