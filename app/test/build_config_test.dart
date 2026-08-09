import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bacain/app_state.dart';
import 'package:bacain/core/store/library_store.dart';
import 'package:bacain/core/store/settings_store.dart';
import 'package:bacain/core/tts/cloud_speech_engine.dart';
import 'package:bacain/core/tts/cloud_tts.dart';
import 'package:bacain/core/tts/google_tts_client.dart';
import 'package:bacain/core/tts/segment_player.dart';
import 'package:bacain/core/tts/speech_engine.dart';
import 'package:bacain/core/tts/tts_budget.dart';

/// Kredensial yang ditanam saat build supaya user tidak perlu mengetik apa
/// pun. Yang diuji di sini: mana yang menang saat keduanya ada, dan bahwa
/// yang tertanam benar-benar sampai ke klien.
void main() {
  late GoogleTtsClient client;

  AppState buat({
    String baked = '',
    String bakedUrl = '',
    String? tersimpan,
    String? tersimpanUrl,
  }) {
    client = GoogleTtsClient();
    final store = MemorySettingsStore();
    if (tersimpan != null || tersimpanUrl != null) {
      store.settings = AppSettings(
        ttsApiKey: tersimpan,
        ttsProxyUrl: tersimpanUrl,
      );
    }
    return AppState(
      store: MemoryLibraryStore(),
      settingsStore: store,
      player: SegmentPlayer(
        engine: CloudSpeechEngine(
          client: client,
          cache: MemoryAudioCache(),
          sink: _SinkDiam(),
          budget: TtsBudget(),
          fallback: FakeSpeechEngine(),
        ),
      ),
      bakedTtsApiKey: baked,
      bakedTtsProxyUrl: bakedUrl,
    );
  }

  test('kunci bawaan build dipakai tanpa user mengetik apa pun', () async {
    await buat(baked: 'KUNCI-BAWAAN').init();
    expect(client.apiKey, 'KUNCI-BAWAAN');
    expect(client.configured, isTrue);
  });

  test('yang diketik user menang atas yang ditanam', () async {
    // Supaya build resmi bisa ditimpa saat mencoba kunci lain, tanpa
    // membangun ulang APK.
    await buat(baked: 'KUNCI-BAWAAN', tersimpan: 'KUNCI-KETIKAN').init();
    expect(client.apiKey, 'KUNCI-KETIKAN');
  });

  test('kolom kosong jatuh kembali ke yang ditanam', () async {
    // Mengosongkan kolom berarti "pakai bawaan", bukan "matikan suara AI".
    await buat(baked: 'KUNCI-BAWAAN', tersimpan: '   ').init();
    expect(client.apiKey, 'KUNCI-BAWAAN');
  });

  test('alamat server yang ditanam ikut terpakai', () async {
    await buat(bakedUrl: 'https://contoh.test/tts').init();
    expect(client.proxyUrl, 'https://contoh.test/tts');
    expect(client.isDirect, isFalse,
        reason: 'lewat server sendiri, bukan kunci telanjang');
  });

  test('tanpa apa pun, klien tahu dirinya belum diatur', () async {
    await buat().init();
    expect(client.configured, isFalse);
    expect(client.apiKey, isNull);
  });
}

class _SinkDiam implements AudioSink {
  @override
  Future<void> play(Uint8List bytes) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
  @override
  void dispose() {}
}
