#!/usr/bin/env bash
# Install otomatis: Hermes Agent + Node.js + 9Router (fork serenhope,
# di-vendor di ./9router) di VM Linux (Debian/Ubuntu).
# Dijalankan sebagai user biasa (bukan root). Tidak butuh input interaktif
# kecuali saat login provider nanti (langkah manual setelah script selesai).
#
# 9Router di sini BUKAN lagi paket npm `9router` upstream (dulu di-pin
# 0.5.104). Repo ini mem-vendor fork serenhope/9router sebagai source
# Next.js di ./9router (lihat VENDORED-9ROUTER.md) — installer menjalankan
# `npm install` + `npm run build` di sana, lalu start-9router.sh
# menjalankannya via `node 9router/custom-server.js`.
# Update fork = ganti isi ./9router, lalu jalankan ulang installer ini
# (build ulang otomatis bila package.json berubah).
#
# Cara pakai:
#   bash scripts/install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../lib/i18n.sh
. "$SCRIPT_DIR/../lib/i18n.sh"

log() { printf '\033[1;32m[install]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[install]\033[0m %s\n' "$*" >&2; }

# --- Versi dependensi (di-pin agar instalasi bisa direproduksi) ---
# Wrangler masih paket npm ter-pin. 9Router TIDAK lagi di-pin lewat npm:
# versinya adalah versi source yang di-vendor di 9router/package.json
# (saat ini 0.5.319, fork serenhope) — naikkan dengan mengganti ./9router.
WRANGLER_VERSION="${HERMUSE_WRANGLER_VERSION:-4.151.2}"
NINEROUTER_DIR="$REPO_DIR/9router"

# --- 1. Cek OS ---
if ! command -v apt-get >/dev/null 2>&1; then
  warn "$(t install_debian_only)"
  exit 1
fi

# --- 1b. sudo harus non-interaktif (sesuai klaim script ini) ---
# Tanpa ini, `sudo apt-get` akan menggantung menunggu password di mesin
# fresh tanpa passwordless sudo — gagal cepat dengan pesan jelas.
if [ "$(id -u)" -ne 0 ]; then
  if ! command -v sudo >/dev/null 2>&1; then
    warn "$(t install_need_sudo)"
    exit 1
  fi
  if ! sudo -n true 2>/dev/null; then
    warn "$(t install_sudo_pw)"
    warn "$(t install_enable_sudo)"
    exit 1
  fi
fi

# --- 2. Dependensi dasar ---
# build-essential + python3: dibutuhkan untuk meng-compile modul native
# 9Router (better-sqlite3) saat `npm install` di ./9router.
log "$(t install_deps)"
sudo apt-get update -y
sudo apt-get install -y git curl tar ca-certificates build-essential python3

# --- 3. Node.js LTS (dibutuhkan 9Router vendored + build-nya) ---
if ! command -v node >/dev/null 2>&1; then
  log "$(t install_node)"
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  sudo apt-get install -y nodejs
else
  log "$(t install_have_node "$(node --version)")"
fi

# --- 4. Hermes Agent (installer resmi Nous Research) ---
if ! command -v hermes >/dev/null 2>&1; then
  log "$(t install_hermes)"
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-browser
  # shellcheck disable=SC1090
  source ~/.bashrc 2>/dev/null || true
  export PATH="$HOME/.local/bin:$PATH"
else
  log "$(t install_have_hermes "$(hermes --version 2>/dev/null || echo '?')")"
fi

# --- 5. Paket npm ter-pin (Wrangler) ---
# Versi yang TERPASANG diverifikasi terhadap pin — bukan sekadar
# "perintahnya ada di PATH". Beda versi (lebih lama ATAU lebih baru)
# -> pasang ulang persis versi pin: upgrade & downgrade lewat jalur yang
# sama, lalu hasil akhir dicek ulang; tidak cocok = installer gagal
# dengan pesan jelas (bukan diam-diam jalan dengan versi yang salah).
# Wrangler dipasang di sini juga: prasyarat scripts/setup-tunnel.sh yang
# dulu tidak dijamin keberadaannya.
pkg_version() { # $1 = nama paket di prefix $HOME/.npm-global
  local f="$HOME/.npm-global/lib/node_modules/$1/package.json"
  [ -f "$f" ] || return 0
  node -e 'console.log(require(process.argv[1]).version)' "$f" 2>/dev/null || true
}
ensure_pkg() { # $1 = paket, $2 = versi pin
  local name="$1" want="$2" have=""
  have="$(pkg_version "$name")"
  if [ "$have" = "$want" ]; then
    log "$(t install_version_ok "$name" "$have")"
    return 0
  fi
  if [ -n "$have" ]; then
    log "$(t install_align_version "$name" "$have" "$want")"
  else
    log "$(t install_pkg_fresh "$name" "$want")"
  fi
  mkdir -p "$HOME/.npm-global"
  npm install -g --prefix "$HOME/.npm-global" "$name@$want"
  export PATH="$HOME/.npm-global/bin:$PATH"
  grep -q '.npm-global/bin' ~/.bashrc 2>/dev/null || \
    echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
  have="$(pkg_version "$name")"
  if [ "$have" != "$want" ]; then
    warn "$(t install_version_bad "$name" "${have:-none}" "$want")"
    exit 1
  fi
  log "$(t install_version_ok "$name" "$have")"
}
ensure_pkg "wrangler" "$WRANGLER_VERSION"

# --- 5b. 9Router: build dari source yang di-vendor (fork serenhope) ---
# `npm run build` di ./9router juga menjalankan postbuild
# (scripts/copy-standalone-assets.mjs) yang menyiapkan .next/standalone
# beserta custom-server.js — itulah yang dijalankan start-9router.sh.
# Build diulang bila belum ada hasil build, atau package.json lebih baru
# dari hasil build terakhir (source fork diganti); bila tidak, lewati.
if [ ! -f "$NINEROUTER_DIR/package.json" ]; then
  warn "9Router vendored source tidak ditemukan di $NINEROUTER_DIR/package.json — clone repo ini utuh (folder 9router/ wajib ada)."
  exit 1
fi
NINEROUTER_VERSION="$(node -e 'console.log(require(process.argv[1]).version)' "$NINEROUTER_DIR/package.json")"
log "9Router (serenhope fork) $NINEROUTER_VERSION — build dari $NINEROUTER_DIR"
if [ ! -f "$NINEROUTER_DIR/.next/BUILD_ID" ] || [ "$NINEROUTER_DIR/package.json" -nt "$NINEROUTER_DIR/.next/BUILD_ID" ]; then
  (cd "$NINEROUTER_DIR" && NEXT_TELEMETRY_DISABLED=1 npm install && NEXT_TELEMETRY_DISABLED=1 npm run build)
else
  log "9Router build sudah terbaru — lewati (hapus $NINEROUTER_DIR/.next untuk build ulang paksa)"
fi
if [ ! -f "$NINEROUTER_DIR/.next/BUILD_ID" ]; then
  warn "9Router build gagal: $NINEROUTER_DIR/.next/BUILD_ID tidak ada setelah build."
  exit 1
fi
log "9Router (serenhope fork) $NINEROUTER_VERSION siap"

# --- 6. Verifikasi ---
log "$(t install_verify)"
export PATH="$HOME/.local/bin:$PATH"
if hermes doctor; then
  log "$(t install_doctor_ok)"
else
  warn "$(t install_doctor_warn)"
fi

cat << 'EOF'

============================================================
 Instalasi selesai. Langkah manual berikutnya:
  1. hermes setup --portal     # login provider model (OAuth)
     atau: hermes model        # pilih provider/model
  2. Buat bot Telegram via @BotFather, catat tokennya.
  3. Dapatkan numeric ID via @userinfobot.
  4. hermes gateway setup       # isi token bot + allowlist ID
  5. bash restart-9router.sh    # 9Router (fork serenhope, dari ./9router)
  6. hermes gateway run         # verifikasi "Connected to Telegram"
 Lihat README.md untuk detail tiap langkah.
============================================================
EOF
