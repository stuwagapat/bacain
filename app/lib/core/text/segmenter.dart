/// Pemecah buku jadi jatah dengar harian.
///
/// Ini mekanik inti produk: buku tidak diubah jadi satu file audio raksasa,
/// tapi jadi serial. Kalau bagian ini salah, sisanya tidak menolong.
///
/// Dua aturan yang dipegang:
///   1. Segmen TIDAK PERNAH melintasi batas bab ke arah maju secara sembarang.
///      Bab pendek boleh disatukan, bab panjang boleh dipecah, tapi sebuah
///      segmen selalu punya asal-usul bab yang jelas — itu yang dipakai
///      ringkasan "sebelumnya..." dan penamaan di daftar isi.
///   2. Potongan tidak pernah jatuh di tengah kalimat. Batas paragraf lebih
///      dulu; kalimat hanya kalau satu paragraf saja sudah kepanjangan.
library;

import '../model/book.dart';
import 'sentences.dart';

class SegmentOptions {
  /// Kecepatan baca narasi. 150 kpm angka yang lazim untuk audiobook
  /// berbahasa Indonesia dengan tempo santai.
  final int wordsPerMinute;

  /// Panjang jatah harian yang dituju.
  final int targetMinutes;

  /// Bab dipecah kalau panjangnya melebihi target dikali angka ini.
  /// Di bawah itu dibiarkan utuh walau agak lewat — lebih baik satu bab
  /// 18 menit daripada dua potongan 9 menit yang memutus alur.
  final double splitAbove;

  /// Bab boleh menyerap bab berikutnya selama masih di bawah target
  /// dikali angka ini. Menangani buku dengan puluhan bab pendek.
  final double mergeBelow;

  const SegmentOptions({
    this.wordsPerMinute = 150,
    this.targetMinutes = 15,
    this.splitAbove = 1.4,
    this.mergeBelow = 0.55,
  });

  int get targetWords => wordsPerMinute * targetMinutes;
}

class Segmenter {
  final SegmentOptions options;
  final SentenceSplitter _sentences;

  const Segmenter({
    this.options = const SegmentOptions(),
    SentenceSplitter sentences = const SentenceSplitter(),
  }) : _sentences = sentences;

  List<Segment> segment(Book book) {
    final chapters = book.chapters
        .where((c) => c.text.trim().isNotEmpty)
        .toList(growable: false);
    if (chapters.isEmpty) return const [];

    final groups = _mergeShortChapters(chapters);

    final out = <Segment>[];
    for (final group in groups) {
      final parts = _splitGroup(group);
      for (var i = 0; i < parts.length; i++) {
        out.add(Segment(
          index: out.length,
          title: parts.length == 1
              ? group.title
              : '${group.title} (${i + 1}/${parts.length})',
          chapterIndex: group.firstChapterIndex,
          part: i + 1,
          partCount: parts.length,
          text: parts[i],
        ));
      }
    }
    return out;
  }

  // ── penggabungan bab pendek ──────────────────────────────────────

  List<_Group> _mergeShortChapters(List<Chapter> chapters) {
    final target = options.targetWords;
    final mergeBelow = target * options.mergeBelow;
    final ceiling = target * options.splitAbove;

    final groups = <_Group>[];
    var i = 0;
    while (i < chapters.length) {
      final first = chapters[i];
      var words = first.wordCount;
      final members = <Chapter>[first];
      i++;

      // Serap bab berikutnya selama grup masih tergolong pendek DAN
      // hasil gabungannya belum melewati batas atas.
      while (i < chapters.length &&
          words < mergeBelow &&
          words + chapters[i].wordCount <= ceiling) {
        words += chapters[i].wordCount;
        members.add(chapters[i]);
        i++;
      }
      groups.add(_Group(members));
    }
    return groups;
  }

  // ── pemecahan bab panjang ────────────────────────────────────────

  List<String> _splitGroup(_Group group) {
    final target = options.targetWords;
    final text = group.text;
    final words = countWords(text);

    if (words <= target * options.splitAbove) return [text];

    final units = _paragraphUnits(text);
    final nParts = (words / target).round().clamp(2, units.length);
    if (nParts < 2) return [text];

    final partTarget = words / nParts;
    final parts = <List<String>>[];
    var current = <String>[];
    var currentWords = 0;

    for (var i = 0; i < units.length; i++) {
      final unit = units[i];
      final unitWords = countWords(unit);
      final partsLeft = nParts - parts.length;
      final unitsLeft = units.length - i;

      final wouldOverflow = currentWords + unitWords > partTarget * 1.15;
      // Jangan memotong kalau sisa unit tinggal pas untuk sisa bagian —
      // tanpa penjaga ini, bagian terakhir bisa jadi kosong.
      final canStillFill = unitsLeft > partsLeft - 1;

      if (current.isNotEmpty && partsLeft > 1 && wouldOverflow && canStillFill) {
        parts.add(current);
        current = <String>[];
        currentWords = 0;
      }
      current.add(unit);
      currentWords += unitWords;
    }
    if (current.isNotEmpty) parts.add(current);

    return parts.map((p) => p.join('\n\n')).toList(growable: false);
  }

  /// Pecah teks jadi unit-unit yang boleh dijadikan titik potong.
  /// Biasanya satu paragraf = satu unit; paragraf yang sendirian saja sudah
  /// melebihi target dipecah lagi per kalimat.
  List<String> _paragraphUnits(String text) {
    final paragraphs = text
        .split(RegExp(r'\n{2,}'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);

    final limit = (options.targetWords * options.splitAbove).round();
    final out = <String>[];
    for (final p in paragraphs) {
      if (countWords(p) <= limit) {
        out.add(p);
      } else {
        // Dipecah jauh lebih halus dari target, bukan sebesar limit. Kalau
        // potongannya sebesar limit, penyusun bagian di atas kehilangan
        // keleluasaan dan tiap jatah jadi jauh melenceng dari 15 menit.
        out.addAll(
            _splitParagraphBySentence(p, (options.targetWords / 3).round()));
      }
    }
    return out;
  }

  List<String> _splitParagraphBySentence(String paragraph, int limit) {
    final sentences = _sentences.split(paragraph);
    if (sentences.length < 2) return [paragraph];

    final out = <String>[];
    final buf = <String>[];
    var words = 0;
    for (final s in sentences) {
      final w = countWords(s.text);
      if (buf.isNotEmpty && words + w > limit) {
        out.add(buf.join(' '));
        buf.clear();
        words = 0;
      }
      buf.add(s.text);
      words += w;
    }
    if (buf.isNotEmpty) out.add(buf.join(' '));
    return out;
  }
}

class _Group {
  final List<Chapter> chapters;
  _Group(this.chapters);

  int get firstChapterIndex => chapters.first.index;

  String get text => chapters.map((c) => c.text.trim()).join('\n\n');

  String get title {
    final titles = chapters
        .map((c) => c.title.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (titles.isEmpty) return 'Bagian ${chapters.first.index + 1}';
    if (titles.length == 1) return titles.first;
    if (titles.length == 2) return '${titles.first} · ${titles.last}';
    return '${titles.first} … ${titles.last}';
  }
}
