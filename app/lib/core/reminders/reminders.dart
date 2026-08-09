/// Antarmuka pengirim pengingat.
///
/// Ada di `core/` — bukan di `platform/` — supaya `AppState` bisa memakainya
/// tanpa menarik paket notifikasi ke dalam uji. Penerapan sungguhannya di
/// `platform/reminders.dart`.
library;

import 'reminder_plan.dart';

abstract class Reminders {
  Future<void> init();

  /// Meminta izin memunculkan notifikasi. `false` kalau ditolak — pemanggil
  /// yang memutuskan apa artinya, bukan lapisan ini.
  Future<bool> requestPermission();

  /// Ganti seluruh jadwal dengan daftar ini. Selalu menimpa, tidak menambah,
  /// supaya pengingat lama tidak menumpuk diam-diam.
  Future<void> replaceAll(List<PlannedReminder> planned);

  Future<void> cancelAll();
}

/// Dipakai di web dan sebagai bawaan saat uji: diam saja. Notifikasi browser
/// hanya hidup selama tab-nya terbuka, jadi menjanjikan pengingat harian di
/// sana akan bohong.
class NoopReminders implements Reminders {
  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> replaceAll(List<PlannedReminder> planned) async {}
  @override
  Future<void> cancelAll() async {}
}

/// Mencatat apa yang dijadwalkan, supaya aturan produknya bisa diperiksa.
class FakeReminders implements Reminders {
  final List<List<PlannedReminder>> jadwal = [];
  int cancelCount = 0;
  bool permissionGranted = true;

  List<PlannedReminder> get terakhir => jadwal.isEmpty ? const [] : jadwal.last;

  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => permissionGranted;
  @override
  Future<void> replaceAll(List<PlannedReminder> planned) async =>
      jadwal.add(planned);
  @override
  Future<void> cancelAll() async => cancelCount++;
}
