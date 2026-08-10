#!/usr/bin/env bash
# Membangun prototipe web ke docs/.
#
# Dua hal yang tidak dilakukan `flutter build web` sendiri, dan dua-duanya
# baru ketahuan saat gagal:
#
#   1. `--base-href` bawaannya MUTLAK. Nilai "/bacain/" cuma jalan di
#      GitHub Pages; di Vercel yang menyajikan dari akar, seluruh aset 404
#      dan yang terlihat cuma layar putih. `<base href="./">` jalan di
#      dua-duanya — aman karena app ini tidak punya rute URL sendiri.
#
#   2. Tanpa `--no-web-resources-cdn`, CanvasKit diambil dari gstatic saat
#      dijalankan. Di jaringan yang memblokirnya, app-nya diam saja tanpa
#      pesan apa pun.
#
# Pakai: bash tools/bangun-web.sh
set -euo pipefail

AKAR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$AKAR/app"

flutter build web --release --no-web-resources-cdn

# Base href relatif: satu keluaran, dua tempat penyajian.
sed -i 's|<base href="/">|<base href="./">|' build/web/index.html
grep -q '<base href="./">' build/web/index.html \
  || { echo 'base href gagal ditulis ulang — periksa index.html'; exit 1; }

cd "$AKAR"
rm -rf docs
cp -r app/build/web docs
touch docs/.nojekyll   # tanpa ini GitHub Pages membuang folder berawalan _

# ── membuang yang tidak pernah diminta saat dijalankan ──────────────
#
# Keluaran mentah 43 MB, dan 25 MB di antaranya tidak akan pernah diambil
# browser. Ini penting karena docs/ IKUT MASUK GIT — tiap kali dibangun
# ulang, seluruh berkasnya jadi objek baru di riwayat.
#
# Dasarnya bukan tebakan, tapi kode pemilih di flutter_bootstrap.js:
#
#   * `renderer: "canvaskit"` — build ini dart2js + CanvasKit. Berkas
#     skwasm*/wimp* cuma dijangkau di dalam pemuat skwasm, dan pemuat itu
#     hanya dipakai kalau build terpilih ber-renderer skwasm (dart2wasm).
#   * `canvasKitVariant == "experimentalWebParagraph"` — varian itu butuh
#     opt-in yang tidak kita pasang.
#   * `*.symbols` adalah peta simbol untuk membaca jejak tumpukan; alat
#     pengembang yang memakainya, bukan app-nya.
#
# Yang TIDAK dibuang: canvaskit/canvaskit.* maupun canvaskit/chromium/*.
# Chromium memakai yang kedua, mesin lain (WebKit di iPhone, Gecko) memakai
# yang pertama — dan jalur non-Chromium itu tidak bisa diuji dari sini,
# jadi ia tetap tinggal.
find docs -name '*.symbols' -delete
rm -rf docs/canvaskit/experimental_webparagraph
rm -f docs/canvaskit/skwasm.js docs/canvaskit/skwasm.wasm \
      docs/canvaskit/skwasm_heavy.js docs/canvaskit/skwasm_heavy.wasm \
      docs/canvaskit/wimp.js docs/canvaskit/wimp.wasm

for wajib in canvaskit/canvaskit.js canvaskit/canvaskit.wasm \
             canvaskit/chromium/canvaskit.js canvaskit/chromium/canvaskit.wasm \
             main.dart.js flutter_bootstrap.js index.html; do
  [ -f "docs/$wajib" ] || { echo "hilang setelah dipangkas: $wajib"; exit 1; }
done

echo "docs/ siap — $(du -sh docs | cut -f1), $(find docs -type f | wc -l) berkas"
