/// Mesin bicara yang memakai Google Cloud TTS.
///
/// Implementasi ketiga dari [SpeechEngine], setelah browser dan mesin bawaan
/// HP. Antarmukanya tidak berubah sedikit pun — itu memang gunanya dipasang
/// sejak awal.
///
/// Satu keuntungan yang tidak dimiliki mesin bawaan Android: audio sungguhan
/// bisa dijeda DI TENGAH kalimat lalu dilanjutkan dari titik yang sama.
library;

import 'dart:typed_data';

import 'cloud_tts.dart';
import 'speech_engine.dart';
import 'tts_budget.dart';

class CloudSpeechEngine implements SpeechEngine {
  CloudSpeechEngine({
    required this.client,
    required this.cache,
    required this.sink,
    required this.budget,
    this.fallback,
    this.onBudgetExhausted,
  });

  final TtsClient client;
  final AudioCache cache;
  final AudioSink sink;
  final TtsBudget budget;

  /// Mesin sistem, dipakai kalau cloud gagal. Kehilangan koneksi sebaiknya
  /// menurunkan kualitas suara, bukan membuat app berhenti membacakan.
  final SpeechEngine? fallback;

  /// Dipanggil sekali saat pagu harian tersentuh, supaya UI bisa memberi
  /// tahu alih-alih diam-diam berganti suara.
  final void Function()? onBudgetExhausted;

  List<VoiceOption> _voices = const [];
  var _budgetWarned = false;
  var _usingFallback = false;
  String? _lastError;

  /// Kesalahan terakhir dari layanan suara, apa adanya. Menelan pesan ini —
  /// seperti versi sebelumnya — membuat kegagalan mustahil didiagnosis: user
  /// tidak bisa membedakan kunci salah, billing belum aktif, dan API belum
  /// diaktifkan. Ketiganya terlihat sama: "tidak terjadi apa-apa".
  String? get lastError => _lastError;

  @override
  List<VoiceOption> get voices => _voices;

  /// Audio sungguhan bisa ditahan di tengah kalimat. Tapi saat sedang jatuh
  /// ke mesin cadangan, yang berlaku kemampuan MESIN ITU — browser bisa,
  /// mesin bawaan Android tidak. Mengaku tidak bisa padahal bisa membuat
  /// pemutar menjeda dengan cara kasar tanpa alasan.
  @override
  bool get canPauseMidSentence =>
      _usingFallback ? (fallback?.canPauseMidSentence ?? false) : true;

  /// Menyala saat kalimat terakhir dibacakan mesin cadangan, bukan cloud.
  bool get usingFallback => _usingFallback;

  @override
  Future<void> init() async {
    await fallback?.init();
    _lastError = null;
    if (!client.configured) {
      _voices = fallback?.voices ?? const [];
      _usingFallback = true;
      return;
    }
    try {
      final list = await client.voices();
      final indo = list.where((v) => v.isIndonesian).toList()
        ..sort((a, b) {
          final byKind = CloudVoice.rank(a).compareTo(CloudVoice.rank(b));
          return byKind != 0 ? byKind : a.id.compareTo(b.id);
        });
      _voices = List.unmodifiable(indo
          .map((v) => VoiceOption(id: v.id, name: v.label, lang: v.lang))
          .toList());
      _usingFallback = false;
      if (_voices.isEmpty) {
        _lastError = 'Tersambung, tapi tidak ada suara Bahasa Indonesia '
            'yang dikembalikan layanan.';
        _voices = fallback?.voices ?? const [];
        _usingFallback = true;
      }
    } on TtsException catch (e) {
      // Pesan Google disimpan, bukan dibuang: itu satu-satunya petunjuk yang
      // memberi tahu user apa yang sebenarnya perlu diperbaiki.
      _lastError = e.message;
      _voices = fallback?.voices ?? const [];
      _usingFallback = true;
    } catch (e) {
      _lastError = '$e';
      _voices = fallback?.voices ?? const [];
      _usingFallback = true;
    }
  }

  @override
  Future<void> speakOne(String text, {String? voiceId, double rate = 1.0}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final bytes = await _audioFor(trimmed, voiceId, rate);
    if (bytes == null) {
      _usingFallback = true;
      await fallback?.speakOne(text, voiceId: null, rate: rate);
      return;
    }
    _usingFallback = false;
    await sink.play(bytes);
  }

  /// Mengembalikan null kalau kalimat ini tidak bisa disintesis — pemanggil
  /// yang memutuskan jatuh ke mesin cadangan.
  Future<Uint8List?> _audioFor(String text, String? voiceId, double rate) async {
    if (!client.configured || voiceId == null) return null;

    final key = AudioCache.keyFor(text, voiceId, rate);

    // Cache diperiksa SEBELUM pagu: mendengar ulang tidak menyentuh biaya,
    // jadi tidak boleh ikut terhalang pagu harian.
    final cached = await cache.get(key);
    if (cached != null) return cached;

    if (!budget.canSpend(text.length)) {
      if (!_budgetWarned) {
        _budgetWarned = true;
        onBudgetExhausted?.call();
      }
      return null;
    }

    try {
      final bytes = await client.synthesize(text, voiceId: voiceId, rate: rate);
      // Dicatat setelah berhasil: permintaan yang gagal tidak ditagih Google,
      // jadi tidak boleh ikut memakan pagu kita.
      budget.spend(text.length);
      await cache.put(key, bytes);
      _lastError = null;
      return bytes;
    } on TtsException catch (e) {
      _lastError = e.message;
      return null;
    } catch (e) {
      _lastError = '$e';
      return null;
    }
  }

  @override
  Future<void> pause() async {
    await sink.pause();
    if (_usingFallback) await fallback?.pause();
  }

  @override
  Future<void> resume() async {
    await sink.resume();
    if (_usingFallback) await fallback?.resume();
  }

  @override
  Future<void> stop() async {
    await sink.stop();
    await fallback?.stop();
  }

  @override
  void dispose() {
    sink.dispose();
    fallback?.dispose();
  }
}
