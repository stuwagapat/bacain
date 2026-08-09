import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/tts/segment_player.dart';
import '../ui/tokens.dart';

/// Pintu masuk mendengarkan. Urutannya: jatah habis → recap → pemutar.
/// Pemeriksaan jatah didahulukan supaya user tidak dibawa ke pemutar hanya
/// untuk langsung ditolak di sana.
Future<void> openListening(BuildContext context, AppState state) async {
  if (state.quotaExhausted && state.isNewContent) {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuotaExhaustedPage(state: state),
    ));
    return;
  }
  if (state.needsRecap) {
    final go = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => RecapPage(state: state),
    ));
    if (go != true || !context.mounted) return;
  }
  if (!context.mounted) return;
  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => PlayerPage(state: state)));
}

// ── ringkasan "sebelumnya" ─────────────────────────────────────────

class RecapPage extends StatelessWidget {
  final AppState state;
  const RecapPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final book = state.active!;
    final next = book.currentSegment;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(30, 8, 30, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            const Text('SEBELUMNYA…',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                    color: ink3)),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  state.recapText(),
                  key: const Key('recap-text'),
                  style: const TextStyle(fontSize: 19, height: 1.7, color: ink),
                ),
              ),
            ),
            // Jujur soal apa yang belum ada: ini kalimat asli dari bagian
            // sebelumnya, bukan ringkasan yang dirangkum AI.
            Text(
              'Ini kalimat penutup bagian sebelumnya. Ringkasan yang benar-benar '
              'merangkum menyusul saat Claude tersambung.',
              style: bodyStyle.copyWith(fontSize: 12.5),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              'Lanjut ke ${next?.title ?? 'bagian berikutnya'}',
              key: const Key('recap-continue'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
            Center(
              child: QuietButton('Lewati',
                  onPressed: () => Navigator.of(context).pop(true)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── jatah habis ────────────────────────────────────────────────────

class QuotaExhaustedPage extends StatelessWidget {
  final AppState state;
  const QuotaExhaustedPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final used = state.settings.dailyMinutes;
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Text('Sampai di sini dulu hari ini.',
                key: const Key('quota-title'), style: titleStyle.copyWith(fontSize: 27)),
            const SizedBox(height: 14),
            Text('Kamu mendengar $used menit hari ini. Lumayan.',
                style: bodyStyle.copyWith(color: ink, fontSize: 15.5)),
            const SizedBox(height: 6),
            Text(
              'Bagian berikutnya kami siapkan untuk besok pagi, '
              'jam ${state.settings.reminderLabel}.',
              style: bodyStyle,
            ),
            const Spacer(),
            const Divider(color: rule),
            const SizedBox(height: 10),
            Text(
              'Bagian yang sudah pernah didengar tidak memakan jatah — '
              'buka saja dari daftar bagian.',
              style: bodyStyle.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 14),
            PrimaryButton('Kembali ke daftar bagian',
                onPressed: () => Navigator.of(context).pop()),
            Center(
              child: QuietButton(
                'Kembalikan jatah (untuk uji coba)',
                key: const Key('quota-reset'),
                onPressed: () async {
                  await state.resetQuota();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── pemutar ────────────────────────────────────────────────────────

class PlayerPage extends StatefulWidget {
  final AppState state;
  const PlayerPage({super.key, required this.state});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final _activeKey = GlobalKey();
  int _lastScrolled = -1;
  bool _focusMode = false;
  bool _quotaShown = false;

  @override
  void initState() {
    super.initState();
    widget.state.player.addListener(_onPlayerTick);
  }

  @override
  void dispose() {
    widget.state.player.removeListener(_onPlayerTick);
    super.dispose();
  }

  void _onPlayerTick() {
    _followActiveSentence();
    _maybeShowQuotaWall();
  }

  /// Jatah bisa habis di TENGAH mendengar. Saat itu terjadi, pemutar dijeda
  /// oleh AppState dan layar ini yang memberi tahu — sekali saja.
  void _maybeShowQuotaWall() {
    if (!widget.state.quotaJustRanOut || _quotaShown || !mounted) return;
    _quotaShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => QuotaExhaustedPage(state: widget.state),
      ));
    });
  }

  void _followActiveSentence() {
    final i = widget.state.player.index;
    if (i == _lastScrolled) return;
    _lastScrolled = i;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _activeKey.currentContext;
      if (ctx == null || !mounted) return;
      Scrollable.ensureVisible(ctx,
          alignment: 0.35,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final player = state.player;
    final segment = state.active!.currentSegment;
    final fontSize = state.settings.largeText ? 21.0 : 17.0;

    return Scaffold(
      appBar: _focusMode
          ? null
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.keyboard_arrow_down),
                onPressed: () {
                  player.stop();
                  Navigator.of(context).pop();
                },
              ),
              title: Text(segment?.title ?? '',
                  style: const TextStyle(fontSize: 15)),
              actions: [
                IconButton(
                  key: const Key('focus-toggle'),
                  tooltip: 'Mode fokus',
                  icon: const Icon(Icons.center_focus_weak),
                  onPressed: () => setState(() => _focusMode = true),
                ),
              ],
            ),
      body: AnimatedBuilder(
        animation: player,
        builder: (context, _) =>
            _focusMode ? _focusView(player, fontSize) : _fullView(player, fontSize),
      ),
    );
  }

  /// Mode fokus: hanya kalimat yang sedang dibacakan. Untuk didengar sambil
  /// jalan, saat mata tidak perlu ikut bekerja.
  Widget _focusView(SegmentPlayer player, double fontSize) => GestureDetector(
        key: const Key('focus-view'),
        onTap: () => setState(() => _focusMode = false),
        child: Container(
          color: ink,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(30, 60, 30, 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.state.active!.title.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11, letterSpacing: 1.4, color: ink3)),
              Text(
                player.current?.text ?? '',
                style: TextStyle(
                    fontSize: fontSize + 5, height: 1.6, color: paper),
              ),
              Column(
                children: [
                  _controls(player, dark: true),
                  const SizedBox(height: 12),
                  const Text('ketuk untuk keluar dari mode fokus',
                      style: TextStyle(fontSize: 11.5, color: ink3)),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _fullView(SegmentPlayer player, double fontSize) {
    final sentences = player.sentences;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            key: const Key('sentences'),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            itemCount: sentences.length,
            itemBuilder: (context, i) {
              final active = i == player.index;
              final past = i < player.index;
              return GestureDetector(
                key: active ? _activeKey : null,
                // Menggulir sendiri setelah user MENGETUK kalimat itu salah:
                // dia sudah tahu di mana kalimatnya, dan layar yang bergeser
                // sendiri terasa seperti tekannya meleset. Penanda gulir
                // dimajukan lebih dulu supaya lompatan ini tidak diikuti.
                onTap: () {
                  _lastScrolled = i;
                  player.seekTo(i);
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: active
                      ? BoxDecoration(
                          color: orange.withValues(alpha: 0.14),
                          border: const Border(
                              left: BorderSide(color: orange, width: 2)))
                      : null,
                  child: Text(
                    sentences[i].text,
                    style: TextStyle(
                      fontSize: fontSize,
                      height: 1.62,
                      color: active ? ink : (past ? ink3 : const Color(0xFF3A3A34)),
                      // Tebal huruf sengaja TIDAK berubah saat kalimat aktif.
                      // Huruf tebal lebih lebar, jadi pemenggalan barisnya ikut
                      // berubah dan seluruh teks di bawahnya bergeser tiap kali
                      // kalimat berpindah. Penandanya sudah cukup lewat latar
                      // oranye, garis kiri, dan warna teks yang lebih pekat.
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _controls(player),
      ],
    );
  }

  Widget _controls(SegmentPlayer player, {bool dark = false}) {
    final state = widget.state;
    final finished = player.status == PlayerStatus.finished;
    final fg = dark ? paper : ink;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, dark ? 0 : 22),
      decoration: dark
          ? null
          : const BoxDecoration(
              border: Border(top: BorderSide(color: rule))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!dark) ...[
            LinearProgressIndicator(
              value: player.progress,
              minHeight: 3,
              backgroundColor: rule,
              valueColor: const AlwaysStoppedAnimation(orange),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('${player.index + 1} / ${player.sentences.length} kalimat',
                    style: const TextStyle(fontSize: 11.5, color: ink2)),
                const Spacer(),
                Text(
                  state.isNewContent
                      ? 'sisa ${state.remainingMinutes} menit'
                      : 'ulangan · bebas jatah',
                  key: const Key('quota-note'),
                  style: const TextStyle(fontSize: 11.5, color: ink2),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: const Key('back-3'),
                iconSize: 28,
                color: fg,
                icon: const Icon(Icons.replay_5),
                onPressed: () => player.skipSentences(-3),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 64,
                height: 64,
                child: FilledButton(
                  key: const Key('play-toggle'),
                  onPressed: player.toggle,
                  style: FilledButton.styleFrom(
                    backgroundColor: dark ? paper : greenDeep,
                    foregroundColor: dark ? ink : paper,
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  child: Icon(
                      player.isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 30),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                key: const Key('fwd-3'),
                iconSize: 28,
                color: fg,
                icon: const Icon(Icons.forward_5),
                onPressed: () => player.skipSentences(3),
              ),
            ],
          ),
          if (finished && !dark) ...[
            const SizedBox(height: 10),
            Text(
              state.active!.isFinished
                  ? 'Bukunya tamat. Selamat.'
                  : 'Bagian ini selesai. Besok lanjut yang berikutnya.',
              key: const Key('finished-note'),
              style: const TextStyle(color: green, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}
