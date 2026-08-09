# Paket google_mlkit_text_recognition merujuk SEMUA varian aksara — Tionghoa,
# Devanagari, Jepang, Korea — padahal kita hanya memakai Latin. R8 menolak
# menyelesaikan build karena kelas-kelas itu tidak ada di dependensi.
#
# Didiamkan, bukan ditambahkan: menyeret empat model aksara yang tidak akan
# pernah dipakai hanya untuk menyenangkan R8 akan menggemukkan APK tanpa
# guna. Kalau nanti butuh aksara lain, tambahkan paketnya dan hapus baris
# yang bersangkutan di sini.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
