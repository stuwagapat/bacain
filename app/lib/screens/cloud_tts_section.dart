/// Bagian Pengaturan untuk suara AI (Google Cloud TTS).
///
/// Dua jalur, dan bedanya penting:
///
///   • **Server sendiri** — jalur produksi. Kuncinya di server, tidak pernah
///     masuk APK, dan kuota ditegakkan di sana.
///   • **Kunci langsung** — hanya untuk MENILAI suaranya. Kunci yang ikut
///     dalam APK bisa diekstrak siapa pun dan dipakai atas tagihan pemiliknya.
///
/// Peringatannya ditulis di layar, bukan disembunyikan di dokumentasi.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
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

  @override
  void initState() {
    super.initState();
    final s = widget.state.settings;
    _server = TextEditingController(text: s.ttsProxyUrl ?? '');
    _key = TextEditingController(text: s.ttsApiKey ?? '');
    _terbuka = s.cloudTtsConfigured;
  }

  @override
  void dispose() {
    _server.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    setState(() {
      _sibuk = true;
      _pesan = null;
    });

    final s = widget.state.settings;
    await widget.state.updateSettings(s.copyWith(
      ttsProxyUrl: _server.text.trim(),
      ttsApiKey: _key.text.trim(),
    ));

    if (!mounted) return;
    final engine = widget.state.player.engine;
    final pakaiCloud = engine is CloudSpeechEngine && !engine.usingFallback;
    final jumlah = engine.voices.length;

    setState(() {
      _sibuk = false;
      _pesan = pakaiCloud
          ? 'Tersambung. $jumlah suara Indonesia siap dicoba.'
          : 'Belum tersambung. Periksa kunci atau alamat servernya — '
              'sementara ini memakai suara bawaan perangkat.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.state.player.engine;
    final pakaiCloud = engine is CloudSpeechEngine && !engine.usingFallback;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          key: const Key('set-cloud-tts'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Suara AI'),
          subtitle: Text(
            pakaiCloud
                ? 'Google Cloud TTS aktif.'
                : 'Belum aktif — memakai suara bawaan perangkat.',
            style: bodyStyle.copyWith(
                fontSize: 12.5, color: pakaiCloud ? greenDeep : ink2),
          ),
          trailing: Icon(_terbuka ? Icons.expand_less : Icons.expand_more,
              color: ink2),
          onTap: () => setState(() => _terbuka = !_terbuka),
        ),

        if (_terbuka) ...[
          const SizedBox(height: 6),
          TextField(
            key: const Key('tts-server'),
            controller: _server,
            decoration: const InputDecoration(
              labelText: 'Alamat server sendiri',
              hintText: 'https://…/tts',
              helperText: 'Cara yang benar untuk dibagikan ke orang lain.',
              helperMaxLines: 2,
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('tts-key'),
            controller: _key,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Kunci Google (hanya untuk mencoba)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),

          // Peringatan yang tidak boleh dilewatkan: ini soal tagihan orang.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: orange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Kunci yang dipasang di sini ikut terbawa dalam APK, dan siapa '
              'pun yang memegang APK-nya bisa mengambil kunci itu lalu '
              'memakainya atas tagihanmu. Pakai untuk menilai suaranya, lalu '
              'hapus kuncinya sebelum APK dibagikan ke orang lain.',
              style: bodyStyle.copyWith(fontSize: 12, height: 1.5),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              PrimaryButton(
                _sibuk ? 'Menyambungkan…' : 'Simpan & sambungkan',
                key: const Key('tts-save'),
                onPressed: _sibuk ? null : _simpan,
              ),
            ],
          ),

          if (_pesan != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_pesan!,
                  style: bodyStyle.copyWith(fontSize: 12.5, height: 1.5)),
            ),

          const SizedBox(height: 10),
          Text(
            'Suara Chirp3 HD terdengar paling manusiawi, lalu Neural2, lalu '
            'WaveNet. Ketiganya ada di daftar "Suara pembaca" di atas begitu '
            'tersambung — pilih satu, dan contohnya langsung diperdengarkan.',
            style: bodyStyle.copyWith(fontSize: 12.5, height: 1.5),
          ),
        ],
      ],
    );
  }
}
