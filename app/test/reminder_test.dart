import 'package:flutter_test/flutter_test.dart';

import 'package:bacain/app_state.dart';
import 'package:bacain/core/reminders/reminder_plan.dart';
import 'package:bacain/core/reminders/reminders.dart';
import 'package:bacain/core/store/library_store.dart';
import 'package:bacain/core/store/settings_store.dart';
import 'package:bacain/core/tts/segment_player.dart';
import 'package:bacain/core/tts/speech_engine.dart';

import 'app_state_test.dart' show sampleEpub;

void main() {
  const planner = ReminderPlanner();
  const settings = AppSettings(
      onboarded: true, reminderHour: 7, reminderMinute: 0, reminderOn: true);

  group('perencanaan pengingat', () {
    test('menjadwalkan beberapa hari ke depan sekaligus', () {
      final out = planner.plan(DateTime(2026, 8, 8, 6), settings,
          bookTitle: 'Filosofi Teras');
      expect(out.length, ReminderPlanner.daysAhead);
      expect(out.first.at, DateTime(2026, 8, 8, 7, 0));
      expect(out.last.at.day, 14);
    });

    test('jam hari ini yang sudah lewat dilewati', () {
      // Pukul 09.00, pengingat jam 07.00 — hari ini sudah terlewat.
      final out = planner.plan(DateTime(2026, 8, 8, 9), settings,
          bookTitle: 'Filosofi Teras');
      expect(out.first.at, DateTime(2026, 8, 9, 7, 0),
          reason: 'pengingat untuk waktu yang sudah berlalu cuma membingungkan');
      expect(out.length, ReminderPlanner.daysAhead - 1);
    });

    test('pengingat mati berarti tidak ada jadwal sama sekali', () {
      final out = planner.plan(
          DateTime(2026, 8, 8, 6), settings.copyWith(reminderOn: false));
      expect(out, isEmpty);
    });

    test('id tetap supaya penjadwalan ulang menimpa, bukan menumpuk', () {
      final a = planner.plan(DateTime(2026, 8, 8, 6), settings, bookTitle: 'X');
      final b = planner.plan(DateTime(2026, 8, 8, 6), settings, bookTitle: 'X');
      expect(a.map((r) => r.id).toList(), b.map((r) => r.id).toList());
      expect(a.map((r) => r.id).toSet().length, a.length,
          reason: 'id tidak boleh kembar dalam satu jadwal');
    });

    test('kalimatnya berganti antar hari', () {
      final out = planner.plan(DateTime(2026, 8, 8, 6), settings,
          bookTitle: 'Filosofi Teras', segmentTitle: 'Dikotomi Kendali');
      final teks = out.map((r) => '${r.title}|${r.body}').toSet();
      expect(teks.length, greaterThan(3),
          reason: 'kalimat yang sama tiap hari berubah jadi kebisingan');
    });

    test('kalimat yang sama untuk hari yang sama, tidak berkedip', () {
      final a = planner.plan(DateTime(2026, 8, 8, 6), settings, bookTitle: 'X');
      final b = planner.plan(DateTime(2026, 8, 8, 6, 30), settings,
          bookTitle: 'X');
      expect(a.first.title, b.first.title);
      expect(a.first.body, b.first.body);
    });

    test('tidak menyebut buku yang tidak ada saat rak kosong', () {
      final out = planner.plan(DateTime(2026, 8, 8, 6), settings);
      for (final r in out) {
        expect('${r.title} ${r.body}', isNot(contains('{')),
            reason: 'penampung teks harus terisi, bukan bocor ke layar');
      }
      expect(out.first.body, isNot(contains('null')));
    });

    test('menyebut judul buku dan bagian berikutnya kalau ada', () {
      final out = planner.plan(DateTime(2026, 8, 8, 6), settings,
          bookTitle: 'Filosofi Teras',
          segmentTitle: 'Dikotomi Kendali',
          minutes: 20);
      final semua = out.map((r) => '${r.title} ${r.body}').join(' ');
      expect(semua, contains('Filosofi Teras'));
      expect(semua, contains('Dikotomi Kendali'));
      expect(semua, contains('20'));
      expect(semua, isNot(contains('{')));
    });

    test('tidak memakai kosakata produktivitas', () {
      final out = planner.plan(DateTime(2026, 8, 8, 6), settings,
          bookTitle: 'Buku', segmentTitle: 'Bagian');
      final semua = out.map((r) => '${r.title} ${r.body}').join(' ').toLowerCase();
      for (final kata in ['target', 'optimal', 'produktif', 'jangan sampai', 'streak']) {
        expect(semua, isNot(contains(kata)),
            reason: 'positioning produknya justru menolak nada ini');
      }
    });
  });

  group('pengingat mengikuti keadaan app', () {
    late FakeReminders reminders;
    late AppState state;

    setUp(() {
      reminders = FakeReminders();
      state = AppState(
        store: MemoryLibraryStore(),
        settingsStore: MemorySettingsStore(),
        player: SegmentPlayer(engine: FakeSpeechEngine()),
        reminders: reminders,
        clock: () => DateTime(2026, 8, 8, 6),
      );
    });

    test('dijadwalkan saat app dibuka', () async {
      await state.init();
      expect(reminders.jadwal, isNotEmpty);
    });

    test('mematikan pengingat membatalkan jadwal', () async {
      await state.init();
      await state.updateSettings(state.settings.copyWith(reminderOn: false));
      expect(reminders.cancelCount, greaterThan(0));
    });

    test('mengganti jam menulis ulang jadwal, bukan menambah', () async {
      await state.init();
      await state.updateSettings(state.settings.copyWith(reminderHour: 20));
      expect(reminders.terakhir.first.at.hour, 20);
    });

    test('menambah buku membuat pengingat menyebut namanya', () async {
      await state.init();
      await state.addEpub(sampleEpub(), filename: 'x.epub');
      final teks = reminders.terakhir.map((r) => '${r.title} ${r.body}').join();
      expect(teks, contains('Filosofi Teras'));
    });

    test('buku yang sudah tamat tidak dipakai di pengingat', () async {
      await state.init();
      final book = (await state.addEpub(sampleEpub(), filename: 'x.epub'))!;
      book.lastFinishedIndex = book.segments.length - 1;
      await state.syncReminders();
      final teks = reminders.terakhir.map((r) => '${r.title} ${r.body}').join();
      expect(teks, isNot(contains('Filosofi Teras')));
    });
  });
}
