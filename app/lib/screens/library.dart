import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_picker/file_picker.dart';

import '../app_state.dart';
import '../core/store/library_store.dart';
import '../ui/tokens.dart';
import 'confirm_book.dart';
import 'settings.dart';

class LibraryPage extends StatelessWidget {
  final AppState state;
  final void Function(StoredBook) onOpen;
  const LibraryPage({super.key, required this.state, required this.onOpen});

  Future<void> _addFromBytes(
      BuildContext context, List<int> bytes, String filename) async {
    final book = await state.parseEpub(bytes, filename: filename);
    if (book == null || !context.mounted) return;
    final segments = state.previewSegments(book);
    final stored = await Navigator.of(context).push<StoredBook?>(
      MaterialPageRoute(
        builder: (_) =>
            ConfirmBookPage(state: state, book: book, segments: segments),
      ),
    );
    if (stored != null) onOpen(stored);
  }

  Future<void> _pickFile(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    if (file?.bytes == null || !context.mounted) return;
    await _addFromBytes(context, file!.bytes!, file.name);
  }

  Future<void> _loadSample(BuildContext context) async {
    final data = await rootBundle.load('assets/contoh.epub');
    if (!context.mounted) return;
    await _addFromBytes(context, data.buffer.asUint8List(), 'contoh.epub');
  }

  void _openAddSheet(BuildContext context) {
    showModalBarrierSheet(context, state, this);
  }

  @override
  Widget build(BuildContext context) {
    final books = state.books;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bacain',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        actions: [
          IconButton(
            key: const Key('open-settings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SettingsPage(state: state),
            )),
          ),
        ],
      ),
      body: state.busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                QuotaBar(
                  remainingMinutes: state.remainingMinutes,
                  totalMinutes: state.settings.dailyMinutes,
                ),
                const SizedBox(height: 22),
                if (state.error != null)
                  Container(
                    key: const Key('error'),
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(state.error!,
                        style: const TextStyle(color: Color(0xFF8A3A1C))),
                  ),
                if (books.isEmpty) ...[
                  const SizedBox(height: 26),
                  Text('Raknya masih kosong.', style: titleStyle),
                  const SizedBox(height: 10),
                  Text(
                    'Mulai dari buku yang paling lama kamu tunda. '
                    'Satu bagian dulu, tidak perlu semuanya.',
                    style: bodyStyle,
                  ),
                  const SizedBox(height: 26),
                ],
                for (final b in books)
                  _BookTile(state: state, book: b, onOpen: onOpen),
                const SizedBox(height: 18),
                PrimaryButton('Tambah buku',
                    key: const Key('add-book'),
                    icon: Icons.add,
                    onPressed: () => _openAddSheet(context)),
              ],
            ),
    );
  }
}

/// Pilihan sumber buku. "Foto buku fisik" sengaja ditampilkan walau belum
/// bisa — supaya alur produknya utuh terlihat, dan jelas apa yang kurang.
void showModalBarrierSheet(
    BuildContext context, AppState state, LibraryPage page) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: paper,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 3,
                decoration: BoxDecoration(
                    color: rule, borderRadius: BorderRadius.circular(999)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Tambah buku',
                style: TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w700, color: ink)),
            const SizedBox(height: 14),
            ListTile(
              key: const Key('src-camera'),
              contentPadding: EdgeInsets.zero,
              enabled: false,
              leading: const Icon(Icons.photo_camera_outlined, color: ink3),
              title: const Text('Foto buku fisik'),
              subtitle: const Text('Butuh versi Android — belum ada di web'),
            ),
            const Divider(color: rule),
            ListTile(
              key: const Key('src-file'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined, color: ink),
              title: const Text('Pilih berkas EPUB'),
              subtitle: const Text('Dari penyimpanan perangkatmu'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                page._pickFile(context);
              },
            ),
            const Divider(color: rule),
            ListTile(
              key: const Key('src-sample'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.auto_stories_outlined, color: ink),
              title: const Text('Buku contoh'),
              subtitle: const Text('Enam bab, untuk mencoba alurnya'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                page._loadSample(context);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _BookTile extends StatelessWidget {
  final AppState state;
  final StoredBook book;
  final void Function(StoredBook) onOpen;
  const _BookTile(
      {required this.state, required this.book, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: rule),
      ),
      child: ListTile(
        key: Key('book-${book.id}'),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        title: Text(book.title,
            style: const TextStyle(fontWeight: FontWeight.w700, color: ink)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            book.isFinished
                ? 'Selesai · ${book.segments.length} bagian'
                : 'Tinggal ${book.remainingCount} bagian lagi',
            style: bodyStyle.copyWith(fontSize: 13.5),
          ),
        ),
        trailing: IconButton(
          tooltip: 'Hapus dari rak',
          icon: const Icon(Icons.delete_outline, color: ink2),
          onPressed: () => state.removeBook(book),
        ),
        onTap: () => onOpen(book),
      ),
    );
  }
}
