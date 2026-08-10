# Bacain — status & serah terima

Ditulis 8 Agustus 2026. Dokumen ini untuk melanjutkan pekerjaan di sesi baru
tanpa perlu membaca ulang seluruh percakapan.

Rencana lengkap (arsitektur, wireframe 11 layar, hitungan biaya TTS, daftar
aset desain) ada di [`rencana-mvp.md`](rencana-mvp.md).

---

## 1. Produk

App yang mengubah buku milik user sendiri jadi **serial audio harian**. Bukan
"satu buku jadi satu file audio raksasa", tapi buku dipecah otomatis jadi
bagian seukuran satu perjalanan, satu bagian per hari.

Hipotesis yang sedang diuji **bukan** "bisakah teks jadi suara" — itu sudah
jelas bisa. Yang belum terbukti: **apakah mekanik satu-bagian-sehari benar-benar
membuat orang menyelesaikan buku.**

Pembagian peran: user memegang produk, desain, dan identitas visual. Claude
menulis kode.

---

## 2. Status: apa yang sudah jalan

App Flutter di `app/`, dibangun untuk web supaya bisa diverifikasi, dengan kode
Dart yang sama untuk Android nanti.

**Alur lengkap sudah bisa dicoba dari awal sampai akhir** dan sudah diuji di
browser sungguhan:

perkenalan → pilih jam dengar → rak kosong → pilih sumber buku → konfirmasi
buku → daftar bagian → recap → pemutar → mode fokus → jatah habis → pengaturan

| Bagian | Keadaan |
|---|---|
| Baca EPUB (EPUB 2 & 3, NCX & nav) | jalan, teruji |
| Normalisasi teks | jalan, teruji |
| Pecah jadi bagian harian | jalan, teruji |
| Pecah kalimat (untuk highlight) | jalan, teruji |
| Pemutar + highlight mengikuti suara | jalan, teruji |
| Progres bertahan lintas sesi | jalan, teruji |
| Penguncian bagian berikutnya | jalan, teruji |
| Jatah harian | jalan, teruji |
| Mode fokus | jalan |
| Pengaturan | jalan |
| Impor PDF berlapis teks | jalan, teruji |
| Build APK lewat GitHub Actions | jalan — APK ±41 MB |
| Mesin bicara Android (flutter_tts) | kode selesai, **belum dicoba di HP** |
| Pengingat harian | kode selesai, **belum dicoba di HP** |
| Pemutaran saat layar mati | kode selesai, **belum dicoba di HP** |
| Kamera + OCR buku fisik | jalan, sudah dicoba di HP |
| Suara AI (Google Cloud TTS) | jalur selesai, **menunggu kredensial** |

**153 uji lolos** (`cd app && flutter test`).

> ⚠️ Baris "belum dicoba di HP" **tidak boleh dianggap beres**. Semuanya
> khusus Android dan nol kemungkinan diverifikasi dari sandbox ini — yang
> terbukti hanya bahwa kodenya terkompilasi dan logikanya benar. Daftar yang
> perlu dicoba ada di bagian 8.
>
> Kamera sudah dicoba di HP dan bekerja. Beberapa kalimat terlewat pada foto
> yang kurang tajam — itu batas OCR, bukan bug, dan memang alasan layar tinjau
> ada.

### Belum ada

| Belum ada | Kenapa |
|---|---|
| Kredensial Google Cloud TTS | jalurnya sudah siap, kuncinya belum ada |
| Ringkasan "sebelumnya" yang benar-benar merangkum | butuh Claude API |
| Kontrol di layar kunci | butuh MediaSession; layanan latar depan sudah ada |
| OCR untuk PDF hasil pindaian | ditolak dengan pesan yang mengarahkan ke kamera |

Layar recap **jujur** menampilkan kalimat penutup bagian sebelumnya dan
menyatakan bahwa ringkasan sungguhan menyusul — tidak mengarang ringkasan.
"Foto buku fisik" tetap tampil di sheet sumber saat dibuka di web, tapi
dimatikan dengan alasannya tertulis — supaya alur produknya utuh terlihat.

---

## 3. Cara mencoba

**Paling mudah — sudah online:**
<https://stuwagapat.github.io/bacain/>

Dilayani GitHub Pages dari branch `claude/app-pembaca-buku-ai-du5dtq`, folder
`/docs`. Tiap kali `docs/` di-push ulang, situsnya ikut ter-update.

**Menjalankan sendiri:**
```bash
export PATH=/opt/flutter/bin:$PATH
cd app
flutter test                 # 153 uji
flutter run -d chrome        # jalankan
```

**Membangun ulang untuk Pages:**
```bash
cd app && flutter build web --release --base-href /bacain/
cd .. && rm -rf docs && cp -r app/build/web docs
rm -rf docs/canvaskit && touch docs/.nojekyll && rm -f docs/.last_build_id
```

> ⚠️ `docs/` adalah **hasil build**, bukan sumber. Jangan simpan berkas tulisan
> tangan di sana — pernah terjadi: `docs/rencana-mvp.md` terhapus saat build
> pertama, dan harus dipulihkan dari riwayat git. Catatan ditulis di `notes/`.

### APK Android

APK **tidak bisa dibangun di sandbox** tempat kode ini ditulis: `dl.google.com`
diblokir kebijakan proxy, dan `maven.google.com` cuma redirect ke sana — jadi
Android SDK, `android.jar`, dan aapt2 semuanya tak terjangkau. Karena itu APK
dibangun di GitHub Actions, yang runner-nya sudah membawa Android SDK lengkap.

Ambil APK-nya: **Actions → "Bangun APK Android" → run terbaru → Artifacts →
`bacain-apk`**. Jalan otomatis tiap kali ada perubahan di `app/`, atau bisa
dipicu manual lewat tombol *Run workflow*.

Di HP: izinkan "pasang dari sumber tak dikenal" untuk aplikasi tempat APK
dibuka, lalu pasang seperti biasa.

> ⚠️ Selama belum ada kunci penandatanganan tetap, tiap build memakai kunci
> debug yang **dibuat baru setiap kali**. Tanda tangannya berubah, jadi Android
> menolak memasang versi baru di atas yang lama — penguji harus menghapus app
> dulu, dan progres mereka ikut hilang. Bisa dipasang sekali saja untuk
> mencoba, tapi untuk pengujian berhari-hari kuncinya harus ditetapkan:
>
> ```bash
> keytool -genkey -v -keystore bacain.jks -keyalg RSA \
>   -keysize 2048 -validity 10000 -alias bacain
> base64 -w0 bacain.jks        # tempel hasilnya jadi secret
> ```
>
> Lalu isi 4 secret repo (Settings → Secrets and variables → Actions):
> `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
> `ANDROID_KEY_PASSWORD`. Begitu keempatnya ada, pipa otomatis memakainya.
> **Simpan `bacain.jks` baik-baik** — kalau hilang, app tidak akan pernah bisa
> di-update di HP yang sudah memasangnya.

---

## 4. Peta repo

```
app/                       proyek Flutter
  lib/core/                logika murni — TANPA Flutter, bisa diuji tanpa emulator
    model/book.dart        Book, Chapter, Segment, countWords
    text/normalizer.dart   sambung kata terpenggal, buang header berulang
    text/sentences.dart    pecah kalimat + offset (untuk highlight)
    text/segmenter.dart    pecah buku jadi jatah harian  ← inti mekanik
    epub/epub_reader.dart  baca EPUB dari byte
    pdf/pdf_reader.dart    baca PDF berlapis teks
    text/chapter_finder.dart  tebak batas bab (dipakai PDF & hasil foto)
    scan/                  susun buku dari hasil foto + antarmuka pemindai
    reminders/             perencanaan pengingat harian (murni)
    playback/keep_awake.dart  antarmuka layanan latar depan
    tts/cloud_tts.dart        antarmuka klien, cache, dan pemutar audio
    tts/cloud_speech_engine.dart  mesin bicara ketiga: Google Cloud TTS
    tts/google_tts_client.dart    HTTP ke Google atau ke server sendiri
    tts/tts_budget.dart       pagu karakter harian — penjaga tagihan
    tts/voice_persona.dart    beri nama manusia pada suara Google
    build_config.dart         nilai yang ditanam saat build (--dart-define)
    tts/speech_engine.dart antarmuka mesin bicara + mesin tiruan untuk uji
    tts/segment_player.dart urutan, jeda, lompat, kalimat aktif
    store/                 rak buku, pengaturan, jatah harian
  lib/platform/            mesin bicara per platform
    web_speech_engine.dart    browser: speechSynthesis
    native_speech_engine.dart Android: flutter_tts
    page_scanner.dart         kamera Google + OCR ML Kit
    reminders.dart            notifikasi terjadwal
    keep_awake.dart           layanan latar depan
    audio_sink.dart           pemutar MP3 hasil sintesis
    file_audio_cache.dart     cache audio di penyimpanan perangkat
  lib/screens/             layar          ← lapisan desain
  lib/ui/tokens.dart       warna & widget bersama  ← lapisan desain
  test/                    153 uji
  android/                 konfigurasi Android (manifest, gradle, penandatanganan)
  assets/contoh.epub       buku contoh, teks tulisan sendiri (bukan berhak cipta)
.github/workflows/apk.yml  pipa pembangun APK
docs/                      HASIL BUILD untuk GitHub Pages — jangan diedit tangan
server/                    perantara TTS — kunci tinggal di sini, bukan di APK
tools/                     pemeriksa pemutar di Chromium sungguhan
design/                    token desain, wireframe, skrip Figma
notes/                     dokumen tulisan tangan (rencana, status ini)
prototype/                 prototipe HTML halaman 1 (sebelum Flutter)
```

**Desain hidup di dua tempat saja**: `lib/ui/tokens.dart` (warna, tipografi,
widget bersama) dan `lib/screens/` (tata letak tiap layar). Tidak ada satu pun
warna atau ukuran yang tertanam di `lib/core/` — jadi mengubah desain tidak
pernah menyentuh logika, dan tidak perlu membangun ulang apa pun selain APK.

---

## 5. Keputusan penting & alasannya

**Mesin bicara mengucap PER KALIMAT, bukan per bagian.** Chrome memutus ucapan
panjang setelah belasan detik. Per kalimat: batas itu tak pernah tersentuh,
highlight jadi tepat tanpa hitung offset, dan potongannya nanti jadi unit
caching yang wajar untuk Cloud TTS.

**Jatah harian membatasi konten BARU saja.** Mendengar ulang bagian yang sudah
selesai selalu bebas — berkasnya sudah ada, tidak ada biaya baru, dan mengunci
akses ke buku sendiri cuma menyiksa. Pemakaian dicatat setelah tiap kalimat
selesai, bukan saat bagian dibuka.

**Bab pendek digabung, bab panjang dipecah** — tapi tiap bagian selalu punya
asal bab yang jelas. Buku 6 bab pendek jadi 3 jatah, bukan 6 hari masing-masing
4 menit.

**Potongan tidak pernah jatuh di tengah kalimat.** Batas paragraf lebih dulu;
kalimat hanya kalau satu paragraf saja sudah kepanjangan.

**Aturan produk ada di `AppState`, bukan di widget** — supaya ikut terbawa utuh
ke Android tanpa ditulis ulang.

**EPUB didahulukan** karena daftar isinya eksplisit: kalau segmentasi salah,
ketahuan penyebabnya memang segmentasi, bukan OCR yang meleset.

**Perencanaan dipisah dari pengiriman.** Pengingat harian, penyusunan buku
dari hasil foto, dan pencarian bab semuanya murni perhitungan di `core/` —
lapisan platform hanya menembakkan hasilnya. Itu satu-satunya alasan fitur
khusus Android masih punya 113 uji: yang diuji keputusannya, bukan kabelnya.

**Pencari bab dipakai bersama PDF dan hasil foto.** Keduanya sampai di titik
yang sama: setumpuk halaman teks tanpa daftar isi. EPUB tidak memerlukannya
karena daftar isinya eksplisit.

**Hasil OCR selalu lewat layar tinjau.** OCR tidak akan pernah 100% benar.
Foto aslinya ditampilkan di atas teks hasil bacaan supaya user bisa
membandingkan — bukan disuruh percaya lalu baru sadar salah setelah
mendengarnya dibacakan.

**Mesin bicara melaporkan kemampuannya, bukan platformnya.** Pemutar tidak
pernah bertanya "ini Android atau web"; ia bertanya `canPauseMidSentence`.
Android tidak punya jeda sungguhan — `flutter_tts.pause()` sebenarnya
menghentikan ucapan lalu menyimpan sisa teks di dalam plugin, dan sisa itu ikut
terbawa ke ucapan berikutnya. Jadi di Android pemutar menjeda dengan cara lain:
hentikan sekarang juga, ulangi kalimat yang sama dari awal saat dilanjutkan.
Loop dibatalkan lebih dulu supaya kalimat yang terpotong tidak terhitung
selesai — kalau tidak, jatah harian ikut terpotong untuk kalimat yang belum
sempat didengar utuh.

---

## 5a. Menyalakan suara AI

Ada dua jalur, dan bedanya soal keamanan, bukan kualitas.

Langkah menyiapkan kuncinya di Google Cloud Console ada di
[`menyalakan-suara-ai.md`](menyalakan-suara-ai.md).

**Untuk menilai suaranya (sekarang):** isi secret repo `BACAIN_TTS_KEY`
dengan API key Google, lalu bangun APK. Kuncinya ditanam saat build lewat
`--dart-define` — tidak ada yang perlu diketik di HP, dan tidak ada kunci di
kode sumber. Begitu app dibuka, daftar "Suara pembaca" sudah berisi suara
Indonesia sungguhan: Chirp3 HD di atas, lalu Neural2, lalu WaveNet.

Kolom isian di Pengaturan tetap ada untuk mencoba kunci lain tanpa membangun
ulang. Yang diketik menang atas yang ditanam; dikosongkan kembali ke bawaan.

**Suara ditawarkan sebagai dua nama: Ayu (perempuan) dan Bima (laki-laki)** —
sesuai wireframe di `rencana-mvp.md`. Nama model Google tidak pernah tampil;
tiap nama dipetakan ke model TERBAIK yang tersedia hari itu, jadi tetap benar
walau Google menambah atau mencabut suara. Untuk membandingkan semua suara
saat menilai kualitas, ada saklar "Bandingkan semua suara" di bagian Suara AI;
sengaja tidak disimpan, jadi kembali ke dua pilihan begitu app ditutup.

> Keterangan di bawah tiap nama baru menyebut **tingkat modelnya** ("model
> terbaru, paling halus"). Karakter suaranya — hangat, tenang, tegas — sengaja
> dikosongkan: itu cuma bisa dinilai dengan mendengarkan, dan menuliskannya
> tanpa mendengar sama saja mengarang. Isi setelah mendengar, di
> `core/tts/voice_persona.dart` → `VoiceCatalog.noteFor`.

> ⚠️ Ditanam saat build **tetap ikut ke dalam APK.** Tidak ada di kode sumber
> bukan berarti tidak bisa diambil. Hapus secret `BACAIN_TTS_KEY` dan bangun
> ulang sebelum APK dibagikan.

**Untuk dibagikan (nanti):** terbitkan `server/` ke Cloud Run, ganti secret-nya
jadi `BACAIN_TTS_URL`, hapus `BACAIN_TTS_KEY`. App otomatis memakai server —
tidak ada kode yang berubah. Kata sandi server bisa dititipkan di URL-nya:
`https://…/tts?s=RAHASIA`. Petunjuknya di [`../server/README.md`](../server/README.md).

**Penjaga biaya, tiga lapis:**

1. **Cache** — kalimat yang sama tidak pernah dibayar dua kali, bahkan setelah
   app ditutup. Mendengar ulang benar-benar gratis.
2. **Pagu harian di app** — 60.000 karakter/hari. Kalau tersentuh, app jatuh
   ke suara sistem alih-alih berhenti membacakan.
3. **Pagu global di server** + **Budget Alert di Google Cloud Console.**
   Pasang yang terakhir itu sebelum layanannya dipakai orang lain — bukan
   sesudah tagihannya datang.

---

## 5b. Lisensi yang perlu kamu urus

**`syncfusion_flutter_pdf`** (dipakai untuk impor PDF) bukan lisensi bebas.
Lisensinya berbunyi: tidak boleh dipakai tanpa Community License **atau**
lisensi komersial.

Kamu memenuhi syarat Community License — gratis, untuk pendapatan di bawah
1 juta USD/tahun dan kurang dari 5 pengembang — tapi **harus didaftarkan**,
tidak otomatis. Daftar di syncfusion.com sebelum app ini dibagikan luas.

Kalau syarat itu mengganjal, penggantinya `pdfrx` (berbasis pdfium, lisensi
permisif). Konsekuensinya: bukan Dart murni, jadi impor PDF tidak lagi bisa
diuji tanpa perangkat — 8 uji PDF sekarang jalan justru karena Syncfusion
murni Dart.

---

## 6. Jebakan lingkungan — akan menggigit lagi

1. **Flutter ada di `/opt/flutter/bin`**, tidak di PATH bawaan. Selalu
   `export PATH=/opt/flutter/bin:$PATH`.
2. **CDN Google diblokir di sandbox ini.** Dua akibat: Flutter Web mengambil
   font Roboto dari CDN → seluruh teks hilang **tanpa satu pun pesan error**
   (sudah diperbaiki dengan menanam Plus Jakarta Sans); dan CanvasKit juga dari
   CDN → halaman putih. Untuk uji lokal, alihkan permintaan gstatic ke
   `app/build/web/canvaskit` lewat `page.route()` Playwright.
3. **Chromium headless tidak punya suara sama sekali.** Uji browser harus
   mengganti `window.speechSynthesis` — dan wajib lewat `Object.defineProperty`,
   karena itu getter read-only; penugasan biasa gagal diam-diam.
4. **Playwright + Flutter semantics**: `getByText(x, {exact:false}).first()`
   mencocokkan simpul induk yang memuat seluruh teks halaman — kliknya mendarat
   di tengah layar. Pakai `.last()` untuk simpul terdalam. Judul+subjudul
   `ListTile` menyatu jadi satu simpul, jadi pencocokan persis sering meleset.
   Klik butuh `force: true` karena lapisan semantics menghalangi.
5. **Figma MCP: 6 panggilan per BULAN** untuk plan Starter seat View — bukan
   harian, bukan jendela bergulir. Kuota sudah terpakai. Skrip Figma di
   `design/figma-scripts/` dibuat untuk dijalankan lewat plugin Scripter, yang
   tidak menyentuh kuota MCP.
6. **Vercel MCP tidak bisa dipakai** untuk app ini: tool deploy-nya menuntut isi
   tiap berkas ditempel di dalam panggilan, sedangkan `main.dart.js` 2,2 MB.
7. **`dl.google.com` diblokir kebijakan proxy** di sandbox ini, dan
   `maven.google.com` hanya redirect ke sana. Artinya Android SDK sama sekali
   tidak bisa diunduh — APK wajib dibangun di GitHub Actions. `pub.dev`,
   Maven Central, dan Gradle sendiri tetap terjangkau, jadi paket Dart dan
   `flutter test` tetap bisa dijalankan lokal.
8. **flutter_tts mengalikan dua nilai kecepatan** sebelum meneruskannya ke
   Android (`setSpeechRate(rate * 2f)`), sedangkan kecepatan normal di Android
   adalah 1.0. Kecepatan 1.0× versi kita harus dikirim sebagai **0.5**.
9. **Sejak Android 11, daftar suara pulang kosong** tanpa pesan error apa pun
   kalau `<queries>` untuk `TTS_SERVICE` tidak ada di manifest. App akan
   terlihat bisu padahal mesin TTS-nya terpasang normal.
10. **`flutter_local_notifications` menuntut core library desugaring.** Tanpa
    itu build berhenti di `checkReleaseAarMetadata`. Pesannya jelas menyebut
    nama paketnya, tapi hanya muncul setelah ±4 menit kompilasi.
11. **APK rilis tidak punya izin INTERNET secara bawaan.** Flutter hanya
    menambahkannya di build debug. Tanpa dideklarasikan di manifest utama,
    suara AI diam-diam tidak bisa menghubungi apa pun di APK rilis — dan
    gejalanya cuma "suaranya tidak berganti", bukan pesan kesalahan.
12. **R8 menolak build karena paket OCR merujuk varian aksara yang tidak
    dipasang** (Tionghoa, Devanagari, Jepang, Korea). Didiamkan lewat
    `-dontwarn` di `android/app/proguard-rules.pro`. Kalau nanti butuh aksara
    lain, tambahkan paketnya dan hapus baris yang bersangkutan.
13. **Proyek ini sengaja memakai AGP 8, bukan AGP 9 bawaan template Flutter.**
    Di AGP 9 dua paket punya asumsi yang saling bertentangan dan tidak ada
    nilai `android.builtInKotlin` yang memuaskan keduanya:
    `false` membuat `file_picker` tidak mengompilasi Kotlin-nya sama sekali
    (gagal diam-diam, muncul sebagai `cannot find symbol: FilePickerPlugin`
    di modul lain), sedangkan `true` membuat `flutter_plugin_android_lifecycle`
    ditolak AGP 9. Keduanya menyematkan AGP 8 di buildscript masing-masing.
    Jangan menaikkan AGP kembali sebelum kedua paket itu sepakat.

---

## 7. Bug yang sudah ditemukan — jangan terulang

Semuanya ketahuan dari **menjalankan**, bukan membaca kode:

- **Label tombol tidak pernah terlukis, hanya ikonnya.** `foregroundColor` tidak
  ditulis, jatuh ke `colorScheme.onPrimary` yang tidak ikut dihitung ulang saat
  `primary` ditimpa di `fromSeed`. Widget ada di pohon semantics dan semua uji
  lolos — hanya terlihat dari memandangi hasil render.
- **`skipSentences` menunggu `play()`** yang baru selesai setelah seluruh bagian
  habis dibacakan → tombol menggantung. `play()` tidak boleh di-await dari
  penangan tombol.
- **Loop lama sempat maju satu kalimat** sebelum dibatalkan, karena mesin
  dihentikan lebih dulu daripada penanda pembatalan.
- **Judul bab menempel ke kalimat pertama** karena tidak berakhiran titik.
  Batas paragraf kini selalu jadi batas kalimat.
- **`<dc:title>` tidak terbaca** karena bernamespace; `findAllElements` perlu
  `namespace: '*'`.
- **Daftar kalimat tidak ikut menggulir**, kalimat aktif terdorong keluar layar
  dan highlight kehilangan gunanya.
- **Pembuang header berulang ikut membuang kalimat isi** yang cuma berbeda
  angka. Sekarang hanya baris paling atas & bawah tiap halaman yang dicurigai.
- **Daftar singkatan terlalu galak**: "dll." dan "dsb." di Bahasa Indonesia
  justru lazim mengakhiri kalimat.

---

## 8. Berikutnya

**Menunggu keputusan user:**

1. **Tes alur** — user sedang mencobanya. Umpan balik menentukan langkah
   berikutnya.
2. **Kredensial Google Cloud TTS.** Jalurnya sudah selesai — tinggal
   ditempel di Pengaturan → Suara AI. Lihat bagian 5a.
3. **Desain.** User bilang desain menyusul setelah fungsi & alur beres. Aset
   yang sudah ada: `logo.png`, `header 1.png`, `footer 1.png`, `ornament.png`.
   Palet asli dari aset: hijau `#2D6B2D`/`#184818`, oranye `#F06C3C`, aprikot
   `#FCB46C`, krem `#EFECE7`. Sudah dipakai di app.

**Yang perlu dicoba di HP sungguhan** — semua ini tidak bisa diverifikasi dari
sandbox, jadi jangan dianggap beres sampai ada yang mencobanya:

*Suara*
- Suara id-ID muncul di daftar dan terpilih otomatis.
- Kecepatan 1.0× terdengar normal, bukan dua kali lipat.
- Tombol jeda berhenti seketika, dan saat dilanjutkan kalimatnya diulang dari
  awal — bukan melompat ke kalimat berikutnya.

*Berkas*
- Impor EPUB dan PDF lewat file picker Android.
- PDF hasil pindaian ditolak dengan pesan yang mengarahkan ke kamera.

*Suara AI* — setelah kredensial dipasang
- Daftar "Suara pembaca" berisi suara Google, bukan suara sistem.
- Memilih suara langsung memperdengarkan contohnya.
- Mendengar ulang bagian yang sama tidak menambah pemakaian karakter.
- Jeda menahan di tengah kalimat, bukan mengulang dari awal.

*Latar belakang*
- Bacaan lanjut saat layar dimatikan dan saat app ditinggal.
- Notifikasi "sedang membacakan" hilang begitu dijeda.

*Pengingat*
- Izin notifikasi diminta saat tombolnya dinyalakan.
- Notifikasi datang di jam yang dipilih, dan kalimatnya berganti antar hari.

**Pekerjaan teknis yang jelas berikutnya:**

- Pemutaran saat layar mati — butuh foreground service. Tanpa ini app tidak
  terpakai di skenario aslinya: di jalan, sambil beres-beres.
- Cloud TTS lewat Cloud Function, dengan penegakan kuota di server dan
  **killswitch pagu biaya global** — satu bug perulangan tanpa itu bisa
  menghabiskan tagihan dalam semalam.
- Impor PDF (lapisan teks dulu, OCR menyusul).
- Ringkasan recap lewat Claude Haiku.

**Catatan hasil audit desain** (Hallmark, 4 critical · 6 major · 2 minor) ada di
`rencana-mvp.md`. Temuan terbesarnya: versi pertama adalah dashboard
produktivitas — persentase, bar progres, hitungan bab di mana-mana — padahal
positioning produknya justru menolak itu. Angka-angka itu sudah dicabut; jaga
supaya tidak diam-diam kembali.

---

## Rantai desain → kode (Agustus 2026)

Dulu `app/lib/ui/tokens.dart` menulis hex-nya sendiri dan `design/tokens.json`
tidak pernah dibaca siapa pun. Sekarang tersambung:

```
design/tokens.json  →  python3 tools/gen_tokens.py  →  app/lib/ui/tokens.g.dart
```

- `tokens.g.dart` **dihasilkan mesin** — jangan diedit tangan, akan tertimpa.
- `tokens.dart` tinggal jadi lapisan tipis: satu pintu warna (`warna`), tiga
  gaya turunan, dan widget buatan tangan (`PrimaryButton`, `QuietButton`,
  `QuotaBar`).
- **Tidak ada satu pun `Color(0x…)` tertulis tangan di `lib/`** — dijaga oleh
  `test/tokens_test.dart`, dan `gen_tokens.py --check` jalan di CI sebelum APK
  dibangun. Kalau tokens.json berubah tanpa generator dijalankan, build gagal
  di situ, bukan diam-diam membawa warna lama.

**Tema bawaan sekarang gelap.** Bukan selera: app ini didengarkan menjelang
tidur. `AppColors.light` sudah ikut dihasilkan dan nilainya masuk akal, tapi
**belum pernah ditata di layar mana pun** — jangan dinyalakan sebelum didesain.
Mode terang bukan pembalikan warna.

**Tiga peran huruf**, semuanya OFL dan aman di-embed:

| Token | Family | Dipakai untuk |
|---|---|---|
| `AppType.uiFamily` | Jakarta | kontrol, angka, label |
| `AppType.readingFamily` | Literata | teks bacaan di pemutar, judul momen besar |
| `AppType.a11yFamily` | AtkinsonHyperlegible | opsi aksesibilitas (belum ada tombolnya) |

Literata aslinya font variabel dua sumbu; yang dibundel adalah instance statis
pada `opsz 12` untuk bobot 400/600/700. Dipotong statis karena Flutter tidak
memilih sumbu `wght` sendiri dari `fontWeight` — tanpa itu w600 dan w700 tampil
sama persis dengan w400.

**Yang belum dikerjakan dari `design/serah-terima.md`:**

- Empat layar baru: *Siap memotret* (4b), *Halaman terkumpul* (4d), dan versi
  penuh *Sebelumnya…* serta *Jatah habis* sesuai papan desain.
- Dua label wajib di layar recap (`Terakhir kamu dengar … lalu` dan
  `Sedang dibacakan`).
- Pil hint sekali-tampil `Ketuk teks untuk mode fokus` di pemutar.
- Rak masih daftar satu kolom, belum grid 2 kolom dengan kartu LANJUTKAN dan
  sampul `AppCover.forTitle`.
- Penandaan kata yang diragukan OCR di `review_scan`.
- `readingHighlightBg` **belum diuji di layar HP dalam gelap** — baru di
  monitor. Yang lembut di monitor bisa menyilaukan di kamar.
