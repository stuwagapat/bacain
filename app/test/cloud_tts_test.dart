import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bacain/core/tts/cloud_speech_engine.dart';
import 'package:bacain/core/tts/cloud_tts.dart';
import 'package:bacain/core/tts/google_tts_client.dart';
import 'package:bacain/core/tts/speech_engine.dart';
import 'package:bacain/core/tts/tts_budget.dart';

Uint8List audio(String tanda) => Uint8List.fromList(utf8.encode('MP3:$tanda'));

/// Pemutar tiruan: mencatat apa yang diputar, tidak berbunyi.
class FakeSink implements AudioSink {
  final List<Uint8List> played = [];
  final List<String> log = [];

  @override
  Future<void> play(Uint8List bytes) async => played.add(bytes);
  @override
  Future<void> pause() async => log.add('pause');
  @override
  Future<void> resume() async => log.add('resume');
  @override
  Future<void> stop() async => log.add('stop');
  @override
  void dispose() => log.add('dispose');
}

/// Klien tiruan: menghitung berapa kali benar-benar mensintesis, supaya
/// pengiritan biaya bisa diperiksa sebagai angka.
class FakeClient implements TtsClient {
  FakeClient({this.configured = true, this.gagal = false});

  @override
  final bool configured;
  bool gagal;
  int calls = 0;
  final List<String> diminta = [];

  @override
  Future<List<CloudVoice>> voices() async => const [
        CloudVoice(id: 'id-ID-Wavenet-A', lang: 'id-ID', gender: 'FEMALE'),
        CloudVoice(id: 'id-ID-Chirp3-HD-Aoede', lang: 'id-ID', gender: 'FEMALE'),
        CloudVoice(id: 'id-ID-Standard-B', lang: 'id-ID', gender: 'MALE'),
        CloudVoice(id: 'en-US-Wavenet-A', lang: 'en-US', gender: 'FEMALE'),
      ];

  @override
  Future<Uint8List> synthesize(String text,
      {required String voiceId, double rate = 1.0}) async {
    calls++;
    diminta.add(text);
    if (gagal) throw TtsException('sedang gagal');
    return audio(text);
  }
}

void main() {
  group('kunci cache', () {
    test('teks sama dengan pengaturan sama menghasilkan kunci sama', () {
      expect(AudioCache.keyFor('Halo dunia.', 'v1', 1.0),
          AudioCache.keyFor('Halo dunia.', 'v1', 1.0));
    });

    test('suara atau kecepatan berbeda menghasilkan kunci berbeda', () {
      final a = AudioCache.keyFor('Halo.', 'v1', 1.0);
      expect(a, isNot(AudioCache.keyFor('Halo.', 'v2', 1.0)));
      expect(a, isNot(AudioCache.keyFor('Halo.', 'v1', 1.5)));
      expect(a, isNot(AudioCache.keyFor('Halo!', 'v1', 1.0)));
    });

    test('aman dipakai sebagai nama berkas', () {
      final k = AudioCache.keyFor('Judul: "Bab 1/2" — sub\\dir?', 'v', 1.0);
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(k), isTrue);
    });
  });

  group('pagu karakter harian', () {
    test('menolak begitu pagu terlampaui', () {
      final b = TtsBudget(maxCharsPerDay: 100);
      expect(b.canSpend(100), isTrue);
      b.spend(90);
      expect(b.remaining, 10);
      expect(b.canSpend(20), isFalse);
    });

    test('kembali penuh saat berganti hari', () {
      var now = DateTime(2026, 8, 8, 9);
      final b = TtsBudget(maxCharsPerDay: 100, clock: () => now);
      b.spend(100);
      expect(b.remaining, 0);
      now = now.add(const Duration(days: 1));
      expect(b.remaining, 100);
    });
  });

  group('mesin bicara cloud', () {
    late FakeClient client;
    late MemoryAudioCache cache;
    late FakeSink sink;
    late FakeSpeechEngine cadangan;
    late CloudSpeechEngine engine;

    setUp(() {
      client = FakeClient();
      cache = MemoryAudioCache();
      sink = FakeSink();
      cadangan = FakeSpeechEngine();
      engine = CloudSpeechEngine(
        client: client,
        cache: cache,
        sink: sink,
        budget: TtsBudget(maxCharsPerDay: 1000),
        fallback: cadangan,
      );
    });

    test('menawarkan dua nama manusia, bukan nama model', () async {
      await engine.init();
      expect(engine.voices.length, 2,
          reason: 'pembaca buku tidak sedang memilih perangkat lunak');
      expect(engine.voices.map((v) => v.name).toList(),
          ['Ayu · perempuan', 'Bima · laki-laki']);
      // Nama modelnya tetap dipakai di balik layar sebagai kunci penyimpanan
      // dan kunci cache — yang berganti cuma yang dilihat user.
      expect(engine.voices.first.id, 'id-ID-Chirp3-HD-Aoede',
          reason: 'nama dipetakan ke model terbaik yang tersedia');
    });

    test('daftar lengkap tetap ada untuk membandingkan saat menilai', () async {
      await engine.init();
      expect(engine.allVoices.length, 3, reason: 'suara en-US tidak relevan');
      expect(engine.allVoices.first.name, contains('Chirp3 HD'));
      expect(engine.allVoices.last.id, 'id-ID-Standard-B');
    });

    test('kalimat yang sama tidak pernah dibayar dua kali', () async {
      await engine.init();
      await engine.speakOne('Halo dunia.', voiceId: 'id-ID-Wavenet-A');
      await engine.speakOne('Halo dunia.', voiceId: 'id-ID-Wavenet-A');
      await engine.speakOne('Halo dunia.', voiceId: 'id-ID-Wavenet-A');

      expect(client.calls, 1, reason: 'sisanya harus datang dari cache');
      expect(sink.played.length, 3, reason: 'tapi tetap diputar tiap kali');
    });

    test('mengganti suara berarti sintesis baru', () async {
      await engine.init();
      await engine.speakOne('Halo.', voiceId: 'id-ID-Wavenet-A');
      await engine.speakOne('Halo.', voiceId: 'id-ID-Standard-B');
      expect(client.calls, 2);
    });

    test('pagu habis menjatuhkan ke suara sistem, bukan membisukan', () async {
      var diberitahu = 0;
      engine = CloudSpeechEngine(
        client: client,
        cache: cache,
        sink: sink,
        budget: TtsBudget(maxCharsPerDay: 5),
        fallback: cadangan,
        onBudgetExhausted: () => diberitahu++,
      );
      await engine.init();

      // Mesin cadangan meniru ucapan yang sedang berjalan, jadi jangan
      // ditunggu selesai — cukup pastikan ucapannya benar-benar dimulai.
      final berjalan = engine.speakOne(
          'Kalimat yang panjangnya lebih dari lima huruf.',
          voiceId: 'id-ID-Wavenet-A');
      await pumpEventQueue();

      expect(client.calls, 0, reason: 'tidak boleh menembus pagu');
      expect(cadangan.spoken, isNotEmpty, reason: 'harus tetap terbacakan');
      expect(diberitahu, 1);
      expect(engine.usingFallback, isTrue);

      cadangan.finishCurrent();
      await berjalan;
    });

    test('pagu tidak menghalangi mendengar ulang dari cache', () async {
      final budget = TtsBudget(maxCharsPerDay: 100);
      engine = CloudSpeechEngine(
          client: client, cache: cache, sink: sink, budget: budget,
          fallback: cadangan);
      await engine.init();

      const kalimat = 'Halo dunia.';
      await engine.speakOne(kalimat, voiceId: 'id-ID-Wavenet-A');
      budget.spend(1000); // pagu kini habis total

      await engine.speakOne(kalimat, voiceId: 'id-ID-Wavenet-A');
      expect(sink.played.length, 2,
          reason: 'yang sudah dibayar tidak boleh ikut terhalang pagu');
      expect(cadangan.spoken, isEmpty);
    });

    test('cloud gagal jatuh ke suara sistem', () async {
      await engine.init();
      client.gagal = true;
      final berjalan = engine.speakOne('Halo.', voiceId: 'id-ID-Wavenet-A');
      await pumpEventQueue();

      expect(cadangan.spoken, ['Halo.']);
      expect(engine.usingFallback, isTrue);

      cadangan.finishCurrent();
      await berjalan;
    });

    test('pesan kesalahan layanan disimpan, bukan ditelan', () async {
      // Tanpa ini, kunci salah / billing belum aktif / API belum diaktifkan
      // terlihat sama persis dari layar: "tidak terjadi apa-apa".
      final gagal = _ClientGagal(
          TtsException('API key not valid. Please pass a valid API key.'));
      engine = CloudSpeechEngine(
        client: gagal,
        cache: cache,
        sink: sink,
        budget: TtsBudget(),
        fallback: cadangan,
      );
      await engine.init();

      expect(engine.usingFallback, isTrue);
      expect(engine.lastError, contains('API key not valid'));
    });

    test('tersambung tapi tanpa suara Indonesia dilaporkan, bukan didiamkan',
        () async {
      engine = CloudSpeechEngine(
        client: _ClientTanpaSuaraIndo(),
        cache: cache,
        sink: sink,
        budget: TtsBudget(),
        fallback: cadangan,
      );
      await engine.init();
      expect(engine.usingFallback, isTrue);
      expect(engine.lastError, isNotNull);
    });

    test('kesalahan hilang setelah berhasil', () async {
      final gagal = _ClientGagal(TtsException('sedang bermasalah'));
      engine = CloudSpeechEngine(
        client: gagal,
        cache: cache,
        sink: sink,
        budget: TtsBudget(),
        fallback: cadangan,
      );
      await engine.init();
      expect(engine.lastError, isNotNull);

      gagal.pulih = true;
      await engine.init();
      expect(engine.lastError, isNull);
      expect(engine.usingFallback, isFalse);
    });

    test('tanpa kredensial langsung memakai suara sistem', () async {
      engine = CloudSpeechEngine(
        client: FakeClient(configured: false),
        cache: cache,
        sink: sink,
        budget: TtsBudget(),
        fallback: cadangan,
      );
      await engine.init();
      expect(engine.usingFallback, isTrue);
      expect(engine.voices, cadangan.voices);
    });

    test('saat jatuh ke cadangan, kemampuan jeda mengikuti mesin cadangan',
        () async {
      // Browser bisa menjeda di tengah kalimat; mesin bawaan Android tidak.
      // Mengaku tidak bisa padahal bisa membuat pemutar menjeda dengan cara
      // kasar — menghentikan lalu mengulang kalimat — tanpa alasan.
      engine = CloudSpeechEngine(
        client: FakeClient(configured: false),
        cache: cache,
        sink: sink,
        budget: TtsBudget(),
        fallback: FakeSpeechEngine(canPauseMidSentence: true),
      );
      await engine.init();
      expect(engine.usingFallback, isTrue);
      expect(engine.canPauseMidSentence, isTrue);

      engine = CloudSpeechEngine(
        client: FakeClient(configured: false),
        cache: cache,
        sink: sink,
        budget: TtsBudget(),
        fallback: FakeSpeechEngine(canPauseMidSentence: false),
      );
      await engine.init();
      expect(engine.canPauseMidSentence, isFalse);
    });

    test('audio sungguhan bisa dijeda di tengah kalimat', () async {
      await engine.init();
      await engine.speakOne('Halo.', voiceId: 'id-ID-Wavenet-A');
      expect(engine.canPauseMidSentence, isTrue,
          reason: 'ini keunggulan cloud atas mesin bawaan Android');
    });
  });

  group('klien Google', () {
    test('menyusun permintaan sintesis sesuai bentuk yang diminta Google',
        () async {
      Map<String, dynamic>? terkirim;
      final client = GoogleTtsClient(
        apiKey: 'RAHASIA',
        httpClient: MockClient((req) async {
          terkirim = jsonDecode(req.body) as Map<String, dynamic>;
          expect(req.url.queryParameters['key'], 'RAHASIA');
          return http.Response(
              jsonEncode({'audioContent': base64Encode(audio('x'))}), 200);
        }),
      );

      final bytes =
          await client.synthesize('Halo.', voiceId: 'id-ID-Wavenet-A', rate: 1.5);

      expect(bytes, audio('x'));
      expect(terkirim!['input'], {'text': 'Halo.'});
      expect(terkirim!['voice'],
          {'languageCode': 'id-ID', 'name': 'id-ID-Wavenet-A'});
      expect((terkirim!['audioConfig'] as Map)['speakingRate'], 1.5);
    });

    test('kecepatan bawaan tidak ikut dikirim', () async {
      Map<String, dynamic>? terkirim;
      final client = GoogleTtsClient(
        apiKey: 'K',
        httpClient: MockClient((req) async {
          terkirim = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
              jsonEncode({'audioContent': base64Encode(audio('x'))}), 200);
        }),
      );
      await client.synthesize('Halo.', voiceId: 'v');
      expect((terkirim!['audioConfig'] as Map).containsKey('speakingRate'),
          isFalse,
          reason: 'sebagian suara menolak parameter yang tidak didukungnya');
    });

    test('server sendiri didahulukan daripada kunci di app', () async {
      Uri? dipanggil;
      final client = GoogleTtsClient(
        apiKey: 'RAHASIA',
        proxyUrl: 'https://contoh.test/tts/',
        httpClient: MockClient((req) async {
          dipanggil = req.url;
          return http.Response(
              jsonEncode({'audioContent': base64Encode(audio('x'))}), 200);
        }),
      );
      await client.synthesize('Halo.', voiceId: 'v');

      expect(dipanggil!.host, 'contoh.test');
      expect(dipanggil!.path, '/tts/text:synthesize');
      expect(dipanggil!.queryParameters.containsKey('key'), isFalse,
          reason: 'kunci tidak boleh ikut keluar saat lewat server sendiri');
      expect(client.isDirect, isFalse);
    });

    test('kata sandi di alamat server ikut terbawa', () async {
      // Supaya kata sandi server bisa dititipkan langsung di URL-nya, tanpa
      // perlu kolom tambahan di layar Pengaturan.
      Uri? dipanggil;
      final client = GoogleTtsClient(
        proxyUrl: 'https://contoh.test/tts?s=RAHASIA',
        httpClient: MockClient((req) async {
          dipanggil = req.url;
          return http.Response(jsonEncode({'voices': []}), 200);
        }),
      );
      await client.voices();

      expect(dipanggil!.path, '/tts/voices');
      expect(dipanggil!.queryParameters['s'], 'RAHASIA');
      expect(dipanggil!.queryParameters['languageCode'], 'id-ID');
    });

    test('pesan kesalahan Google diteruskan apa adanya', () async {
      final client = GoogleTtsClient(
        apiKey: 'SALAH',
        httpClient: MockClient((req) async => http.Response(
            jsonEncode({
              'error': {'message': 'API key not valid.'}
            }),
            403)),
      );

      expect(
        () => client.synthesize('Halo.', voiceId: 'v'),
        throwsA(isA<TtsException>()
            .having((e) => e.message, 'pesan', contains('API key not valid'))
            .having((e) => e.permanent, 'permanen', isTrue)),
      );
    });

    test('hanya meminta suara Bahasa Indonesia', () async {
      Uri? dipanggil;
      final client = GoogleTtsClient(
        apiKey: 'K',
        httpClient: MockClient((req) async {
          dipanggil = req.url;
          return http.Response(
              jsonEncode({
                'voices': [
                  {
                    'name': 'id-ID-Wavenet-A',
                    'languageCodes': ['id-ID'],
                    'ssmlGender': 'FEMALE'
                  }
                ]
              }),
              200);
        }),
      );

      final v = await client.voices();
      expect(dipanggil!.queryParameters['languageCode'], 'id-ID');
      expect(v.single.id, 'id-ID-Wavenet-A');
      expect(v.single.kind, 'WaveNet');
    });

    test('belum diatur berarti belum diatur, bukan gagal misterius', () {
      final client = GoogleTtsClient();
      expect(client.configured, isFalse);
      expect(
        () => client.voices(),
        throwsA(isA<TtsException>()
            .having((e) => e.message, 'pesan', contains('belum diatur'))),
      );
    });
  });
}


/// Klien yang selalu gagal sampai [pulih] dinyalakan.
class _ClientGagal implements TtsClient {
  _ClientGagal(this.kesalahan);

  final TtsException kesalahan;
  bool pulih = false;

  @override
  bool get configured => true;

  @override
  Future<List<CloudVoice>> voices() async {
    if (pulih) {
      return const [
        CloudVoice(id: 'id-ID-Wavenet-A', lang: 'id-ID', gender: 'FEMALE'),
      ];
    }
    throw kesalahan;
  }

  @override
  Future<Uint8List> synthesize(String text,
      {required String voiceId, double rate = 1.0}) async {
    if (pulih) return audio(text);
    throw kesalahan;
  }
}

/// Tersambung baik-baik saja, tapi tidak punya suara Bahasa Indonesia.
class _ClientTanpaSuaraIndo implements TtsClient {
  @override
  bool get configured => true;

  @override
  Future<List<CloudVoice>> voices() async => const [
        CloudVoice(id: 'en-US-Wavenet-A', lang: 'en-US', gender: 'FEMALE'),
      ];

  @override
  Future<Uint8List> synthesize(String text,
          {required String voiceId, double rate = 1.0}) async =>
      audio(text);
}
