/// Pemilih mesin bicara per platform.
///
/// Web memakai `speechSynthesis` bawaan browser; Android memakai mesin TTS
/// bawaan HP lewat flutter_tts. Keduanya gratis dan tanpa kredensial, dan
/// keduanya memakai suara sistem. Google Cloud TTS nanti masuk sebagai
/// implementasi berikutnya di antarmuka yang sama. Yang di atas antarmuka ini
/// tidak perlu tahu bedanya.
library;

export 'native_speech_engine.dart'
    if (dart.library.js_interop) 'web_speech_engine.dart';
