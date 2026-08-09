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

import 'core/build_config.dart';
import 'core/epub/epub_reader.dart';
import 'core/model/book.dart';
import 'core/pdf/pdf_reader.dart';
import 'core/playback/keep_awake.dart';
import 'core/scan/page_scanner.dart';
import 'core/scan/scan_import.dart';
import 'core/reminders/reminder_plan.dart';
import 'core/reminders/reminders.dart';
import 'core/store/library_store.dart';
import 'core/store/settings_store.dart';
import 'core/text/segmenter.dart';
import 'core/text/sentences.dart';
import 'core/tts/cloud_speech_engine.dart';
import 'core/tts/google_tts_client.dart';
import 'core/tts/segment_player.dart';

class AppState extends ChangeNotifier {
  final LibraryStore store;
  final SettingsStore settingsStore;
  final SegmentPlayer player;
  final EpubReader reader;
  final PdfReader pdfReader;
  final Segmenter segmenter;
  final Reminders reminders;
  final ReminderPlanner planner;
  final KeepAwake keepAwake;
  final PageScanner scanner;
  final ScanImport scanImport;

  /// Kredensial yang ditanam saat build. Yang diketik user di Pengaturan
  /// menang atas ini — supaya build resmi bisa ditimpa saat mencoba kunci
  /// lain tanpa membangun ulang.
  final String bakedTtsProxyUrl;
  final String bakedTtsApiKey;

  final DateTime Function() clock;

  AppState({
    required this.store,
    required this.settingsStore,
    required this.player,
    this.reader = const EpubReader(),
    this.pdfReader = const PdfReader(),
    this.segmenter = const Segmenter(),
    Reminders? reminders,
    KeepAwake? keepAwake,
    PageScanner? scanner,
    this.scanImport = const ScanImport(),
    this.planner = const ReminderPlanner(),
    this.bakedTtsProxyUrl = BuildConfig.ttsProxyUrl,
    this.bakedTtsApiKey = BuildConfig.ttsApiKey,
    DateTime Function()? clock,
  })  : clock = clock ?? DateTime.now,
        reminders = reminders ?? NoopReminders(),
        keepAwake = keepAwake ?? NoopKeepAwake(),
        scanner = scanner ?? UnavailableScanner() {
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

    await _applyTtsConfig();
    player.setRate(_settings.rate);
    _busy = false;
    notifyListeners();
    await syncReminders();
  }

  /// Jadwal pengingat ditulis ulang tiap kali sesuatu yang memengaruhinya
  /// berubah: jam, tombol pengingat, buku yang sedang dibaca, atau progresnya.
  /// Selalu menimpa seluruh jadwal — menambah akan menumpuk diam-diam.
  ///
  /// Dijadwalkan beberapa hari ke depan sekaligus supaya kalimatnya tetap
  /// berganti walau app-nya lama tidak dibuka.
  Future<void> syncReminders() async {
    if (!_settings.reminderOn) {
      await reminders.cancelAll();
      return;
    }
    final book = _nextUp;
    await reminders.replaceAll(planner.plan(
      clock(),
      _settings,
      bookTitle: book?.title,
      segmentTitle: book?.nextSegmentTitle,
      minutes: _settings.dailyMinutes,
    ));
  }

  /// Buku yang paling wajar dilanjutkan: yang terakhir didengar dan belum
  /// tamat. Dipakai untuk menyebut nama buku di teks pengingat.
  StoredBook? get _nextUp {
    final belum = _books.where((b) => !b.isFinished).toList();
    if (belum.isEmpty) return null;
    belum.sort((a, b) {
      final ta = a.lastListenedAt, tb = b.lastListenedAt;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    return belum.first;
  }

  // ── pengaturan ───────────────────────────────────────────────────

  Future<void> updateSettings(AppSettings next) async {
    final kredensialBerubah = next.ttsProxyUrl != _settings.ttsProxyUrl ||
        next.ttsApiKey != _settings.ttsApiKey;
    _settings = next;
    player.setRate(next.rate);
    if (next.voiceId != null) player.setVoice(next.voiceId);
    await settingsStore.saveSettings(next);

    // Kredensial baru harus langsung terasa: daftar suara diambil ulang dan
    // suaranya berganti tanpa app dimulai ulang.
    if (kredensialBerubah) await _applyTtsConfig();

    notifyListeners();
    await syncReminders();
  }

  /// Menyambungkan ulang ke layanan suara, apa pun keadaannya.
  ///
  /// Perlu terpisah karena `updateSettings` hanya menyambung ulang saat
  /// kredensialnya BERUBAH. Tanpa ini, menekan "Sambungkan" setelah gagal —
  /// tanpa mengubah apa pun — tidak melakukan apa-apa, dan itu persis gejala
  /// yang paling membingungkan.
  Future<void> reconnectTts() async {
    await _applyTtsConfig();
    notifyListeners();
  }

  /// Menyalakan mesin bicara dengan kredensial yang tersimpan, lalu memilih
  /// suara. Dipanggil saat app dibuka dan tiap kali kredensialnya berubah.
  Future<void> _applyTtsConfig() async {
    final engine = player.engine;
    if (engine is CloudSpeechEngine) {
      final client = engine.client;
      if (client is GoogleTtsClient) {
        client.proxyUrl = _pilih(_settings.ttsProxyUrl, bakedTtsProxyUrl);
        client.apiKey = _pilih(_settings.ttsApiKey, bakedTtsApiKey);
      }
    }

    await player.engine.init();
    await _pickVoice();
  }

  /// Yang diketik user menang; kalau kosong, pakai yang ditanam saat build.
  static String? _pilih(String? diketik, String tertanam) {
    final t = (diketik ?? '').trim();
    if (t.isNotEmpty) return t;
    return tertanam.trim().isEmpty ? null : tertanam.trim();
  }

  /// `true` kalau suara AI bisa jalan tanpa user mengetik apa pun.
  bool get ttsBakedIn => BuildConfig.hasBakedTts;

  /// Suara tersimpan dipakai kalau masih ada di daftar. Kalau tidak — misalnya
  /// kredensial baru dipasang dan daftarnya berganti total — pilih yang
  /// pertama, karena daftarnya sudah diurutkan dari yang terbaik.
  Future<void> _pickVoice() async {
    final tersedia = player.engine.voices;
    if (tersedia.isEmpty) return;

    final tersimpan = _settings.voiceId;
    if (tersimpan != null && tersedia.any((v) => v.id == tersimpan)) {
      player.setVoice(tersimpan);
      return;
    }

    final indo = tersedia.where((v) => v.isIndonesian);
    final dipilih = (indo.isNotEmpty ? indo.first : tersedia.first).id;
    player.setVoice(dipilih);

    // Ikut disimpan. Tanpa ini `settings.voiceId` masih menunjuk suara lama
    // yang sudah tidak ada di daftar — dan pemilih suara di Pengaturan
    // menunjuk nilai yang tidak punya pilihan yang cocok.
    _settings = _settings.copyWith(voiceId: dipilih);
    await settingsStore.saveSettings(_settings);
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

  /// Kalimat contoh untuk mencicipi suara. Sengaja dipilih yang menuntut
  /// intonasi: ada koma, tanda tanya, nama diri, dan angka — empat hal yang
  /// paling sering membuat mesin bicara terdengar kaku.
  static const voiceSample =
      'Pada bab keempat, Epictetus bertanya: apa yang sungguh-sungguh ada '
      'dalam kendali kita? Ternyata tidak banyak — hanya tiga hal.';

  /// Membacakan kalimat contoh dengan suara tertentu, tanpa mengganggu
  /// bagian yang sedang dibuka di pemutar.
  Future<void> previewVoice(String voiceId) async {
    await player.engine.stop();
    try {
      await player.engine
          .speakOne(voiceSample, voiceId: voiceId, rate: _settings.rate);
    } catch (_) {
      // Gagal mencicip bukan alasan menjatuhkan layar Pengaturan.
    }
  }

  /// Hanya untuk uji coba: kembalikan jatah hari ini supaya alurnya bisa
  /// dicoba berulang tanpa menunggu besok.
  Future<void> resetQuota() async {
    quota.reset();
    await settingsStore.saveUsage(quota.usage);
    quotaJustRanOut = false;
    notifyListeners();
  }

  // ── rak buku ─────────────────────────────────────────────────────

  /// Berkas dikenali dari TANDA TANGAN ISINYA, bukan dari ekstensi nama.
  /// Orang sering menyimpan PDF dengan nama .epub atau sebaliknya, dan
  /// ekstensi yang salah tidak boleh berujung "berkas rusak".
  static bool looksLikePdf(List<int> b) =>
      b.length > 4 &&
      b[0] == 0x25 && // %
      b[1] == 0x50 && // P
      b[2] == 0x44 && // D
      b[3] == 0x46; //  F

  Future<Book?> parseFile(List<int> bytes, {required String filename}) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final id = '${clock().millisecondsSinceEpoch}';
      final isPdf = looksLikePdf(bytes) ||
          (bytes.length <= 4 && filename.toLowerCase().endsWith('.pdf'));
      return isPdf
          ? pdfReader.read(bytes, id: id, filename: filename)
          : reader.read(bytes, id: id);
    } on EpubException catch (e) {
      _error = e.message;
      return null;
    } on PdfException catch (e) {
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

  Future<Book?> parseEpub(List<int> bytes, {required String filename}) =>
      parseFile(bytes, filename: filename);

  /// Halaman hasil foto — sudah lewat layar tinjau — jadi buku.
  Future<Book?> buildScanned(
    List<ScannedPage> pages, {
    required String title,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      return scanImport.build(
        pages.map((p) => p.text).toList(),
        id: '${clock().millisecondsSinceEpoch}',
        title: title,
      );
    } on ScanException catch (e) {
      _error = e.message;
      return null;
    } catch (e) {
      _error = 'Gagal menyusun buku: $e';
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
    // Pengingat menyebut nama buku, jadi harus ikut berubah begitu raknya
    // berubah — kalau tidak, teksnya masih menyebut rak kosong.
    await syncReminders();
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
    await syncReminders();
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
    _syncKeepAwake(b);
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

  /// Layanan latar depan hanya hidup selagi benar-benar membacakan. Dijeda,
  /// selesai, atau berhenti — layanannya ikut mati, supaya tidak ada
  /// notifikasi menggantung yang mengaku sedang membacakan padahal tidak.
  bool _awake = false;

  void _syncKeepAwake(StoredBook book) {
    final perlu = player.status == PlayerStatus.playing;
    if (perlu == _awake) return;
    _awake = perlu;
    if (perlu) {
      keepAwake.start(
        title: book.title,
        text: book.currentSegment?.title ?? 'Sedang membacakan',
      );
    } else {
      keepAwake.stop();
    }
  }

  @override
  void dispose() {
    keepAwake.stop();
    player.removeListener(_onPlayerChanged);
    player.onSentenceCompleted = null;
    super.dispose();
  }
}
