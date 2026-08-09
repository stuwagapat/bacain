# Alat verifikasi di browser sungguhan

`cek-pemutar.mjs` menjalankan app di Chromium dan menguji jalur yang **tidak
bisa ditangkap `flutter test`**: perilaku Web Speech API milik browser.

## Kenapa ada

Bug yang ditemukan user — "mengetuk kalimat di pemutar membuatnya berhenti
membaca" — lolos dari 76 uji Dart, dan memang seharusnya begitu: penyebabnya
bukan di logika kita, tapi di dua keanehan Chrome:

1. `cancel()` **tidak** mencabut keadaan `paused`.
2. `speak()` saat `paused` masuk antrean tapi tidak pernah berbunyi — dan
   `onend`-nya juga tidak pernah datang, jadi pemutar tampak hidup tapi bisu.

Mesin bicara tiruan di skrip ini sengaja meniru kedua keanehan itu. Jadi
skripnya gagal kalau perbaikannya dicabut, dan lolos kalau ada — sudah
dibuktikan dua arah.

## Menjalankan

```bash
export PATH=/opt/flutter/bin:$PATH
cd app && flutter build web --release --no-web-resources-cdn && cd ..
(cd app/build/web && python3 -m http.server 8099 &)

npm install playwright          # sekali saja, jangan di dalam repo
node tools/cek-pemutar.mjs
```

Keluar dengan kode 1 kalau ucapan ditelan atau ketukan tidak membacakan apa
pun. Tangkapan layar tiap langkah ditulis ke direktori kerja.

Kalau Chromium-nya tidak ketemu, sesuaikan `executablePath` di dalam skrip —
di lingkungan ini terpasang di `/opt/pw-browsers/chromium-1194/`.
