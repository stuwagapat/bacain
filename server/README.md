# Perantara TTS

Ada karena satu alasan: **kunci Google tidak boleh ada di dalam APK.** Siapa
pun yang memegang APK bisa mengekstrak kuncinya dan memakainya atas tagihanmu.
Di sini kuncinya tinggal di server, dan app hanya tahu alamatnya.

## Menyiapkan di Google Cloud

```bash
# 1. Aktifkan API dan buat kuncinya
gcloud services enable texttospeech.googleapis.com
#    Buat API key di Console → APIs & Services → Credentials.
#    BATASI kuncinya ke "Cloud Text-to-Speech API" saja.

# 2. Terbitkan layanannya
cd server
gcloud run deploy bacain-tts \
  --source . \
  --region asia-southeast2 \
  --allow-unauthenticated \
  --set-env-vars GOOGLE_TTS_API_KEY=...,BACAIN_SHARED_SECRET=...

# 3. Tempelkan URL yang keluar ke Pengaturan → Suara AI → Alamat server
```

## Pengaturan lingkungan

| Nama | Guna |
|---|---|
| `GOOGLE_TTS_API_KEY` | wajib. Kunci Google, dibatasi ke TTS saja. |
| `BACAIN_SHARED_SECRET` | sangat disarankan. Tanpa ini alamatnya jadi layanan TTS gratis bagi siapa pun yang menemukannya — tagihannya tetap atas namamu. |
| `BACAIN_MAX_CHARS_PER_DAY` | pagu global harian. Bawaan 500.000. |
| `BACAIN_ALLOW_ORIGIN` | asal yang diizinkan untuk build web. Bawaan `*`. |

## Yang perlu kamu tahu soal pagunya

Penghitung karakter di sini disimpan **di memori**, jadi ikut hilang tiap kali
instance dingin dimulai ulang. Artinya pagunya bersifat usaha-terbaik, bukan
jaminan.

**Penjaga yang sesungguhnya adalah Budget Alert di Google Cloud Console.**
Pasang itu sebelum layanan ini dipakai orang lain — bukan sesudah tagihannya
datang. Kalau nanti butuh pagu yang benar-benar tahan restart, penghitungnya
harus pindah ke Firestore.

## Harga, per Agustus 2026

| Suara | Harga | Gratis per bulan |
|---|---|---|
| Standard | $4 / 1 juta karakter | 4 juta |
| WaveNet / Neural2 | $16 / 1 juta karakter | 1 juta |
| Chirp3 HD | $30 / 1 juta karakter | 1 juta |

Satu buku ±400 halaman ≈ 800 ribu karakter. Dengan WaveNet itu masuk kuota
gratis bulanan untuk satu buku; di atas itu ±$13 per buku. Cache di app
memastikan tiap kalimat hanya dibayar sekali seumur hidup, jadi mendengar
ulang tidak menambah biaya sama sekali.
