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

echo "docs/ siap — $(du -sh docs | cut -f1)"
