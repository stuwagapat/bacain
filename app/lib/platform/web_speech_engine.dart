/// Mesin bicara untuk web, di atas Web Speech API bawaan browser.
///
/// Gratis, tanpa kredensial, dan di Chrome Android sudah ada suara Bahasa
/// Indonesia. Suaranya suara sistem — cukup untuk membuktikan mekaniknya,
/// belum untuk menilai kualitas narasi.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../core/tts/speech_engine.dart';

SpeechEngine createSpeechEngine() => WebSpeechEngine();

class WebSpeechEngine implements SpeechEngine {
  final web.SpeechSynthesis _synth = web.window.speechSynthesis;

  List<VoiceOption> _voices = const [];
  final Map<String, web.SpeechSynthesisVoice> _byId = {};

  Completer<void>? _pending;
  web.SpeechSynthesisUtterance? _utterance;
  Timer? _guard;
  var _stopping = false;

  @override
  List<VoiceOption> get voices => _voices;

  /// `speechSynthesis.pause()` menahan ucapan di tengah kalimat dan
  /// melanjutkannya dari titik yang sama.
  @override
  bool get canPauseMidSentence => true;

  /// Browser mengisi daftar suara secara asinkron; panggilan pertama
  /// `getVoices()` hampir selalu mengembalikan daftar kosong. Jadi dicoba
  /// beberapa kali sebentar-sebentar, bukan sekali lalu menyerah.
  @override
  Future<void> init() async {
    for (var attempt = 0; attempt < 25; attempt++) {
      _readVoices();
      if (_voices.isNotEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  void _readVoices() {
    final list = _synth.getVoices().toDart;
    if (list.isEmpty) return;
    _byId.clear();
    final out = <VoiceOption>[];
    for (final v in list) {
      final id = v.voiceURI.isNotEmpty ? v.voiceURI : v.name;
      if (_byId.containsKey(id)) continue;
      _byId[id] = v;
      out.add(VoiceOption(id: id, name: v.name, lang: v.lang));
    }
    // Suara Bahasa Indonesia didahulukan supaya jadi pilihan pertama.
    out.sort((a, b) {
      if (a.isIndonesian != b.isIndonesian) return a.isIndonesian ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    _voices = List.unmodifiable(out);
  }

  @override
  Future<void> speakOne(String text, {String? voiceId, double rate = 1.0}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return Future<void>.value();

    _finish();
    _stopping = false;

    final u = web.SpeechSynthesisUtterance(trimmed);
    final voice = voiceId != null ? _byId[voiceId] : null;
    if (voice != null) {
      u.voice = voice;
      u.lang = voice.lang;
    } else {
      u.lang = 'id-ID';
    }
    u.rate = rate;

    // `cancel()` di Chrome TIDAK mencabut keadaan "paused". Kalau user menjeda
    // lalu mengetuk kalimat lain, ucapan baru masuk antrean tapi tidak pernah
    // berbunyi — dan `onend`-nya juga tidak pernah datang. Pemutar tampak
    // hidup tapi bisu, lalu maju sendiri tiap kali penjaga waktu habis.
    if (_synth.paused) _synth.resume();

    final completer = Completer<void>();
    _pending = completer;
    _utterance = u;

    u.onend = ((web.Event _) => _finish()).toJS;
    u.onerror = ((web.Event _) => _finish()).toJS;

    // Jaring pengaman: kalau browser menelan `onend` (pernah terjadi di
    // Chrome saat tab tidak aktif), ucapan tidak boleh menggantung selamanya.
    _armGuard(completer, (trimmed.length * 90 / rate).clamp(4000, 60000).toInt());

    _synth.speak(u);
    return completer.future;
  }

  /// Penjaga waktu yang MENUNGGU, bukan menyalip.
  ///
  /// Versi sebelumnya menyelesaikan ucapan begitu perkiraan durasinya lewat,
  /// tanpa memeriksa apakah suaranya benar-benar sudah habis. Perkiraan itu
  /// tidak mungkin selalu tepat, dan tiap kali ia kecepatan akibatnya bukan
  /// sekali meleset lalu pulih:
  ///
  ///   1. pemutar maju ke kalimat berikutnya — teks mendahului suara;
  ///   2. `speak()` berikutnya masuk ANTREAN di belakang ucapan yang masih
  ///      berjalan, bukan menggantikannya;
  ///   3. selisihnya menumpuk di tiap kalimat sesudahnya.
  ///
  /// Jadi selama mesinnya masih berbunyi, penjaga ini memasang ulang dirinya.
  /// Asimetrinya disengaja: penjaga yang kecepatan merusak diam-diam, penjaga
  /// yang kelambatan cuma jadi jeda yang terlihat dan bisa ditekan ulang.
  void _armGuard(Completer<void> completer, int ms, {int sisaPercobaan = 60}) {
    _guard?.cancel();
    _guard = Timer(Duration(milliseconds: ms), () {
      if (!identical(_pending, completer) || completer.isCompleted) return;
      if ((_synth.speaking || _synth.pending) && sisaPercobaan > 0) {
        _armGuard(completer, 1000, sisaPercobaan: sisaPercobaan - 1);
        return;
      }
      _finish();
    });
  }

  void _finish() {
    _guard?.cancel();
    _guard = null;
    final c = _pending;
    _pending = null;
    _utterance = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  @override
  Future<void> pause() async {
    if (_synth.speaking && !_synth.paused) _synth.pause();
  }

  @override
  Future<void> resume() async {
    if (_synth.paused) _synth.resume();
  }

  @override
  Future<void> stop() async {
    _stopping = true;
    _synth.cancel();
    // `cancel()` memicu onend; kalau tidak, ini yang membebaskan penunggu.
    _finish();
    await _settleAfterCancel();
  }

  /// Menunggu Chrome benar-benar membereskan antrean setelah `cancel()`.
  ///
  /// Memanggil `speak()` terlalu cepat sesudah `cancel()` membuat ucapan
  /// berikutnya tidak pernah mulai — bug lama Chrome yang belum hilang. Ini
  /// jalur yang dilewati tiap kali user mengetuk kalimat untuk melompat, jadi
  /// akibatnya persis: pemutar berhenti membaca padahal statusnya "memutar".
  ///
  /// Ditunggu sampai mesinnya benar-benar diam, bukan dijeda sekian milidetik
  /// asal-asalan — batas 500 ms hanya supaya tidak menggantung selamanya.
  Future<void> _settleAfterCancel() async {
    for (var i = 0; i < 20; i++) {
      if (!_synth.speaking && !_synth.pending) return;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  bool get isStopping => _stopping;

  web.SpeechSynthesisUtterance? get currentUtterance => _utterance;

  @override
  void dispose() {
    _synth.cancel();
    _finish();
  }
}
