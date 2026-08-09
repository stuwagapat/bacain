/// Layanan latar depan Android, supaya bacaan tidak berhenti saat layar mati.
///
/// Layanannya sengaja TIDAK mengerjakan apa pun sendiri — tidak ada callback
/// berulang, tidak ada isolate kedua. Tugasnya cuma satu: menaikkan derajat
/// proses supaya Android tidak membunuhnya, sementara mesin bicara tetap
/// berjalan di isolate utama bersama seluruh logika pemutar.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../core/playback/keep_awake.dart';

KeepAwake createKeepAwake() =>
    kIsWeb ? NoopKeepAwake() : ForegroundServiceKeepAwake();

class ForegroundServiceKeepAwake implements KeepAwake {
  var _configured = false;

  void _configure() {
    if (_configured) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'memutar',
        channelName: 'Sedang membacakan',
        channelDescription:
            'Muncul selama Bacain membacakan, supaya tidak terhenti saat '
            'layar mati.',
        // Serendah mungkin: notifikasi ini keterangan, bukan panggilan.
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Tidak ada pekerjaan berulang yang perlu dijalankan layanan ini.
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        autoRunOnBoot: false,
        allowAutoRestart: false,
      ),
    );
    _configured = true;
  }

  @override
  Future<void> start({required String title, required String text}) async {
    _configure();
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        );
        return;
      }
      await FlutterForegroundTask.startService(
        // Android 14+ menuntut jenis layanan disebutkan. Yang dikerjakan di
        // sini memang pemutaran suara.
        serviceTypes: [ForegroundServiceTypes.mediaPlayback],
        notificationTitle: title,
        notificationText: text,
      );
    } catch (_) {
      // Izin ditolak atau layanan tidak bisa dimulai. Bacaan tetap jalan
      // selama app di depan — jangan sampai ini menjatuhkan pemutar.
    }
  }

  @override
  Future<void> stop() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {
      // Sudah berhenti duluan. Bukan masalah.
    }
  }
}
