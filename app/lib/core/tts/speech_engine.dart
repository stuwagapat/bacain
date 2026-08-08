/// Antarmuka mesin bicara.
///
/// Sengaja tipis dan berbasis SATU KALIMAT sekali ucap, bukan satu segmen
/// sekali ucap. Tiga alasan:
///
///   1. Chrome memutus ucapan panjang setelah belasan detik — bug lama yang
///      belum hilang. Per kalimat, batas itu tidak pernah tersentuh.
///   2. Highlight jadi tepat tanpa menghitung offset karakter: kalimat yang
///      sedang dibacakan ya kalimat yang sedang diucapkan.
///   3. Saat nanti pindah ke Google Cloud TTS, potongan per kalimat itu juga
///      unit caching yang wajar.
library;

import 'dart:async';

class VoiceOption {
  final String id;
  final String name;
  final String lang;

  const VoiceOption({required this.id, required this.name, required this.lang});

  bool get isIndonesian => lang.toLowerCase().startsWith('id');

  @override
  String toString() => '$name ($lang)';
}

abstract class SpeechEngine {
  /// Siapkan mesin. Di web ini menunggu daftar suara terisi — browser
  /// mengisinya secara asinkron dan awalnya kosong.
  Future<void> init();

  List<VoiceOption> get voices;

  /// Ucapkan satu kalimat. Future baru selesai ketika kalimatnya habis
  /// dibacakan, dibatalkan, atau gagal.
  Future<void> speakOne(String text, {String? voiceId, double rate = 1.0});

  /// Apakah mesin ini bisa menahan ucapan DI TENGAH kalimat lalu
  /// melanjutkannya dari titik yang sama.
  ///
  /// Web bisa (`speechSynthesis.pause()`). Android tidak: di sana tidak ada
  /// jeda sungguhan, yang ada hanya berhenti. Pemutar memakai keterangan ini
  /// untuk memilih cara menjeda — bukan untuk mematikan tombolnya.
  bool get canPauseMidSentence => true;

  Future<void> pause();
  Future<void> resume();

  /// Hentikan dan buang antrean. `speakOne` yang sedang berjalan harus
  /// selesai, bukan menggantung.
  Future<void> stop();

  void dispose();
}

/// Mesin tiruan untuk uji. Tidak berbunyi; hanya menyelesaikan ucapan saat
/// diminta, supaya alur pemutar bisa diperiksa langkah demi langkah.
class FakeSpeechEngine implements SpeechEngine {
  /// [canPauseMidSentence] bisa dimatikan untuk meniru Android, supaya cara
  /// menjeda di sana ikut teruji tanpa perlu HP.
  FakeSpeechEngine({this.canPauseMidSentence = true});

  final List<String> spoken = [];
  final List<String> log = [];
  Completer<void>? _current;
  var _stopped = false;

  @override
  final bool canPauseMidSentence;

  @override
  List<VoiceOption> get voices =>
      const [VoiceOption(id: 'ayu', name: 'Ayu', lang: 'id-ID')];

  @override
  Future<void> init() async => log.add('init');

  @override
  Future<void> speakOne(String text, {String? voiceId, double rate = 1.0}) {
    spoken.add(text);
    _stopped = false;
    _current = Completer<void>();
    return _current!.future;
  }

  /// Tandai kalimat yang sedang diucapkan sebagai selesai.
  void finishCurrent() {
    final c = _current;
    _current = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  bool get isSpeaking => _current != null && !_current!.isCompleted;

  @override
  Future<void> pause() async => log.add('pause');

  @override
  Future<void> resume() async => log.add('resume');

  @override
  Future<void> stop() async {
    log.add('stop');
    _stopped = true;
    finishCurrent();
  }

  bool get wasStopped => _stopped;

  @override
  void dispose() => log.add('dispose');
}
