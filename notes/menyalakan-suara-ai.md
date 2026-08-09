# Menyalakan suara AI (Google Cloud TTS)

Semuanya dikerjakan di **Google Cloud Console** lewat browser. Tidak ada yang
perlu dipasang di komputer.

Sekali jalan biasanya 10–15 menit. Login pakai akun Google biasa.

---

## 0. Yang perlu disiapkan lebih dulu

**Kartu kredit atau debit.** Google menuntut akun penagihan aktif sebelum
Text-to-Speech bisa dipakai — bahkan untuk kuota gratisnya. Ini bukan biaya:
kuota gratis tetap gratis, kartunya hanya jadi syarat pendaftaran. Tapi tanpa
itu API-nya tidak akan menyala sama sekali, dan lebih baik kamu tahu sekarang
daripada di tengah jalan.

Akun baru biasanya juga dapat kredit percobaan $300 berlaku 90 hari.

---

## 1. Buat proyek

<https://console.cloud.google.com/projectcreate>

Isi **Project name** — misalnya `bacain`. Sisanya biarkan bawaan, lalu
**Create**. Tunggu beberapa detik sampai proyeknya terpilih di bagian atas
layar.

## 2. Aktifkan penagihan

<https://console.cloud.google.com/billing>

**Link a billing account** → buat akun penagihan baru kalau belum punya →
masukkan data kartunya.

Pastikan proyek `bacain` benar-benar tertaut. Kalau belum, TTS akan menolak
dengan pesan tentang billing.

## 3. Aktifkan Text-to-Speech API

<https://console.cloud.google.com/apis/library/texttospeech.googleapis.com>

Pastikan proyek yang benar terpilih di kotak atas, lalu tekan **Enable**.

## 4. Buat API key

<https://console.cloud.google.com/apis/credentials>

**+ Create credentials** → **API key**. Kuncinya langsung muncul —
salin sekarang, karena setelah kotaknya ditutup kuncinya tidak ditampilkan
utuh lagi. (Kalau telanjur tertutup, buka kuncinya dan pakai **Show key**.)

## 5. Batasi kuncinya — jangan dilewati

Masih di halaman Credentials, klik nama kuncinya:

- **API restrictions** → pilih **Restrict key** → centang
  **Cloud Text-to-Speech API** saja → **Save**.

Ini membuat kunci yang bocor hanya bisa dipakai untuk TTS, bukan untuk seluruh
layanan Google Cloud di proyekmu.

> **Application restrictions sengaja dibiarkan "None".** Pembatasan "Android
> apps" tidak akan bekerja di sini: pembatasan itu mengandalkan header khusus
> yang dikirim SDK Google, sedangkan app ini memanggil TTS lewat HTTP biasa.
> Kalau dinyalakan, semua permintaan malah ditolak.

## 6. Pasang Budget Alert — ini yang benar-benar menjaga

<https://console.cloud.google.com/billing/budgets>

**Create budget** → beri nama, isi jumlah kecil dulu (misalnya **Rp 50.000**
atau **$5**) → aktifkan pemberitahuan di 50%, 90%, 100%.

Ini satu-satunya penjaga yang tidak bisa dilewati bug di app. Pagu di dalam
app dan di server adalah usaha-terbaik; yang ini datang dari Google sendiri.

## 7. Tempel ke app

Buka Bacain → **Pengaturan** → **Suara AI** → tempel kuncinya di kolom
**"Kunci Google (hanya untuk mencoba)"** → **Simpan & sambungkan**.

Kalau berhasil, muncul: *"Tersambung. N suara Indonesia siap dicoba."*
Naik ke **Suara pembaca** — daftarnya kini berisi suara Google.

---

## Kalau gagal tersambung

Pesan dari Google diteruskan apa adanya ke layar, jadi baca kalimatnya:

| Pesan | Artinya |
|---|---|
| `API key not valid` | kunci salah ketik, atau tersalin sebagian |
| `Cloud Text-to-Speech API has not been used in project…` | langkah 3 terlewat |
| `This API method requires billing to be enabled` | langkah 2 terlewat |
| `Requests to this API … are blocked` | pembatasan di langkah 5 terlalu ketat — pastikan Application restrictions = None |
| `Quota exceeded` | kuota gratis bulan ini habis |

---

## Sesudah selesai menilai

**Hapus kuncinya dari Pengaturan sebelum APK dibagikan ke siapa pun.** Kunci
yang ada di dalam app ikut terbawa dalam APK dan bisa diambil siapa saja yang
memegang berkasnya — lalu dipakai atas tagihanmu.

Untuk dibagikan, terbitkan `server/` ke Cloud Run; kuncinya tinggal di server
dan app hanya tahu alamatnya. Petunjuknya di [`../server/README.md`](../server/README.md).

Kalau kuncinya sempat tersebar, cabut di halaman Credentials (**Delete**) dan
buat yang baru — mencabut jauh lebih murah daripada menunggu tagihan.

---

## Harga, per Agustus 2026

| Suara | Gratis per bulan | Di atas itu |
|---|---|---|
| Standard | 4 juta karakter | $4 / 1 juta |
| WaveNet, Neural2 | 1 juta karakter | $16 / 1 juta |
| Chirp3 HD | 1 juta karakter | $30 / 1 juta |

Satu buku ±400 halaman ≈ 800 ribu karakter — masih di dalam kuota gratis
bulanan, bahkan untuk Chirp3 HD. Cache di app membuat tiap kalimat hanya
dibayar sekali seumur hidup, jadi mendengar ulang tidak menambah apa pun.

Untuk sekadar menilai suara, pemakaiannya jauh di bawah itu: mencicipi 10
suara ≈ 1.500 karakter total.
