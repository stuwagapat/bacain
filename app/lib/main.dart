import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'app_state.dart';
import 'core/store/library_store.dart';
import 'core/store/settings_store.dart';
import 'core/tts/segment_player.dart';
import 'platform/reminders.dart';
import 'platform/speech_engine_factory.dart';
import 'screens/book.dart';
import 'screens/library.dart';
import 'screens/onboarding.dart';
import 'ui/tokens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Dinyalakan permanen: teks jadi terbaca screen reader, dan alurnya bisa
  // diperiksa uji browser. Aksesibilitas memang salah satu klaim produk ini.
  SemanticsBinding.instance.ensureSemantics();

  final state = AppState(
    store: PrefsLibraryStore(),
    settingsStore: PrefsSettingsStore(),
    player: SegmentPlayer(engine: createSpeechEngine()),
    reminders: createReminders(),
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
        scaffoldBackgroundColor: paper,
        colorScheme: ColorScheme.fromSeed(
          seedColor: green,
          primary: green,
          surface: paper,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: paper,
          foregroundColor: ink,
          elevation: 0,
          centerTitle: false,
        ),
        dividerColor: rule,
      ),
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
