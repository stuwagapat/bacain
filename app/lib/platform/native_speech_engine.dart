/// Mesin bicara untuk platform asli — Android lebih dulu — di atas flutter_tts.
///
/// Memakai mesin TTS bawaan HP. Gratis, jalan tanpa koneksi, dan hampir semua
/// HP Android di Indonesia sudah punya suara id-ID. Suaranya masih suara
/// sistem: cukup untuk membuktikan mekaniknya, belum untuk menilai kualitas
/// narasi. Google Cloud TTS nanti masuk sebagai implementasi ketiga di
/// antarmuka yang sama, bukan bedah ulang.
library;

import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import '../core/tts/speech_engine.dart';

SpeechEngine createSpeechEngine() => NativeSpeechEngine();

class NativeSpeechEngine implements SpeechEngine {
  NativeSpeechEngine({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  /// flutter_tts mengalikan dua nilai kecepatan sebelum meneruskannya ke
  /// Android — `tts.setSpeechRate(rate * 2f)` — sedangkan kecepatan normal di
  /// Android adalah 1.0. Jadi 1.0× versi kita harus dikirim sebagai 0.5.
  /// Tanpa pembagian ini seluruh buku terbaca dua kali lebih cepat.
  static const _rateScale = 0.5;

  /// Android menolak diam-diam teks yang melewati batas panjangnya — tidak
  /// ada error, hanya tidak berbunyi. Ditanya ke sistem saat init; angka ini
  /// cuma jaring pengaman kalau jawabannya tidak masuk akal.
  static const _fallbackMaxChars = 4000;

  List<VoiceOption> _voices = const [];
  final Map<String, Map<String, String>> _byId = {};

  Completer<void>? _pending;

  /// Naik tiap kali ucapan dihentikan. Kalimat yang dipecah jadi beberapa
  /// potongan memeriksa nomor ini di antara potongan — tanpa itu, `stop()`
  /// di tengah kalimat panjang tetap dilanjutkan potongan berikutnya.
  int _run = 0;

  int _maxChars = _fallbackMaxChars;
  Map<String, String>? _appliedVoice;
  double? _appliedRate;

  @override
  List<VoiceOption> get voices => _voices;

  /// Android tidak punya jeda sungguhan: `pause()` di flutter_tts sebenarnya
  /// menghentikan ucapan lalu menyimpan sisa teksnya sendiri — keadaan yang
  /// bentrok dengan model satu-kalimat-sekali-ucap di sini. Pemutar diberi
  /// tahu supaya menjeda dengan cara lain: hentikan sekarang, ulangi kalimat
  /// yang sama dari awal saat dilanjutkan.
  @override
  bool get canPauseMidSentence => false;

  @override
  Future<void> init() async {
    _tts.setCompletionHandler(_finish);
    _tts.setCancelHandler(_finish);
    _tts.setErrorHandler((dynamic _) => _finish());

    try {
      final max = await _tts.getMaxSpeechInputLength;
      if (max != null && max > 200) _maxChars = max;
    } catch (_) {
      // Bukan Android, atau mesin TTS belum siap. Pakai angka cadangan.
    }

    try {
      if (await _tts.isLanguageAvailable('id-ID') == true) {
        await _tts.setLanguage('id-ID');
      }
    } catch (_) {
      // Bahasa akan ikut suara yang dipilih; bukan alasan menggagalkan init.
    }

    await _readVoices();
  }

  Future<void> _readVoices() async {
    List<dynamic> raw;
    try {
      raw = (await _tts.getVoices as List<dynamic>?) ?? const [];
    } catch (_) {
      return;
    }

    _byId.clear();
    final out = <VoiceOption>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = entry.map((k, v) => MapEntry('$k', '$v'));
      final name = map['name'] ?? '';
      final locale = map['locale'] ?? '';
      if (name.isEmpty || locale.isEmpty) continue;

      final id = '$name|$locale';
      if (_byId.containsKey(id)) continue;
      // setVoice mencocokkan PERSIS dua kunci ini; sisanya hanya keterangan.
      _byId[id] = {'name': name, 'locale': locale};
      out.add(VoiceOption(id: id, name: name, lang: locale));
    }

    int rank(VoiceOption v) {
      final map = _rawOf(raw, v.id);
      // Suara Indonesia dulu, lalu yang bisa jalan tanpa koneksi, lalu yang
      // kualitasnya paling tinggi. Buku didengar di jalan — suara yang minta
      // jaringan akan terputus persis saat paling dibutuhkan.
      final indo = v.isIndonesian ? 0 : 1000;
      final offline = (map?['network_required'] == '1') ? 100 : 0;
      const quality = {'very high': 0, 'high': 1, 'normal': 2, 'low': 3};
      final q = quality[map?['quality'] ?? 'normal'] ?? 2;
      return indo + offline + q;
    }

    out.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : a.name.compareTo(b.name);
    });
    _voices = List.unmodifiable(out);
  }

  Map<String, String>? _rawOf(List<dynamic> raw, String id) {
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = entry.map((k, v) => MapEntry('$k', '$v'));
      if ('${map['name']}|${map['locale']}' == id) return map;
    }
    return null;
  }

  @override
  Future<void> speakOne(String text, {String? voiceId, double rate = 1.0}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Bereskan ucapan sebelumnya supaya penunggunya tidak tertinggal.
    _finish();
    final run = _run;

    await _applyVoice(voiceId);
    await _applyRate(rate);
    if (run != _run) return;

    for (final piece in _chunk(trimmed)) {
      final completer = Completer<void>();
      _pending = completer;

      try {
        await _tts.speak(piece);
      } catch (_) {
        _finish();
        return;
      }

      // Jaring pengaman: kalau mesin TTS menelan callback selesainya, ucapan
      // tidak boleh menggantung selamanya dan mengunci seluruh bab.
      final guardMs = (piece.length * 120 / (rate <= 0 ? 1 : rate))
          .clamp(5000, 90000)
          .toInt();
      Timer(Duration(milliseconds: guardMs), () {
        if (identical(_pending, completer) && !completer.isCompleted) _finish();
      });

      await completer.future;
      // Dihentikan di tengah: jangan lanjut ke potongan berikutnya.
      if (run != _run) return;
    }
  }

  Future<void> _applyVoice(String? voiceId) async {
    final voice = voiceId != null ? _byId[voiceId] : null;
    if (voice == null || _sameVoice(voice, _appliedVoice)) return;
    try {
      await _tts.setVoice(voice);
      _appliedVoice = voice;
    } catch (_) {
      // Suara tidak ada di HP ini; biarkan mesin memakai suara bawaannya.
    }
  }

  bool _sameVoice(Map<String, String> a, Map<String, String>? b) =>
      b != null && a['name'] == b['name'] && a['locale'] == b['locale'];

  Future<void> _applyRate(double rate) async {
    if (_appliedRate == rate) return;
    try {
      await _tts.setSpeechRate((rate * _rateScale).clamp(0.0, 1.0));
      _appliedRate = rate;
    } catch (_) {
      // Kecepatan gagal dipasang bukan alasan membatalkan bacaan.
    }
  }

  /// Kalimat yang melewati batas panjang Android dipecah di batas spasi.
  /// Buku hasil OCR kadang punya "kalimat" sepanjang satu halaman penuh.
  List<String> _chunk(String text) {
    if (text.length <= _maxChars) return [text];

    final out = <String>[];
    var rest = text;
    while (rest.length > _maxChars) {
      var cut = rest.lastIndexOf(' ', _maxChars);
      if (cut <= 0) cut = _maxChars; // satu kata raksasa: potong apa adanya
      out.add(rest.substring(0, cut).trim());
      rest = rest.substring(cut).trim();
    }
    if (rest.isNotEmpty) out.add(rest);
    return out;
  }

  void _finish() {
    final c = _pending;
    _pending = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  /// Tidak pernah memanggil `flutter_tts.pause()`: di Android itu menghentikan
  /// ucapan lalu menyimpan sisa teks di dalam plugin, dan sisa itu ikut
  /// terbawa ke `speak()` berikutnya. Pemutar sudah tahu lewat
  /// [canPauseMidSentence] dan menjeda dengan caranya sendiri.
  @override
  Future<void> pause() => stop();

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {
    _run++;
    try {
      await _tts.stop();
    } catch (_) {
      // Tetap bebaskan penunggu walau mesinnya menolak berhenti.
    }
    _finish();
  }

  @override
  void dispose() {
    _run++;
    _tts.stop();
    _finish();
  }
}
