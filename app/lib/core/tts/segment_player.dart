/// Pemutar satu segmen: berjalan dari kalimat ke kalimat lewat mesin bicara.
///
/// Semua logika urutan, jeda, lompat, dan penandaan kalimat aktif ada di sini
/// — bukan di widget dan bukan di mesin bicara. Itu yang membuatnya bisa
/// diuji tanpa browser dan tetap sama nanti di Android.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../text/sentences.dart';
import 'speech_engine.dart';

enum PlayerStatus { idle, playing, paused, finished }

class SegmentPlayer extends ChangeNotifier {
  final SpeechEngine engine;
  final SentenceSplitter _splitter;

  SegmentPlayer({
    required this.engine,
    SentenceSplitter splitter = const SentenceSplitter(),
  }) : _splitter = splitter;

  List<Sentence> _sentences = const [];
  int _index = -1;
  PlayerStatus _status = PlayerStatus.idle;
  String? _voiceId;
  double _rate = 1.0;

  /// Naik tiap kali pemutaran dimulai ulang. Loop yang sudah kedaluwarsa
  /// memeriksa nomor ini dan berhenti sendiri — tanpa itu, dua loop bisa
  /// berjalan bersamaan setelah user menekan putar dua kali.
  int _run = 0;
  Completer<void>? _pauseGate;

  /// Menyala kalau jeda terpaksa dilakukan dengan menghentikan ucapan, karena
  /// mesinnya tidak bisa menahan di tengah kalimat (Android). Saat dilanjutkan,
  /// kalimat yang sama diulang dari awal.
  bool _pausedByStopping = false;

  /// Dipanggil tiap kali satu kalimat SELESAI dibacakan. Dipakai untuk
  /// mencatat pemakaian jatah harian — dicatat setelah didengar, bukan saat
  /// segmen dibuka, supaya membuka lalu menutup tidak memakan jatah.
  void Function(Sentence sentence)? onSentenceCompleted;

  List<Sentence> get sentences => _sentences;
  int get index => _index;
  PlayerStatus get status => _status;
  double get rate => _rate;
  String? get voiceId => _voiceId;

  bool get isPlaying => _status == PlayerStatus.playing;
  Sentence? get current =>
      _index >= 0 && _index < _sentences.length ? _sentences[_index] : null;

  /// 0..1, berdasarkan kalimat keberapa — bukan waktu. Cukup untuk bar
  /// progres; durasi sebenarnya baru diketahui setelah dibacakan.
  double get progress =>
      _sentences.isEmpty ? 0 : (_index + 1).clamp(0, _sentences.length) / _sentences.length;

  void load(String text) {
    _stopInternal();
    _sentences = _splitter.split(text);
    _index = -1;
    _status = PlayerStatus.idle;
    notifyListeners();
  }

  void setVoice(String? id) {
    _voiceId = id;
    notifyListeners();
  }

  void setRate(double value) {
    _rate = value.clamp(0.5, 2.0);
    notifyListeners();
  }

  Future<void> play({int? from}) async {
    if (_sentences.isEmpty) return;

    final start = from ?? (_index < 0 ? 0 : _index);
    _stopInternal();
    final run = ++_run;

    _status = PlayerStatus.playing;
    _index = start;
    notifyListeners();

    for (var i = start; i < _sentences.length; i++) {
      if (run != _run) return;

      // Tahan di gerbang jeda sebelum kalimat berikutnya dimulai.
      final gate = _pauseGate;
      if (gate != null) await gate.future;
      if (run != _run) return;

      _index = i;
      notifyListeners();

      var spoken = true;
      try {
        await engine.speakOne(_sentences[i].text,
            voiceId: _voiceId, rate: _rate);
      } catch (_) {
        // Satu kalimat gagal diucapkan tidak boleh menghentikan seluruh bab.
        spoken = false;
      }
      if (run != _run) return;
      if (spoken) onSentenceCompleted?.call(_sentences[i]);
    }

    _status = PlayerStatus.finished;
    notifyListeners();
  }

  Future<void> pause() async {
    if (_status != PlayerStatus.playing) return;

    if (!engine.canPauseMidSentence) {
      // Android tidak punya jeda sungguhan. Menunggu kalimat ini habis dulu
      // akan terasa seperti tombolnya rusak, jadi ucapan dihentikan sekarang
      // juga dan kalimat yang sama diulang dari awal saat dilanjutkan.
      //
      // Loop dibatalkan LEBIH DULU supaya kalimat yang terpotong tidak
      // terhitung selesai — kalau tidak, jatah harian ikut terpotong untuk
      // kalimat yang belum sempat didengar utuh.
      final at = _index < 0 ? 0 : _index;
      _stopInternal();
      _pausedByStopping = true;
      _index = at;
      _status = PlayerStatus.paused;
      notifyListeners();
      await engine.stop();
      return;
    }

    _pauseGate ??= Completer<void>();
    _status = PlayerStatus.paused;
    notifyListeners();
    await engine.pause();
  }

  Future<void> resume() async {
    if (_status != PlayerStatus.paused) return;

    if (_pausedByStopping) {
      _pausedByStopping = false;
      _status = PlayerStatus.playing;
      notifyListeners();
      unawaited(play(from: _index < 0 ? 0 : _index));
      return;
    }

    _status = PlayerStatus.playing;
    notifyListeners();
    await engine.resume();
    final gate = _pauseGate;
    _pauseGate = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  /// `play()` baru selesai setelah SELURUH segmen habis dibacakan, jadi
  /// jangan pernah di-await dari penangan tombol — nanti tombolnya
  /// menggantung sampai bab selesai.
  Future<void> toggle() async {
    switch (_status) {
      case PlayerStatus.playing:
        await pause();
      case PlayerStatus.paused:
        await resume();
      case PlayerStatus.idle:
        unawaited(play());
      case PlayerStatus.finished:
        unawaited(play(from: 0));
    }
  }

  Future<void> stop() async {
    _stopInternal();
    _status = PlayerStatus.idle;
    notifyListeners();
    await engine.stop();
  }

  /// Lompat mundur/maju sekian kalimat lalu lanjut membacakan.
  Future<void> skipSentences(int delta) =>
      seekTo((_index < 0 ? 0 : _index) + delta);

  Future<void> seekTo(int sentenceIndex) async {
    if (_sentences.isEmpty) return;
    // Batalkan loop lama SEBELUM menghentikan mesin. Kalau dibalik, ucapan
    // yang sedang berjalan selesai lebih dulu dan loop lama sempat maju satu
    // kalimat sebelum sadar dirinya sudah kedaluwarsa.
    _stopInternal();
    await engine.stop();
    unawaited(play(from: sentenceIndex.clamp(0, _sentences.length - 1)));
  }

  void _stopInternal() {
    _run++;
    _pausedByStopping = false;
    final gate = _pauseGate;
    _pauseGate = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  void dispose() {
    _stopInternal();
    super.dispose();
  }
}
