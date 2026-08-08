/// Pemecah kalimat, dipakai untuk highlight yang mengikuti suara.
///
/// Setiap kalimat menyimpan offset aslinya di dalam teks segmen. Itu yang
/// menyambungkannya ke mesin TTS: Web Speech mengirim `charIndex` saat
/// membaca, dan dari angka itu kita tahu kalimat mana yang sedang dibacakan.
library;

class Sentence {
  /// Posisi karakter pertama di dalam teks segmen.
  final int start;

  /// Posisi tepat setelah karakter terakhir.
  final int end;

  final String text;

  const Sentence({required this.start, required this.end, required this.text});

  bool contains(int charIndex) => charIndex >= start && charIndex < end;

  @override
  String toString() => 'Sentence($start-$end, "$text")';
}

/// Singkatan yang titiknya HAMPIR TIDAK PERNAH mengakhiri kalimat, karena
/// selalu diikuti nama atau angka: "Prof. Budi", "Jl. Merdeka", "hlm. 42".
///
/// Sengaja tidak memuat "dll.", "dsb.", "dst.", "tsb." — di Bahasa Indonesia
/// singkatan penutup enumerasi itu justru lazim mengakhiri kalimat
/// ("Bawa buku, pena, dll. Lalu berangkat."). Untuk itu aturan umum yang
/// dipakai: titik diikuti spasi lalu huruf besar berarti kalimat baru.
const _neverEndsSentence = <String>{
  'hlm', 'no', 'tgl', 'jl', 'gg', 'kec', 'kab', 'prov', 'kel', 'rt', 'rw',
  'dr', 'drs', 'dra', 'ir', 'prof', 'hj', 'kh', 'st', 'mr', 'mrs', 'ms',
  'vol', 'ed', 'cet', 'terj', 'pen', 'red', 'a.n', 'u.p', 'ttd',
};

class SentenceSplitter {
  const SentenceSplitter();

  List<Sentence> split(String text) {
    final out = <Sentence>[];
    // Batas paragraf SELALU batas kalimat. Tanpa aturan ini, judul bab yang
    // tidak berakhiran titik menempel ke paragraf pertama dan ikut terbaca
    // sebagai satu tarikan napas.
    var pos = 0;
    for (final m in RegExp(r'\n{2,}').allMatches(text)) {
      _splitRange(out, text, pos, m.start);
      pos = m.end;
    }
    _splitRange(out, text, pos, text.length);
    return out;
  }

  void _splitRange(List<Sentence> out, String text, int from, int to) {
    if (to <= from) return;
    var start = from;
    var i = from;

    while (i < to) {
      final c = text[i];
      final isTerminator = c == '.' || c == '!' || c == '?' || c == '…';

      if (!isTerminator) {
        i++;
        continue;
      }

      // Lahap deretan tanda baca beruntun: "?!", "...", "!)"
      var j = i + 1;
      while (j < to && '.!?…"\')»”'.contains(text[j])) {
        j++;
      }

      if (c == '.' && _endsWithAbbreviation(text, i)) {
        i = j;
        continue;
      }

      // Kalimat baru hanya kalau setelahnya ada spasi lalu huruf besar,
      // angka, atau tanda kutip pembuka. Ini yang menjaga "3.14" dan
      // "www.contoh.com" tetap utuh.
      if (j >= to) {
        _emit(out, text, start, to);
        start = to;
        i = j;
        continue;
      }

      final gap = _whitespaceRun(text, j, to);
      if (gap == 0) {
        i = j;
        continue;
      }
      final nextIndex = j + gap;
      if (nextIndex >= to) {
        _emit(out, text, start, to);
        start = to;
        break;
      }
      if (!_startsNewSentence(text[nextIndex])) {
        i = j;
        continue;
      }

      _emit(out, text, start, j);
      start = nextIndex;
      i = nextIndex;
    }

    if (start < to) _emit(out, text, start, to);
  }

  void _emit(List<Sentence> out, String text, int from, int to) {
    // Rapikan tepi tanpa kehilangan offset asli — offset itu kontraknya
    // dengan mesin TTS.
    var s = from;
    var e = to;
    while (s < e && _isSpace(text.codeUnitAt(s))) {
      s++;
    }
    while (e > s && _isSpace(text.codeUnitAt(e - 1))) {
      e--;
    }
    if (e <= s) return;
    out.add(Sentence(start: s, end: e, text: text.substring(s, e)));
  }

  int _whitespaceRun(String text, int at, int to) {
    var n = 0;
    while (at + n < to && _isSpace(text.codeUnitAt(at + n))) {
      n++;
    }
    return n;
  }

  bool _startsNewSentence(String ch) {
    if (ch == '"' || ch == "'" || ch == '“' || ch == '‘' || ch == '«') {
      return true;
    }
    final upper = ch.toUpperCase();
    if (upper != ch.toLowerCase() && ch == upper) return true;
    return RegExp(r'\d').hasMatch(ch);
  }

  bool _endsWithAbbreviation(String text, int dotIndex) {
    var s = dotIndex;
    while (s > 0 && RegExp(r'[A-Za-zÀ-ÿ.]').hasMatch(text[s - 1])) {
      s--;
    }
    final word = text.substring(s, dotIndex).toLowerCase();
    if (word.isEmpty) return false;
    if (_neverEndsSentence.contains(word)) return true;
    // Inisial tunggal: "J. K. Rowling"
    if (word.length == 1) return true;
    return false;
  }

  bool _isSpace(int c) =>
      c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0xA0;
}
