/// Nilai yang ditanam saat APK dibangun, bukan diketik user.
///
/// Diisi lewat `--dart-define` di pipa build, dan nilainya datang dari GitHub
/// Secrets — jadi tidak pernah ada di dalam kode sumber maupun riwayat git.
///
/// ```
/// flutter build apk --release \
///   --dart-define=BACAIN_TTS_URL=https://…/tts \
///   --dart-define=BACAIN_TTS_KEY=AIza…
/// ```
///
/// **Yang tertanam tetap ikut ke dalam APK.** Tidak ada di kode sumber bukan
/// berarti tidak bisa diambil: siapa pun yang memegang APK bisa mengeluarkan
/// nilai ini dari berkasnya. Bedanya cuma satu — repo-nya tetap bersih.
///
/// Karena itu urutannya penting:
///
///   • `BACAIN_TTS_URL` — alamat server sendiri. **Ini yang aman dibagikan.**
///     Kunci Google tinggal di server; yang tertanam di APK cuma alamat.
///   • `BACAIN_TTS_KEY` — kunci Google langsung. Untuk build milik sendiri
///     saat menilai suara. Jangan dipakai untuk APK yang dibagikan.
///
/// Kalau keduanya ada, alamat server yang menang.
library;

class BuildConfig {
  const BuildConfig._();

  static const ttsProxyUrl = String.fromEnvironment('BACAIN_TTS_URL');
  static const ttsApiKey = String.fromEnvironment('BACAIN_TTS_KEY');

  static bool get hasBakedTts =>
      ttsProxyUrl.trim().isNotEmpty || ttsApiKey.trim().isNotEmpty;

  /// `true` kalau yang tertanam adalah kunci telanjang, bukan alamat server.
  /// Dipakai layar Pengaturan untuk memasang peringatan sebelum APK-nya
  /// dibagikan ke orang lain.
  static bool get bakedKeyIsExposed =>
      ttsProxyUrl.trim().isEmpty && ttsApiKey.trim().isNotEmpty;
}
