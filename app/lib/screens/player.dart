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
            // Menjawab "kenapa layar ini muncul" — pertanyaan yang cuma ada
            // di hari kedua, persis saat tidak ada yang menjelaskan.
            if (state.jedaTerakhir != null)
              Center(
                child: Text(
                  'TERAKHIR KAMU DENGAR ${state.jedaTerakhir!.toUpperCase()}',
                  key: const Key('recap-jeda'),
                  style: AppType.uiCaption.copyWith(
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                      color: warna.textDisabled),
                ),
              ),
            const SizedBox(height: 14),
            Center(
              child: Text('Sebelumnya…',
                  style: AppType.uiHeadline.copyWith(
                      fontSize: 27, color: warna.textSecondary)),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  state.recapText(),
                  key: const Key('recap-text'),
                  textAlign: TextAlign.center,
                  style: AppType.readingRecap
                      .copyWith(color: warna.readingTextActive),
                ),
              ),
            ),
            // Menjawab "kenapa tiba-tiba ada suara". Teks recap langsung
            // disuarakan begitu layar terbuka, dan tanpa penanda ini suaranya
            // terasa datang entah dari mana.
            const _IndikatorSuara(),
            const SizedBox(height: 6),
            Center(
              child: Text('Sedang dibacakan',
                  key: const Key('recap-dibacakan'),
                  style: AppType.uiCaption
                      .copyWith(color: warna.textDisabled)),
            ),
            const SizedBox(height: 18),
            // Jujur soal apa yang belum ada: ini kalimat asli dari bagian
            // sebelumnya, bukan ringkasan yang dirangkum AI.
            Center(
              child: Text(
                'Ini kalimat penutup bagian sebelumnya — ringkasan yang '
                'benar-benar merangkum menyusul.',
                textAlign: TextAlign.center,
                style: bodyStyle.copyWith(fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 14),
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

/// Harus terasa seperti garis finis, bukan tembok.
///
/// Satu-satunya layar dengan latar merek penuh di seluruh app — dan itu
/// disengaja: ia muncul paling banyak sekali sehari, jadi ia boleh menjadi
/// kejadian. Nadanya memberi selamat, bukan menghalangi.
class QuotaExhaustedPage extends StatelessWidget {
  final AppState state;
  const QuotaExhaustedPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final menit = (state.quota.usedSeconds() / 60).round();
    final tinta = warna.brandOnPrimary;

    return Scaffold(
      backgroundColor: warna.brandPrimary,
      appBar: AppBar(
        backgroundColor: warna.brandPrimary,
        foregroundColor: tinta,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Biarkan angkanya yang pamer. Tidak ada tanda seru di mana pun
              // di app ini; besarnya angka sudah cukup jadi perayaan.
              Text('$menit',
                  key: const Key('quota-menit'),
                  textAlign: TextAlign.center,
                  style: AppType.uiDisplay.copyWith(
                      fontSize: 104, height: 0.9, color: tinta)),
              const SizedBox(height: 10),
              Text('MENIT HARI INI',
                  textAlign: TextAlign.center,
                  style: AppType.uiCaption.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: tinta.withValues(alpha: 0.56))),
              const SizedBox(height: 22),
              Text('Cukup untuk hari ini. Lumayan, kan?',
                  key: const Key('quota-title'),
                  textAlign: TextAlign.center,
                  style: AppType.uiHeadline
                      .copyWith(fontSize: 26, color: tinta)),
              const SizedBox(height: 11),
              Text(
                'Bagian berikutnya kami siapkan untuk besok, jam '
                '${state.settings.reminderLabel}. Sampai besok, ya.',
                textAlign: TextAlign.center,
                style: AppType.uiBody.copyWith(
                    fontSize: 14,
                    height: 1.55,
                    color: tinta.withValues(alpha: 0.72)),
              ),
              const Spacer(),

              // Tombol paling menonjol di layar ini, dan TIDAK PERNAH dikunci:
              // bagian yang sudah pernah disintesis tidak menimbulkan biaya
              // baru, jadi tidak ada alasan menghalanginya.
              FilledButton(
                key: const Key('quota-ulang'),
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: tinta,
                  foregroundColor: warna.bgSurfaceVariant,
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
                child: Text('Dengar ulang bagian lama',
                    style: AppType.uiLabel.copyWith(fontSize: 15.5)),
              ),
              TextButton(
                key: const Key('quota-reset'),
                onPressed: () async {
                  await state.resetQuota();
                  if (context.mounted) Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                    foregroundColor: tinta.withValues(alpha: 0.62)),
                child: Text('Kembalikan jatah (untuk uji coba)',
                    style: AppType.uiLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lima batang yang bergerak — penanda bahwa ada yang sedang dibacakan.
///
/// Sengaja bukan animasi berkelanjutan yang berat: lima `AnimatedContainer`
/// yang berdenyut sudah menyampaikan "ini hidup", dan berhenti sendiri saat
/// pengguna memilih mengurangi gerak.
class _IndikatorSuara extends StatefulWidget {
  const _IndikatorSuara();

  @override
  State<_IndikatorSuara> createState() => _IndikatorSuaraState();
}

class _IndikatorSuaraState extends State<_IndikatorSuara>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  static const _tinggi = [8.0, 18.0, 26.0, 14.0, 7.0];

  @override
  void initState() {
    super.initState();
    _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diam = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _tinggi.length; i++)
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final fase = (_c.value + i * 0.16) % 1.0;
                final skala = diam ? 1.0 : 0.45 + 0.55 * (1 - (fase - 0.5).abs() * 2);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 3,
                  height: _tinggi[i] * skala,
                  decoration: BoxDecoration(
                    color: warna.brandPrimary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
        ],
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
  bool _hintTertutup = false;

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
                onLongPress: () {
                  // Gesturnya tetap ada — ikon di app bar untuk penemuan,
                  // tekan lama untuk yang sudah tahu.
                  if (!widget.state.settings.focusHintSeen) _tutupHint();
                  setState(() => _focusMode = true);
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
        // Mode fokus dulu cuma gestur ketuk-teks: tidak ada petunjuk apa pun,
        // jadi hampir tidak akan ditemukan. Pil ini muncul sekali lalu tidak
        // pernah kembali — petunjuk yang terus muncul berubah jadi kebisingan.
        if (!widget.state.settings.focusHintSeen && !_hintTertutup)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Center(
              child: Material(
                color: warna.bgSurface,
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: InkWell(
                  key: const Key('focus-hint'),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  onTap: _tutupHint,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Ketuk teks untuk mode fokus',
                            style: AppType.uiCaption
                                .copyWith(color: warna.textDisabled)),
                        const SizedBox(width: 9),
                        Icon(Icons.close, size: 12, color: warna.textDisabled),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        _controls(player),
      ],
    );
  }

  /// Ditutup sekali, hilang selamanya — termasuk sesudah app ditutup.
  Future<void> _tutupHint() async {
    setState(() => _hintTertutup = true);
    final s = widget.state.settings;
    await widget.state.updateSettings(s.copyWith(focusHintSeen: true));
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
