import 'package:flutter/material.dart';

import '../app_state.dart';
import '../ui/tokens.dart';

/// Perkenalan tiga langkah. Hanya SATU pertanyaan yang diajukan — jam dengar.
/// Sisanya penjelasan. Menumpuk keputusan di awal adalah cara tercepat
/// kehilangan user sebelum ia sempat mencoba apa pun.
class OnboardingFlow extends StatefulWidget {
  final AppState state;
  const OnboardingFlow({super.key, required this.state});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;
  late TimeOfDay _time = TimeOfDay(
    hour: widget.state.settings.reminderHour,
    minute: widget.state.settings.reminderMinute,
  );
  bool _reminderOn = true;

  static const _slides = [
    (
      'Buku yang menumpuk,\nakhirnya terbaca.',
      'Foto bukumu, dengarkan satu bab tiap hari. '
          'Tidak perlu menyisihkan waktu khusus.'
    ),
    (
      'Satu bagian sehari,\nbukan satu buku sekaligus.',
      'Bacain memecah bukumu jadi potongan seukuran satu perjalanan. '
          'Besok lanjut, tidak perlu mengulang dari awal.'
    ),
  ];

  Future<void> _finish() async {
    await widget.state.completeOnboarding(
      hour: _time.hour,
      minute: _time.minute,
      reminderOn: _reminderOn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTimeStep = _step == _slides.length;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
          child: isTimeStep ? _timeStep() : _slide(_slides[_step]),
        ),
      ),
    );
  }

  Widget _slide((String, String) s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('BACAIN',
              style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: ink2)),
          const Spacer(),
          Text(s.$1, style: titleStyle.copyWith(fontSize: 28)),
          const SizedBox(height: 14),
          Text(s.$2, style: bodyStyle),
          const Spacer(),
          _dots(),
          const SizedBox(height: 18),
          PrimaryButton(
            'Lanjut',
            key: const Key('onboard-next'),
            icon: Icons.arrow_forward,
            onPressed: () => setState(() => _step++),
          ),
        ],
      );

  Widget _timeStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kapan kamu mau dengar?',
              style: TextStyle(
                  fontSize: 15, color: ink2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          GestureDetector(
            key: const Key('pick-time'),
            onTap: () async {
              final picked =
                  await showTimePicker(context: context, initialTime: _time);
              if (picked != null) setState(() => _time = picked);
            },
            child: Text(
              '${_time.hour.toString().padLeft(2, '0')} : '
              '${_time.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                  fontSize: 62,
                  fontWeight: FontWeight.w800,
                  color: ink,
                  height: 1),
            ),
          ),
          const SizedBox(height: 10),
          Text('Ketuk untuk mengubah. Bisa diganti kapan saja di Pengaturan.',
              style: bodyStyle.copyWith(fontSize: 13)),
          const SizedBox(height: 24),
          SwitchListTile(
            key: const Key('reminder-toggle'),
            contentPadding: EdgeInsets.zero,
            value: _reminderOn,
            activeThumbColor: green,
            title: const Text('Ingatkan saya tiap hari',
                style: TextStyle(fontSize: 15, color: ink)),
            subtitle: Text(
              'Pengingat sungguhan menyusul di versi Android. '
              'Di web ini jamnya cuma disimpan.',
              style: bodyStyle.copyWith(fontSize: 12.5),
            ),
            onChanged: (v) => setState(() => _reminderOn = v),
          ),
          const Spacer(),
          _dots(),
          const SizedBox(height: 18),
          PrimaryButton('Selesai',
              key: const Key('onboard-finish'), onPressed: _finish),
        ],
      );

  Widget _dots() => Row(
        children: List.generate(_slides.length + 1, (i) {
          final active = i == _step;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(right: 6),
            width: active ? 20 : 7,
            height: 4,
            decoration: BoxDecoration(
              color: active ? orange : rule,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      );
}
