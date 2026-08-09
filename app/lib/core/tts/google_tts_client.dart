/// Klien Google Cloud TTS, dua jalur di satu antarmuka.
///
///   • **Lewat server sendiri** (`proxyUrl`) — jalur produksi. Kuncinya ada di
///     server, tidak pernah masuk APK, dan kuota ditegakkan di sana.
///
///   • **Langsung ke Google** (`apiKey`) — HANYA untuk menilai suaranya.
///     Kunci yang dipasang di app bisa diekstrak siapa pun dari APK dan
///     dipakai atas tagihanmu. Kuncinya diketik user saat dipakai, disimpan
///     di perangkatnya sendiri, dan tidak pernah ikut dikompilasi.
///
/// Kalau keduanya diisi, server yang menang — jalur yang aman didahulukan.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'cloud_tts.dart';

class GoogleTtsClient implements TtsClient {
  GoogleTtsClient({
    this.apiKey,
    this.proxyUrl,
    http.Client? httpClient,
    this.languageCode = 'id-ID',
  }) : _http = httpClient ?? http.Client();

  /// Bisa diubah saat berjalan: user memasukkan kredensial di Pengaturan,
  /// dan suaranya harus langsung ikut berganti tanpa app dimulai ulang.
  String? apiKey;
  String? proxyUrl;
  final String languageCode;
  final http.Client _http;

  static const _base = 'https://texttospeech.googleapis.com/v1';

  bool get _hasProxy => (proxyUrl ?? '').trim().isNotEmpty;
  bool get _hasKey => (apiKey ?? '').trim().isNotEmpty;

  @override
  bool get configured => _hasProxy || _hasKey;

  /// `true` kalau permintaan pergi langsung ke Google dengan kunci di app.
  /// Dipakai UI untuk memasang peringatan — bukan untuk melarang.
  bool get isDirect => !_hasProxy && _hasKey;

  Uri _uri(String path, [Map<String, String>? query]) {
    if (_hasProxy) {
      // Parameter yang sudah ada di alamat server DIPERTAHANKAN. Itu yang
      // membuat kata sandi server bisa dititipkan langsung di URL-nya —
      // `https://…/tts?s=RAHASIA` — tanpa perlu kolom tambahan di layar.
      final base = Uri.parse(proxyUrl!.trim());
      final bersih = base.path.replaceAll(RegExp(r'/+$'), '');
      return base.replace(
        path: '$bersih/$path',
        queryParameters: {...base.queryParameters, ...?query},
      );
    }
    return Uri.parse('$_base/$path')
        .replace(queryParameters: {...?query, 'key': apiKey!.trim()});
  }

  @override
  Future<List<CloudVoice>> voices() async {
    if (!configured) {
      throw TtsException('Suara AI belum diatur.', permanent: true);
    }

    final res = await _get(_uri('voices', {'languageCode': languageCode}));
    final body = _decode(res.body);
    final list = (body['voices'] as List?) ?? const [];

    final out = <CloudVoice>[];
    for (final item in list) {
      if (item is! Map) continue;
      final name = item['name']?.toString() ?? '';
      if (name.isEmpty) continue;
      final langs = (item['languageCodes'] as List?) ?? const [];
      out.add(CloudVoice(
        id: name,
        lang: langs.isEmpty ? languageCode : langs.first.toString(),
        gender: item['ssmlGender']?.toString() ?? '',
      ));
    }
    return out;
  }

  @override
  Future<Uint8List> synthesize(
    String text, {
    required String voiceId,
    double rate = 1.0,
  }) async {
    if (!configured) {
      throw TtsException('Suara AI belum diatur.', permanent: true);
    }

    final payload = <String, dynamic>{
      'input': {'text': text},
      'voice': {'languageCode': languageCode, 'name': voiceId},
      'audioConfig': {
        'audioEncoding': 'MP3',
        // Kecepatan hanya dikirim kalau memang diubah. Sebagian suara baru
        // menolak parameter yang tidak didukungnya, dan tidak ada gunanya
        // mengambil risiko itu untuk nilai bawaan.
        if (rate != 1.0) 'speakingRate': rate.clamp(0.25, 4.0),
      },
    };

    final res = await _post(_uri('text:synthesize'), payload);
    final body = _decode(res.body);
    final audio = body['audioContent'] as String?;
    if (audio == null || audio.isEmpty) {
      throw TtsException('Jawaban dari layanan suara tidak berisi audio.');
    }
    return base64Decode(audio);
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      return _check(await _http.get(uri));
    } on TtsException {
      rethrow;
    } catch (e) {
      throw TtsException('Tidak bisa menghubungi layanan suara: $e');
    }
  }

  Future<http.Response> _post(Uri uri, Map<String, dynamic> body) async {
    try {
      return _check(await _http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ));
    } on TtsException {
      rethrow;
    } catch (e) {
      throw TtsException('Tidak bisa menghubungi layanan suara: $e');
    }
  }

  /// Kesalahan dari Google datang sebagai JSON berisi pesan yang cukup jelas.
  /// Ditampilkan apa adanya lebih menolong daripada "gagal" tanpa keterangan.
  http.Response _check(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return res;

    var pesan = 'Layanan suara menolak (kode ${res.statusCode}).';
    try {
      final err = _decode(res.body)['error'];
      if (err is Map && err['message'] != null) {
        pesan = err['message'].toString();
      }
    } catch (_) {
      // Jawaban bukan JSON. Pakai pesan bawaan.
    }

    // 401/403 = kunci salah atau API belum diaktifkan; 429 = kuota habis.
    // Mengulang permintaan yang sama tidak akan menolong.
    final permanen = res.statusCode == 400 ||
        res.statusCode == 401 ||
        res.statusCode == 403 ||
        res.statusCode == 429;
    throw TtsException(pesan, permanent: permanen);
  }

  Map<String, dynamic> _decode(String body) {
    final v = jsonDecode(body);
    if (v is Map<String, dynamic>) return v;
    throw TtsException('Jawaban dari layanan suara tidak dikenali.');
  }
}
