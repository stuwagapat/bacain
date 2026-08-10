import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'app_state.dart';
import 'core/store/library_store.dart';
import 'core/store/settings_store.dart';
import 'core/tts/cloud_speech_engine.dart';
import 'core/tts/google_tts_client.dart';
import 'core/tts/segment_player.dart';
import 'core/tts/tts_budget.dart';
import 'platform/keep_awake.dart';
import 'platform/audio_sink.dart';
import 'platform/file_audio_cache.dart';
import 'platform/page_scanner.dart';
import 'platform/reminders.dart';
import 'platform/speech_engine_factory.dart';
import 'screens/book.dart';
import 'screens/library.dart';
import 'screens/onboarding.dart';
import 'ui/bingkai_ponsel.dart';
import 'ui/tokens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Dinyalakan permanen: teks jadi terbaca screen reader, dan alurnya bisa
  // diperiksa uji browser. Aksesibilitas memang salah satu klaim produk ini.
  SemanticsBinding.instance.ensureSemantics();

  final state = AppState(
    store: PrefsLibraryStore(),
    settingsStore: PrefsSettingsStore(),
    // Mesin cloud dibungkus di atas mesin sistem. Kredensialnya dipasang
    // belakangan dari Pengaturan; selama belum ada, mesin sistem yang dipakai
    // dan app tetap membacakan seperti biasa.
    player: SegmentPlayer(
      engine: CloudSpeechEngine(
        client: GoogleTtsClient(),
        cache: createAudioCache(),
        sink: PlayerAudioSink(),
        budget: TtsBudget(),
        fallback: createSpeechEngine(),
      ),
    ),
    reminders: createReminders(),
    keepAwake: createKeepAwake(),
    scanner: createPageScanner(),
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
      // Gelap adalah keadaan awal, bukan pilihan. App ini didengarkan malam
      // hari dan menjelang tidur; layar terang di kamar gelap adalah yang
      // paling cepat membuat orang berhenti.
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: AppType.uiFamily,
        scaffoldBackgroundColor: warna.bgBase,
        colorScheme: ColorScheme.fromSeed(
          seedColor: warna.brandPrimary,
          primary: warna.brandPrimary,
          onPrimary: warna.brandOnPrimary,
          surface: warna.bgSurface,
          onSurface: warna.textPrimary,
          brightness: Brightness.dark,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: warna.bgBase,
          foregroundColor: warna.textPrimary,
          elevation: 0,
          centerTitle: false,
        ),
        dividerColor: warna.borderDefault,
      ),
      // Dipasang di `builder`, bukan membungkus `home`: builder membungkus
      // Navigator, jadi SELURUH layar ikut dibatasi — termasuk pemutar,
      // pengaturan, dan bottom sheet yang didorong belakangan. Membungkus
      // `home` saja akan membuat layar pertama rapi lalu sisanya melar.
      builder: (context, child) =>
          BingkaiPonsel(child: child ?? const SizedBox.shrink()),
      home: AnimatedBuilder(
        animation: widget.state,
        builder: (context, _) {
          final s = widget.state;
          if (s.busy && s.books.isEmpty && !s.settings.onboarded) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (!s.settings.onboarded) return OnboardingFlow(state: s);
          if (s.active != null) return BookPage(state: s);
          return LibraryPage(state: s, onOpen: s.openBook);
        },
      ),
    );
  }
}
