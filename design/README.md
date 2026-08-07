# Design Tokens — Bacain

`tokens.json` adalah **satu-satunya sumber kebenaran** untuk warna, spasi, radius, ukuran, dan tipografi.
Figma dan kode Flutter sama-sama membacanya, jadi keduanya tidak akan pernah tidak sinkron.

Format: [Design Tokens Community Group (DTCG)](https://tr.designtokens.org/format/) — `$type` / `$value`,
dengan `$metadata` dan `$themes` agar bisa langsung dibaca plugin Tokens Studio.

---

## Aturan utama

**Ganti nilainya, jangan ganti namanya.**
Nama token adalah kontrak antara desain dan kode. Mengganti nilai `brand/500` dari abu-abu jadi warna
merek akan otomatis merambat ke seluruh app. Mengganti *namanya* akan mematahkan kode.

---

## Cara memakai di Figma

1. Pasang plugin **Tokens Studio for Figma** (gratis)
2. Buka plugin → menu ⚙ → **Import** → pilih `design/tokens.json`
3. Set `primitives` sebagai **source**, dan aktifkan salah satu dari `color/light` atau `color/dark`
4. Klik **Create Variables** — Tokens Studio akan membuat Figma Variables dengan nama yang persis sama
5. Setelah selesai mengubah nilai: **Export** kembali ke `design/tokens.json`, commit, dan kode ikut terbarui

Kalau plugin terasa berlebihan, tabel token lengkapnya juga tertulis di dokumen rencana — bisa dibuat manual.

---

## Struktur

| Token set | Isi | Mode |
|---|---|---|
| `primitives` | Palet mentah. **Tidak pernah dipakai langsung** di komponen — hanya jadi sumber alias. | tunggal |
| `color/light` | Warna semantik mode terang. Semua alias ke `primitives`. | Light |
| `color/dark` | Warna semantik mode gelap. Semua alias ke `primitives`. | Dark |
| `spacing` | Skala kelipatan 4 (`space/0` … `space/8`) | tunggal |
| `radius` | `none` / `sm` / `md` / `lg` / `full` | tunggal |
| `size` | Ukuran tetap yang dipakai bersama desain & kode | tunggal |
| `typography` | Keluarga font, weight, dan 12 text style | tunggal |

Dua lapis (primitives → semantik) memang terasa berlebihan di awal, tapi itu yang membuat ganti tema
gelap/terang jadi sekali kerja, bukan menyisir ratusan layer.

---

## Yang masih placeholder

| Token | Keterangan |
|---|---|
| `primitives/brand/*` | Abu-abu. Diganti warna merek Bacain. |
| `primitives/accent/*` | Abu-abu. Warna aksen sekunder — dipakai highlight bacaan & bar kuota. |
| `typography/font/family/*` | Inter. Diganti typeface pilihan. |

Yang **sudah berisi warna sungguhan** dan boleh dipakai apa adanya kalau cocok:

- `status/*` — merah/kuning/hijau fungsional. Kalau ini ikut diabu-abukan, kondisi error jadi tak terbaca.
- `cover/1` … `cover/8` — palet sampul buku otomatis (lihat di bawah).

---

## Catatan per kelompok

### `reading/*` — empat token paling menentukan

`textPast`, `textFuture`, `textActive`, `highlightBg` mengatur teks berjalan di layar player.
Harus cukup kontras untuk membantu fokus, tapi tidak menyilaukan.

⚠️ **Uji langsung di layar HP dalam gelap, bukan di monitor.** Highlight yang terlihat lembut di
monitor terang bisa menyilaukan di kamar gelap. Itu sebabnya `highlightBg` di mode gelap sengaja
jauh lebih redup daripada padanannya di mode terang — bukan sekadar dibalik.

### `cover/1` … `cover/8` — sampul buku otomatis

Buku hasil scan dan sebagian besar PDF **tidak punya gambar sampul**. Tanpa palet ini, rak di
beranda jadi barisan kotak kosong. Warna dipilih otomatis dari hash judul buku, jadi kedelapannya
harus tetap enak dilihat saat berjejer.

### `typography/Reading/*`

Line-height sengaja longgar (±1,65) — ini teks yang dipandangi 15 menit sambil mendengarkan.
Kerapatan UI biasa terlalu sesak untuk itu.

⚠️ **Lisensi font**: typeface harus boleh di-*embed* dalam aplikasi. Google Fonts (OFL) aman.
Typeface berbayar butuh lisensi app embedding — lisensi desktop saja tidak cukup.

---

## Batasan yang mengikat semua desain

| Hal | Ketentuan |
|---|---|
| Artboard | 360 × 800 dp. Desain di 1× — satuannya dp. |
| Mini player | Menutup `size/miniPlayer` (64dp) di bawah semua layar utama. |
| Target sentuh | Minimal `size/touchMin` (48dp). |
| Kontras teks | Minimal 4,5:1 (WCAG AA). Wajib — aksesibilitas adalah klaim produk ini. |
| Penskalaan font | Tata letak harus utuh sampai ukuran font sistem 200%. Hindari tinggi terkunci. |
| Dark mode | Setiap layar butuh dua versi. Tidak ada yang "cukup dibalik warnanya". |
