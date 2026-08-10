/// Uji untuk empat layar yang baru masuk dari papan desain.
///
/// Yang diuji di sini bukan rupanya, tapi **janji yang dipegang layarnya**:
/// panduan kamera muncul sekali, halaman buram tertangkap sebelum OCR,
/// tombol dengar-ulang tidak pernah dikunci, dan petunjuk sekali-tampil
/// benar-benar sekali.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bacain/app_state.dart';
import 'package:bacain/core/scan/page_scanner.dart';
import 'package:bacain/core/store/library_store.dart';
import 'package:bacain/core/store/settings_store.dart';
import 'package:bacain/core/tts/segment_player.dart';
import 'package:bacain/core/tts/speech_engine.dart';
import 'package:bacain/screens/player.dart';
import 'package:bacain/screens/scan_intro.dart';
import 'package:bacain/screens/scan_tray.dart';
import 'package:bacain/ui/tokens.dart';

import 'app_state_test.dart' show sampleEpub;

AppState buatState({
  AppSettings settings = const AppSettings(onboarded: true),
  List<ScannedPage> hasilScan = const [],
}) {
  final store = MemorySettingsStore()..settings = settings;
  return AppState(
    store: MemoryLibraryStore(),
    settingsStore: store,
    player: SegmentPlayer(engine: FakeSpeechEngine()),
    scanner: FakeScanner(hasilScan),
  );
}

Widget bungkus(Widget child) => MaterialApp(home: child);

ScannedPage foto(String text, [String path = '/tmp/a.jpg']) =>
    ScannedPage(imagePath: path, text: text);

/// Satu buku terpasang dan bagian pertamanya terbuka, supaya pemutar punya
/// sesuatu untuk ditampilkan.
Future<void> bukaBagian(AppState state) async {
  await state.init();
  final book = (await state.addEpub(sampleEpub(), filename: 'x.epub'))!;
  state.openBook(book);
  await state.openSegment(0);
}

const _isiPenuh =
    'Ia menutup buku itu dan membiarkannya di meja dekat jendela yang '
    'setengah terbuka, lalu lupa selama berbulan-bulan.';

void main() {
  group('4b · Siap memotret', () {
    testWidgets('menyebut ketiga hal yang tidak bisa disampaikan kamera sistem',
        (t) async {
      await t.pumpWidget(bungkus(const ScanIntroPage()));

      expect(find.text('Foto halamannya satu per satu.'), findsOneWidget);
      expect(find.textContaining('permukaan datar'), findsOneWidget);
      expect(find.textContaining('seluruh halaman masuk'), findsOneWidget);
      // Yang paling penting: tanpa ini user menekan rana berkali-kali dan
      // menghasilkan halaman kembar.
      expect(find.textContaining('potret otomatis'), findsOneWidget);
    });

    testWidgets('"Mulai memotret" meneruskan, "Nanti saja" tidak', (t) async {
      final jawaban = <bool?>[];
      await t.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              jawaban.add(await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const ScanIntroPage()),
              ));
            },
            child: const Text('buka'),
          ),
        ),
      ));

      await t.tap(find.text('buka'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('scan-intro-start')));
      await t.pumpAndSettle();
      expect(jawaban.single, isTrue);

      await t.tap(find.text('buka'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('scan-intro-later')));
      await t.pumpAndSettle();
      expect(jawaban.last, isFalse);
    });
  });

  group('4d · Halaman terkumpul', () {
    testWidgets('halaman yang hampir tidak terbaca ditandai', (t) async {
      await t.pumpWidget(bungkus(ScanTrayPage(
        pages: [foto(_isiPenuh, '/tmp/1.jpg'), foto('mm', '/tmp/2.jpg')],
        onScanMore: () async => const [],
      )));

      expect(find.byKey(const Key('tray-buram')), findsOneWidget);
      // Nomornya disebut: tanpa itu peringatan tidak bisa ditindaklanjuti.
      expect(find.textContaining('Halaman 2'), findsOneWidget);
    });

    testWidgets('semua halaman bagus berarti tidak ada peringatan sama sekali',
        (t) async {
      await t.pumpWidget(bungkus(ScanTrayPage(
        pages: [foto(_isiPenuh, '/tmp/1.jpg'), foto(_isiPenuh, '/tmp/2.jpg')],
        onScanMore: () async => const [],
      )));

      expect(find.byKey(const Key('tray-buram')), findsNothing);
    });

    testWidgets('membuang halaman mengurangi hitungan dan judulnya', (t) async {
      await t.pumpWidget(bungkus(ScanTrayPage(
        pages: [foto(_isiPenuh, '/tmp/1.jpg'), foto(_isiPenuh, '/tmp/2.jpg')],
        onScanMore: () async => const [],
      )));

      expect(find.text('2 halaman'), findsOneWidget);
      await t.tap(find.byKey(const Key('tray-buang-1')));
      await t.pump();

      expect(find.text('1 halaman'), findsOneWidget);
      expect(find.text('Proses 1 halaman'), findsOneWidget);
    });

    testWidgets('mengembalikan halaman yang tersisa, bukan yang masuk',
        (t) async {
      List<ScannedPage>? keluar;
      await t.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              keluar = await Navigator.of(context).push<List<ScannedPage>>(
                MaterialPageRoute(
                  builder: (_) => ScanTrayPage(
                    pages: [
                      foto(_isiPenuh, '/tmp/1.jpg'),
                      foto(_isiPenuh, '/tmp/2.jpg'),
                      foto(_isiPenuh, '/tmp/3.jpg'),
                    ],
                    onScanMore: () async => const [],
                  ),
                ),
              );
            },
            child: const Text('buka'),
          ),
        ),
      ));

      await t.tap(find.text('buka'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('tray-buang-2')));
      await t.pump();
      await t.tap(find.byKey(const Key('tray-process')));
      await t.pumpAndSettle();

      expect(keluar!.map((p) => p.imagePath).toList(),
          ['/tmp/1.jpg', '/tmp/3.jpg']);
    });
  });

  group('10 · Jatah habis', () {
    testWidgets('tombol dengar ulang tidak pernah dikunci', (t) async {
      final state = buatState();
      await state.init();
      await t.pumpWidget(bungkus(QuotaExhaustedPage(state: state)));

      final tombol = t.widget<FilledButton>(
          find.byKey(const Key('quota-ulang')));
      // MP3-nya sudah ada, tidak ada biaya baru. Mengunci ini berarti
      // menghukum user karena sudah mendengarkan.
      expect(tombol.onPressed, isNotNull);
    });

    testWidgets('nadanya memberi selamat, tanpa satu pun tanda seru',
        (t) async {
      final state = buatState();
      await state.init();
      await t.pumpWidget(bungkus(QuotaExhaustedPage(state: state)));

      expect(find.text('Cukup untuk hari ini. Lumayan, kan?'), findsOneWidget);

      final semuaTeks = t
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .join(' ');
      expect(semuaTeks, isNot(contains('!')));
      // Kata yang menghalangi, bukan merayakan.
      for (final larangan in ['habis', 'batas', 'tidak bisa']) {
        expect(semuaTeks.toLowerCase(), isNot(contains(larangan)));
      }
    });

    testWidgets('memakai latar merek penuh dengan tinta yang lolos AA',
        (t) async {
      final state = buatState();
      await state.init();
      await t.pumpWidget(bungkus(QuotaExhaustedPage(state: state)));

      final scaffold = t.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, warna.brandPrimary);

      final judul = t.widget<Text>(find.byKey(const Key('quota-title')));
      expect(judul.style?.color, warna.brandOnPrimary);
    });
  });

  group('petunjuk sekali-tampil', () {
    testWidgets('pil mode fokus muncul saat belum pernah ditutup', (t) async {
      final state = buatState();
      await bukaBagian(state);
      await t.pumpWidget(bungkus(PlayerPage(state: state)));
      await t.pump();

      expect(find.byKey(const Key('focus-hint')), findsOneWidget);
    });

    testWidgets('sekali ditutup, tidak kembali — dan tersimpan', (t) async {
      final state = buatState();
      await bukaBagian(state);
      await t.pumpWidget(bungkus(PlayerPage(state: state)));
      await t.pump();

      await t.tap(find.byKey(const Key('focus-hint')));
      await t.pumpAndSettle();

      expect(find.byKey(const Key('focus-hint')), findsNothing);
      // Tersimpan, bukan cuma hilang dari layar: petunjuk yang kembali tiap
      // app dibuka justru lebih menjengkelkan daripada tidak ada petunjuk.
      expect(state.settings.focusHintSeen, isTrue);
    });

    testWidgets('tidak muncul sama sekali kalau sudah pernah ditutup',
        (t) async {
      final state = buatState(
        settings: const AppSettings(onboarded: true, focusHintSeen: true),
      );
      await bukaBagian(state);
      await t.pumpWidget(bungkus(PlayerPage(state: state)));
      await t.pump();

      expect(find.byKey(const Key('focus-hint')), findsNothing);
    });
  });
}
