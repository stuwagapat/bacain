/// Model inti Bacain.
///
/// Sengaja polos: tidak ada Flutter, tidak ada I/O. Semua di file ini bisa
/// diuji tanpa emulator dan nanti dipakai apa adanya oleh versi Android.
library;

/// Satu bab hasil baca dari EPUB (nanti juga dari PDF / hasil scan).
class Chapter {
  /// Urutan bab di dalam buku, mulai dari 0.
  final int index;

  /// Judul dari daftar isi. Kosong kalau EPUB-nya tidak menyediakan.
  final String title;

  /// Teks bersih, paragraf dipisah baris kosong.
  final String text;

  const Chapter({required this.index, required this.title, required this.text});

  int get wordCount => countWords(text);

  @override
  String toString() => 'Chapter($index, "$title", ${wordCount}w)';
}

class Book {
  final String id;
  final String title;
  final String author;
  final List<Chapter> chapters;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.chapters,
  });

  int get wordCount => chapters.fold(0, (a, c) => a + c.wordCount);
}

/// Satu jatah dengar. Inilah unit yang dikirim ke user tiap hari.
class Segment {
  /// Urutan segmen di dalam buku, mulai dari 0.
  final int index;

  /// Judul yang ditampilkan — nama bab, atau gabungan kalau beberapa bab
  /// pendek disatukan, atau "Judul (2/3)" kalau satu bab dipecah.
  final String title;

  /// Indeks bab asal. Untuk segmen gabungan, bab yang pertama.
  final int chapterIndex;

  /// Bagian ke berapa dari babnya, mulai dari 1. Selalu 1 kalau tidak dipecah.
  final int part;

  /// Total bagian dari bab yang sama.
  final int partCount;

  final String text;

  const Segment({
    required this.index,
    required this.title,
    required this.chapterIndex,
    required this.part,
    required this.partCount,
    required this.text,
  });

  int get wordCount => countWords(text);

  /// Perkiraan durasi dengar. Dipakai untuk label "±14 menit", bukan untuk
  /// menagih kuota — kuota dihitung dari jumlah karakter di sisi server.
  Duration estimatedDuration({int wordsPerMinute = 150}) =>
      Duration(seconds: (wordCount / wordsPerMinute * 60).round());

  @override
  String toString() => 'Segment($index, "$title", ${wordCount}w)';
}

/// Hitung kata dengan memisah di spasi. Cukup untuk Bahasa Indonesia yang
/// memakai spasi antar kata; tidak cocok untuk aksara tanpa spasi.
int countWords(String text) {
  var n = 0;
  var inWord = false;
  for (var i = 0; i < text.length; i++) {
    final isSpace = _isWhitespace(text.codeUnitAt(i));
    if (!isSpace && !inWord) {
      n++;
      inWord = true;
    } else if (isSpace) {
      inWord = false;
    }
  }
  return n;
}

bool _isWhitespace(int c) =>
    c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0x0B || c == 0x0C ||
    c == 0xA0 || c == 0x2007 || c == 0x202F;
