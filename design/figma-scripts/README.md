# Skrip Figma — 4 frame wireframe yang tersisa

Pembangunan wireframe terhenti di frame ke-11 karena **batas panggilan Figma MCP pada plan Starter**.
Skrip di folder ini menyelesaikan sisanya tanpa perlu menyusun ulang dari nol.

File Figma: https://www.figma.com/design/509ex6znf0rrktS8oouOwd

## Sudah berdiri di halaman `Wireframes` (10 frame)

`01 · Onboarding` · `02 · Pilih jam dengar` · `03a · Beranda kosong` · `03b · Beranda terisi` ·
`04 · Tambah buku (sheet)` · `05 · Tinjau hasil scan` · `06 · Konfirmasi buku` · `07 · Detail buku` ·
`08 · Recap Sebelumnya` · `09 · Player`

## Yang diselesaikan skrip ini (4 frame)

| Skrip | Frame | Posisi x |
|---|---|---|
| `01-fokus-dan-kuota.js` | `09b · Player · mode fokus` (memakai koleksi **Dark**), `10 · Kuota habis` | 4400, 4840 |
| `02-pengaturan-dan-notifikasi.js` | `11 · Pengaturan`, `12 · Notifikasi` | 5280, 5720 |

Keduanya ditulis sebagai skrip berdiri sendiri — masing-masing memuat ulang font, variabel, dan
text style, jadi urutan menjalankannya tidak berpengaruh dan aman diulang kalau gagal di tengah.

## Cara menjalankan

**Opsi A — lewat Claude.** Minta jalankan skrip ini; keduanya masuk ke `use_figma` apa adanya.
Batas Starter perlu sudah pulih dulu.

**Opsi B — manual lewat Figma plugin console.** Tempel isi skrip ke plugin yang bisa menjalankan
Plugin API (mis. *Scripter*). Buang baris `return` di akhir kalau plugin-nya tidak menerimanya.

## Catatan kalau nanti dimodifikasi

Tiga jebakan yang sudah menggigit sekali selama pembangunan ini:

1. **Frame di Figma default-nya berlatar putih.** Setiap `createAutoLayout` / `createFrame` yang
   tidak diberi fill akan menutupi latar induknya dengan putih. Helper `box()` di skrip ini selalu
   mengosongkan `fills` — jangan dihapus. Bug ini sempat membuat mode gelap terlihat terbalik.
2. **`layoutSizing` harus disetel setelah `appendChild`**, bukan sebelum.
3. **Hindari emoji** — Inter tidak memuatnya dan hasilnya jadi kotak kosong. Pakai glyph yang pasti
   ada (`← → ✓ ○ ● ⋮ ✕ ▶ ▮ ↺ ↻ ▷ ▸ ⌄ ◀ ✎`) atau kotak abu-abu sebagai penampung ikon.
