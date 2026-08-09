/// Memberi nama manusia pada suara Google.
///
/// `id-ID-Chirp3-HD-Aoede` adalah nama model, bukan nama yang pantas dilihat
/// orang yang cuma ingin mendengarkan buku. Di sini tiap suara diberi persona
/// — nama, jenis kelamin, dan satu baris keterangan.
///
/// Pemetaannya dihitung dari daftar yang BENAR-BENAR dikembalikan Google,
/// bukan dari daftar ID yang ditulis tangan: Google menambah dan mencabut
/// suara sesukanya, dan daftar tulisan tangan akan basi diam-diam.
///
/// Persona diberikan ke suara TERBAIK yang tersedia untuk tiap jenis kelamin,
/// jadi "Ayu" selalu berarti suara perempuan terbaik yang ada hari ini —
/// bukan satu model tertentu yang bisa hilang.
library;

import 'cloud_tts.dart';

class VoicePersona {
  /// Nama yang dilihat user. Sengaja nama orang, bukan nama model.
  final String name;

  /// "perempuan" atau "laki-laki".
  final String gender;

  /// Satu baris keterangan di bawah namanya.
  final String note;

  /// Nama model Google yang sebenarnya. Tetap dipakai sebagai kunci
  /// penyimpanan dan kunci cache — nama persona bisa berubah kapan saja,
  /// nama model tidak boleh.
  final String voiceId;

  const VoicePersona({
    required this.name,
    required this.gender,
    required this.note,
    required this.voiceId,
  });

  /// Yang ditampilkan di pemilih suara.
  String get label => '$name · $gender';
}

class VoiceCatalog {
  const VoiceCatalog();

  /// Urutan nama dipakai berurutan: yang pertama untuk suara terbaik.
  static const perempuan = ['Ayu', 'Sari', 'Laras'];
  static const lakiLaki = ['Bima', 'Damar', 'Arga'];

  /// Berapa persona per jenis kelamin yang ditawarkan ke user.
  ///
  /// Satu berarti tepat dua pilihan — satu perempuan, satu laki-laki. Itu
  /// yang dipakai: pembaca buku tidak sedang memilih perangkat lunak, dan
  /// belasan nama model justru membuatnya berhenti memilih.
  static const defaultPerGender = 1;

  /// **Keterangan di bawah ini hanya menyebut apa yang bisa diperiksa dari
  /// data Google: tingkat modelnya.** Karakter suara — hangat, tenang, tegas
  /// — sengaja TIDAK ditulis di sini, karena itu cuma bisa dinilai dengan
  /// mendengarkan. Ganti kalimatnya setelah suaranya benar-benar didengar.
  static String noteFor(CloudVoice v) => switch (v.kind) {
        'Chirp3 HD' => 'model terbaru, paling halus',
        'Studio' => 'model untuk narasi panjang',
        'Neural2' => 'jernih dan stabil',
        'Polyglot' => 'jernih, terbiasa banyak bahasa',
        'WaveNet' => 'jernih, model lama yang terbukti',
        'Chirp' => 'model generasi awal',
        _ => 'paling ringan dan paling hemat',
      };

  bool _perempuan(CloudVoice v) => v.gender.toUpperCase().startsWith('F');
  bool _lakiLaki(CloudVoice v) => v.gender.toUpperCase().startsWith('M');

  /// Susun persona dari daftar suara Google.
  ///
  /// Suara yang jenis kelaminnya tidak disebutkan diabaikan — menebak jenis
  /// kelamin dari nama model adalah tebakan yang akan salah.
  List<VoicePersona> personas(
    List<CloudVoice> voices, {
    int perGender = defaultPerGender,
  }) {
    final indo = voices.where((v) => v.isIndonesian).toList()
      ..sort((a, b) {
        final byKind = CloudVoice.rank(a).compareTo(CloudVoice.rank(b));
        return byKind != 0 ? byKind : a.id.compareTo(b.id);
      });

    final out = <VoicePersona>[];
    out.addAll(_ambil(indo.where(_perempuan), perempuan, 'perempuan', perGender));
    out.addAll(_ambil(indo.where(_lakiLaki), lakiLaki, 'laki-laki', perGender));

    // Perempuan dulu lalu laki-laki, bukan selang-seling: daftar pendek lebih
    // mudah dibaca kalau dikelompokkan.
    return List.unmodifiable(out);
  }

  Iterable<VoicePersona> _ambil(
    Iterable<CloudVoice> sumber,
    List<String> nama,
    String gender,
    int berapa,
  ) sync* {
    var i = 0;
    for (final v in sumber) {
      if (i >= berapa || i >= nama.length) return;
      yield VoicePersona(
        name: nama[i],
        gender: gender,
        note: noteFor(v),
        voiceId: v.id,
      );
      i++;
    }
  }
}
