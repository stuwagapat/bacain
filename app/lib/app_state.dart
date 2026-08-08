/// Keadaan aplikasi: rak buku, buku aktif, dan pemutar.
///
/// Aturan produk yang dijaga di sini — bukan di widget:
///   • Segmen berikutnya baru terbuka setelah yang sekarang selesai didengar.
///   • Progres disimpan tiap kali berubah, bukan saat app ditutup.
///   • Ringkasan "sebelumnya..." hanya muncul kalau jeda lebih dari sehari.
library;

import 'package:flutter/foundation.dart';

import 'core/epub/epub_reader.dart';
import 'core/model/book.dart';
import 'core/store/library_store.dart';
import 'core/text/segmenter.dart';
import 'core/tts/segment_player.dart';

class AppState extends ChangeNotifier {
  final LibraryStore store;
  final SegmentPlayer player;
  final EpubReader reader;
  final Segmenter segmenter;

  AppState({
    required this.store,
    required this.player,
    this.reader = const EpubReader(),
    this.segmenter = const Segmenter(),
  }) {
    player.addListener(_onPlayerChanged);
  }

  List<StoredBook> _books = [];
  StoredBook? _active;
  bool _busy = false;
  String? _error;

  List<StoredBook> get books => List.unmodifiable(_books);
  StoredBook? get active => _active;
  bool get busy => _busy;
  String? get error => _error;

  /// Jeda minimal sebelum ringkasan "sebelumnya..." dianggap perlu.
  static const recapAfter = Duration(hours: 24);

  bool get needsRecap {
    final b = _active;
    if (b == null || b.lastFinishedIndex < 0) return false;
    final gap = b.sinceLastListened;
    return gap != null && gap >= recapAfter;
  }

  Future<void> init() async {
    _busy = true;
    notifyListeners();
    _books = await store.load();
    await player.engine.init();
    final id = player.engine.voices
        .where((v) => v.isIndonesian)
        .map((v) => v.id)
        .firstOrNull;
    if (id != null) player.setVoice(id);
    _busy = false;
    notifyListeners();
  }

  /// Baca EPUB, pecah jadi segmen harian, masukkan ke rak.
  Future<StoredBook?> addEpub(List<int> bytes, {required String filename}) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final id = '${DateTime.now().millisecondsSinceEpoch}';
      final Book book = reader.read(bytes, id: id);
      final segments = segmenter.segment(book);
      if (segments.isEmpty) {
        throw EpubException('Buku ini terbaca kosong.');
      }
      final stored = StoredBook(
        id: id,
        title: book.title.isEmpty ? filename : book.title,
        author: book.author,
        segments: segments,
      );
      _books = [stored, ..._books];
      await store.save(_books);
      return stored;
    } on EpubException catch (e) {
      _error = e.message;
      return null;
    } catch (e) {
      _error = 'Gagal membaca berkas: $e';
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void openBook(StoredBook book) {
    _active = book;
    notifyListeners();
  }

  void closeBook() {
    player.stop();
    _active = null;
    notifyListeners();
  }

  /// Segmen mana yang boleh dibuka. Yang sudah selesai boleh diulang; yang
  /// berikutnya boleh; yang jauh di depan belum.
  bool canOpen(StoredBook book, int index) =>
      index <= book.lastFinishedIndex + 1;

  Future<void> openSegment(int index) async {
    final b = _active;
    if (b == null || index < 0 || index >= b.segments.length) return;
    if (!canOpen(b, index)) return;
    b.currentIndex = index;
    player.load(b.segments[index].text);
    await store.save(_books);
    notifyListeners();
  }

  Future<void> removeBook(StoredBook book) async {
    _books = _books.where((b) => b.id != book.id).toList();
    if (_active?.id == book.id) {
      player.stop();
      _active = null;
    }
    await store.save(_books);
    notifyListeners();
  }

  void _onPlayerChanged() {
    final b = _active;
    if (b == null) return;
    if (player.status == PlayerStatus.playing) {
      b.lastListenedAt = DateTime.now();
    }
    if (player.status == PlayerStatus.finished &&
        b.currentIndex > b.lastFinishedIndex) {
      b.lastFinishedIndex = b.currentIndex;
      store.save(_books);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    player.removeListener(_onPlayerChanged);
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
