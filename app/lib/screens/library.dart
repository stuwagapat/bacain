import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_picker/file_picker.dart';

import '../app_state.dart';
import '../core/scan/page_scanner.dart';
import '../core/store/library_store.dart';
import '../ui/tokens.dart';
import 'confirm_book.dart';
import 'review_scan.dart';
import 'scan_intro.dart';
import 'scan_tray.dart';
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

  /// Foto buku fisik. Urutannya: panduan (sekali) → pemindai Google →
  /// halaman terkumpul → OCR → layar tinjau. Baru setelah user memeriksa
  /// hasilnya, bukunya disusun.
  Future<void> _scanBook(BuildContext context) async {
    // Panduan muncul sekali seumur pemasangan, sebelum kamera pertama kali
    // dibuka. Pemindai Google tidak bisa kita beri panduan apa pun, jadi
    // semua yang perlu diketahui harus disampaikan sebelum masuk.
    if (!state.settings.cameraBriefed) {
      final lanjut = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const ScanIntroPage()),
      );
      if (!context.mounted) return;
      // Ditandai sudah dibaca hanya kalau user benar-benar meneruskan.
      // "Nanti saja" berarti ia belum sempat membacanya.
      if (lanjut != true) return;
      await state.updateSettings(state.settings.copyWith(cameraBriefed: true));
      if (!context.mounted) return;
    }

    final pages = await state.scanner.scan();
    // Daftar kosong berarti dibatalkan — bukan kegagalan, jadi diam saja.
    if (pages.isEmpty || !context.mounted) return;

    // Halaman terkumpul: ditandai buram di sini, sebelum OCR jalan, saat
    // memfoto ulang masih murah.
    final dipilih = await Navigator.of(context).push<List<ScannedPage>>(
      MaterialPageRoute(
        builder: (_) => ScanTrayPage(
          pages: pages,
          onScanMore: state.scanner.scan,
        ),
      ),
    );
    if (dipilih == null || dipilih.isEmpty || !context.mounted) return;

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (reviewContext) => ReviewScanPage(
        state: state,
        pages: dipilih,
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
    final lanjut = state.nextUp;
    // Kartu LANJUTKAN sudah menampilkan buku ini besar-besar di atas; ia tidak
    // perlu muncul lagi sebagai petak kecil tepat di bawahnya.
    final sisa = books.where((b) => b.id != lanjut?.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Bacain',
            style: AppType.uiTitle.copyWith(
                fontWeight: FontWeight.w800, letterSpacing: -0.3)),
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
                const SizedBox(height: AppSpacing.space5),

                if (state.error != null)
                  Container(
                    key: const Key('error'),
                    margin: const EdgeInsets.only(bottom: AppSpacing.space4),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: warna.statusErrorBg,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(state.error!,
                        style: AppType.uiBody
                            .copyWith(color: warna.statusError)),
                  ),

                if (books.isEmpty) _rakKosong(context),

                if (lanjut != null) ...[
                  _KartuLanjutkan(book: lanjut, onOpen: onOpen),
                  const SizedBox(height: AppSpacing.space5),
                ],

                if (sisa.isNotEmpty || lanjut != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('Rakmu',
                          style: AppType.uiHeadline.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              color: warna.textPrimary)),
                      const Spacer(),
                      Text(
                          '${books.length} '
                          '${books.length == 1 ? 'buku' : 'buku'}',
                          style: AppType.uiCaption
                              .copyWith(color: warna.textDisabled)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  // Dua kolom, tidak pernah tiga. Di 360 dp kolom ketiga
                  // memaksa judul terpotong jadi satu-dua kata, dan rak yang
                  // judulnya tidak terbaca berhenti jadi rak.
                  GridView.count(
                    key: const Key('rak'),
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.space3,
                    crossAxisSpacing: AppSpacing.space3,
                    childAspectRatio: 2.35,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final b in sisa)
                        _PetakBuku(state: state, book: b, onOpen: onOpen),
                      _PetakTambah(onTap: () => _openAddSheet(context)),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  /// Layar yang dilihat 100% user baru — dan tempat sebagian besar dari
  /// mereka memutuskan berhenti atau lanjut. Dua tombol langsung, tanpa
  /// lembar pilihan di tengah: pertanyaan "sekarang apa" harus hilang
  /// seketika.
  Widget _rakKosong(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Raknya masih kosong.',
                style: titleStyle, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.space2),
            Text(
              'Mulai saja dari buku yang paling lama kamu tunda. '
              'Satu bagian dulu, tidak perlu semuanya.',
              style: bodyStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.space6),
            PrimaryButton(
              'Foto buku fisik',
              key: const Key('kosong-kamera'),
              icon: Icons.photo_camera_outlined,
              onPressed:
                  state.scanner.available ? () => _scanBook(context) : null,
            ),
            const SizedBox(height: AppSpacing.space2),
            SecondaryButton(
              'Ambil file PDF atau EPUB',
              key: const Key('kosong-berkas'),
              icon: Icons.description_outlined,
              onPressed: () => _pickFile(context),
            ),
            const SizedBox(height: AppSpacing.space3),
            Text(
              state.scanner.available
                  ? 'Ambil file membuka file manager bawaan HP.'
                  : 'Kamera hanya ada di versi Android. Ambil file membuka '
                      'file manager bawaan HP.',
              style: AppType.uiCaption.copyWith(color: warna.textDisabled),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.space4),
            Center(
              child: QuietButton('Coba dengan buku contoh',
                  key: const Key('kosong-contoh'),
                  onPressed: () => _loadSample(context)),
            ),
          ],
        ),
      );
}

/// Satu-satunya bidang warna besar di seluruh layar, karena ia satu-satunya
/// aksi utama. Begitu ada bidang warna kedua, keduanya berhenti berarti.
class _KartuLanjutkan extends StatelessWidget {
  final StoredBook book;
  final void Function(StoredBook) onOpen;
  const _KartuLanjutkan({required this.book, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final bagian = book.segments.isEmpty
        ? null
        : book.segments[
            (book.lastFinishedIndex + 1).clamp(0, book.segments.length - 1)];
    final menit = bagian?.estimatedDuration().inMinutes ?? 0;

    return Material(
      color: warna.brandPrimary,
      borderRadius: BorderRadius.circular(AppRadius.md + 2),
      child: InkWell(
        key: const Key('lanjutkan'),
        borderRadius: BorderRadius.circular(AppRadius.md + 2),
        onTap: () => onOpen(book),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LANJUTKAN',
                  style: AppType.uiCaption.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                      color: warna.brandOnPrimary.withValues(alpha: 0.62))),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Sampul(title: book.title, width: 52, height: 70),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(book.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.readingChapterTitle.copyWith(
                                fontSize: 21,
                                height: 1.12,
                                color: warna.brandOnPrimary)),
                        const SizedBox(height: 3),
                        Builder(builder: (context) {
                          final gaya = AppType.uiCaption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: warna.brandOnPrimary
                                  .withValues(alpha: 0.72));
                          if (bagian == null) {
                            return Text('Siap didengarkan', style: gaya);
                          }
                          final nama = bagian.title.isEmpty
                              ? 'Bagian ${bagian.index + 1}'
                              : bagian.title;
                          return Row(
                            children: [
                              Flexible(
                                child: Text(nama,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: gaya),
                              ),
                              Text(' · $menit menit',
                                  maxLines: 1, style: gaya),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: LinearProgressIndicator(
                        value: book.progress,
                        minHeight: 4,
                        backgroundColor:
                            warna.brandOnPrimary.withValues(alpha: 0.22),
                        valueColor:
                            AlwaysStoppedAnimation(warna.brandOnPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${(book.progress * 100).round()}%',
                      style: AppType.uiCaption.copyWith(
                          fontWeight: FontWeight.w800,
                          color:
                              warna.brandOnPrimary.withValues(alpha: 0.78))),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 11),
                    decoration: BoxDecoration(
                      color: warna.brandOnPrimary,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow,
                            size: 15, color: warna.textPrimary),
                        const SizedBox(width: 6),
                        Text('Putar',
                            style: AppType.uiLabel
                                .copyWith(color: warna.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sampul yang dibangkitkan dari judul. Buku hasil foto dan sebagian besar
/// PDF tidak punya gambar sampul — tanpa ini rak jadi barisan kotak kosong.
class _Sampul extends StatelessWidget {
  final String title;
  final double width;
  final double height;
  const _Sampul(
      {required this.title, required this.width, required this.height});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          // Sengaja PERSEGI, tidak pernah pil: warna sampul dipilih dari hash
          // judul dan tidak berarti apa-apa, sedangkan pil selalu berarti
          // aksi. Salah satu warna sampul kebetulan sama dengan warna aksi —
          // bentuknya yang membedakan.
          color: AppCover.forTitle(title),
          borderRadius: BorderRadius.circular(AppRadius.sm - 1),
        ),
      );
}

class _PetakBuku extends StatelessWidget {
  final AppState state;
  final StoredBook book;
  final void Function(StoredBook) onOpen;
  const _PetakBuku(
      {required this.state, required this.book, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: warna.bgSurface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        key: Key('book-${book.id}'),
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => onOpen(book),
        onLongPress: () => state.removeBook(book),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _Sampul(title: book.title, width: 38, height: 52),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.uiCaption.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            color: warna.textPrimary)),
                    const SizedBox(height: 3),
                    Text(
                      book.isFinished
                          ? 'Selesai'
                          : book.lastFinishedIndex < 0
                              ? 'Belum disentuh'
                              : '${(book.progress * 100).round()}%',
                      style: AppType.uiCaption.copyWith(
                          fontSize: 11, color: warna.textDisabled),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetakTambah extends StatelessWidget {
  final VoidCallback onTap;
  const _PetakTambah({required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        key: const Key('add-book'),
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: DottedKotak(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 15, color: warna.textSecondary),
              const SizedBox(width: 8),
              Text('Tambah',
                  style: AppType.uiCaption.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: warna.textSecondary)),
            ],
          ),
        ),
      );
}

/// Kotak bergaris putus-putus. Flutter tidak punya border putus-putus bawaan,
/// dan menariknya lewat paket tambahan tidak sepadan untuk satu petak — garis
/// tipis penuh sudah cukup membedakannya dari kartu buku yang berlatar.
class DottedKotak extends StatelessWidget {
  final Widget child;
  const DottedKotak({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: warna.borderStrong),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Center(child: child),
      );
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
