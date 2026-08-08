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
  var _stopping = false;

  @override
  List<VoiceOption> get voices => _voices;

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

    final completer = Completer<void>();
    _pending = completer;
    _utterance = u;

    u.onend = ((web.Event _) => _finish()).toJS;
    u.onerror = ((web.Event _) => _finish()).toJS;

    // Jaring pengaman: kalau browser menelan `onend` (pernah terjadi di
    // Chrome saat tab tidak aktif), ucapan tidak boleh menggantung selamanya.
    final guardMs = (trimmed.length * 90 / rate).clamp(4000, 60000).toInt();
    Timer(Duration(milliseconds: guardMs), () {
      if (identical(_pending, completer) && !completer.isCompleted) _finish();
    });

    _synth.speak(u);
    return completer.future;
  }

  void _finish() {
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
  }

  bool get isStopping => _stopping;

  web.SpeechSynthesisUtterance? get currentUtterance => _utterance;

  @override
  void dispose() {
    _synth.cancel();
    _finish();
  }
}
