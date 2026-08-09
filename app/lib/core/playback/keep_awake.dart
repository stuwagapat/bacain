/// Menjaga app tetap hidup selagi membacakan.
///
/// Tanpa ini Android bebas membunuh proses begitu layarnya mati, dan bacaan
/// berhenti di tengah jalan. Justru di situ app ini dipakai: di jalan, sambil
/// beres-beres, dengan layar mati di saku.
///
/// Antarmukanya ada di `core/` supaya `AppState` bisa memakainya tanpa
/// menarik paket platform ke dalam uji.
library;

abstract class KeepAwake {
  /// Menyalakan layanan latar depan. Judul dan keterangan tampil di
  /// notifikasi yang WAJIB terlihat selama layanan hidup — itu aturan
  /// Android, sekaligus jujur: user berhak tahu app-nya masih jalan.
  Future<void> start({required String title, required String text});

  Future<void> stop();
}

/// Dipakai di web dan sebagai bawaan saat uji.
class NoopKeepAwake implements KeepAwake {
  @override
  Future<void> start({required String title, required String text}) async {}
  @override
  Future<void> stop() async {}
}

class FakeKeepAwake implements KeepAwake {
  int starts = 0;
  int stops = 0;
  bool running = false;
  final List<String> judul = [];

  @override
  Future<void> start({required String title, required String text}) async {
    starts++;
    running = true;
    judul.add(title);
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
  }
}
