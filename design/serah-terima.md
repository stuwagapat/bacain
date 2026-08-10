# Serah terima desain → kode

Untuk sesi coding. Isinya hal yang **tidak muat di `tokens.json`**: struktur layar, perilaku,
dan aturan yang tidak bisa diwakili sebuah nilai warna.

Papan desain lengkap (19 layar, bisa dibuka di browser): `design/layar-lengkap.html`
Perbandingan sebelum–sesudah per keputusan: `design/banding/`

---

## 1 · Cara token bekerja sekarang

Dulu `app/lib/ui/tokens.dart` menulis hex-nya sendiri, dan `design/tokens.json` tidak pernah
dibaca siapa pun. Sekarang rantainya tersambung:

```
design/tokens.json  →  python3 tools/gen_tokens.py  →  app/lib/ui/tokens.g.dart
```

- **`tokens.g.dart` dihasilkan otomatis.** Jangan diedit tangan — akan tertimpa.
- **`tokens.dart` tetap milikmu.** Widget buatan tangan (`PrimaryButton`, `QuietButton`,
  `QuotaBar`) tidak disentuh generator. Yang perlu diubah cuma sumber nilainya: ganti
  `const green = Color(0xFF2D6B2D)` jadi `AppColors.dark.brandPrimary`, dan seterusnya.
- **`python3 tools/gen_tokens.py --check`** gagal kalau keluaran basi. Layak dipasang di
  `.github/workflows/apk.yml` supaya nilai desain dan kode tidak pernah diam-diam menyimpang.

Yang tersedia: `AppColors.dark` / `AppColors.light` (30 warna), `AppSpacing`, `AppRadius`,
`AppSize`, `AppType`, `AppCover`.

**Nama token adalah kontrak.** Nilainya boleh berubah kapan saja lewat `tokens.json`;
namanya tidak. Kalau butuh token baru, minta — jangan tambahkan hex di Dart.

---

## 2 · Yang harus ditambahkan sebelum reskin

| Hal | Keadaan sekarang | Yang dibutuhkan |
|---|---|---|
| Font Literata | belum ada | tambahkan ke `app/assets/fonts/` + `pubspec.yaml`, family `Literata` |
| Font Atkinson Hyperlegible | belum ada | idem, family `AtkinsonHyperlegible` |
| Tema default | terang | **gelap** |

Keduanya OFL, aman di-*embed* dalam APK. Nama family di `pubspec.yaml` harus persis sama
dengan yang ada di `FAMILY` pada `tools/gen_tokens.py` — kalau meleset, Flutter diam-diam
jatuh ke font sistem tanpa error.

Tiga peran huruf:

- **`AppType.uiFamily`** (Jakarta) — kontrol, angka, label. Mayoritas antarmuka.
- **`AppType.readingFamily`** (Literata) — teks bacaan di player **dan** judul momen besar
  (`uiDisplay`, `uiHeadline`). Yang dibaca user adalah buku; judul serif membuat batas itu
  terasa tanpa perlu garis pemisah.
- **`AppType.a11yFamily`** (Atkinson) — opsi yang bisa dipilih user di Pengaturan.

---

## 3 · Layar yang belum ada

Sudah ada: `onboarding`, `library`, `book`, `confirm_book`, `player`, `review_scan`, `settings`.

Belum ada, dan ada di papan desain:

### 3.1 · Siap memotret (`4b`)
Muncul **sekali saja**, sebelum kamera pertama kali dibuka. Simpan flag di `settings_store`.

Isinya tiga hal, dan yang ketiga paling penting: **potretnya otomatis**. Tanpa itu user akan
menekan shutter berkali-kali dan menghasilkan duplikat. Layar ini memikul beban terberat dari
jalan tengah — karena scanner sistem tidak bisa kita beri panduan, semua yang perlu diketahui
harus disampaikan di sini.

### 3.2 · Halaman terkumpul (`4d`)
Muncul setelah kembali dari scanner, **sebelum** OCR jalan. Grid 3 kolom berisi thumbnail
bernomor, halaman buram ditandai amber, tekan lama untuk mengubah urutan.

Menandai halaman buram di sini disengaja: memfoto ulang sekarang jauh lebih murah daripada
membetulkan teks kacau di `review_scan`, saat bukunya mungkin sudah ditutup.

### 3.3 · Sebelumnya… (recap)
Muncul **hanya bila jeda sesi terakhir > 24 jam**. Kalau user mendengarkan berturut-turut,
layar ini mengganggu dan harus dilewati sepenuhnya. Teksnya langsung disuarakan begitu layar
terbuka.

Dua label wajib ada, keduanya menjawab pertanyaan yang cuma muncul di hari kedua:
- di atas judul: `Terakhir kamu dengar 2 hari lalu` — kenapa layar ini muncul
- di bawah indikator audio: `Sedang dibacakan` — kenapa tiba-tiba ada suara

### 3.4 · Jatah habis
Latar penuh `brandPrimary`, tinta `brandOnPrimary`, ornamen versi tinta
(`design/aset/ornament-ink.png`) sebagai ilustrasi.

**Tombol "Dengar ulang bab lama" tidak pernah dikunci.** MP3-nya sudah ada, tidak ada biaya
baru. Justru itu tombol paling menonjol di layar ini.

---

## 4 · Perubahan pada layar yang sudah ada

### `player.dart`
- **Ikon mode fokus di app bar kanan atas**, di sebelah kiri ikon ⋮. Sebelumnya mode fokus
  hanya gestur ketuk-teks — tidak ada petunjuk apa pun, jadi hampir tidak akan ditemukan.
  Gestur ketuknya tetap ada; ikon ini untuk penemuan.
- **Pil hint sekali-tampil** di bawah area teks: `Ketuk teks untuk mode fokus`, bisa ditutup.
- **Mode fokus butuh jalan keluar yang terlihat**: baris redup di paling bawah,
  `Ketuk di mana saja untuk kembali`. Tanpa itu user yang tidak sengaja masuk akan terjebak
  di layar hampir kosong.
- Mode fokus **mencabut aksen sepenuhnya** — tidak ada satu pun warna merek. Layar yang
  dipakai di jalan atau saat mata istirahat harus berhenti menarik perhatian.

### `library.dart`
- Rak **maksimal 2 kolom** di 360 dp. Tidak pernah 3.
- Kartu LANJUTKAN adalah satu-satunya bidang warna besar di layar, karena ia satu-satunya
  aksi utama.
- Sampul buku: pakai `AppCover.forTitle(judul)`. Jangan pakai `hashCode` Dart — nilainya
  tidak stabil antar-proses, jadi warna sampul akan berubah sendiri tiap app dibuka.
- Rak kosong: baris di bawah tombol menyebut bahwa **"Ambil file" membuka file manager HP**.
  Jalur kamera tidak perlu peringatan di sini karena layar 4b sudah menanganinya.

### `review_scan.dart`
- Kata yang diragukan OCR ditandai `statusWarning` bergaris titik. Ini **satu-satunya tempat
  di seluruh app** warna dipakai untuk memberi arti.
- Kalimatnya: `Ada 2 kata yang kami ragukan — ketuk untuk memperbaiki`. Yang ragu adalah kami,
  bukan katanya yang salah — sesuai arahan dokumen rencana soal kejujuran OCR.

---

## 5 · Aturan yang tidak muat di file token

1. **Aksen hanya untuk aksi.** `brandPrimary` boleh muncul sebagai pil terisi atau lingkaran
   terisi, tidak pernah untuk hal yang bukan aksi. Semua pastel duduk di tingkat terang yang
   mirip, jadi hierarki dipegang bentuk dan posisi, bukan kecerahan.

2. **Teks di atas bidang berwarna selalu `brandOnPrimary`** (hijau wordmark `#001E03`),
   tidak pernah putih. Putih di atas coral cuma 3,0:1 — gagal WCAG AA. Ambang 4,5:1 wajib;
   aksesibilitas adalah klaim produk ini.

3. **Warna sampul tanpa makna.** Dipilih dari hash judul. Begitu user mengira hijau berarti
   "selesai", sistemnya berbohong. `cover/6` kebetulan sama dengan `brandPrimary` —
   dibedakan lewat bentuk: aksen selalu pil/lingkaran, sampul selalu persegi.

4. **Mini player memakan `AppSize.miniPlayer` (64 dp)** di setiap layar utama. Desain setiap
   layar sudah memperhitungkan 64 dp itu terpotong.

5. **Status bab dibedakan bentuk, bukan hanya warna**: centang (sudah), lingkaran penuh
   (siap), lingkaran kosong redup (belum disintesis).

6. **`readingHighlightBg` wajib diuji di layar HP dalam gelap**, bukan di monitor. Yang
   terlihat lembut di monitor terang bisa menyilaukan di kamar gelap.

---

## 6 · Suara tulisan

Register semi-formal yang hangat. Selalu **`kamu`**, tidak pernah "Anda". Kata-katanya baku —
tidak ada *nggak*, *udah*, *dengerin*. Kesan santai datang dari kalimat pendek dan sapaan
langsung, bukan kosakata gaul.

- **Tombol tetap kata kerja polos**: "Putar", "Lanjut", "Simpan ke rak". Santainya hidup di
  kalimat, bukan di tombol — tombol harus mengatakan persis apa yang terjadi kalau ditekan.
- **Biarkan angka yang pamer.** 32 menit, 18 hari, 12 bab. Tidak ada tanda seru di seluruh app.
- **Teks buku tidak pernah ikut gaya ini** — itu suara penulisnya, bukan suara Bacain.
- Satu pengecualian sengaja: `akhirnya kebaca` di kalimat pembuka onboarding. Itu hook, dan
  hook boleh punya kepribadian lebih dari body copy.

Contoh yang sudah dipakai di papan: `Kapan kamu mau dengar?` · `Cukup untuk hari ini.
Lumayan, kan?` · `Bab 4 sudah menunggu.` · `Belum disentuh` · `Sampai besok, ya`

---

## 7 · Yang belum ada, dan jangan dianggap sudah

- **Mode terang belum didesain.** `AppColors.light` ada dan nilainya masuk akal, tapi belum
  pernah ditata di layar mana pun. Mode terang bukan pembalikan warna — `readingHighlightBg`
  di gelap sengaja jauh lebih redup daripada padanannya di terang.
- **Typeface wordmark belum teridentifikasi.** Logo memakai serif kontras tinggi yang belum
  diketahui namanya. Sementara ini Literata memikul peran display. Wordmark tetap dipakai
  sebagai gambar (`logo.png`), tidak di-set ulang dengan huruf.
- **Logo hanya punya versi terang** (krem + hairline hijau, untuk ground gelap). Mode terang
  nanti butuh versi bertinta gelap.
- **Wordmark di ukuran kecil belum diuji di HP sungguhan.** Di app bar ia tampil 92 px lebar;
  hairline serif di ukuran itu bisa putus-putus di layar DPI rendah.
- **Dua hambatan pemahaman user masih terbuka**, keduanya berdampak besar:
  kuota harian belum dijanjikan sebagai batas keras di onboarding, dan progres user anonim
  bisa hilang tanpa peringatan saat app di-*uninstall*.
