import 'package:flutter_test/flutter_test.dart';

import 'package:bacain/core/scan/ocr_doubt.dart';

/// Ambil teks yang ditandai, supaya uji membaca seperti kalimatnya.
List<String> ditandai(String teks, {Map<String, double>? keyakinan}) =>
    cariKataRagu(teks, keyakinan: keyakinan)
        .map((d) => teks.substring(d.start, d.end))
        .toList();

void main() {
  group('kalimat yang bersih tidak ditandai sama sekali', () {
    test('prosa Indonesia biasa', () {
      const t = 'Manusia adalah makhluk sosial yang tidak bisa hidup sendiri. '
          'Sebagian hal ada di bawah kendali kita, sebagian lagi tidak.';
      expect(ditandai(t), isEmpty);
    });

    test('nomor halaman, nomor bab, dan angka Romawi lolos', () {
      expect(ditandai('BAB IV Halaman 128 dari 240'), isEmpty);
      expect(ditandai('XII 1998 45'), isEmpty);
    });

    test('kata satu huruf yang memang ada dalam tulisan Indonesia', () {
      // "a" pada "a.n.", "p" pada "hal. p 12" — bukan noda.
      expect(ditandai('ia pergi ke kota'), isEmpty);
    });

    test('nama diri dan singkatan huruf besar tidak dicurigai', () {
      expect(ditandai('Henry Manampiring menulis Filosofi Teras'), isEmpty);
      expect(ditandai('PBB dan WHO bertemu di NTT'), isEmpty);
    });

    test('gugus huruf mati yang wajar tetap lolos', () {
      // "ngkl" di "bengkel", "nstr" di "instrumen" — tiga huruf mati aman.
      expect(ditandai('bengkel instrumen struktur transportasi'), isEmpty);
    });
  });

  group('salah baca yang khas ditandai', () {
    test('huruf tertukar angka di tengah kata', () {
      expect(ditandai('pada har1 ke-65'), ['har1']);
      expect(ditandai('kata1 biasa'), ['kata1']);
    });

    test('satu huruf nyasar dari garis tepi atau noda', () {
      expect(ditandai('sebuah j buku'), ['j']);
      expect(ditandai('halaman t ini'), ['t']);
    });

    test('kata tanpa satu pun huruf hidup', () {
      expect(ditandai('mncl di tengah kalimat'), ['mncl']);
    });

    test('empat huruf mati berturut-turut', () {
      expect(ditandai('kata sksrpt aneh'), ['sksrpt']);
    });

    test('huruf besar nyelip di tengah kata', () {
      expect(ditandai('ilmu peNgetahuan alam'), ['peNgetahuan']);
    });

    test('beberapa kata dalam satu kalimat semuanya ketemu', () {
      final out = ditandai('pada har1 ia mnbc buku j itu');
      expect(out, ['har1', 'mnbc', 'j']);
    });
  });

  group('rentangnya menunjuk ke tempat yang benar', () {
    test('tanda baca di ujung tidak ikut ditandai', () {
      const t = 'lalu har1, kemudian pergi.';
      final d = cariKataRagu(t);
      expect(d, hasLength(1));
      expect(t.substring(d.single.start, d.single.end), 'har1');
    });

    test('kata yang sama muncul dua kali ditandai dua-duanya, di posisi masing-masing', () {
      const t = 'har1 lalu har1';
      final d = cariKataRagu(t);
      expect(d, hasLength(2));
      expect(d.first.start, 0);
      expect(d.last.start, 10);
    });

    test('teks kosong dan spasi saja tidak menjatuhkan apa pun', () {
      expect(cariKataRagu(''), isEmpty);
      expect(cariKataRagu('   \n  '), isEmpty);
    });
  });

  group('skor dari ML Kit mengalahkan tebakan bentuk', () {
    test('kata berbentuk aneh yang skornya tinggi TIDAK ditandai', () {
      // Model yang melihat gambarnya lebih tahu daripada aturan di sini.
      expect(ditandai('kata mncl aneh', keyakinan: {'mncl': 0.97}), isEmpty);
    });

    test('kata berbentuk wajar yang skornya rendah TETAP ditandai', () {
      expect(ditandai('buku yang bagus', keyakinan: {'bagus': 0.2}), ['bagus']);
    });

    test('kata tanpa skor tetap dinilai dari bentuknya', () {
      final out = ditandai('mncl dan har1', keyakinan: {'mncl': 0.99});
      expect(out, ['har1']);
    });
  });

  test('tidak menandai lebih dari sepersepuluh kalimat prosa biasa', () {
    // Penanda yang muncul di mana-mana berhenti berarti apa pun. Ambang ini
    // yang menahan aturan baru dari menjadi terlalu curiga.
    const t = 'Kegelisahan lahir ketika kita mencoba mengendalikan yang bukan '
        'urusan kita sendiri. Yang bisa kita atur hanyalah penilaian dan '
        'tindakan kita, bukan hasil akhirnya. Itulah inti dikotomi kendali '
        'yang diajarkan para filsuf Stoa sejak dua ribu tahun lalu.';
    final jumlahKata = t.split(RegExp(r'\s+')).length;
    expect(cariKataRagu(t).length, lessThan(jumlahKata / 10));
  });
}
