/// Sintesis suara lewat Google Cloud TTS.
///
/// Dipisah jadi tiga bagian yang bisa ditukar sendiri-sendiri:
///
///   • [TtsClient]  — mengubah teks jadi audio. Bisa langsung ke Google
///     (untuk menilai suaranya) atau lewat server sendiri (untuk produksi).
///   • [AudioCache] — menyimpan hasilnya. Kalimat yang sudah pernah
///     disintesis TIDAK PERNAH dibayar dua kali.
///   • [AudioSink]  — memutar audionya.
///
/// Semuanya antarmuka, jadi seluruh aturan bisa diuji tanpa kredensial,
/// tanpa jaringan, dan tanpa suara.
library;

import 'dart:convert';
import 'dart:typed_data';

class TtsException implements Exception {
  final String message;

  /// `true` kalau mencoba lagi tidak akan menolong — kredensial salah, kuota
  /// habis, atau teksnya ditolak. Pemanggil memakai ini untuk memutuskan
  /// menyerah ke suara sistem alih-alih mengulang terus.
  final bool permanent;

  TtsException(this.message, {this.permanent = false});

  @override
  String toString() => 'TtsException: $message';
}

class CloudVoice {
  /// Nama persis yang diminta Google, mis. `id-ID-Wavenet-A`.
  final String id;
  final String lang;
  final String gender;

  const CloudVoice({required this.id, required this.lang, required this.gender});

  bool get isIndonesian => lang.toLowerCase().startsWith('id');

  /// Golongan suara, disimpulkan dari namanya. Ini yang paling menentukan
  /// kualitas intonasi — dan juga harganya.
  String get kind {
    final n = id.toLowerCase();
    if (n.contains('chirp3-hd') || n.contains('chirp3hd')) return 'Chirp3 HD';
    if (n.contains('chirp')) return 'Chirp';
    if (n.contains('neural2')) return 'Neural2';
    if (n.contains('wavenet')) return 'WaveNet';
    if (n.contains('polyglot')) return 'Polyglot';
    if (n.contains('studio')) return 'Studio';
    return 'Standard';
  }

  /// Suara termurah per karakter didahulukan hanya kalau kualitasnya setara;
  /// urutan ini menaruh yang terdengar paling manusiawi di atas, karena itu
  /// yang sedang dinilai.
  static int rank(CloudVoice v) => switch (v.kind) {
        'Chirp3 HD' => 0,
        'Studio' => 1,
        'Neural2' => 2,
        'Polyglot' => 3,
        'WaveNet' => 4,
        'Chirp' => 5,
        _ => 6,
      };

  String get label => '$id · $kind';

  Map<String, dynamic> toJson() => {'id': id, 'lang': lang, 'gender': gender};

  static CloudVoice fromJson(Map<String, dynamic> j) => CloudVoice(
        id: j['id'] as String? ?? '',
        lang: j['lang'] as String? ?? '',
        gender: j['gender'] as String? ?? '',
      );
}

abstract class TtsClient {
  /// `false` kalau kredensial atau alamat servernya belum diisi. Dipakai UI
  /// untuk menjelaskan keadaan, bukan untuk diam-diam gagal.
  bool get configured;

  /// Daftar suara yang tersedia. Diambil dari Google, bukan ditulis tangan —
  /// daftar yang ditulis tangan akan basi begitu Google menambah suara.
  Future<List<CloudVoice>> voices();

  /// Kembalikan audio MP3 untuk satu kalimat.
  Future<Uint8List> synthesize(
    String text, {
    required String voiceId,
    double rate = 1.0,
  });
}

/// Menyimpan audio yang sudah disintesis.
///
/// Ini yang membuat mendengar ulang tidak berbiaya: kuncinya dari teks +
/// suara + kecepatan, jadi kalimat yang sama dengan pengaturan yang sama
/// hanya dibayar sekali seumur hidup.
abstract class AudioCache {
  Future<Uint8List?> get(String key);
  Future<void> put(String key, Uint8List bytes);

  static String keyFor(String text, String voiceId, double rate) {
    final r = rate.toStringAsFixed(2);
    // Hash sederhana yang cukup: kuncinya dipakai sebagai nama berkas, jadi
    // harus pendek dan aman untuk sistem berkas.
    final raw = '$voiceId|$r|${text.trim()}';
    var h1 = 0x811c9dc5, h2 = 0x01000193;
    for (final c in utf8.encode(raw)) {
      h1 = ((h1 ^ c) * 0x01000193) & 0xFFFFFFFF;
      h2 = ((h2 + c) * 0x85ebca6b) & 0xFFFFFFFF;
    }
    return '${h1.toRadixString(16)}${h2.toRadixString(16)}'
        '-${raw.length}';
  }
}

class MemoryAudioCache implements AudioCache {
  final Map<String, Uint8List> _items = {};
  int hits = 0;
  int misses = 0;

  @override
  Future<Uint8List?> get(String key) async {
    final v = _items[key];
    v == null ? misses++ : hits++;
    return v;
  }

  @override
  Future<void> put(String key, Uint8List bytes) async => _items[key] = bytes;

  int get count => _items.length;
}

/// Pemutar audio. Future dari [play] baru selesai ketika audionya habis,
/// dibatalkan, atau gagal — sama seperti kontrak `speakOne`.
abstract class AudioSink {
  Future<void> play(Uint8List bytes);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  void dispose();
}
