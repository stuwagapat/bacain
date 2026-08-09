/// Pengirim pengingat harian.
///
/// Antarmukanya sengaja tipis: terima daftar pengingat yang SUDAH dihitung,
/// lalu jadwalkan. Semua keputusan — kapan, kalimat apa, dilewati atau tidak
/// — ada di `core/reminders/reminder_plan.dart` supaya bisa diuji tanpa HP.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/reminders/reminder_plan.dart';
import '../core/reminders/reminders.dart';

Reminders createReminders() => kIsWeb ? NoopReminders() : LocalReminders();

class LocalReminders implements Reminders {
  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;

  static const _channel = AndroidNotificationChannel(
    'harian',
    'Pengingat harian',
    description: 'Satu pengingat sehari, di jam yang kamu pilih.',
    importance: Importance.defaultImportance,
  );

  @override
  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Zona waktu perangkat tidak terbaca. Jakarta sebagai cadangan —
      // meleset sejam jauh lebih baik daripada pengingatnya tidak jalan.
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    return await android.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> planned) async {
    await init();
    await cancelAll();
    for (final r in planned) {
      try {
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          scheduledDate: tz.TZDateTime.from(r.at, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'harian',
              'Pengingat harian',
              channelDescription:
                  'Satu pengingat sehari, di jam yang kamu pilih.',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
          ),
          // Tanpa alarm persis: Android 12+ menuntut izin khusus untuk itu,
          // dan meminta izin sebesar itu demi pengingat baca tidak sepadan.
          // Meleset beberapa menit sama sekali tidak masalah di sini.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (_) {
        // Satu jadwal gagal tidak boleh menjatuhkan sisanya.
      }
    }
  }

  @override
  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}
