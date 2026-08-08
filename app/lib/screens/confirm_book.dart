import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/model/book.dart';
import '../ui/tokens.dart';

/// Layar konfirmasi sebelum buku masuk rak.
///
/// Baris "± N hari mendengar" adalah satu-satunya kalimat di seluruh app yang
/// menjelaskan bahwa ini serial harian, bukan file audio raksasa. Karena itu
/// ia diberi porsi terbesar di layar ini.
class ConfirmBookPage extends StatefulWidget {
  final AppState state;
  final Book book;
  final List<Segment> segments;

  const ConfirmBookPage({
    super.key,
    required this.state,
    required this.book,
    required this.segments,
  });

  @override
  State<ConfirmBookPage> createState() => _ConfirmBookPageState();
}

class _ConfirmBookPageState extends State<ConfirmBookPage> {
  String? _voiceId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _voiceId = widget.state.settings.voiceId ?? widget.state.player.voiceId;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final days = s.estimatedDays(widget.segments);
    final totalMinutes = widget.segments
            .fold<int>(0, (a, x) => a + x.estimatedDuration().inSeconds) ~/
        60;
    final voices = s.player.engine.voices;

    return Scaffold(
      appBar: AppBar(title: const Text('Buku baru')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(26, 8, 26, 28),
        children: [
          Text(widget.book.title,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: ink)),
          if (widget.book.author.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(widget.book.author, style: bodyStyle),
            ),
          const SizedBox(height: 26),
          Text('± $days hari mendengar',
              key: const Key('estimated-days'),
              style: titleStyle.copyWith(fontSize: 34)),
          const SizedBox(height: 8),
          Text(
            '${widget.segments.length} bagian · sekitar $totalMinutes menit total. '
            'Dengan jatah ${s.settings.dailyMinutes} menit sehari.',
            style: bodyStyle,
          ),
          const SizedBox(height: 28),
          const Text('SUARA PEMBACA',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: ink3)),
          const SizedBox(height: 8),
          if (voices.isEmpty)
            Text(
              'Perangkat ini belum punya suara yang bisa dipakai. '
              'Di HP Android biasanya ada suara Bahasa Indonesia.',
              style: bodyStyle.copyWith(fontSize: 13),
            )
          else
            ...voices.take(6).map((v) => RadioListTile<String>(
                  key: Key('voice-${v.id}'),
                  contentPadding: EdgeInsets.zero,
                  value: v.id,
                  groupValue: _voiceId,
                  activeColor: green,
                  title: Text(v.name,
                      style: const TextStyle(fontSize: 15, color: ink)),
                  subtitle: Text(v.lang, style: bodyStyle.copyWith(fontSize: 12)),
                  onChanged: (id) => setState(() => _voiceId = id),
                )),
          const SizedBox(height: 24),
          PrimaryButton(
            _saving ? 'Menyimpan…' : 'Masukkan ke rak',
            key: const Key('confirm-add'),
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    if (_voiceId != null) {
                      await s.updateSettings(
                          s.settings.copyWith(voiceId: _voiceId));
                    }
                    final stored = await s.addBook(widget.book, widget.segments);
                    if (!context.mounted) return;
                    Navigator.of(context).pop(stored);
                  },
          ),
          const SizedBox(height: 6),
          Center(
            child: QuietButton('Batal',
                onPressed: () => Navigator.of(context).pop()),
          ),
        ],
      ),
    );
  }
}
