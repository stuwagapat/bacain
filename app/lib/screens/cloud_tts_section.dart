/// Bagian Pengaturan untuk suara AI (Google Cloud TTS).
///
/// Kalau kredensialnya sudah ditanam saat build, bagian ini cuma melaporkan
/// keadaan — tidak ada yang perlu diketik. Kolom isian tetap disediakan untuk
/// mencoba kunci lain tanpa membangun ulang.
///
/// Yang paling penting di layar ini: **pesan kesalahan dari Google
/// ditampilkan apa adanya.** Tanpa itu, kunci salah, billing belum aktif, dan
/// API belum diaktifkan terlihat sama persis — "tidak terjadi apa-apa".
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/build_config.dart';
import '../core/tts/cloud_speech_engine.dart';
import '../ui/tokens.dart';

class CloudTtsSection extends StatefulWidget {
  final AppState state;
  const CloudTtsSection({super.key, required this.state});

  @override
  State<CloudTtsSection> createState() => _CloudTtsSectionState();
}

class _CloudTtsSectionState extends State<CloudTtsSection> {
  late final TextEditingController _server;
  late final TextEditingController _key;
  var _terbuka = false;
  var _sibuk = false;
  String? _pesan;
  var _berhasil = false;

  @override
  void initState() {
    super.initState();
    final s = widget.state.settings;
    _server = TextEditingController(text: s.ttsProxyUrl ?? '');
    _key = TextEditingController(text: s.ttsApiKey ?? '');
  }

  @override
  void dispose() {
    _server.dispose();
    _key.dispose();
    super.dispose();
  }

  CloudSpeechEngine? get _engine {
    final e = widget.state.player.engine;
    return e is CloudSpeechEngine ? e : null;
  }

  bool get _aktif => _engine != null && !_engine!.usingFallback;

  Future<void> _sambungkan() async {
    setState(() {
      _sibuk = true;
      _pesan = null;
    });

    final s = widget.state.settings;
    await widget.state.updateSettings(s.copyWith(
      ttsProxyUrl: _server.text.trim(),
      ttsApiKey: _key.text.trim(),
    ));
    // Selalu menyambung ulang, bukan hanya saat kredensialnya berubah:
    // menekan tombol ini lalu tidak terjadi apa-apa adalah gejala paling
    // membingungkan yang bisa diberikan sebuah tombol.
    await widget.state.reconnectTts();

    if (!mounted) return;
    final jumlah = widget.state.player.engine.voices.length;

    setState(() {
      _sibuk = false;
      _berhasil = _aktif;
      _pesan = _aktif
          ? 'Tersambung. $jumlah suara Indonesia siap dicoba — pilih di '
              '"Suara pembaca" di atas.'
          : _engine?.lastError ??
              'Belum tersambung, dan layanan tidak memberi alasan.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final tertanam = BuildConfig.hasBakedTts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          key: const Key('set-cloud-tts'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Suara AI'),
          subtitle: Text(
            _aktif
                ? 'Google Cloud TTS aktif.'
                : tertanam
                    ? 'Kredensial sudah ditanam, tapi belum tersambung. '
                        'Buka untuk melihat alasannya.'
                    : 'Belum aktif — memakai suara bawaan perangkat.',
            style: bodyStyle.copyWith(
                fontSize: 12.5, color: _aktif ? greenDeep : ink2),
          ),
          trailing: Icon(_terbuka ? Icons.expand_less : Icons.expand_more,
              color: ink2),
          onTap: () => setState(() => _terbuka = !_terbuka),
        ),

        if (_terbuka) ...[
          const SizedBox(height: 4),

          if (tertanam)
            _kotak(
              _aktif ? greenDeep : orange,
              BuildConfig.bakedKeyIsExposed
                  ? 'Build ini membawa kunci Google di dalamnya, jadi tidak '
                      'ada yang perlu diketik. Tapi kunci itu ikut ke dalam '
                      'APK dan bisa diambil siapa pun yang memegangnya — '
                      'jangan bagikan APK ini ke orang lain.'
                  : 'Build ini sudah membawa alamat server sendiri. Kunci '
                      'Google tinggal di server, tidak ikut ke dalam APK. '
                      'Aman dibagikan.',
            ),

          if (!_aktif) ...[
            const SizedBox(height: 14),
            Text(
              tertanam
                  ? 'Kolom di bawah untuk mencoba kredensial lain tanpa '
                      'membangun ulang. Biarkan kosong untuk memakai yang '
                      'sudah ditanam.'
                  : 'Isi salah satu. Alamat server lebih aman; kunci langsung '
                      'lebih cepat untuk sekadar mencoba.',
              style: bodyStyle.copyWith(fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('tts-server'),
              controller: _server,
              decoration: const InputDecoration(
                labelText: 'Alamat server sendiri',
                hintText: 'https://…/tts',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('tts-key'),
              controller: _key,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Kunci Google',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],

          const SizedBox(height: 14),
          Row(
            children: [
              PrimaryButton(
                _sibuk
                    ? 'Menyambungkan…'
                    : _aktif
                        ? 'Sambungkan ulang'
                        : 'Sambungkan',
                key: const Key('tts-save'),
                onPressed: _sibuk ? null : _sambungkan,
              ),
            ],
          ),

          if (_pesan != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _kotak(_berhasil ? greenDeep : orange, _pesan!),
            ),

          const SizedBox(height: 12),
          Text(
            'Chirp3 HD terdengar paling manusiawi, lalu Neural2, lalu WaveNet. '
            'Memilih suara di daftar atas langsung memperdengarkan contohnya.',
            style: bodyStyle.copyWith(fontSize: 12.5, height: 1.5),
          ),
        ],
      ],
    );
  }

  Widget _kotak(Color warna, String teks) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: warna.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SelectableText(
          teks,
          // Bisa disalin: pesan dari Google kadang panjang dan perlu dicari
          // di internet apa adanya.
          style: bodyStyle.copyWith(fontSize: 12, height: 1.5),
        ),
      );
}
