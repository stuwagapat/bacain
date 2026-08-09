import 'package:flutter/material.dart';

import '../app_state.dart';
import '../ui/tokens.dart';

class SettingsPage extends StatelessWidget {
  final AppState state;
  const SettingsPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final s = state.settings;
        return Scaffold(
          appBar: AppBar(title: const Text('Pengaturan')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
            children: [
              _group('KEBIASAAN'),
              ListTile(
                key: const Key('set-time'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Pengingat harian'),
                trailing: Text(s.reminderLabel,
                    style: const TextStyle(color: ink2, fontSize: 14)),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime:
                        TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute),
                  );
                  if (picked == null) return;
                  await state.updateSettings(s.copyWith(
                      reminderHour: picked.hour, reminderMinute: picked.minute));
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.reminderOn,
                activeThumbColor: green,
                title: const Text('Notifikasi'),
                subtitle: Text(
                    'Satu pengingat sehari. Di web tidak ada — notifikasi '
                    'browser cuma hidup selama tab-nya terbuka.',
                    style: bodyStyle.copyWith(fontSize: 12.5)),
                // Izin diminta saat DINYALAKAN, bukan saat app pertama dibuka.
                // Menodong izin di layar pertama sebelum user tahu gunanya
                // adalah cara tercepat untuk ditolak permanen.
                onChanged: (v) async {
                  if (v) await state.reminders.requestPermission();
                  await state.updateSettings(s.copyWith(reminderOn: v));
                },
              ),
              _slider(
                key: const Key('set-quota'),
                label: 'Jatah harian',
                value: s.dailyMinutes.toDouble(),
                min: 5,
                max: 60,
                divisions: 11,
                display: '${s.dailyMinutes} menit',
                note: 'Yang dibatasi hanya bagian BARU. '
                    'Mendengar ulang bagian lama selalu bebas.',
                onChanged: (v) =>
                    state.updateSettings(s.copyWith(dailyMinutes: v.round())),
              ),
              const SizedBox(height: 18),
              _group('SUARA'),
              if (state.player.engine.voices.isNotEmpty)
                ListTile(
                  key: const Key('set-voice'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Suara pembaca'),
                  trailing: SizedBox(
                    width: 170,
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: s.voiceId ?? state.player.voiceId,
                      underline: const SizedBox.shrink(),
                      items: state.player.engine.voices
                          .take(12)
                          .map((v) => DropdownMenuItem(
                                value: v.id,
                                child: Text(v.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14)),
                              ))
                          .toList(),
                      onChanged: (id) =>
                          state.updateSettings(s.copyWith(voiceId: id)),
                    ),
                  ),
                ),
              _slider(
                key: const Key('set-rate'),
                label: 'Kecepatan',
                value: s.rate,
                min: 0.5,
                max: 2.0,
                divisions: 6,
                display: '${s.rate.toStringAsFixed(1)}×',
                onChanged: (v) => state.updateSettings(
                    s.copyWith(rate: double.parse(v.toStringAsFixed(2)))),
              ),
              const SizedBox(height: 18),
              _group('KETERBACAAN'),
              SwitchListTile(
                key: const Key('set-large-text'),
                contentPadding: EdgeInsets.zero,
                value: s.largeText,
                activeThumbColor: green,
                title: const Text('Huruf besar saat mendengar'),
                subtitle: Text('Memperbesar teks yang berjalan di pemutar.',
                    style: bodyStyle.copyWith(fontSize: 12.5)),
                onChanged: (v) => state.updateSettings(s.copyWith(largeText: v)),
              ),
              const SizedBox(height: 18),
              _group('UJI COBA'),
              ListTile(
                key: const Key('reset-quota'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Kembalikan jatah hari ini'),
                subtitle: Text(
                    'Terpakai ${(state.quota.usedSeconds() / 60).ceil()} menit. '
                    'Ada supaya alurnya bisa dicoba tanpa menunggu besok.',
                    style: bodyStyle.copyWith(fontSize: 12.5)),
                trailing: const Icon(Icons.refresh, color: ink2),
                onTap: state.resetQuota,
              ),
              const SizedBox(height: 22),
              Text(
                'Versi web. Kamera, OCR, notifikasi, dan pemutaran di latar '
                'belakang menyusul di versi Android. Suaranya masih suara '
                'sistem — suara AI menyusul lewat Google Cloud TTS.',
                style: bodyStyle.copyWith(fontSize: 12.5),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _group(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(t,
            style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: ink3)),
      );

  Widget _slider({
    Key? key,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    String? note,
    required ValueChanged<double> onChanged,
  }) =>
      Padding(
        key: key,
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label, style: const TextStyle(fontSize: 15, color: ink)),
                const Spacer(),
                Text(display,
                    style: const TextStyle(color: ink2, fontSize: 14)),
              ],
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              activeColor: green,
              onChanged: onChanged,
            ),
            if (note != null)
              Text(note, style: bodyStyle.copyWith(fontSize: 12.5)),
          ],
        ),
      );
}
