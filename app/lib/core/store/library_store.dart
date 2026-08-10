/// Penyimpanan rak buku dan progres.
///
/// Progres yang bertahan itu bagian dari mekaniknya, bukan pemanis: kalau
/// besok buka app lagi dan harus mengulang dari awal, seluruh gagasan serial
/// harian runtuh. Maka segmen ikut disimpan, bukan cuma nomor terakhir.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/book.dart';

class StoredBook {
  final String id;
  final String title;
  final String author;
  final List<Segment> segments;

  /// Segmen yang sedang berjalan hari ini.
  int currentIndex;

  /// Segmen terakhir yang selesai didengar, -1 kalau belum ada.
  int lastFinishedIndex;

  DateTime? lastListenedAt;

  StoredBook({
    required this.id,
    required this.title,
    required this.author,
    required this.segments,
    this.currentIndex = 0,
    this.lastFinishedIndex = -1,
    this.lastListenedAt,
  });

  Segment? get currentSegment =>
      currentIndex >= 0 && currentIndex < segments.length
          ? segments[currentIndex]
          : null;

  bool get isFinished => lastFinishedIndex >= segments.length - 1;

  /// Judul bagian yang akan didengar berikutnya. Dipakai di teks pengingat —
  /// menyebut bagian yang sudah selesai akan terasa seperti app-nya tidak
  /// mengikuti.
  String? get nextSegmentTitle {
    final next = lastFinishedIndex + 1;
    if (next < 0 || next >= segments.length) return null;
    return segments[next].title;
  }

  int get remainingCount => segments.length - (lastFinishedIndex + 1);

  /// Bagian yang sudah selesai dibagi seluruh bagian. Dipakai di rak.
  double get progress => segments.isEmpty
      ? 0
      : ((lastFinishedIndex + 1) / segments.length).clamp(0.0, 1.0);

  /// Berapa lama sejak terakhir mendengar. Dipakai untuk memutuskan apakah
  /// ringkasan "sebelumnya..." perlu ditampilkan.
  Duration? get sinceLastListened => lastListenedAt == null
      ? null
      : DateTime.now().difference(lastListenedAt!);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'currentIndex': currentIndex,
        'lastFinishedIndex': lastFinishedIndex,
        'lastListenedAt': lastListenedAt?.toIso8601String(),
        'segments': segments
            .map((s) => {
                  'index': s.index,
                  'title': s.title,
                  'chapterIndex': s.chapterIndex,
                  'part': s.part,
                  'partCount': s.partCount,
                  'text': s.text,
                })
            .toList(),
      };

  static StoredBook fromJson(Map<String, dynamic> j) => StoredBook(
        id: j['id'] as String,
        title: j['title'] as String? ?? 'Tanpa judul',
        author: j['author'] as String? ?? '',
        currentIndex: (j['currentIndex'] as num?)?.toInt() ?? 0,
        lastFinishedIndex: (j['lastFinishedIndex'] as num?)?.toInt() ?? -1,
        lastListenedAt: j['lastListenedAt'] == null
            ? null
            : DateTime.tryParse(j['lastListenedAt'] as String),
        segments: ((j['segments'] as List?) ?? const [])
            .map((e) => e as Map<String, dynamic>)
            .map((s) => Segment(
                  index: (s['index'] as num).toInt(),
                  title: s['title'] as String? ?? '',
                  chapterIndex: (s['chapterIndex'] as num?)?.toInt() ?? 0,
                  part: (s['part'] as num?)?.toInt() ?? 1,
                  partCount: (s['partCount'] as num?)?.toInt() ?? 1,
                  text: s['text'] as String? ?? '',
                ))
            .toList(),
      );
}

abstract class LibraryStore {
  Future<List<StoredBook>> load();
  Future<void> save(List<StoredBook> books);
}

class PrefsLibraryStore implements LibraryStore {
  static const _key = 'bacain.library.v1';

  @override
  Future<List<StoredBook>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => StoredBook.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Data rusak tidak boleh membuat app gagal dibuka. Lebih baik rak
      // terlihat kosong daripada layar putih.
      return [];
    }
  }

  @override
  Future<void> save(List<StoredBook> books) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(books.map((b) => b.toJson()).toList()));
  }
}

/// Penyimpanan di memori untuk uji.
class MemoryLibraryStore implements LibraryStore {
  List<StoredBook> books = [];
  int saveCount = 0;

  @override
  Future<List<StoredBook>> load() async => books;

  @override
  Future<void> save(List<StoredBook> value) async {
    books = value;
    saveCount++;
  }
}
