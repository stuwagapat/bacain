/// Keadaan aplikasi: pengaturan, jatah harian, rak buku, dan pemutar.
///
/// Aturan produk dijaga di sini — bukan di widget:
///   • Jatah harian membatasi KONTEN BARU. Mendengar ulang bagian yang sudah
///     selesai selalu bebas: berkasnya sudah ada, tidak ada biaya baru, dan
///     mengunci akses ke buku sendiri cuma menyiksa.
///   • Segmen berikutnya terbuka setelah yang sekarang selesai didengar.
///   • Progres disimpan saat berubah, bukan saat app ditutup.
///   • Ringkasan "sebelumnya" hanya muncul setelah jeda lebih dari sehari.
library;

import 'package:flutter/foundation.dart';

import 'core/epub/epub_reader.dart';
import 'core/model/book.dart';
import 'core/store/library_store.dart';
import 'core/store/settings_store.dart';
import 'core/text/segmenter.dart';
import 'core/text/sentences.dart';
import 'core/tts/segment_player.dart';

class AppState extends ChangeNotifier {
  final LibraryStore store;
  final SettingsStore settingsStore;
  final SegmentPlayer player;
  final EpubReader reader;
  final Segmenter segmenter;
  final DateTime Function() clock;

  AppState({
    required this.store,
    required this.settingsStore,
    required this.player,
    this.reader = const EpubReader(),
    this.segmenter = const Segmenter(),
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now {
    quota = QuotaTracker(clock: this.clock);
    player.addListener(_onPlayerChanged);
    player.onSentenceCompleted = _onSentenceCompleted;
  }

  late QuotaTracker quota;

  List<StoredBook> _books = [];
  StoredBook? _active;
  AppSettings _settings = const AppSettings();
  bool _busy = false;
  String? _error;

  /// Menyala saat jatah baru saja habis di tengah mendengar, supaya UI bisa
  /// memunculkan layar "jatah habis" sekali — bukan berulang-ulang.
  bool quotaJustRanOut = false;

  List<StoredBook> get books => List.unmodifiable(_books);
  StoredBook? get active => _active;
  AppSettings get settings => _settings;
  bool get busy => _busy;
  String? get error => _error;

  int get remainingSeconds => quota.remainingSeconds(_settings);
  int get remainingMinutes => (remainingSeconds / 60).ceil();
  bool get quotaExhausted => quota.isExhausted(_settings);

  static const recapAfter = Duration(hours: 24);

  bool get needsRecap {
    final b = _active;
    if (b == null || b.lastFinishedIndex < 0) return false;
    if (b.currentIndex <= b.lastFinishedIndex) return false;
    final last = b.lastListenedAt;
    if (last == null) return false;
    return clock().difference(last) >= recapAfter;
  }

  /// Kalimat terakhir yang didengar dari bagian sebelumnya. Berdiri sebagai
  /// pengganti ringkasan AI sampai Claude tersambung — jujur menampilkan
  /// kalimat asli, bukan mengarang ringkasan.
  String recapText() {
    final b = _active;
    if (b == null || b.lastFinishedIndex < 0) return '';
    final prev = b.segments[b.lastFinishedIndex];
    final sentences = const SentenceSplitter().split(prev.text);
    final tail = sentences.length <= 3
        ? sentences
        : sentences.sublist(sentences.length - 3);
    return tail.map((s) => s.text).join(' ');
  }

  bool get isNewContent {
    final b = _active;
    return b != null && b.currentIndex > b.lastFinishedIndex;
  }

  Future<void> init() async {
    _busy = true;
    notifyListeners();

    _settings = await settingsStore.loadSettings();
    quota = QuotaTracker(usage: await settingsStore.loadUsage(), clock: clock);
    _books = await store.load();

    await player.engine.init();
    player.setRate(_settings.rate);
    final voice = _settings.voiceId ??
        player.engine.voices
            .where((v) => v.isIndonesian)
            .map((v) => v.id)
            .firstOrNull ??
        player.engine.voices.map((v) => v.id).firstOrNull;
    if (voice != null) player.setVoice(voice);

    _busy = false;
    notifyListeners();
  }

  // ── pengaturan ───────────────────────────────────────────────────

  Future<void> updateSettings(AppSettings next) async {
    _settings = next;
    player.setRate(next.rate);
    if (next.voiceId != null) player.setVoice(next.voiceId);
    await settingsStore.saveSettings(next);
    notifyListeners();
  }

  Future<void> completeOnboarding({
    required int hour,
    required int minute,
    required bool reminderOn,
  }) =>
      updateSettings(_settings.copyWith(
        onboarded: true,
        reminderHour: hour,
        reminderMinute: minute,
        reminderOn: reminderOn,
      ));

  /// Hanya untuk uji coba: kembalikan jatah hari ini supaya alurnya bisa
  /// dicoba berulang tanpa menunggu besok.
  Future<void> resetQuota() async {
    quota.reset();
    await settingsStore.saveUsage(quota.usage);
    quotaJustRanOut = false;
    notifyListeners();
  }

  // ── rak buku ─────────────────────────────────────────────────────

  Future<Book?> parseEpub(List<int> bytes, {required String filename}) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      return reader.read(bytes, id: '${clock().millisecondsSinceEpoch}');
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

  List<Segment> previewSegments(Book book) => segmenter.segment(book);

  /// Berapa hari kira-kira buku ini habis, dengan jatah harian sekarang.
  int estimatedDays(List<Segment> segments) {
    final total = segments.fold<int>(
        0, (a, s) => a + s.estimatedDuration().inSeconds);
    final perDay = _settings.dailyBudget.inSeconds;
    if (perDay <= 0) return segments.length;
    return (total / perDay).ceil().clamp(1, 9999);
  }

  Future<StoredBook?> addBook(Book book, List<Segment> segments) async {
    if (segments.isEmpty) {
      _error = 'Buku ini terbaca kosong.';
      notifyListeners();
      return null;
    }
    final stored = StoredBook(
      id: book.id,
      title: book.title,
      author: book.author,
      segments: segments,
    );
    _books = [stored, ..._books];
    await store.save(_books);
    notifyListeners();
    return stored;
  }

  /// Jalur singkat: baca, pecah, masukkan — dipakai tombol "buku contoh".
  Future<StoredBook?> addEpub(List<int> bytes, {required String filename}) async {
    final book = await parseEpub(bytes, filename: filename);
    if (book == null) return null;
    return addBook(book, previewSegments(book));
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

  bool canOpen(StoredBook book, int index) =>
      index <= book.lastFinishedIndex + 1;

  Future<void> openSegment(int index) async {
    final b = _active;
    if (b == null || index < 0 || index >= b.segments.length) return;
    if (!canOpen(b, index)) return;
    b.currentIndex = index;
    quotaJustRanOut = false;
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

  // ── jatah harian ─────────────────────────────────────────────────

  void _onSentenceCompleted(Sentence sentence) {
    // Mendengar ulang bagian yang sudah selesai tidak memakan jatah.
    if (!isNewContent) return;

    final words = countWords(sentence.text);
    final seconds =
        (words / 150 * 60 / player.rate).round().clamp(1, 600);
    quota.spend(seconds);
    settingsStore.saveUsage(quota.usage);

    if (quota.isExhausted(_settings) && player.isPlaying) {
      quotaJustRanOut = true;
      player.pause();
    }
    notifyListeners();
  }

  void _onPlayerChanged() {
    final b = _active;
    if (b == null) return;
    if (player.status == PlayerStatus.playing) {
      b.lastListenedAt = clock();
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
    player.onSentenceCompleted = null;
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
