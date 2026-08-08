import 'package:flutter_test/flutter_test.dart';

import 'package:bacain/core/model/book.dart';
import 'package:bacain/core/text/normalizer.dart';
import 'package:bacain/core/text/segmenter.dart';
import 'package:bacain/core/text/sentences.dart';

/// Bangun paragraf dengan jumlah kata yang persis, supaya uji segmentasi
/// bisa memeriksa angka, bukan kira-kira.
String para(int words, {String word = 'kata'}) =>
    List.filled(words, word).join(' ');

Book bookOf(List<Chapter> chapters) =>
    Book(id: 'b', title: 'Uji', author: 'Penulis', chapters: chapters);

Chapter chap(int i, String title, String text) =>
    Chapter(index: i, title: title, text: text);

void main() {
  group('countWords', () {
    test('memisah di spasi dan mengabaikan spasi berlebih', () {
      expect(countWords('satu dua tiga'), 3);
      expect(countWords('  satu   dua  '), 2);
      expect(countWords('satu\ndua\n\ntiga'), 3);
      expect(countWords(''), 0);
      expect(countWords('   '), 0);
    });

    test('menghitung non-breaking space sebagai pemisah', () {
      expect(countWords('satu dua'), 2);
    });
  });

  group('Normalizer', () {
    const n = Normalizer();

    test('menyambung kata yang terpenggal di akhir baris', () {
      expect(n.joinHyphenated('peng-\nhasilan'), 'penghasilan');
      expect(n.joinHyphenated('meng-\n   ambil'), 'mengambil');
    });

    test('tidak menyambung kata ulang dan nama tempat', () {
      // Huruf besar di sisi kanan menandai nama diri, bukan kata terpenggal.
      expect(n.joinHyphenated('Jakarta-\nBandung'), 'Jakarta-\nBandung');
    });

    test('merapikan spasi tanpa menghapus batas paragraf', () {
      final out = n.clean('Satu   dua.\n\n\n\nTiga empat.');
      expect(out, 'Satu dua.\n\nTiga empat.');
    });

    test('membuang baris yang berulang di banyak halaman', () {
      final pages = List.generate(
        6,
        (i) => 'Filosofi Teras\nIsi halaman ${i + 1} yang berbeda.\nHalaman ${i + 1}',
      );
      final out = n.cleanPages(pages);
      expect(out, isNot(contains('Filosofi Teras')));
      expect(out, isNot(contains('Halaman 3')));
      expect(out, contains('Isi halaman 3 yang berbeda.'));
    });

    test('tidak membuang baris panjang walau berulang', () {
      final long = 'Kalimat pembuka yang panjang sekali dan berulang di tiap halaman '
          'sehingga tidak boleh dianggap sebagai header berjalan.';
      final pages = List.generate(6, (i) => '$long\nIsi $i');
      expect(n.cleanPages(pages), contains(long));
    });
  });

  group('SentenceSplitter', () {
    const s = SentenceSplitter();

    test('memecah kalimat biasa dan menjaga offset', () {
      const text = 'Satu dua. Tiga empat! Lima?';
      final out = s.split(text);
      expect(out.map((e) => e.text).toList(),
          ['Satu dua.', 'Tiga empat!', 'Lima?']);
      for (final sen in out) {
        expect(text.substring(sen.start, sen.end), sen.text);
      }
    });

    test('memotong setelah singkatan penutup enumerasi', () {
      // "dll." di Bahasa Indonesia lazim justru MENGAKHIRI kalimat.
      final out = s.split('Bawa buku, pena, dll. Lalu kita berangkat.');
      expect(out.length, 2);
      expect(out.first.text, 'Bawa buku, pena, dll.');
    });

    test('tidak memotong di singkatan yang selalu diikuti nama atau angka', () {
      expect(s.split('Lihat hlm. 42 untuk detailnya.').length, 1);
      expect(s.split('Rumahnya di Jl. Merdeka nomor tiga.').length, 1);
    });

    test('tidak memotong di angka desimal', () {
      final out = s.split('Nilainya 3.14 dan itu cukup. Selesai.');
      expect(out.length, 2);
      expect(out.first.text, 'Nilainya 3.14 dan itu cukup.');
    });

    test('tidak memotong di gelar', () {
      final out = s.split('Menurut Prof. Budi hal itu wajar. Titik.');
      expect(out.length, 2);
    });

    test('memasukkan tanda kutip penutup ke kalimat yang sama', () {
      final out = s.split('Dia berkata, "Selesai." Lalu pergi.');
      expect(out.length, 2);
      expect(out.first.text, 'Dia berkata, "Selesai."');
    });


    test('judul bab tidak menempel ke paragraf pertama', () {
      // Judul tidak berakhiran titik. Tanpa batas paragraf sebagai batas
      // kalimat, keduanya jadi satu tarikan napas saat dibacakan.
      final out = s.split('Sebuah Undangan\n\nPada hari itu ia pulang. Lalu tidur.');
      expect(out.first.text, 'Sebuah Undangan');
      expect(out.length, 3);
    });

    test('paragraf berbeda tidak pernah digabung jadi satu kalimat', () {
      final out = s.split('Satu\n\nDua\n\nTiga');
      expect(out.map((e) => e.text).toList(), ['Satu', 'Dua', 'Tiga']);
    });

    test('contains() memetakan charIndex ke kalimat yang benar', () {
      const text = 'Satu dua. Tiga empat.';
      final out = s.split(text);
      expect(out.first.contains(0), isTrue);
      expect(out.first.contains(text.indexOf('Tiga')), isFalse);
      expect(out.last.contains(text.indexOf('Tiga')), isTrue);
    });
  });

  group('Segmenter', () {
    const opts = SegmentOptions(); // 150 kpm × 15 menit = 2250 kata
    const seg = Segmenter(options: opts);

    test('bab berukuran pas jadi satu segmen', () {
      final out = seg.segment(bookOf([chap(0, 'Bab Satu', para(2000))]));
      expect(out.length, 1);
      expect(out.first.title, 'Bab Satu');
      expect(out.first.partCount, 1);
    });

    test('bab panjang dipecah, tiap potongan mendekati target', () {
      final text = List.generate(20, (_) => para(300)).join('\n\n'); // 6000 kata
      final out = seg.segment(bookOf([chap(0, 'Bab Panjang', text)]));

      expect(out.length, 3);
      expect(out.map((s) => s.title).toList(), [
        'Bab Panjang (1/3)',
        'Bab Panjang (2/3)',
        'Bab Panjang (3/3)',
      ]);
      for (final s in out) {
        expect(s.wordCount, greaterThan(1200));
        expect(s.wordCount, lessThan(3200));
      }
      // Tidak ada kata yang hilang saat dipecah.
      expect(out.fold<int>(0, (a, s) => a + s.wordCount), countWords(text));
    });

    test('bab pendek beruntun disatukan jadi satu jatah', () {
      final chapters = List.generate(6, (i) => chap(i, 'Bab ${i + 1}', para(400)));
      final out = seg.segment(bookOf(chapters));

      expect(out.length, lessThan(6),
          reason: 'enam bab 400 kata seharusnya tidak jadi enam hari terpisah');
      expect(out.first.wordCount, greaterThanOrEqualTo(1200));
      expect(out.first.chapterIndex, 0);
    });

    test('bab panjang tidak ikut disatukan dengan tetangganya', () {
      final out = seg.segment(bookOf([
        chap(0, 'Panjang', para(2200)),
        chap(1, 'Pendek', para(300)),
      ]));
      expect(out.length, 2);
      expect(out.first.title, 'Panjang');
      expect(out.last.title, 'Pendek');
    });

    test('indeks segmen berurutan tanpa lompatan', () {
      final chapters = List.generate(
        8,
        (i) => chap(i, 'Bab ${i + 1}', para(i.isEven ? 3000 : 500)),
      );
      final out = seg.segment(bookOf(chapters));
      for (var i = 0; i < out.length; i++) {
        expect(out[i].index, i);
      }
    });

    test('potongan tidak pernah jatuh di tengah kalimat', () {
      // Satu paragraf raksasa tanpa satu pun batas paragraf: pemecah wajib
      // mundur ke batas kalimat. 1500 kalimat x 4 kata = 6000 kata.
      final sentences = List.generate(1500, (i) => 'Ini kalimat nomor $i.');
      final out = seg.segment(bookOf([chap(0, 'Bab', sentences.join(' '))]));

      expect(out.length, greaterThan(1));
      for (final s in out) {
        final t = s.text.trim();
        expect(t.endsWith('.'), isTrue, reason: 'segmen "$t" terputus');
        expect(t, startsWith('Ini kalimat nomor'));
      }
    });

    test('bab kosong dilewati, bukan jadi segmen hampa', () {
      final out = seg.segment(bookOf([
        chap(0, 'Kosong', '   '),
        chap(1, 'Isi', para(1500)),
      ]));
      expect(out.length, 1);
      expect(out.first.title, 'Isi');
    });

    test('buku tanpa bab menghasilkan daftar kosong, bukan error', () {
      expect(seg.segment(bookOf([])), isEmpty);
    });

    test('bab tanpa judul diberi label cadangan', () {
      final out = seg.segment(bookOf([chap(4, '', para(1500))]));
      expect(out.first.title, 'Bagian 5');
    });

    test('perkiraan durasi masuk akal untuk satu jatah', () {
      final out = seg.segment(bookOf([chap(0, 'Bab', para(2250))]));
      expect(out.first.estimatedDuration().inMinutes, 15);
    });

    test('target yang lebih pendek menghasilkan lebih banyak segmen', () {
      final text = List.generate(20, (_) => para(300)).join('\n\n');
      final short = Segmenter(
        options: const SegmentOptions(targetMinutes: 5),
      ).segment(bookOf([chap(0, 'Bab', text)]));
      final long = seg.segment(bookOf([chap(0, 'Bab', text)]));
      expect(short.length, greaterThan(long.length));
    });
  });
}
