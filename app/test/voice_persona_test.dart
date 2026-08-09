import 'package:flutter_test/flutter_test.dart';

import 'package:bacain/core/tts/cloud_tts.dart';
import 'package:bacain/core/tts/voice_persona.dart';

CloudVoice suara(String id, String gender, [String lang = 'id-ID']) =>
    CloudVoice(id: id, lang: lang, gender: gender);

/// Daftar yang mirip jawaban Google sungguhan: bercampur tingkat model,
/// bercampur bahasa, urutannya acak.
final daftarLengkap = [
  suara('id-ID-Standard-A', 'FEMALE'),
  suara('id-ID-Wavenet-B', 'MALE'),
  suara('id-ID-Chirp3-HD-Aoede', 'FEMALE'),
  suara('id-ID-Standard-C', 'MALE'),
  suara('id-ID-Chirp3-HD-Puck', 'MALE'),
  suara('id-ID-Wavenet-D', 'FEMALE'),
  suara('en-US-Chirp3-HD-Kore', 'FEMALE', 'en-US'),
];

void main() {
  const katalog = VoiceCatalog();

  test('menawarkan tepat dua nama: satu perempuan, satu laki-laki', () {
    final out = katalog.personas(daftarLengkap);
    expect(out.length, 2);
    expect(out.map((p) => p.name).toList(), ['Ayu', 'Bima']);
    expect(out.map((p) => p.gender).toList(), ['perempuan', 'laki-laki']);
  });

  test('tiap nama dipetakan ke model TERBAIK yang tersedia', () {
    final out = katalog.personas(daftarLengkap);
    expect(out.first.voiceId, 'id-ID-Chirp3-HD-Aoede');
    expect(out.last.voiceId, 'id-ID-Chirp3-HD-Puck');
  });

  test('nama tetap sama walau model terbaiknya berganti', () {
    // Google mencabut Chirp3; Ayu tetap Ayu, cuma modelnya turun ke WaveNet.
    final tanpaChirp = daftarLengkap
        .where((v) => !v.id.contains('Chirp3'))
        .toList();
    final out = katalog.personas(tanpaChirp);
    expect(out.first.name, 'Ayu');
    expect(out.first.voiceId, 'id-ID-Wavenet-D');
    expect(out.last.name, 'Bima');
    expect(out.last.voiceId, 'id-ID-Wavenet-B');
  });

  test('suara bahasa lain tidak pernah ikut', () {
    for (final p in katalog.personas(daftarLengkap)) {
      expect(p.voiceId, startsWith('id-ID'));
    }
  });

  test('satu jenis kelamin saja tetap menghasilkan daftar, bukan kosong', () {
    final out = katalog.personas([suara('id-ID-Wavenet-A', 'FEMALE')]);
    expect(out.length, 1);
    expect(out.single.name, 'Ayu');
  });

  test('jenis kelamin yang tidak disebutkan diabaikan, bukan ditebak', () {
    // Menebak jenis kelamin dari nama model adalah tebakan yang akan salah.
    final out = katalog.personas([
      suara('id-ID-Aneh-X', 'SSML_VOICE_GENDER_UNSPECIFIED'),
      suara('id-ID-Aneh-Y', ''),
    ]);
    expect(out, isEmpty);
  });

  test('daftar kosong tidak menjatuhkan apa pun', () {
    expect(katalog.personas(const []), isEmpty);
  });

  test('bisa diperbanyak kalau nanti dua terasa kurang', () {
    final out = katalog.personas(daftarLengkap, perGender: 2);
    expect(out.length, 4);
    expect(out.map((p) => p.name).toList(), ['Ayu', 'Sari', 'Bima', 'Damar']);
    // Tidak ada nama kembar, dan tidak ada model yang dipakai dua kali.
    expect(out.map((p) => p.name).toSet().length, 4);
    expect(out.map((p) => p.voiceId).toSet().length, 4);
  });

  test('label yang dilihat user tidak mengandung nama model', () {
    for (final p in katalog.personas(daftarLengkap)) {
      expect(p.label, isNot(contains('id-ID')));
      expect(p.label, isNot(contains('Chirp')));
      expect(p.label, anyOf(contains('perempuan'), contains('laki-laki')));
    }
  });

  test('keterangan hanya menyebut tingkat model, tidak mengarang karakter', () {
    // Karakter suara — hangat, tenang, tegas — cuma bisa dinilai dengan
    // mendengarkan. Menuliskannya tanpa mendengar sama saja mengarang.
    final teks = katalog
        .personas(daftarLengkap)
        .map((p) => p.note.toLowerCase())
        .join(' ');
    for (final karangan in ['hangat', 'tenang', 'tegas', 'ramah', 'lembut']) {
      expect(teks, isNot(contains(karangan)));
    }
  });
}
