import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:bacain/app_state.dart';
import 'package:bacain/core/model/book.dart';
import 'package:bacain/core/store/library_store.dart';
import 'package:bacain/core/store/settings_store.dart';
import 'package:bacain/core/tts/segment_player.dart';
import 'package:bacain/core/tts/speech_engine.dart';

import 'epub_test.dart' show buildEpub, doc;

String para(int words) => List.filled(words, 'kata').join(' ');

/// Teks berkalimat sungguhan. Penting untuk uji jatah: kalau bab hanya satu
/// kalimat raksasa, jatah tidak akan pernah habis di TENGAH bagian.
String prose(int sentenceCount) =>
    List.generate(sentenceCount, (i) => 'Ini kalimat nomor $i.').join(' ');

/// EPUB tiga bab, tiap bab cukup panjang untuk jadi satu jatah sendiri.
List<int> sampleEpub() => buildEpub(
      docs: [
        (file: 'a.xhtml', xhtml: doc('Bab Satu', prose(450))),
        (file: 'b.xhtml', xhtml: doc('Bab Dua', prose(450))),
        (file: 'c.xhtml', xhtml: doc('Bab Tiga', prose(450))),
      ],
      nav: [
        (href: 'a.xhtml', label: 'Bab Satu'),
        (href: 'b.xhtml', label: 'Bab Dua'),
        (href: 'c.xhtml', label: 'Bab Tiga'),
      ],
    );

void main() {
  late MemoryLibraryStore store;
  late MemorySettingsStore settingsStore;
  late FakeSpeechEngine engine;
  late AppState state;
  late DateTime now;

  setUp(() {
    store = MemoryLibraryStore();
    settingsStore = MemorySettingsStore();
    engine = FakeSpeechEngine();
    now = DateTime(2026, 8, 8, 9);
    state = AppState(
      store: store,
      settingsStore: settingsStore,
      player: SegmentPlayer(engine: engine),
      clock: () => now,
    );
  });

  /// Habiskan seluruh kalimat di segmen yang sedang dibuka.
  Future<void> listenThrough() async {
    state.player.play();
    await pumpEventQueue();
    while (engine.isSpeaking) {
      engine.finishCurrent();
      await pumpEventQueue();
    }
  }

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
    test('tidak muncul saat mengulang bagian yang sudah didengar', () async {
      final book = (await state.addEpub(sampleEpub(), filename: 'x'))!;
      book.lastFinishedIndex = 1;
      book.currentIndex = 1; // ulangan, bukan bagian baru
      book.lastListenedAt = now.subtract(const Duration(days: 3));
      state.openBook(book);
      expect(state.needsRecap, isFalse);
    });

    test('tidak muncul sebelum ada yang selesai', () async {
      final book = (await state.addEpub(sampleEpub(), filename: 'x'))!;
      state.openBook(book);
      expect(state.needsRecap, isFalse);
    });

    test('tidak muncul kalau baru saja mendengar', () async {
      final book = (await state.addEpub(sampleEpub(), filename: 'x'))!;
      book.lastFinishedIndex = 0;
      book.currentIndex = 1;
      book.lastListenedAt = now.subtract(const Duration(minutes: 30));
      state.openBook(book);
      expect(state.needsRecap, isFalse);
    });

    test('muncul kalau jeda lebih dari sehari', () async {
      final book = (await state.addEpub(sampleEpub(), filename: 'x'))!;
      book.lastFinishedIndex = 0;
      book.currentIndex = 1; // akan mendengar bagian BARU
      book.lastListenedAt = now.subtract(const Duration(days: 2));
      state.openBook(book);
      expect(state.needsRecap, isTrue);
    });
  });


  group('jatah harian', () {
    late StoredBook book;

    setUp(() async {
      await state.init();
      book = (await state.addEpub(sampleEpub(), filename: 'x.epub'))!;
      state.openBook(book);
    });

    test('mulai penuh, lalu berkurang setelah didengar', () async {
      expect(state.remainingMinutes, state.settings.dailyMinutes);
      await state.openSegment(0);
      state.player.play();
      await pumpEventQueue();
      engine.finishCurrent();
      await pumpEventQueue();
      expect(state.quota.usedSeconds(), greaterThan(0));
    });

    test('membuka segmen tanpa mendengar tidak memakan jatah', () async {
      await state.openSegment(0);
      expect(state.quota.usedSeconds(), 0);
    });

    test('habis di tengah jalan menjeda pemutar dan menyalakan penanda',
        () async {
      await state.updateSettings(state.settings.copyWith(dailyMinutes: 1));
      await state.openSegment(0);
      await listenThrough();
      expect(state.quotaExhausted, isTrue);
      expect(state.quotaJustRanOut, isTrue);
      expect(state.player.status, PlayerStatus.paused,
          reason: 'harus dijeda, bukan dibiarkan terus membaca');
    });

    test('mendengar ulang bagian yang sudah selesai tidak memakan jatah',
        () async {
      await state.openSegment(0);
      await listenThrough();
      final usedAfterFirst = state.quota.usedSeconds();
      expect(book.lastFinishedIndex, 0);

      await state.openSegment(0); // ulangan
      await listenThrough();
      expect(state.quota.usedSeconds(), usedAfterFirst,
          reason: 'ulangan tidak menambah pemakaian');
    });

    test('jatah kembali penuh saat berganti hari', () async {
      await state.openSegment(0);
      state.player.play();
      await pumpEventQueue();
      engine.finishCurrent();
      await pumpEventQueue();
      expect(state.quota.usedSeconds(), greaterThan(0));

      now = now.add(const Duration(days: 1));
      expect(state.quota.usedSeconds(), 0);
      expect(state.remainingMinutes, state.settings.dailyMinutes);
    });

    test('pemakaian tersimpan supaya tidak hilang saat app ditutup', () async {
      await state.openSegment(0);
      state.player.play();
      await pumpEventQueue();
      engine.finishCurrent();
      await pumpEventQueue();
      expect(settingsStore.usage.seconds, greaterThan(0));
      expect(settingsStore.usage.day, '2026-08-08');
    });
  });

  group('pengaturan', () {
    test('perkenalan awal menyimpan jam dan menandai selesai', () async {
      await state.init();
      expect(state.settings.onboarded, isFalse);
      await state.completeOnboarding(hour: 6, minute: 30, reminderOn: false);
      expect(state.settings.onboarded, isTrue);
      expect(state.settings.reminderLabel, '06.30');
      expect(settingsStore.settings.onboarded, isTrue);
    });

    test('perkiraan hari mengikuti jatah harian', () async {
      await state.init();
      final book = await state.parseEpub(sampleEpub(), filename: 'x');
      final segments = state.previewSegments(book!);

      await state.updateSettings(state.settings.copyWith(dailyMinutes: 40));
      final few = state.estimatedDays(segments);
      await state.updateSettings(state.settings.copyWith(dailyMinutes: 10));
      final many = state.estimatedDays(segments);
      expect(many, greaterThan(few));
    });

    test('kecepatan ikut terpasang ke pemutar', () async {
      await state.init();
      await state.updateSettings(state.settings.copyWith(rate: 1.5));
      expect(state.player.rate, 1.5);
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
