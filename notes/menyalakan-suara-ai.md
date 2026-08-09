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

## 7. Tanam kuncinya ke build — tidak perlu diketik di HP

Repo → **Settings → Secrets and variables → Actions → New repository secret**

| Nama | Isi |
|---|---|
| `BACAIN_TTS_KEY` | kunci dari langkah 4 |

Itu saja. Setiap APK yang dibangun sesudah ini sudah membawa kuncinya —
buka app, **Pengaturan → Suara AI** langsung berbunyi *"Google Cloud TTS
aktif"*, dan daftar **Suara pembaca** sudah berisi suara Google.

Untuk memicu build baru: buka **Actions → run terbaru → "Re-run all jobs"**
(kanan atas). Secret dibaca saat build berjalan, jadi re-run pada commit yang
sama tetap mengambil secret barumu.

> Tombol **"Run workflow"** tidak muncul karena berkas workflow-nya hanya ada
> di branch fitur. GitHub hanya menampilkan tombol itu kalau workflow-nya juga
> ada di branch default repo (`main`).

> Kalau saat menempel kuncinya ikut terbawa baris baru atau spasi, pipa-nya
> sudah membersihkannya sendiri. Dulu tidak, dan akibatnya build gagal dengan
> pesan `Target file "--dart-define=..." not found` yang sama sekali tidak
> menyinggung secret.

Nanti setelah `server/` terbit, ganti secret-nya jadi `BACAIN_TTS_URL` berisi
alamat server, lalu **hapus** `BACAIN_TTS_KEY`. App otomatis memakai server —
tidak ada kode yang perlu diubah, dan APK-nya jadi aman dibagikan.

### Kalau ingin mencoba kunci lain tanpa membangun ulang

Kolom isian di **Pengaturan → Suara AI** tetap ada. Yang diketik di situ
menang atas yang ditanam; mengosongkannya kembali ke yang ditanam.

---

## Kalau gagal tersambung

Buka **Pengaturan → Suara AI** lalu tekan **Sambungkan**. Pesan dari Google
ditampilkan apa adanya di kotak oranye — bisa disalin. Baca kalimatnya:

| Pesan | Artinya |
|---|---|
| `API key not valid` | kunci salah ketik, atau tersalin sebagian |
| `Cloud Text-to-Speech API has not been used in project…` | langkah 3 terlewat |
| `This API method requires billing to be enabled` | langkah 2 terlewat |
| `Requests to this API … are blocked` | pembatasan di langkah 5 terlalu ketat — pastikan Application restrictions = None |
| `Tidak bisa menghubungi layanan suara` | tidak ada koneksi, atau APK-nya versi lama yang belum punya izin internet |
| `Quota exceeded` | kuota gratis bulan ini habis |

---

## Sesudah selesai menilai

**Hapus secret `BACAIN_TTS_KEY` sebelum APK dibagikan ke siapa pun**, lalu
bangun ulang. Kunci
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
