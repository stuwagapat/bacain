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

**69 uji lolos** (`cd app && flutter test`).

### Belum ada

| Belum ada | Kenapa |
|---|---|
| Kamera + OCR buku fisik | butuh Android asli (ML Kit on-device) |
| Notifikasi harian sungguhan | butuh Android asli |
| Pemutaran di latar belakang | butuh Android asli |
| Suara AI berkualitas | butuh kredensial Google Cloud TTS |
| Ringkasan "sebelumnya" yang benar-benar merangkum | butuh Claude API |
| Impor PDF | jalur EPUB didahulukan |
| Build Android | butuh Android SDK, dan APK tidak bisa dijalankan di lingkungan ini |

Layar recap **jujur** menampilkan kalimat penutup bagian sebelumnya dan
menyatakan bahwa ringkasan sungguhan menyusul — tidak mengarang ringkasan.
"Foto buku fisik" tetap tampil di sheet sumber tapi dimatikan dengan alasannya
tertulis, supaya alur produknya utuh terlihat.

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
flutter test                 # 69 uji
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
    tts/speech_engine.dart antarmuka mesin bicara + mesin tiruan untuk uji
    tts/segment_player.dart urutan, jeda, lompat, kalimat aktif
    store/                 rak buku, pengaturan, jatah harian
  lib/platform/            mesin bicara per platform (web / stub Android)
  lib/screens/             layar
  lib/ui/tokens.dart       warna & widget bersama
  test/                    69 uji
  assets/contoh.epub       buku contoh, teks tulisan sendiri (bukan berhak cipta)
docs/                      HASIL BUILD untuk GitHub Pages — jangan diedit tangan
design/                    token desain, wireframe, skrip Figma
notes/                     dokumen tulisan tangan (rencana, status ini)
prototype/                 prototipe HTML halaman 1 (sebelum Flutter)
```

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
2. **Kredensial Google Cloud TTS.** Ini satu-satunya penghalang suara AI
   berkualitas. Suara sekarang = suara sistem, terdengar robotik. Antarmuka
   `SpeechEngine` sudah disiapkan supaya penggantiannya jadi penambahan satu
   berkas, bukan bedah ulang.
3. **Desain.** User bilang desain menyusul setelah fungsi & alur beres. Aset
   yang sudah ada: `logo.png`, `header 1.png`, `footer 1.png`, `ornament.png`.
   Palet asli dari aset: hijau `#2D6B2D`/`#184818`, oranye `#F06C3C`, aprikot
   `#FCB46C`, krem `#EFECE7`. Sudah dipakai di app.

**Pekerjaan teknis yang jelas berikutnya:**

- Build Android (butuh Android SDK) + `flutter_tts` sebagai `SpeechEngine`
  kedua.
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
