# Preamble bersama

Skrip `10` / `11` / `12` masing-masing memuat blok pembuka yang identik (resolusi
token, muat font, helper ikon SVG, helper auto-layout). Duplikasi itu **disengaja** —
`use_figma` dan konsol plugin Figma tidak menyimpan state antar-eksekusi, jadi tiap
skrip harus berdiri sendiri.

Kalau blok pembukanya diubah, ubah di ketiganya.

## Helper yang tersedia di tiap skrip

| Helper | Guna |
|---|---|
| `pt(M, 'text/primary')` | Paint terikat variabel. `M` = `L` (terang) atau `D` (gelap). |
| `T(M, 'Reading/Body', 'teks', 'text/primary')` | Text node + text style + warna terikat. |
| `box('VERTICAL', {…})` | Auto-layout frame **dengan fills dikosongkan**. Jangan dilepas — frame Figma default-nya putih dan akan menutupi latar induknya. |
| `add(parent, node, hug)` | Append lalu setel sizing. `hug = true` untuk lebar mengikuti isi. |
| `screen(M, nama, x)` | Frame 360×800 berlatar `bg/base`. |
| `icon(M, PATH.ar, 22, 'text/primary')` | Ikon SVG, stroke 1,5px ujung bulat — satu suara untuk semua. |
| `rect(w, h, M, token)` | Persegi dengan fill terikat. |
| `spacer(h)` | Jarak vertikal tetap (auto-layout hanya punya gap seragam). |

## Urutan menjalankan

`00` → `10` → `11` → `12`

`00` wajib duluan: skrip layar mencari text style v2 dan akan berhenti dengan pesan
jelas kalau belum ada.

Semua aman diulang — tiap skrip menghapus frame bernama sama sebelum membangun ulang.
Halaman `Wireframes` (v1) **tidak disentuh**, supaya bisa dibandingkan berdampingan.
