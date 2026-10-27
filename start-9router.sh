#!/bin/bash
# Supervisor 9Router (fork serenhope, di-vendor di ./9router):
# bind ke localhost saja (127.0.0.1:20128), auto-restart kalau proses
# crash. Log: 9router.log (di root repo, bukan di 9router/).
#
# Password dashboard dibaca dari file 600 (JANGAN tulis password di script!):
#   echo -n 'password-baru' > .dashboard-pw && chmod 600 .dashboard-pw
# Password itu diteruskan sebagai INITIAL_PASSWORD — password login
# pertama fork serenhope (default bawaannya, "seren123", TIDAK dipakai
# selama INITIAL_PASSWORD ter-set). Data 9Router (SQLite, secret) tinggal
# di ~/.9router (DATA_DIR default fork; bisa di-override lewat env).
#
# Cara jalan: `node 9router/custom-server.js --port 20128 --hostname 127.0.0.1`
# dari dalam folder 9router/. custom-server.js membaca PORT dari env dan
# meneruskan argv ke `next start`; bila hasil build standalone sudah ada
# (.next/standalone/server.js), server itu membaca PORT/HOSTNAME dari env
# — jadi PORT=20128 + HOSTNAME=127.0.0.1 di-export untuk kedua jalur.
# JANGAN pakai `npm run start`: script itu membekukan `--port 20127`.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/i18n.sh
. "$SCRIPT_DIR/lib/i18n.sh"

ROUTER_DIR="$SCRIPT_DIR/9router"
ROUTER_LOG="$SCRIPT_DIR/9router.log"
DASHBOARD_PW_FILE="${DASHBOARD_PW_FILE:-$SCRIPT_DIR/.dashboard-pw}"
# -s (bukan -f): file yang ADA tapi KOSONG sama berbahayanya dengan
# tidak ada — password kosong/default tetap dipakai 9Router (putaran 4).
if [ -s "$DASHBOARD_PW_FILE" ]; then
  export INITIAL_PASSWORD="$(cat "$DASHBOARD_PW_FILE")"
elif [ -f "$SCRIPT_DIR/.tunnel-url" ]; then
  # Fail-closed (audit putaran 3): .tunnel-url berarti dashboard akan
  # terekspos publik lewat tunnel. Password default di setup publik
  # BUKAN pilihan — dulu script hanya memperingatkan lalu tetap jalan.
  # Pemakaian lokal murni (tanpa .tunnel-url) tetap cukup peringatan.
  echo "$(t router_pw_required_public "$DASHBOARD_PW_FILE")" >&2
  exit 1
else
  echo "$(t router_pw_warn "$DASHBOARD_PW_FILE")" >&2
fi

# Cek ini SETELAH cek password, supaya smoke test fail-closed
# (tests/launcher-smoke.sh) tetap lolos tanpa folder 9router/.
if [ ! -f "$ROUTER_DIR/custom-server.js" ]; then
  echo "9Router vendored source tidak ditemukan di $ROUTER_DIR/custom-server.js — clone repo ini utuh." >&2
  exit 1
fi
if [ ! -f "$ROUTER_DIR/.next/BUILD_ID" ]; then
  echo "9Router belum di-build — jalankan: bash scripts/install.sh" >&2
  exit 1
fi

export PORT=20128
export HOSTNAME=127.0.0.1
export NODE_ENV=production
export DATA_DIR="${DATA_DIR:-$HOME/.9router}"
export BASE_URL="${BASE_URL:-http://127.0.0.1:20128}"
export NEXT_PUBLIC_BASE_URL="${NEXT_PUBLIC_BASE_URL:-http://127.0.0.1:20128}"

while true; do
  echo "[$(date -u '+%H:%M:%S')] starting 9router (serenhope fork)..." >> "$ROUTER_LOG"
  (cd "$ROUTER_DIR" && exec node custom-server.js --port 20128 --hostname 127.0.0.1) >> "$ROUTER_LOG" 2>&1
  echo "[$(date -u '+%H:%M:%S')] 9router exited (code $?), restarting in 5s..." >> "$ROUTER_LOG"
  sleep 5
done
