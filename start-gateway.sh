#!/bin/bash
# Start Telegram gateway Hermes secara detached (tetap jalan setelah shell ditutup).
# Log: gateway.log. Cek dengan: pgrep -f "gateway.*run"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# VM ini hanya punya egress via proxy HTTP (env HTTPS_PROXY). Adapter Telegram
# Hermes hanya memakai proxy bila TELEGRAM_PROXY diset eksplisit (fallback ke
# HTTPS_PROXY tidak jalan di sini), jadi teruskan proxy egress saat ini.
# Di VPS biasa HTTPS_PROXY kosong -> variabel tetap kosong, tanpa efek.
export TELEGRAM_PROXY="${TELEGRAM_PROXY:-${HTTPS_PROXY:-${https_proxy:-}}}"
setsid nohup ./run-hermes.sh gateway run >> gateway.log 2>&1 < /dev/null &
echo "gateway starting, pid $!"
