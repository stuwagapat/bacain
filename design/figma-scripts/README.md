# Skrip Figma — Wireframe v2

Menerapkan hasil audit Hallmark ke file Figma: token baru + 12 layar yang dibangun ulang.

File Figma: https://www.figma.com/design/509ex6znf0rrktS8oouOwd

---

## Kenapa lewat skrip, bukan langsung

Figma MCP membatasi **6 panggilan tool per bulan** untuk plan Starter dengan seat View —
bukan harian, bukan jendela bergulir. Kuotanya sudah terpakai, jadi menunggu tidak menolong.

**Plugin Figma jalan di klien Figma-mu sendiri dan tidak menyentuh kuota MCP sama sekali.**
Itu jalan keluarnya — tanpa upgrade, tanpa menunggu bulan depan.

---

## Cara menjalankan

1. Buka file Figma di aplikasi desktop atau browser
2. Pasang plugin **Scripter** (gratis, cari di Figma Community)
3. Buka Scripter, tempel isi tiap file, tekan ▶
4. Jalankan **berurutan**:

| Urutan | File | Menghasilkan |
|---|---|---|
| 1 | `00-tokens-v2.js` | Nilai warna baru + 13 text style v2 |
| 2 | `10-layar-01-03b.js` | 01 Onboarding · 02 Pilih jam · 03a Beranda kosong · 03b Beranda terisi |
| 3 | `11-layar-04-07.js` | 04 Tambah buku · 05 Tinjau scan · 06 Konfirmasi · 07 Detail buku |
| 4 | `12-layar-08-12.js` | 08 Recap · 09 Player · 09b Mode fokus · 10 Jatah habis · 11 Pengaturan · 12 Notifikasi |

`00` wajib duluan — skrip layar mencari text style v2 dan berhenti dengan pesan jelas kalau belum ada.

**Semua aman diulang.** Tiap skrip menghapus frame bernama sama sebelum membangun ulang, jadi
boleh dijalankan berkali-kali. Halaman `Wireframes` (v1) **tidak disentuh** — v2 masuk ke halaman
baru `Wireframes v2`, supaya bisa dibandingkan berdampingan.

### Kalau typeface-nya belum ada

`00-tokens-v2.js` mencari **Literata** dan **Plus Jakarta Sans**. Keduanya ada di Google Fonts
dan tersedia di Figma. Kalau tidak ketemu, skrip mundur ke pengganti dan **memberi tahu di hasil
kembaliannya** — tidak diam-diam. Aktifkan fontnya di Figma, lalu jalankan ulang.

---

## Yang berubah dari v1

Audit Hallmark menemukan **4 critical · 6 major · 2 minor**. Temuan terbesar: v1 adalah
dashboard produktivitas — padahal positioning produknya justru menolak itu.

| Temuan | Perbaikan |
|---|---|
| Kontradiksi positioning | Persentase, bar progres, hitungan bab dicabut. Diganti *“tinggal 8 bab lagi”*. Kuota dikeluarkan dari layar player. |
| Inter-everywhere | Literata (baca) + Plus Jakarta Sans (UI). Dua peran, dua wajah. |
| Pure black / pure white | Ramp netral dicondongkan hangat. Tidak ada `#ffffff` maupun `#000000`. |
| Satu ritme di 10 layar | Tiap layar diberi logika komposisi sendiri. |
| Centred everything | Layar 01, 08, 10 dibuat bias kiri. |
| Icon-tile feature card | Dua aksi dengan bobot berbeda, bukan kartu kembar. |
| Tik eyebrow | Label mono-caps disisakan hanya untuk grup Pengaturan. |
| Tombol lebar penuh di mana-mana | Diganti tautan bergaris di layar yang tidak butuh penekanan. |
| Suara ikon campur | Semua ikon digambar SVG, stroke 1,5px, ujung bulat. |
| Card-in-card | Grup dipisah garis rambut, bukan kotak di dalam kotak. |
| `...` | Diganti elipsis `…`. |
| Padding seragam | Divariasikan per layar. |

Pratinjau HTML-nya: [`../wireframe-v2.html`](../wireframe-v2.html) — buka di browser,
font sudah tertanam jadi tidak perlu koneksi.

---

## Kalau nanti skripnya dimodifikasi

Tiga jebakan yang sudah menggigit selama pembangunan ini:

1. **Frame di Figma default-nya berlatar putih.** Helper `box()` selalu mengosongkan `fills` —
   jangan dilepas. Bug ini sempat membuat mode gelap terlihat seolah token `past`/`future` tertukar,
   padahal pengikatannya benar.
2. **`layoutSizing*` harus disetel setelah `appendChild`**, bukan sebelum.
3. **Jangan pakai emoji atau glyph teks sebagai ikon.** Cakupan simbol tiap font berbeda dan tebal
   garisnya tidak seragam — itu tell "ikon campur aduk". Pakai `icon()` yang menggambar SVG.

Blok pembuka di `10` / `11` / `12` sengaja diduplikasi — konsol plugin tidak menyimpan state
antar-eksekusi, jadi tiap skrip harus berdiri sendiri. Kalau pembukanya diubah, ubah di ketiganya.
Rinciannya di [`_preamble.md`](_preamble.md).
