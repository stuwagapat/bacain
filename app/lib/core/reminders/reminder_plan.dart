/// Perencanaan pengingat harian.
///
/// Sengaja dipisah dari pengirimannya. Yang di sini murni perhitungan —
/// kapan pengingat jatuh dan kalimat apa yang dipakai — jadi bisa diuji utuh
/// tanpa perangkat. Bagian platform tinggal menembakkan hasilnya.
///
/// Notifikasi harian adalah titik sentuh paling berulang di seluruh produk.
/// Kalimat yang sama tiap hari selama sebulan berubah jadi kebisingan yang
/// dimatikan user, jadi teksnya berganti-ganti dan dijadwalkan beberapa hari
/// ke depan sekaligus — supaya tetap berganti walau app-nya tidak dibuka.
library;

import '../store/settings_store.dart';

class PlannedReminder {
  /// Tetap dan bisa ditebak, supaya penjadwalan ulang menimpa yang lama
  /// alih-alih menumpuk.
  final int id;
  final DateTime at;
  final String title;
  final String body;

  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });

  @override
  String toString() => '#$id $at · $title — $body';
}

/// Varian kalimat pengingat. Nada: hangat, mengajak, tidak pernah menyalahkan.
/// Tanpa kosakata produktivitas — tidak ada "target", "optimalkan", "jangan
/// sampai putus".
const _openings = <(String, String)>[
  ('Bagian hari ini sudah siap', 'Tinggal didengarkan, {menit} menit saja.'),
  ('Ada yang menunggu dibacakan', '{buku} — {menit} menit untuk hari ini.'),
  ('Lanjut sedikit hari ini?', '{bagian} sudah menunggu di rak.'),
  ('{buku} menunggu', 'Satu bagian, {menit} menit. Tidak perlu buru-buru.'),
  ('Waktunya mendengar', '{bagian} — pas untuk perjalanan hari ini.'),
  ('Bagian berikutnya sudah siap', 'Dengarkan sambil jalan, {menit} menit.'),
  ('Sedikit lagi dari {buku}', 'Hari ini {bagian}.'),
  ('Bukumu masih di sini', '{menit} menit, kapan pun kamu sempat.'),
  ('Mau lanjut mendengar?', '{bagian} tinggal dibuka.'),
  ('Satu bagian untuk hari ini', '{buku} — santai saja, {menit} menit.'),
];

/// Kalimat cadangan saat raknya masih kosong: tidak boleh menyebut buku yang
/// tidak ada.
const _emptyShelf = <(String, String)>[
  ('Raknya masih kosong', 'Mulai dari buku yang paling lama kamu tunda.'),
  ('Belum ada yang dibacakan', 'Masukkan satu buku, sisanya kami yang atur.'),
  ('Mau mulai satu buku?', 'Cukup satu, tidak perlu semuanya sekaligus.'),
];

class ReminderPlanner {
  const ReminderPlanner();

  /// Berapa hari ke depan dijadwalkan sekaligus. Dijadwalkan ulang tiap app
  /// dibuka, jadi angka ini hanya menentukan berapa lama teksnya tetap
  /// berganti kalau app-nya lama tidak disentuh.
  static const daysAhead = 7;

  List<PlannedReminder> plan(
    DateTime now,
    AppSettings settings, {
    String? bookTitle,
    String? segmentTitle,
    int? minutes,
  }) {
    if (!settings.reminderOn) return const [];

    final out = <PlannedReminder>[];
    for (var day = 0; day < daysAhead; day++) {
      final at = _slotFor(now, settings, day);
      // Jam hari ini yang sudah lewat dilewati — memunculkan pengingat untuk
      // waktu yang sudah berlalu cuma membingungkan.
      if (!at.isAfter(now)) continue;

      final punya = (bookTitle ?? '').trim().isNotEmpty;
      final daftar = punya ? _openings : _emptyShelf;
      final v = daftar[_indexFor(at) % daftar.length];

      out.add(PlannedReminder(
        id: 1000 + day,
        at: at,
        title: _fill(v.$1, bookTitle, segmentTitle, minutes, settings),
        body: _fill(v.$2, bookTitle, segmentTitle, minutes, settings),
      ));
    }
    return out;
  }

  DateTime _slotFor(DateTime now, AppSettings s, int dayOffset) {
    final d = DateTime(now.year, now.month, now.day + dayOffset);
    return DateTime(d.year, d.month, d.day, s.reminderHour, s.reminderMinute);
  }

  /// Berbasis tanggal, bukan acak: dua kali menjadwalkan untuk hari yang sama
  /// menghasilkan kalimat yang sama, jadi tidak berkedip-kedip kalau user
  /// membuka app berkali-kali.
  int _indexFor(DateTime at) =>
      at.difference(DateTime(2026, 1, 1)).inDays.abs();

  String _fill(
    String t,
    String? book,
    String? segment,
    int? minutes,
    AppSettings s,
  ) =>
      t
          .replaceAll('{buku}', (book ?? '').trim())
          .replaceAll('{bagian}',
              (segment ?? '').trim().isEmpty ? 'Bagian berikutnya' : segment!.trim())
          .replaceAll('{menit}', '${minutes ?? s.dailyMinutes}');
}
