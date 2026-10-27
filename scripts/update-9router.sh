#!/bin/bash
# update-9router.sh — update 9Router fork serenhope yang di-vendor di ./9router
# ke revisi terbaru (atau revisi tertentu) dari serenhope/9router.
#
# Cara pakai (dari root repo):
#   bash scripts/update-9router.sh            # latest master
#   bash scripts/update-9router.sh <ref>      # commit / tag / branch tertentu
#   DRY_RUN=1 bash scripts/update-9router.sh  # lihat apa yang berubah, tanpa mengubah apa-apa
#
# Yang dilakukan:
#   1. Clone dangkal serenhope/9router (ref yang diminta) ke temp dir.
#   2. Bandingkan commit + versi dengan yang sedang di-vendor; bila sama,
#      berhenti — tidak ada yang berubah.
#   3. Ganti isi 9router/ dengan hasil clone (tanpa .git).
#   4. Perbarui tabel "Sumber" di VENDORED-9ROUTER.md (commit + versi).
#   5. Cetak langkah lanjut: rebuild, doctor, commit.
#
# Keamanan:
#   - Menolak jalan bila ada perubahan lokal yang belum di-commit di
#     9router/ atau VENDORED-9ROUTER.md (supaya update tidak menimpa
#     kerja kamu diam-diam).
#   - Tidak pernah menyentuh file di luar 9router/ dan VENDORED-9ROUTER.md.
#   - Setelah update, install.sh di mesin target akan build ulang otomatis
#     (package.json lebih baru dari .next/BUILD_ID).
#   - Script ini TIDAK men-commit dan TIDAK men-push — kamu yang commit
#     setelah memeriksa diff-nya (git diff --stat).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
REF="${1:-master}"
UPSTREAM="https://github.com/serenhope/9router.git"
DRY_RUN="${DRY_RUN:-0}"

# 0. Harus di dalam repo git, dan area yang disentuh harus bersih.
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: bukan repo git — jalankan dari hasil clone repo ini." >&2
  exit 1
fi
# Menolak bila ada perubahan yang belum di-stage (diff vs index) atau file
# tak terlacak di area yang disentuh. Perubahan yang sudah di-stage aman:
# index menyimpan versi lamanya, jadi update tidak menghilangkan apa-apa.
# (Cek `git status --porcelain` polos tidak dipakai: sebelum commit pertama,
# semua file berstatus "A" dan cek itu akan selalu menolak.)
if ! git diff --quiet -- 9router VENDORED-9ROUTER.md \
  || [ -n "$(git ls-files --others --exclude-standard -- 9router VENDORED-9ROUTER.md)" ]; then
  echo "ERROR: ada perubahan lokal yang belum di-stage di 9router/ atau VENDORED-9ROUTER.md — git add dulu (atau commit/stash)." >&2
  exit 1
fi

# Versi + commit yang sedang di-vendor (untuk perbandingan).
# require() butuh path ABSOLUT — path relatif dibaca sebagai nama modul dan gagal.
OLD_VERSION="$(node -e 'console.log(require(process.argv[1]).version)' "$ROOT/9router/package.json" 2>/dev/null || echo '?')"
OLD_COMMIT="$(sed -n 's/.*serenhope\/9router.*commit `\([0-9a-f]*\)`.*/\1/p' VENDORED-9ROUTER.md | head -1)"

# 1. Clone (dangkal bila ref-nya branch/tag; clone penuh + checkout bila commit SHA).
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "[update-9router] mengambil serenhope/9router@$REF ..."
if ! git clone --quiet --depth 1 --branch "$REF" "$UPSTREAM" "$TMP/9router" 2>/dev/null; then
  # Ref berupa commit SHA (bukan branch/tag): ambil commit itu saja,
  # jangan clone penuh (riwayat fork besar dan lambat). Fetch by-SHA
  # butuh SHA LENGKAP (40 karakter) — SHA pendek ditolak server.
  echo "[update-9router] ref '$REF' bukan branch/tag — ambil commit itu saja ..."
  git clone --quiet --depth 1 "$UPSTREAM" "$TMP/9router"
  if ! git -C "$TMP/9router" fetch --quiet --depth 1 origin "$REF" 2>/dev/null; then
    echo "ERROR: tidak bisa mengambil ref '$REF'. Bila ini commit SHA, pakai SHA lengkap (40 karakter) — SHA pendek tidak bisa di-fetch. Atau pakai nama branch/tag." >&2
    exit 1
  fi
  git -C "$TMP/9router" checkout --quiet "$REF"
fi
NEW_COMMIT="$(git -C "$TMP/9router" rev-parse HEAD)"
NEW_COMMIT_SHORT="${NEW_COMMIT:0:7}"
NEW_VERSION="$(node -e 'console.log(require(process.argv[1]).version)' "$TMP/9router/package.json")"

# 2. Sudah terbaru? Berhenti.
if [ -n "$OLD_COMMIT" ] && [ "$NEW_COMMIT_SHORT" = "$OLD_COMMIT" ]; then
  echo "[update-9router] sudah terbaru: 9router $OLD_VERSION ($OLD_COMMIT) — tidak ada yang berubah."
  exit 0
fi
echo "[update-9router] $OLD_VERSION ($OLD_COMMIT) -> $NEW_VERSION ($NEW_COMMIT_SHORT)"
if [ "$DRY_RUN" = "1" ]; then
  echo "[update-9router] DRY_RUN=1 — tidak ada file yang diubah."
  exit 0
fi

# 3. Ganti isi 9router/ (tanpa .git hasil clone).
rm -rf 9router
mkdir -p 9router
cp -r "$TMP/9router/." 9router/
rm -rf 9router/.git

# 4. Perbarui tabel "Sumber" di VENDORED-9ROUTER.md.
sed -i -E "s/(serenhope\/9router.*commit \`)[0-9a-f]+(\`)/\1$NEW_COMMIT_SHORT\2/" VENDORED-9ROUTER.md
sed -i -E "s/(\| Versi fork \| \`)[0-9.]+(\`)/\1$NEW_VERSION\2/" VENDORED-9ROUTER.md
grep -q "$NEW_COMMIT_SHORT" VENDORED-9ROUTER.md || { echo "ERROR: gagal memperbarui VENDORED-9ROUTER.md" >&2; exit 1; }

echo ""
echo "[update-9router] selesai: 9router $NEW_VERSION ($NEW_COMMIT_SHORT)"
echo "Periksa dulu:  git diff --stat"
echo "Langkah lanjut:"
echo "  1. bash scripts/install.sh   # build ulang (di mesin target)"
echo "  2. bash scripts/doctor.sh    # harus 0 FAIL"
echo "  3. git add -A && git commit -m \"Update 9router (serenhope) ke $NEW_VERSION ($NEW_COMMIT_SHORT)\""
