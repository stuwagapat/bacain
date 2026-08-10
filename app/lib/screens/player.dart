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
            Text('SEBELUMNYA…',
                style: AppType.uiCaption.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                    color: warna.textDisabled)),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  state.recapText(),
                  key: const Key('recap-text'),
                  style: AppType.readingRecap
                      .copyWith(color: warna.readingTextActive),
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
                style: bodyStyle.copyWith(
                    color: warna.textPrimary, fontSize: 15.5)),
            const SizedBox(height: 6),
            Text(
              'Bagian berikutnya kami siapkan untuk besok pagi, '
              'jam ${state.settings.reminderLabel}.',
              style: bodyStyle,
            ),
            const Spacer(),
            Divider(color: warna.borderDefault),
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
    // Ukuran teks bacaan datang dari token, bukan angka di sini. "Huruf besar
    // saat mendengar" di Pengaturan memilih antara dua gaya yang memang
    // dirancang berpasangan — bukan sekadar menambah beberapa poin.
    final gaya = readingStyle(besar: state.settings.largeText);

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
              title: Text(segment?.title ?? '', style: AppType.uiTitleSmall),
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
            _focusMode ? _focusView(player) : _fullView(player, gaya),
      ),
    );
  }

  /// Mode fokus: hanya kalimat yang sedang dibacakan. Untuk didengar sambil
  /// jalan, saat mata tidak perlu ikut bekerja.
  ///
  /// Layar ini MENCABUT aksen sepenuhnya — tidak ada satu pun warna merek.
  /// Sesuatu yang dipakai di jalan atau saat mata istirahat harus berhenti
  /// menarik perhatian.
  Widget _focusView(SegmentPlayer player) => GestureDetector(
        key: const Key('focus-view'),
        onTap: () => setState(() => _focusMode = false),
        child: Container(
          color: warna.bgBase,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(30, 60, 30, 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.state.active!.title.toUpperCase(),
                  style: AppType.uiCaption.copyWith(
                      fontSize: 11,
                      letterSpacing: 1.4,
                      color: warna.textDisabled)),
              Text(
                player.current?.text ?? '',
                style: AppType.readingBodyLarge
                    .copyWith(color: warna.readingTextActive),
              ),
              Column(
                children: [
                  _controls(player, fokus: true),
                  const SizedBox(height: 12),
                  // Jalan keluar harus terlihat. Tanpa baris ini, user yang
                  // tidak sengaja masuk akan terjebak di layar hampir kosong.
                  Text('Ketuk di mana saja untuk kembali',
                      style: AppType.uiCaption
                          .copyWith(color: warna.textDisabled)),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _fullView(SegmentPlayer player, TextStyle gaya) {
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
                  // Latar penanda saja, tanpa garis aksen: warna merek hanya
                  // untuk hal yang bisa ditekan, dan kalimat yang sedang
                  // dibaca bukan tombol. readingHighlightBg di tema gelap
                  // sengaja jauh lebih redup daripada padanannya di terang —
                  // yang lembut di monitor bisa menyilaukan di kamar gelap.
                  decoration: active
                      ? BoxDecoration(color: warna.readingHighlightBg)
                      : null,
                  child: Text(
                    sentences[i].text,
                    style: gaya.copyWith(
                      color: active
                          ? warna.readingTextActive
                          : (past
                              ? warna.readingTextPast
                              : warna.readingTextFuture),
                      // Tebal huruf sengaja TIDAK berubah saat kalimat aktif.
                      // Huruf tebal lebih lebar, jadi pemenggalan barisnya ikut
                      // berubah dan seluruh teks di bawahnya bergeser tiap kali
                      // kalimat berpindah. Penandanya sudah cukup lewat latar
                      // penanda dan warna teks yang lebih pekat.
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

  /// [fokus] bukan "versi gelap" — seluruh app sudah gelap. Yang dibedakan
  /// adalah seberapa banyak yang boleh menarik perhatian: di mode fokus,
  /// kemajuan, jatah, dan warna merek semuanya dicabut.
  Widget _controls(SegmentPlayer player, {bool fokus = false}) {
    final state = widget.state;
    final finished = player.status == PlayerStatus.finished;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, fokus ? 0 : 22),
      decoration: fokus
          ? null
          : BoxDecoration(
              border: Border(top: BorderSide(color: warna.borderDefault))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!fokus) ...[
            LinearProgressIndicator(
              value: player.progress,
              minHeight: 3,
              backgroundColor: warna.progressTrack,
              valueColor: AlwaysStoppedAnimation(warna.progressFilled),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('${player.index + 1} / ${player.sentences.length} kalimat',
                    style: AppType.uiCaption
                        .copyWith(color: warna.textSecondary)),
                const Spacer(),
                Text(
                  state.isNewContent
                      ? 'sisa ${state.remainingMinutes} menit'
                      : 'ulangan · bebas jatah',
                  key: const Key('quota-note'),
                  style: AppType.uiCaption
                      .copyWith(color: warna.textSecondary),
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
                color: warna.textPrimary,
                icon: const Icon(Icons.replay_5),
                onPressed: () => player.skipSentences(-3),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: AppSize.miniPlayer,
                height: AppSize.miniPlayer,
                child: FilledButton(
                  key: const Key('play-toggle'),
                  onPressed: player.toggle,
                  style: FilledButton.styleFrom(
                    backgroundColor: fokus
                        ? warna.bgSurfaceVariant
                        : warna.playerControlBg,
                    foregroundColor:
                        fokus ? warna.textPrimary : warna.playerControlIcon,
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
                color: warna.textPrimary,
                icon: const Icon(Icons.forward_5),
                onPressed: () => player.skipSentences(3),
              ),
            ],
          ),
          if (finished && !fokus) ...[
            const SizedBox(height: 10),
            Text(
              state.active!.isFinished
                  ? 'Bukunya tamat. Selamat.'
                  : 'Bagian ini selesai. Besok lanjut yang berikutnya.',
              key: const Key('finished-note'),
              style: AppType.uiLabel.copyWith(color: warna.statusSuccess),
            ),
          ],
        ],
      ),
    );
  }
}
