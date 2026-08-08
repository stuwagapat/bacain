import 'package:flutter_test/flutter_test.dart';

import 'package:bacain/core/tts/segment_player.dart';
import 'package:bacain/core/tts/speech_engine.dart';

const _text = 'Kalimat satu. Kalimat dua. Kalimat tiga. Kalimat empat.';

void main() {
  late FakeSpeechEngine engine;
  late SegmentPlayer player;

  setUp(() {
    engine = FakeSpeechEngine();
    player = SegmentPlayer(engine: engine);
    player.load(_text);
  });

  test('memecah segmen jadi kalimat saat dimuat', () {
    expect(player.sentences.length, 4);
    expect(player.status, PlayerStatus.idle);
    expect(player.index, -1);
    expect(player.current, isNull);
  });

  test('membacakan kalimat berurutan sampai habis', () async {
    final done = player.play();
    await pumpEventQueue();

    expect(player.status, PlayerStatus.playing);
    expect(player.index, 0);
    expect(engine.spoken, ['Kalimat satu.']);

    for (var i = 1; i < 4; i++) {
      engine.finishCurrent();
      await pumpEventQueue();
      expect(player.index, i);
    }

    engine.finishCurrent();
    await done;
    expect(player.status, PlayerStatus.finished);
    expect(engine.spoken.length, 4);
  });

  test('jeda menahan di batas kalimat, bukan memotong di tengah', () async {
    player.play();
    await pumpEventQueue();

    await player.pause();
    expect(player.status, PlayerStatus.paused);
    expect(engine.log, contains('pause'));

    // Kalimat berjalan selesai; pemutar TIDAK boleh maju ke kalimat berikutnya
    // selagi masih dijeda.
    engine.finishCurrent();
    await pumpEventQueue();
    expect(player.index, 0);
    expect(engine.spoken.length, 1);

    await player.resume();
    await pumpEventQueue();
    expect(player.status, PlayerStatus.playing);
    expect(player.index, 1);
    expect(engine.spoken.length, 2);
  });

  test('lompat mundur mengulang dari kalimat yang diminta', () async {
    player.play();
    await pumpEventQueue();
    for (var i = 0; i < 2; i++) {
      engine.finishCurrent();
      await pumpEventQueue();
    }
    expect(player.index, 2);

    await player.skipSentences(-2);
    await pumpEventQueue();
    expect(player.index, 0);
    expect(engine.spoken.last, 'Kalimat satu.');
  });

  test('lompat tidak keluar dari batas segmen', () async {
    await player.seekTo(99);
    await pumpEventQueue();
    expect(player.index, 3);

    await player.seekTo(-5);
    await pumpEventQueue();
    expect(player.index, 0);
  });

  test('menekan putar dua kali tidak menjalankan dua loop sekaligus', () async {
    player.play();
    await pumpEventQueue();
    player.play(from: 2);
    await pumpEventQueue();

    expect(player.index, 2);
    final before = engine.spoken.length;

    // Kalau loop lama masih hidup, satu penyelesaian akan memajukan DUA
    // kalimat sekaligus dan jumlah ucapan melonjak.
    engine.finishCurrent();
    await pumpEventQueue();
    expect(engine.spoken.length, before + 1);
    expect(player.index, 3);
  });

  test('berhenti mengembalikan ke keadaan diam', () async {
    player.play();
    await pumpEventQueue();
    await player.stop();
    await pumpEventQueue();
    expect(player.status, PlayerStatus.idle);
    expect(engine.log, contains('stop'));
  });

  test('progres naik dari nol sampai satu', () async {
    expect(player.progress, 0);
    player.play();
    await pumpEventQueue();
    expect(player.progress, closeTo(0.25, 0.001));

    for (var i = 0; i < 4; i++) {
      engine.finishCurrent();
      await pumpEventQueue();
    }
    expect(player.progress, 1.0);
  });

  test('kalimat yang gagal diucapkan tidak menghentikan bab', () async {
    final failing = _ThrowingEngine(failAt: 1);
    final p = SegmentPlayer(engine: failing)..load(_text);
    await p.play();
    expect(p.status, PlayerStatus.finished);
    expect(failing.attempts, 4);
  });

  test('kecepatan dibatasi pada rentang yang wajar', () {
    player.setRate(5);
    expect(player.rate, 2.0);
    player.setRate(0.1);
    expect(player.rate, 0.5);
  });

  test('memuat teks baru mengatur ulang posisi', () async {
    player.play();
    await pumpEventQueue();
    player.load('Halo. Dunia.');
    expect(player.index, -1);
    expect(player.sentences.length, 2);
    expect(player.status, PlayerStatus.idle);
  });
}

/// Mesin yang menggagalkan satu kalimat tertentu, untuk memastikan kegagalan
/// tunggal tidak menjatuhkan seluruh pemutaran.
class _ThrowingEngine implements SpeechEngine {
  final int failAt;
  int attempts = 0;
  _ThrowingEngine({required this.failAt});

  @override
  List<VoiceOption> get voices => const [];
  @override
  Future<void> init() async {}
  @override
  Future<void> speakOne(String text, {String? voiceId, double rate = 1.0}) async {
    final i = attempts++;
    if (i == failAt) throw StateError('suara gagal');
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
  @override
  void dispose() {}
}
