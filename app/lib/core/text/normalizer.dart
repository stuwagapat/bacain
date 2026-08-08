/// Pembersihan teks sebelum dipecah jadi segmen.
///
/// Untuk EPUB kerjanya ringan. Bobot sesungguhnya nanti terasa di PDF dan
/// hasil OCR foto buku — makanya dipisah sejak awal, supaya jalur masuk apa
/// pun bermuara ke fungsi yang sama.
library;

class Normalizer {
  const Normalizer();

  /// Bersihkan teks satu bab.
  ///
  /// Urutannya penting: sambung kata terpenggal dulu (butuh baris asli),
  /// baru rapikan spasi.
  String clean(String raw) {
    var t = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    t = _stripSoftHyphens(t);
    t = joinHyphenated(t);
    t = _collapseSpaces(t);
    t = _collapseBlankLines(t);
    return t.trim();
  }

  /// Bersihkan sekumpulan halaman sekaligus, sambil membuang baris yang
  /// berulang di banyak halaman — nomor halaman, judul buku di kepala
  /// halaman, dan sejenisnya.
  ///
  /// Dipakai jalur PDF dan hasil scan. EPUB tidak punya konsep halaman.
  String cleanPages(List<String> pages, {double repeatRatio = 0.6}) {
    if (pages.isEmpty) return '';
    if (pages.length < 3) return clean(pages.join('\n\n'));

    // Hanya baris PALING ATAS dan PALING BAWAH tiap halaman yang dianggap
    // calon header/footer. Tanpa batasan posisi ini, kalimat isi yang cuma
    // berbeda angka ("Bab 1 dimulai", "Bab 2 dimulai") ikut terbuang —
    // karena angka disamarkan jadi '#' saat dibandingkan.
    final tally = <String, int>{};
    for (final page in pages) {
      final seen = <String>{};
      for (final key in _edgeKeys(page)) {
        if (seen.add(key)) tally[key] = (tally[key] ?? 0) + 1;
      }
    }
    final threshold = (pages.length * repeatRatio).ceil();
    final noise = tally.entries
        .where((e) => e.value >= threshold)
        .map((e) => e.key)
        .toSet();

    final kept = pages.map((page) {
      final lines = page.split('\n');
      final first = lines.indexWhere((l) => l.trim().isNotEmpty);
      final last = lines.lastIndexWhere((l) => l.trim().isNotEmpty);
      final out = <String>[];
      for (var i = 0; i < lines.length; i++) {
        final isEdge = i == first || i == last;
        if (isEdge && noise.contains(_runningHeaderKey(lines[i]))) continue;
        out.add(lines[i]);
      }
      return out.join('\n');
    });
    return clean(kept.join('\n\n'));
  }

  /// Sambung kata yang terpenggal tanda hubung di akhir baris:
  /// "peng-\nhasilan" jadi "penghasilan".
  ///
  /// Hanya digabung kalau kedua sisi huruf kecil. "Jakarta-\nBandung" dan
  /// "anak-\nanak" sengaja dibiarkan: yang pertama nama tempat, yang kedua
  /// kata ulang yang tanda hubungnya memang bagian dari kata.
  String joinHyphenated(String t) {
    return t.replaceAllMapped(
      RegExp(r'([a-zà-ÿ])-\n[ \t]*([a-zà-ÿ])'),
      (m) => '${m[1]}${m[2]}',
    );
  }

  /// Buang soft hyphen (U+00AD) — tak terlihat, tapi bikin TTS tersendat.
  String _stripSoftHyphens(String t) => t.replaceAll('­', '');

  String _collapseSpaces(String t) => t
      .replaceAll(' ', ' ')
      .replaceAllMapped(RegExp(r'[ \t]+'), (_) => ' ')
      .replaceAllMapped(RegExp(r' *\n *'), (_) => '\n');

  /// Tiga baris kosong atau lebih dirapatkan jadi satu batas paragraf.
  String _collapseBlankLines(String t) =>
      t.replaceAllMapped(RegExp(r'\n{3,}'), (_) => '\n\n');

  /// Kunci baris paling atas dan paling bawah sebuah halaman — satu-satunya
  /// posisi yang boleh dicurigai sebagai header/footer berjalan.
  List<String> _edgeKeys(String page) {
    final lines = page.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return const [];
    final keys = <String>[];
    for (final line in {lines.first, lines.last}) {
      final key = _runningHeaderKey(line);
      if (key.isNotEmpty) keys.add(key);
    }
    return keys;
  }

  /// Kunci pembanding untuk mendeteksi baris berulang. Angka diganti '#'
  /// supaya "Halaman 12" dan "Halaman 13" dianggap baris yang sama.
  /// Baris panjang tidak pernah dianggap header — itu isi.
  String _runningHeaderKey(String line) {
    final t = line.trim();
    if (t.isEmpty || t.length > 60) return '';
    return t.toLowerCase().replaceAllMapped(RegExp(r'\d+'), (_) => '#');
  }
}
