/// Menandai kata yang kemungkinan besar salah baca.
///
/// OCR takkan pernah 100% akurat, dan berpura-pura sempurna adalah cara
/// tercepat membuat user berhenti percaya. Yang jujur: tunjukkan mana yang
/// **kami** ragukan, lalu beri jalan memperbaikinya.
///
/// Dua sumber keraguan, dipakai berurutan:
///
/// 1. **Skor keyakinan dari ML Kit**, kalau ada. Ini yang paling bisa
///    dipercaya karena datang dari model yang benar-benar melihat gambarnya.
///    Sayangnya model Latin bawaan sering mengembalikan `null` di Android,
///    jadi ia tidak bisa jadi satu-satunya sumber.
/// 2. **Bentuk katanya sendiri.** Murni Dart, tidak perlu gambar, jadi bisa
///    diuji sungguhan. Aturannya sengaja sedikit dan konservatif — menandai
///    kata benar sebagai salah jauh lebih merusak kepercayaan daripada
///    melewatkan satu kata salah.
library;

/// Sepotong teks yang diragukan, dalam satuan indeks karakter pada teks utuh.
class DoubtSpan {
  final int start;
  final int end;

  const DoubtSpan(this.start, this.end);

  @override
  bool operator ==(Object other) =>
      other is DoubtSpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'DoubtSpan($start, $end)';
}

/// Huruf hidup Indonesia. Dipakai untuk menolak rentetan huruf mati yang
/// tidak mungkin muncul di kata sungguhan.
const _hidup = 'aeiouAEIOU';

/// Kata satu huruf yang memang ada dalam tulisan Indonesia. Selain ini,
/// satu huruf berdiri sendiri hampir selalu sisa noda atau garis tepi.
const _satuHurufSah = {'a', 'i', 'u', 'e', 'o', 'k', 'p', 'n'};

/// Angka Romawi — sering muncul sebagai nomor bab dan penuh huruf mati,
/// jadi harus dikecualikan sebelum aturan huruf mati bekerja.
final _romawi = RegExp(r'^[IVXLCDMivxlcdm]+$');

/// Pemisah kata. Tanda baca ikut dibuang dari ujung kata sebelum diperiksa.
final _pemisah = RegExp(r'[\s]+');
final _bersihkanUjung = RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true);

/// Di bawah nilai ini, ML Kit sendiri sudah tidak yakin.
const ambangKeyakinan = 0.55;

/// Mencari kata yang diragukan di [teks].
///
/// [keyakinan] memetakan kata (apa adanya, termasuk tanda baca) ke skor dari
/// ML Kit. Kata yang punya skor dinilai HANYA dari skornya — model yang
/// melihat gambarnya lebih tahu daripada tebakan bentuk di sini.
List<DoubtSpan> cariKataRagu(String teks, {Map<String, double>? keyakinan}) {
  final hasil = <DoubtSpan>[];
  var i = 0;

  for (final potong in teks.split(_pemisah)) {
    // Cari posisi sebenarnya di teks asli; split membuang pemisahnya.
    if (potong.isEmpty) {
      i += 1;
      continue;
    }
    final mulai = teks.indexOf(potong, i);
    if (mulai < 0) break;
    i = mulai + potong.length;

    final skor = keyakinan?[potong];
    if (skor != null) {
      if (skor < ambangKeyakinan) hasil.add(DoubtSpan(mulai, i));
      continue;
    }

    final inti = potong.replaceAll(_bersihkanUjung, '');
    if (inti.isEmpty) continue;
    if (!_meragukan(inti)) continue;

    // Rentangnya menunjuk ke intinya, bukan ke tanda bacanya — garis titik di
    // bawah koma terlihat seperti cacat render, bukan penanda.
    final geser = potong.indexOf(inti);
    hasil.add(DoubtSpan(mulai + geser, mulai + geser + inti.length));
  }

  return hasil;
}

bool _meragukan(String kata) {
  // Tanda hubung adalah pemisah di dalam kata, bukan bagian dari ejaannya:
  // "ke-65", "hari-hari", "anak-anak". Tiap sisi dinilai sendiri, kalau tidak
  // "ke-65" akan tertuduh mencampur huruf dengan angka.
  if (kata.contains('-')) {
    return kata
        .split('-')
        .where((b) => b.isNotEmpty)
        .any((b) => _meragukan(b));
  }

  // Angka murni dan angka Romawi selalu lolos: nomor halaman dan nomor bab
  // memang begitu bentuknya.
  if (RegExp(r'^\p{N}+$', unicode: true).hasMatch(kata)) return false;
  if (_romawi.hasMatch(kata)) return false;

  final huruf = kata.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');
  final angka = kata.replaceAll(RegExp(r'[^\p{N}]', unicode: true), '');

  // Huruf bercampur angka di tengah kata: "hari" jadi "har1", "l" jadi "1".
  if (huruf.isNotEmpty && angka.isNotEmpty) return true;

  if (huruf.isEmpty) return false;

  // Satu huruf berdiri sendiri yang bukan kata.
  if (huruf.length == 1) return !_satuHurufSah.contains(huruf.toLowerCase());

  // Singkatan pendek serba huruf besar — PBB, WHO, NTT, KTP. Aturan huruf
  // hidup dan gugus huruf mati di bawah dilewati untuk kata seperti ini,
  // karena singkatan memang melanggar keduanya secara sah. Batas lima huruf
  // menjaga supaya sampah OCR yang panjang tetap tertangkap.
  final serbaBesar = huruf == huruf.toUpperCase() && huruf.length <= 5;
  if (serbaBesar) return false;

  // Tidak ada huruf hidup sama sekali di kata tiga huruf atau lebih.
  if (huruf.length >= 3 && !huruf.split('').any(_hidup.contains)) return true;

  // Lima huruf mati berturut-turut. Empat masih terjadi di kata sungguhan —
  // "instrumen", "ekstrem" — jadi ambangnya harus di atas itu.
  var beruntun = 0;
  for (final c in huruf.split('')) {
    beruntun = _hidup.contains(c) ? 0 : beruntun + 1;
    if (beruntun >= 5) return true;
  }

  // Huruf besar di tengah kata, sesudah huruf kecil: "peNgetahuan".
  for (var n = 1; n < huruf.length; n++) {
    final sebelum = huruf[n - 1];
    final ini = huruf[n];
    if (sebelum == sebelum.toLowerCase() &&
        sebelum != sebelum.toUpperCase() &&
        ini == ini.toUpperCase() &&
        ini != ini.toLowerCase()) {
      return true;
    }
  }

  return false;
}
