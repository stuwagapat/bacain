# Riset & Analisis: App Pembaca Buku AI (Working Title)

> Dokumen ringkasan riset, validasi masalah, analisis kompetitor, rekomendasi teknis, dan kritik kelayakan untuk ide aplikasi yang mengubah buku fisik/PDF/ebook menjadi narasi audio AI.

---

## 1. Latar Belakang & Ide Inti

Aplikasi yang dapat membacakan buku, PDF, dan ebook dengan cara mengubah tulisan yang diupload (termasuk hasil foto buku fisik) menjadi narasi audio AI dengan intonasi dan artikulasi natural dalam Bahasa Indonesia. Rencana model bisnis: **gratis**.

---

## 2. Validasi Masalah (Data Pendukung)

### 2.1 Minat baca Indonesia rendah
- UNESCO: minat baca Indonesia hanya **0,001%** — dari 1.000 orang, hanya 1 yang rajin membaca.
- BPS: hanya sekitar **10%** penduduk Indonesia yang rajin membaca buku.
- PISA 2018: Indonesia peringkat **73 dari 79 negara** untuk kemampuan membaca siswa.
- GoodStats (2025): **20,7%** masyarakat rutin membaca setiap hari; **15,4%** hampir tidak pernah membaca.

### 2.2 Preferensi budaya terhadap audio/lisan
- Indonesia memiliki sekitar **4.521 tradisi lisan** yang tersebar di berbagai daerah — akar budaya storytelling yang kuat sebelum budaya tulis berkembang luas.
- Indonesia **peringkat pertama dunia** untuk proporsi pendengar podcast: **42,6%** pengguna internet 16+ mendengarkan podcast mingguan (rata-rata global: 22,1%).
- Durasi mendengarkan rata-rata **1 jam 4 menit/hari** — tertinggi ke-9 di dunia.
- ⚠️ **Catatan penting**: survei Populix (Sept 2025) menunjukkan mayoritas pendengar podcast Indonesia sekarang lebih suka **format video (54%)** dibanding audio murni (7%) — preferensi audio murni sedang tergerus tren video.

### 2.3 Fenomena Tsundoku (buku dibeli, tidak dibaca)
- Istilah Jepang untuk kebiasaan menumpuk buku tanpa membacanya.
- Penyebab utama: keterbatasan waktu, distraksi, FOMO saat membeli, tekanan sosial (buku sebagai simbol status).
- Fenomena ini valid dan terdokumentasi di banyak sumber, bukan sekadar pengalaman personal.

### 2.4 Penurunan attention span
- Rentang perhatian manusia turun dari rata-rata **12 detik (2000)** menjadi **~8 detik (2023)**, bertepatan dengan revolusi konten digital/media sosial.
- Riset akademik (2026, UNESA): intensitas penggunaan media sosial berkorelasi dengan menurunnya kemampuan mempertahankan fokus saat belajar/membaca materi dalam waktu lama.
- Survei Pew Research: 31% remaja kehilangan fokus karena sering cek ponsel; 49% menggunakan teknologi untuk hal tak berkaitan dengan tugas utama.

### 2.5 Ukuran pasar
- Pasar audiobook Indonesia: proyeksi tumbuh **11,21%/tahun (2024-2029)**, mencapai **US$17,01 juta di 2029**.
- Pasar buku Indonesia umum: CAGR **~9,97% (2025-2029)**, didorong pergeseran ke format digital.
- Riset industri global: Indonesia (bersama India, Brazil, Nigeria, Meksiko) disebut representasi **2,4 miliar calon pendengar** dengan pertumbuhan smartphone 14-22%/tahun; AI narration menurunkan biaya produksi audiobook **~73%** (dari $6.400 menjadi $1.720 per jam audio).

---

## 3. Analisis Kompetitor

| Kategori | Contoh | Kekuatan | Kelemahan |
|---|---|---|---|
| App lokal generik | "Teks ke Suara: Baca PDF AI" | Sudah ada fitur scan kamera + suara Bahasa Indonesia | Traksi sangat kecil (4 rating), developer app-factory generik, subscription agresif |
| App aksesibilitas | Seeing AI, KNFB Reader, Envision AI | Sudah punya fitur foto buku fisik → audio otomatis, matang secara teknologi | Dirancang untuk tunanetra, suara robotic (TTS OS bawaan), bukan untuk pengalaman "menikmati cerita" |
| App OCR umum | AI Text Scanner, dll | OCR + TTS sebagai fitur tambahan | Fokus utama produktivitas, bukan pengalaman audio berkualitas |
| Audiobook curated | Storytel | Katalog resmi, narasi manusia profesional | Model beda (bukan TTS dari upload user), harga langganan, katalog terbatas |

**Kesimpulan kompetitor:** tidak ada pemain yang benar-benar fokus & niche di "buku fisik → audiobook AI berkualitas" untuk pasar Indonesia dengan eksekusi kuat. Gap ada di **kualitas suara**, **akurasi OCR untuk konteks buku lokal**, dan **positioning budaya otentik**.

---

## 4. Rekomendasi Tech Stack (TTS)

| Opsi | Model Biaya | Kualitas | Kompleksitas | Cocok Untuk |
|---|---|---|---|---|
| **Google Cloud TTS** | Pay-per-karakter setelah kuota gratis (4jt char/bulan Standard, 1jt WaveNet/Neural2) | Bagus, teruji produksi | Rendah, tinggal panggil API | Fase MVP/validasi awal |
| **Piper TTS (self-hosted)** | Gratis selamanya | Cukup baik, kurang ekspresif | Sedang, perlu deploy & maintain server | Skala besar, app gratis jangka panjang |
| **Chatterbox-TTS-Indonesian** | Gratis (open-weight), biaya komputasi sendiri | Lebih natural, dioptimasi Bahasa Indonesia | Tinggi, butuh GPU | Fase lanjut, kualitas suara jadi prioritas |

**Strategi:** mulai dari Google Cloud TTS untuk validasi cepat → migrasi ke Piper/Chatterbox self-hosted begitu biaya API mulai membengkak karena model gratis tanpa revenue jelas. Desain sistem voice engine agar *pluggable* dari awal.

---

## 5. Fitur Pembeda (Diferensiasi)

1. **Akurasi OCR untuk kondisi buku Indonesia nyata** — preprocessing gambar (auto-crop, deskew, enhance kontras), panduan capture real-time (deteksi blur/miring/gelap).
2. **Mode "storytelling"** — deteksi struktur teks (judul bab, dialog vs narasi), jeda & intonasi otomatis berbeda.
3. **Sinkronisasi teks-suara (highlight mengikuti audio)** — bantu fokus & aksesibilitas disleksia.
4. **Mode offline / hemat kuota** — unduh audio untuk didengarkan tanpa koneksi.
5. **Positioning budaya "menghidupkan tradisi mendongeng"** — kurasi cerita rakyat nusantara sebagai starter content gratis, branding hangat bukan tool produktivitas kaku.
6. **Fitur sosial ringan** — share klip audio kutipan favorit, mode "baca bareng".
7. **Progress & kebiasaan (gamifikasi secukupnya)** — lihat catatan kritis di bagian 6.
8. **Scan buku fisik sebagai fitur andalan utama** (bukan pelengkap) — langsung menjawab masalah tsundoku buku fisik, target user paling representatif dari masalah ini.

### 5.1 Konsep gabungan: Chunking + Audiobook AI
Bukan "convert buku jadi 1 file audio utuh", tapi **serial harian** — buku dipecah otomatis jadi segmen ~10-15 menit berdasarkan struktur bab, dikirim/dibuka bertahap sesuai jadwal pilihan user. Setiap segmen baru dibuka dengan **ringkasan singkat otomatis** ("sebelumnya...") untuk mengatasi masalah lupa progres baca.

**Manfaat tambahan dari model ini:**
- Mengurangi risiko hukum (distribusi bertahap, bukan file utuh yang bisa disebar bebas)
- Meratakan beban komputasi TTS (generate bertahap, bukan sekaligus)
- Selaras dengan mekanisme pembentukan kebiasaan yang terbukti (pola ala Duolingo)

### 5.2 Catatan kritis: Gamifikasi
- **Risiko**: streak anxiety, extra step di onboarding, jadi mini-distraksi baru yang kontradiktif dengan tujuan produk.
- **Rekomendasi**: elemen aman → progress tracker pasif, reminder opsional (default on, mudah dimatikan). Elemen ditunda ke versi lanjut → streak, badge, leaderboard sosial. Prinsip: gamifikasi *invisible* sampai user butuh dorongan, bukan hadir terus-menerus.

---

## 6. Kritik Keras (Devil's Advocate)

1. **Risiko hukum hak cipta** — reproduksi karya berhak cipta ke bentuk audio secara massal berisiko somasi dari penerbit (Gramedia, Mizan, Elex Media), terutama karena mengancam lini bisnis audiobook mereka sendiri.
2. **Menyelesaikan masalah format, bukan perilaku** — distraksi digital & attention span rendah tetap ada di format audio; audiobook/podcast sudah punya pola tsundoku versi digital sendiri.
3. **Preferensi pasar bergerak ke video**, bukan audio murni (54% vs 7%).
4. **Ukuran pasar kecil** (~US$17 juta di 2029) untuk skala bisnis serius/menarik investor.
5. **Model gratis vs biaya infrastruktur** yang terus naik seiring user bertambah — risiko "viral tapi bangkrut" tanpa model revenue jelas.
6. **Akurasi OCR untuk foto buku fisik** adalah tantangan computer vision nyata (bayangan, pantulan cahaya, halaman melengkung, font lama).
7. **Tidak ada moat teknologi kuat** — mudah ditiru pemain besar bermodal lebih besar.
8. **Validasi masih n=1** — insight kuat secara data makro, belum tervalidasi ke calon user lain di luar pengalaman personal.

---

## 7. Lima Ide Alternatif Penyelesaian Masalah

| # | Ide | Kedalaman Dampak | Jangkauan | Kompleksitas/Risiko |
|---|---|---|---|---|
| 1 | **Chunking konten** (drip harian ala Duolingo) | Tinggi | Tinggi | Rendah-sedang |
| 2 | **App AI audiobook** (ide awal) | Tinggi (berpotensi) | Tinggi | Tinggi (hukum, biaya, teknis) |
| 3 | **Klub baca komunitas** | Sangat tinggi | Rendah | Rendah |
| 4 | **Reading sprint + akuntabilitas sosial** | Sedang | Sedang | Rendah |
| 5 | **Video pendek (reels/shorts) ringkasan buku** | Rendah (risiko dangkal) | Sangat tinggi | Rendah |

**Ranking impact gabungan (kedalaman × jangkauan):** Chunking konten → App AI audiobook → Klub baca → Reading sprint → Video pendek.

**Insight kunci:** kombinasi paling kuat adalah menjadikan **chunking sebagai mekanisme inti di dalam app AI audiobook**, bukan memilih salah satu.

---

## 8. Kesimpulan Kelayakan

**Jika faktor hukum & biaya diabaikan sementara:** ide ini **layak dibangun sebagai hipotesis yang perlu diuji**, dengan fondasi masalah yang solid dan saling mengunci (minat baca rendah + preferensi audio tinggi + tsundoku + attention span menurun). Namun **belum layak dieksekusi penuh** sampai satu syarat terpenuhi:

> **Validasi ke calon user lain di luar pengalaman personal** — apakah orang lain yang mengalami tsundoku benar-benar akan mengubah kebiasaan dengan app ini, atau punya cara lain mengatasinya (termasuk kemungkinan tidak menganggapnya masalah).

### Prioritas langkah berikutnya (disarankan urutan):
1. **Validasi primer** — wawancara 10-20 orang dengan masalah tsundoku serupa, cari jawaban jujur (termasuk penolakan).
2. **Jawab risiko hukum** — riset lisensi konten yang aman untuk MVP (domain publik, cerita rakyat, dokumen milik user sendiri, kerja sama penulis indie).
3. **Jawab model sustainability** — tentukan sumber pendanaan operasional (donasi, sponsor konten, freemium ringan, dsb) sebelum biaya TTS membengkak.
4. **Eksperimen murah dulu** (opsional) — uji mekanisme chunking/reading sprint secara manual (grup WhatsApp + jadwal manual) sebelum membangun produk teknologi penuh.

---

*Dokumen ini disusun dari hasil riset dan diskusi eksploratif. Data pasar dan statistik perlu diverifikasi ulang sumber aslinya sebelum digunakan untuk keperluan formal (pitch deck, proposal investor, dsb).*
