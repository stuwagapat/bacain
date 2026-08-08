import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_picker/file_picker.dart';

import 'app_state.dart';
import 'core/store/library_store.dart';
import 'core/tts/segment_player.dart';
import 'platform/speech_engine_factory.dart';

// Warna diambil dari aset desain (ornamen & logo). Tipografi menyusul —
// tahap ini soal fungsi, bukan rupa.
const _paper = Color(0xFFEFECE7);
const _green = Color(0xFF2D6B2D);
const _greenDeep = Color(0xFF184818);
const _orange = Color(0xFFF06C3C);
const _ink = Color(0xFF161616);
const _ink2 = Color(0xFF5A5A54);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  final state = AppState(
    store: PrefsLibraryStore(),
    player: SegmentPlayer(engine: createSpeechEngine()),
  );
  runApp(BacainApp(state: state));
}

class BacainApp extends StatefulWidget {
  final AppState state;
  const BacainApp({super.key, required this.state});

  @override
  State<BacainApp> createState() => _BacainAppState();
}

class _BacainAppState extends State<BacainApp> {
  @override
  void initState() {
    super.initState();
    widget.state.init();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bacain',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Jakarta',
        scaffoldBackgroundColor: _paper,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _green,
          primary: _green,
          surface: _paper,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _paper,
          foregroundColor: _ink,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: AnimatedBuilder(
        animation: widget.state,
        builder: (context, _) => widget.state.active == null
            ? LibraryPage(state: widget.state)
            : BookPage(state: widget.state),
      ),
    );
  }
}

// ── rak buku ────────────────────────────────────────────────────────

class LibraryPage extends StatelessWidget {
  final AppState state;
  const LibraryPage({super.key, required this.state});

  Future<void> _pick(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    if (file?.bytes == null) return;
    final book = await state.addEpub(file!.bytes!, filename: file.name);
    if (book != null) state.openBook(book);
  }

  Future<void> _loadSample() async {
    final data = await rootBundle.load('assets/contoh.epub');
    final book = await state.addEpub(
      data.buffer.asUint8List(),
      filename: 'contoh.epub',
    );
    if (book != null) state.openBook(book);
  }

  @override
  Widget build(BuildContext context) {
    final books = state.books;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bacain',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3)),
      ),
      body: state.busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (state.error != null)
                  Container(
                    key: const Key('error'),
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(state.error!,
                        style: const TextStyle(color: Color(0xFF8A3A1C))),
                  ),
                if (books.isEmpty) ...[
                  const SizedBox(height: 40),
                  const Text('Raknya masih kosong.',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          color: _green)),
                  const SizedBox(height: 10),
                  const Text(
                    'Masukkan satu EPUB. Bacain memecahnya jadi bab-bab '
                    'seukuran satu perjalanan, lalu membacakannya.',
                    style: TextStyle(color: _ink2, height: 1.55),
                  ),
                  const SizedBox(height: 28),
                ],
                for (final b in books) _BookTile(state: state, book: b),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const Key('pick-epub'),
                  onPressed: () => _pick(context),
                  icon: const Icon(Icons.menu_book_outlined, size: 20),
                  label: const Text('Pilih berkas EPUB'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  key: const Key('load-sample'),
                  onPressed: _loadSample,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: _green,
                  ),
                  child: const Text('Coba dengan buku contoh'),
                ),
              ],
            ),
    );
  }
}

class _BookTile extends StatelessWidget {
  final AppState state;
  final StoredBook book;
  const _BookTile({required this.state, required this.book});

  @override
  Widget build(BuildContext context) {
    final left = book.remainingCount;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFDDD8CE)),
      ),
      child: ListTile(
        key: Key('book-${book.id}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        title: Text(book.title,
            style: const TextStyle(fontWeight: FontWeight.w700, color: _ink)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            book.isFinished
                ? 'Selesai · ${book.segments.length} bagian'
                : 'Tinggal $left bagian lagi',
            style: const TextStyle(color: _ink2),
          ),
        ),
        trailing: IconButton(
          tooltip: 'Hapus dari rak',
          icon: const Icon(Icons.delete_outline, color: _ink2),
          onPressed: () => state.removeBook(book),
        ),
        onTap: () => state.openBook(book),
      ),
    );
  }
}

// ── daftar bagian ───────────────────────────────────────────────────

class BookPage extends StatelessWidget {
  final AppState state;
  const BookPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final book = state.active!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('back-to-library'),
          icon: const Icon(Icons.arrow_back),
          onPressed: state.closeBook,
        ),
        title: Text(book.title, style: const TextStyle(fontSize: 17)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        itemCount: book.segments.length,
        itemBuilder: (context, i) {
          final s = book.segments[i];
          final done = i <= book.lastFinishedIndex;
          final open = state.canOpen(book, i);
          final isNext = i == book.lastFinishedIndex + 1;
          return ListTile(
            key: Key('segment-$i'),
            enabled: open,
            leading: Icon(
              done
                  ? Icons.check_circle
                  : isNext
                      ? Icons.play_circle_fill
                      : Icons.lock_outline,
              color: done ? _ink2 : (isNext ? _green : const Color(0xFFB9B5AC)),
            ),
            title: Text(
              s.title.isEmpty ? 'Bagian ${i + 1}' : s.title,
              style: TextStyle(
                fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                color: open ? _ink : const Color(0xFFA6A29A),
              ),
            ),
            subtitle: Text(
              '${s.estimatedDuration().inMinutes} menit · ${s.wordCount} kata',
              style: const TextStyle(color: _ink2, fontSize: 12.5),
            ),
            onTap: open
                ? () async {
                    await state.openSegment(i);
                    if (!context.mounted) return;
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PlayerPage(state: state),
                    ));
                  }
                : null,
          );
        },
      ),
    );
  }
}

// ── pemutar ─────────────────────────────────────────────────────────

class PlayerPage extends StatefulWidget {
  final AppState state;
  const PlayerPage({super.key, required this.state});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  /// Kunci menempel di kalimat yang sedang dibacakan, supaya daftar bisa
  /// menggulir mengikutinya. Tanpa ini highlight kehilangan gunanya —
  /// kalimat aktif terdorong keluar layar dan user kehilangan tempatnya.
  final _activeKey = GlobalKey();
  int _lastScrolled = -1;

  @override
  void initState() {
    super.initState();
    widget.state.player.addListener(_followActiveSentence);
  }

  @override
  void dispose() {
    widget.state.player.removeListener(_followActiveSentence);
    super.dispose();
  }

  void _followActiveSentence() {
    final i = widget.state.player.index;
    if (i == _lastScrolled) return;
    _lastScrolled = i;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _activeKey.currentContext;
      // Kalau kalimat aktif jauh di luar jangkauan, widget-nya belum dibangun.
      // Dibiarkan saja — bukan alasan untuk melempar error.
      if (ctx == null || !mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.35,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final book = state.active!;
    final segment = book.currentSegment;
    final player = state.player;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () {
            player.stop();
            Navigator.of(context).pop();
          },
        ),
        title: Text(segment?.title ?? '', style: const TextStyle(fontSize: 15)),
      ),
      body: AnimatedBuilder(
        animation: player,
        builder: (context, _) {
          final sentences = player.sentences;
          return Column(
            children: [
              if (state.needsRecap)
                Container(
                  key: const Key('recap'),
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Kamu terakhir mendengar lebih dari sehari lalu. '
                    'Ringkasan otomatis menyusul di sini.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF8A3A1C)),
                  ),
                ),
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
                      onTap: () => player.seekTo(i),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: active
                            ? BoxDecoration(
                                color: _orange.withValues(alpha: 0.14),
                                border: const Border(
                                    left: BorderSide(color: _orange, width: 2)),
                              )
                            : null,
                        child: Text(
                          sentences[i].text,
                          style: TextStyle(
                            fontSize: 17,
                            height: 1.62,
                            color: active
                                ? _ink
                                : past
                                    ? const Color(0xFFA6A29A)
                                    : const Color(0xFF3A3A34),
                            fontWeight:
                                active ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _Controls(state: state),
            ],
          );
        },
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final AppState state;
  const _Controls({required this.state});

  @override
  Widget build(BuildContext context) {
    final player = state.player;
    final book = state.active!;
    final finished = player.status == PlayerStatus.finished;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFDDD8CE))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: player.progress,
            minHeight: 3,
            backgroundColor: const Color(0xFFDDD8CE),
            valueColor: const AlwaysStoppedAnimation(_orange),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('${player.index + 1} / ${player.sentences.length} kalimat',
                  style: const TextStyle(fontSize: 11.5, color: _ink2)),
              const Spacer(),
              if (player.engine.voices.isNotEmpty)
                Text(
                  player.engine.voices
                      .firstWhere((v) => v.id == player.voiceId,
                          orElse: () => player.engine.voices.first)
                      .name,
                  style: const TextStyle(fontSize: 11.5, color: _ink2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: const Key('back-5'),
                iconSize: 28,
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
                    backgroundColor: _greenDeep,
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  child: Icon(
                    player.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                key: const Key('fwd-5'),
                iconSize: 28,
                icon: const Icon(Icons.forward_5),
                onPressed: () => player.skipSentences(3),
              ),
            ],
          ),
          if (finished) ...[
            const SizedBox(height: 10),
            Text(
              book.isFinished
                  ? 'Bukunya tamat. Selamat.'
                  : 'Bagian ini selesai. Besok lanjut yang berikutnya.',
              key: const Key('finished-note'),
              style: const TextStyle(color: _green, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
