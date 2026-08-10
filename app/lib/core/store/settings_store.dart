/// Pengaturan dan jatah dengar harian.
///
/// Kuota harian bukan pembatas teknis — TTS browser gratis tanpa batas. Ini
/// mekanik produknya: yang dibatasi adalah KONTEN BARU, bukan akses ke buku
/// sendiri. Mendengar ulang bagian yang sudah selesai selalu bebas.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  /// Sudah melewati perkenalan awal.
  final bool onboarded;

  /// Jam pengingat harian, waktu lokal.
  final int reminderHour;
  final int reminderMinute;
  final bool reminderOn;

  /// Jatah konten baru per hari.
  final int dailyMinutes;

  final double rate;
  final String? voiceId;

  /// Teks bacaan diperbesar — opsi keterbacaan, bukan pemanis.
  final bool largeText;

  /// Sudah pernah melihat panduan memotret. Layar itu muncul SEKALI, sebelum
  /// kamera pertama kali dibuka — sesudahnya ia cuma menghalangi.
  final bool cameraBriefed;

  /// Sudah pernah menutup pil "Ketuk teks untuk mode fokus". Petunjuk sekali
  /// tampil yang terus muncul berubah jadi kebisingan.
  final bool focusHintSeen;

  /// Alamat server sintesis sendiri. Jalur produksi: kuncinya ada di server
  /// dan tidak pernah masuk APK.
  final String? ttsProxyUrl;

  /// Kunci Google yang diketik user, HANYA untuk menilai suaranya. Disimpan
  /// di perangkatnya sendiri, tidak pernah ikut dikompilasi. Kalau server
  /// sudah ada, server yang dipakai dan kunci ini diabaikan.
  final String? ttsApiKey;

  const AppSettings({
    this.onboarded = false,
    this.reminderHour = 7,
    this.reminderMinute = 0,
    this.reminderOn = true,
    this.dailyMinutes = 20,
    this.rate = 1.0,
    this.voiceId,
    this.largeText = false,
    this.cameraBriefed = false,
    this.focusHintSeen = false,
    this.ttsProxyUrl,
    this.ttsApiKey,
  });

  bool get cloudTtsConfigured =>
      (ttsProxyUrl ?? '').trim().isNotEmpty || (ttsApiKey ?? '').trim().isNotEmpty;

  Duration get dailyBudget => Duration(minutes: dailyMinutes);

  String get reminderLabel =>
      '${reminderHour.toString().padLeft(2, '0')}.${reminderMinute.toString().padLeft(2, '0')}';

  AppSettings copyWith({
    bool? onboarded,
    int? reminderHour,
    int? reminderMinute,
    bool? reminderOn,
    int? dailyMinutes,
    double? rate,
    String? voiceId,
    bool? largeText,
    bool? cameraBriefed,
    bool? focusHintSeen,
    String? ttsProxyUrl,
    String? ttsApiKey,
  }) =>
      AppSettings(
        onboarded: onboarded ?? this.onboarded,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
        reminderOn: reminderOn ?? this.reminderOn,
        dailyMinutes: dailyMinutes ?? this.dailyMinutes,
        rate: rate ?? this.rate,
        voiceId: voiceId ?? this.voiceId,
        largeText: largeText ?? this.largeText,
        cameraBriefed: cameraBriefed ?? this.cameraBriefed,
        focusHintSeen: focusHintSeen ?? this.focusHintSeen,
        ttsProxyUrl: ttsProxyUrl ?? this.ttsProxyUrl,
        ttsApiKey: ttsApiKey ?? this.ttsApiKey,
      );

  Map<String, dynamic> toJson() => {
        'onboarded': onboarded,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'reminderOn': reminderOn,
        'dailyMinutes': dailyMinutes,
        'rate': rate,
        'voiceId': voiceId,
        'largeText': largeText,
        'cameraBriefed': cameraBriefed,
        'focusHintSeen': focusHintSeen,
        'ttsProxyUrl': ttsProxyUrl,
        'ttsApiKey': ttsApiKey,
      };

  static AppSettings fromJson(Map<String, dynamic> j) => AppSettings(
        onboarded: j['onboarded'] as bool? ?? false,
        reminderHour: (j['reminderHour'] as num?)?.toInt() ?? 7,
        reminderMinute: (j['reminderMinute'] as num?)?.toInt() ?? 0,
        reminderOn: j['reminderOn'] as bool? ?? true,
        dailyMinutes: (j['dailyMinutes'] as num?)?.toInt() ?? 20,
        rate: (j['rate'] as num?)?.toDouble() ?? 1.0,
        voiceId: j['voiceId'] as String?,
        largeText: j['largeText'] as bool? ?? false,
        cameraBriefed: j['cameraBriefed'] as bool? ?? false,
        focusHintSeen: j['focusHintSeen'] as bool? ?? false,
        ttsProxyUrl: j['ttsProxyUrl'] as String?,
        ttsApiKey: j['ttsApiKey'] as String?,
      );
}

/// Pemakaian jatah untuk satu hari kalender (waktu lokal).
class DailyUsage {
  final String day; // yyyy-mm-dd
  final int seconds;

  const DailyUsage({required this.day, required this.seconds});

  Map<String, dynamic> toJson() => {'day': day, 'seconds': seconds};

  static DailyUsage fromJson(Map<String, dynamic> j) => DailyUsage(
        day: j['day'] as String? ?? '',
        seconds: (j['seconds'] as num?)?.toInt() ?? 0,
      );

  static String dayOf(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
}

/// Menghitung jatah yang sudah terpakai hari ini. Berganti hari otomatis
/// mengembalikan jatah penuh — tanpa perlu ada yang membersihkan.
class QuotaTracker {
  final DateTime Function() now;
  DailyUsage _usage;

  QuotaTracker({DailyUsage? usage, DateTime Function()? clock})
      : now = clock ?? DateTime.now,
        _usage = usage ?? const DailyUsage(day: '', seconds: 0);

  DailyUsage get usage => _usage;

  int usedSeconds() {
    final today = DailyUsage.dayOf(now());
    if (_usage.day != today) return 0;
    return _usage.seconds;
  }

  int remainingSeconds(AppSettings s) {
    final left = s.dailyBudget.inSeconds - usedSeconds();
    return left < 0 ? 0 : left;
  }

  bool isExhausted(AppSettings s) => remainingSeconds(s) <= 0;

  /// Catat pemakaian. Mengembalikan `true` kalau ada yang tercatat.
  bool spend(int seconds) {
    if (seconds <= 0) return false;
    final today = DailyUsage.dayOf(now());
    _usage = _usage.day == today
        ? DailyUsage(day: today, seconds: _usage.seconds + seconds)
        : DailyUsage(day: today, seconds: seconds);
    return true;
  }

  /// Hanya untuk keperluan uji dan tombol "atur ulang" di pengaturan.
  void reset() => _usage = DailyUsage(day: DailyUsage.dayOf(now()), seconds: 0);
}

abstract class SettingsStore {
  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings s);
  Future<DailyUsage> loadUsage();
  Future<void> saveUsage(DailyUsage u);
}

class PrefsSettingsStore implements SettingsStore {
  static const _settingsKey = 'bacain.settings.v1';
  static const _usageKey = 'bacain.usage.v1';

  @override
  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  @override
  Future<void> saveSettings(AppSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(s.toJson()));
  }

  @override
  Future<DailyUsage> loadUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usageKey);
    if (raw == null) return const DailyUsage(day: '', seconds: 0);
    try {
      return DailyUsage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const DailyUsage(day: '', seconds: 0);
    }
  }

  @override
  Future<void> saveUsage(DailyUsage u) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usageKey, jsonEncode(u.toJson()));
  }
}

class MemorySettingsStore implements SettingsStore {
  AppSettings settings = const AppSettings();
  DailyUsage usage = const DailyUsage(day: '', seconds: 0);

  @override
  Future<AppSettings> loadSettings() async => settings;
  @override
  Future<void> saveSettings(AppSettings s) async => settings = s;
  @override
  Future<DailyUsage> loadUsage() async => usage;
  @override
  Future<void> saveUsage(DailyUsage u) async => usage = u;
}
