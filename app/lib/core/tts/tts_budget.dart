/// Pagu karakter sintesis per hari.
///
/// Ini penjaga tagihan, bukan mekanik produk. Jatah dengar harian sudah
/// membatasi konten baru; yang dijaga di sini adalah kemungkinan lain:
/// satu bug perulangan yang memanggil sintesis terus-menerus bisa
/// menghabiskan kuota gratis — bahkan menembusnya — dalam semalam, tanpa
/// ada yang mendengarkan apa pun.
///
/// Cache adalah pertahanan pertama: kalimat yang sama tidak pernah dibayar
/// dua kali. Pagu ini pertahanan kedua, untuk hal yang tidak terpikirkan.
library;

class DailyChars {
  final String day; // yyyy-mm-dd
  final int chars;

  const DailyChars({required this.day, required this.chars});

  Map<String, dynamic> toJson() => {'day': day, 'chars': chars};

  static DailyChars fromJson(Map<String, dynamic> j) => DailyChars(
        day: j['day'] as String? ?? '',
        chars: (j['chars'] as num?)?.toInt() ?? 0,
      );

  static String dayOf(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
}

class TtsBudget {
  TtsBudget({
    this.maxCharsPerDay = defaultMaxCharsPerDay,
    DailyChars? usage,
    DateTime Function()? clock,
  })  : now = clock ?? DateTime.now,
        _usage = usage ?? const DailyChars(day: '', chars: 0);

  /// 60.000 karakter/hari ≈ 40 ribu kata ≈ jauh di atas jatah dengar 20 menit
  /// (±3.000 kata). Longgar untuk pemakaian wajar, ketat untuk perulangan
  /// yang lepas kendali. Kuota gratis WaveNet 4 juta/bulan tetap aman walau
  /// pagu ini terpakai penuh tiap hari oleh dua user.
  static const defaultMaxCharsPerDay = 60000;

  final int maxCharsPerDay;
  final DateTime Function() now;
  DailyChars _usage;

  DailyChars get usage => _usage;

  int usedToday() {
    final today = DailyChars.dayOf(now());
    return _usage.day == today ? _usage.chars : 0;
  }

  int get remaining {
    final left = maxCharsPerDay - usedToday();
    return left < 0 ? 0 : left;
  }

  bool canSpend(int chars) => chars <= remaining;

  void spend(int chars) {
    if (chars <= 0) return;
    final today = DailyChars.dayOf(now());
    _usage = _usage.day == today
        ? DailyChars(day: today, chars: _usage.chars + chars)
        : DailyChars(day: today, chars: chars);
  }

  void reset() => _usage = DailyChars(day: DailyChars.dayOf(now()), chars: 0);
}
