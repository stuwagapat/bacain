/// Pemutar audio hasil sintesis.
///
/// Kontraknya sama dengan mesin bicara: `play` baru selesai ketika audionya
/// habis, dihentikan, atau gagal — tidak boleh menggantung, karena pemutar
/// segmen menunggunya sebelum lanjut ke kalimat berikutnya.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../core/tts/cloud_tts.dart';

class PlayerAudioSink implements AudioSink {
  PlayerAudioSink({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  Completer<void>? _pending;
  StreamSubscription<void>? _done;

  /// Naik tiap kali diputus, supaya pemutaran lama tidak menyelesaikan
  /// penunggu yang sudah berganti.
  int _run = 0;

  @override
  Future<void> play(Uint8List bytes) async {
    _finish();
    final run = _run;

    final completer = Completer<void>();
    _pending = completer;

    await _done?.cancel();
    _done = _player.onPlayerComplete.listen((_) {
      if (run == _run) _finish();
    });

    try {
      await _player.play(BytesSource(bytes, mimeType: 'audio/mpeg'));
    } catch (_) {
      _finish();
      return;
    }

    // Jaring pengaman: kalau pemberitahuan selesainya tertelan, satu kalimat
    // tidak boleh mengunci seluruh bab. Panjangnya diperkirakan dari ukuran
    // berkas — MP3 128 kbps ≈ 16 KB per detik.
    final guardMs = ((bytes.length / 16000) * 1000 + 8000).clamp(8000, 180000);
    Timer(Duration(milliseconds: guardMs.toInt()), () {
      if (identical(_pending, completer) && !completer.isCompleted) _finish();
    });

    await completer.future;
  }

  void _finish() {
    final c = _pending;
    _pending = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (_) {
      // Tidak sedang memutar. Bukan masalah.
    }
  }

  @override
  Future<void> resume() async {
    try {
      await _player.resume();
    } catch (_) {
      // Tidak ada yang perlu dilanjutkan.
    }
  }

  @override
  Future<void> stop() async {
    _run++;
    try {
      await _player.stop();
    } catch (_) {
      // Tetap bebaskan penunggu walau pemutarnya menolak berhenti.
    }
    _finish();
  }

  @override
  void dispose() {
    _run++;
    _done?.cancel();
    _finish();
    _player.dispose();
  }
}
