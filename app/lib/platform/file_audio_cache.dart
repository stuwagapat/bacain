/// Cache audio di penyimpanan perangkat.
///
/// Ini yang membuat mendengar ulang benar-benar gratis: kalimat yang sudah
/// pernah disintesis dibaca dari berkas, tidak pernah dibayar dua kali —
/// bahkan setelah app ditutup dan dibuka lagi.
///
/// Di web tidak ada berkas, jadi di sana cache-nya hanya bertahan selama tab
/// terbuka. Cukup untuk menilai suara, dan memang bukan target utamanya.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/tts/cloud_tts.dart';

AudioCache createAudioCache() =>
    kIsWeb ? MemoryAudioCache() : FileAudioCache();

class FileAudioCache implements AudioCache {
  Directory? _dir;

  /// Cache disimpan di direktori sementara aplikasi — boleh dibersihkan
  /// sistem kalau penyimpanan menipis. Kehilangannya cuma berarti sintesis
  /// ulang, bukan kehilangan progres.
  Future<Directory> _ensure() async {
    final ada = _dir;
    if (ada != null) return ada;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/suara');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  File _file(Directory dir, String key) => File('${dir.path}/$key.mp3');

  @override
  Future<Uint8List?> get(String key) async {
    try {
      final f = _file(await _ensure(), key);
      if (!await f.exists()) return null;
      return await f.readAsBytes();
    } catch (_) {
      // Cache tidak terbaca bukan alasan berhenti membacakan.
      return null;
    }
  }

  @override
  Future<void> put(String key, Uint8List bytes) async {
    try {
      await _file(await _ensure(), key).writeAsBytes(bytes, flush: false);
    } catch (_) {
      // Penyimpanan penuh atau tidak bisa ditulis. Audionya tetap diputar;
      // hanya saja nanti disintesis ulang.
    }
  }

  /// Total ukuran cache, untuk ditampilkan di Pengaturan.
  Future<int> sizeInBytes() async {
    try {
      final dir = await _ensure();
      var total = 0;
      await for (final f in dir.list()) {
        if (f is File) total += await f.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clear() async {
    try {
      final dir = await _ensure();
      await for (final f in dir.list()) {
        if (f is File) await f.delete();
      }
    } catch (_) {
      // Sebagian gagal dihapus. Tidak ada yang rusak karenanya.
    }
  }
}
