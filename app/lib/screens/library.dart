import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_picker/file_picker.dart';

import '../app_state.dart';
import '../core/store/library_store.dart';
import '../ui/tokens.dart';
import 'confirm_book.dart';
import 'review_scan.dart';
import 'settings.dart';

class LibraryPage extends StatelessWidget {
  final AppState state;
  final void Function(StoredBook) onOpen;
  const LibraryPage({super.key, required this.state, required this.onOpen});

  Future<void> _addFromBytes(
      BuildContext context, List<int> bytes, String filename) async {
    final book = await state.parseFile(bytes, filename: filename);
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

  /// Foto buku fisik: pemindai Google, lalu OCR di perangkat, lalu layar
  /// tinjau. Baru setelah user memeriksa hasilnya, bukunya disusun.
  Future<void> _scanBook(BuildContext context) async {
    final pages = await state.scanner.scan();
    // Daftar kosong berarti dibatalkan — bukan kegagalan, jadi diam saja.
    if (pages.isEmpty || !context.mounted) return;

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (reviewContext) => ReviewScanPage(
        state: state,
        pages: pages,
        onDone: (edited, title) async {
          final book = await state.buildScanned(edited, title: title);
          if (!reviewContext.mounted) return;
          if (book == null) {
            ScaffoldMessenger.of(reviewContext).showSnackBar(
              SnackBar(content: Text(state.error ?? 'Gagal membaca foto.')),
            );
            return;
          }
          final segments = state.previewSegments(book);
          final stored = await Navigator.of(reviewContext).push<StoredBook?>(
            MaterialPageRoute(
              builder: (_) => ConfirmBookPage(
                  state: state, book: book, segments: segments),
            ),
          );
          if (stored == null || !reviewContext.mounted) return;
          // Layar tinjau ikut ditutup: tugasnya sudah selesai, dan
          // meninggalkannya di tumpukan membuat tombol kembali membingungkan.
          Navigator.of(reviewContext).pop();
          onOpen(stored);
        },
      ),
    ));
  }

  Future<void> _pickFile(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub', 'pdf'],
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
                      color: warna.statusErrorBg,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(state.error!,
                        style: AppType.uiBody
                            .copyWith(color: warna.statusError)),
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
    backgroundColor: warna.bgSurface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
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
                    color: warna.borderStrong,
                    borderRadius: BorderRadius.circular(AppRadius.full)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Tambah buku',
                style: AppType.uiTitle.copyWith(color: warna.textPrimary)),
            const SizedBox(height: 14),
            ListTile(
              key: const Key('src-camera'),
              contentPadding: EdgeInsets.zero,
              enabled: state.scanner.available,
              leading: Icon(Icons.photo_camera_outlined,
                  color: state.scanner.available
                      ? warna.textPrimary
                      : warna.textDisabled),
              title: const Text('Foto buku fisik'),
              subtitle: Text(state.scanner.available
                  ? 'Satu bab saja sudah cukup untuk beberapa hari'
                  : 'Hanya di versi Android — kameranya jalan di perangkat'),
              onTap: state.scanner.available
                  ? () {
                      Navigator.of(sheetContext).pop();
                      page._scanBook(context);
                    }
                  : null,
            ),
            Divider(color: warna.borderDefault),
            ListTile(
              key: const Key('src-file'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.description_outlined,
                  color: warna.textPrimary),
              title: const Text('Pilih berkas'),
              subtitle: const Text('EPUB atau PDF berteks'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                page._pickFile(context);
              },
            ),
            Divider(color: warna.borderDefault),
            ListTile(
              key: const Key('src-sample'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.auto_stories_outlined,
                  color: warna.textPrimary),
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
      color: warna.bgSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: warna.borderDefault),
      ),
      child: ListTile(
        key: Key('book-${book.id}'),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        title: Text(book.title,
            style: AppType.uiTitleSmall.copyWith(color: warna.textPrimary)),
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
          icon: Icon(Icons.delete_outline, color: warna.textSecondary),
          onPressed: () => state.removeBook(book),
        ),
        onTap: () => onOpen(book),
      ),
    );
  }
}
