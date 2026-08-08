/// Pemilih mesin bicara per platform.
///
/// Web memakai `speechSynthesis` bawaan browser — gratis, tanpa kredensial,
/// tapi suaranya suara sistem. Android nanti memakai flutter_tts, lalu
/// Google Cloud TTS begitu kualitas suara jadi prioritas. Yang di atas
/// antarmuka ini tidak perlu tahu bedanya.
library;

export 'speech_engine_stub.dart'
    if (dart.library.js_interop) 'web_speech_engine.dart';
