import 'package:flutter_test/flutter_test.dart';

import 'package:bacain/app_state.dart';
import 'package:bacain/core/playback/keep_awake.dart';
import 'package:bacain/core/store/library_store.dart';
import 'package:bacain/core/store/settings_store.dart';
import 'package:bacain/core/tts/segment_player.dart';
import 'package:bacain/core/tts/speech_engine.dart';

import 'app_state_test.dart' show sampleEpub;

/// Layanan latar depan menahan Android agar tidak membunuh proses saat layar
/// mati. Yang dijaga di sini: layanannya hidup PERSIS selama membacakan —
/// tidak lebih. Notifikasi yang menggantung dan mengaku sedang membacakan
/// padahal tidak jauh lebih buruk daripada tidak ada sama sekali.
void main() {
  late FakeKeepAwake awake;
  late FakeSpeechEngine engine;
  late AppState state;

  setUp(() async {
    awake = FakeKeepAwake();
    engine = FakeSpeechEngine();
    state = AppState(
      store: MemoryLibraryStore(),
      settingsStore: MemorySettingsStore(),
      player: SegmentPlayer(engine: engine),
      keepAwake: awake,
      clock: () => DateTime(2026, 8, 8, 9),
    );
    await state.init();
    final book = (await state.addEpub(sampleEpub(), filename: 'x.epub'))!;
    state.openBook(book);
    await state.openSegment(0);
  });

  test('menyala saat mulai membacakan', () async {
    expect(awake.running, isFalse);
    state.player.play();
    await pumpEventQueue();
    expect(awake.running, isTrue);
    expect(awake.judul.last, 'Filosofi Teras');
  });

  test('mati saat dijeda', () async {
    state.player.play();
    await pumpEventQueue();
    await state.player.pause();
    await pumpEventQueue();
    expect(awake.running, isFalse);
  });

  test('mati saat bagiannya habis', () async {
    state.player.play();
    await pumpEventQueue();
    while (engine.isSpeaking) {
      engine.finishCurrent();
      await pumpEventQueue();
    }
    expect(state.player.status, PlayerStatus.finished);
    expect(awake.running, isFalse);
  });

  test('mati saat dihentikan', () async {
    state.player.play();
    await pumpEventQueue();
    await state.player.stop();
    await pumpEventQueue();
    expect(awake.running, isFalse);
  });

  test('tidak dinyalakan berulang selama membacakan', () async {
    state.player.play();
    await pumpEventQueue();
    // Tiap kalimat selesai memicu pemberitahuan; layanannya tidak boleh
    // dinyalakan ulang tiap kali.
    for (var i = 0; i < 3; i++) {
      engine.finishCurrent();
      await pumpEventQueue();
    }
    expect(awake.starts, 1);
  });
}
