import '../core/tts/speech_engine.dart';

/// Dipakai di platform yang belum punya mesin bicara sendiri (Android).
/// Sengaja tidak diam-diam: kalau dipanggil, jelas terlihat belum ada.
SpeechEngine createSpeechEngine() => _UnsupportedEngine();

class _UnsupportedEngine implements SpeechEngine {
  @override
  List<VoiceOption> get voices => const [];
  @override
  Future<void> init() async {}
  @override
  Future<void> speakOne(String text, {String? voiceId, double rate = 1.0}) async {
    throw UnsupportedError(
        'Mesin bicara untuk platform ini belum dipasang. Web memakai '
        'speechSynthesis; Android menyusul lewat flutter_tts.');
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
