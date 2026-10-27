#!/bin/bash
# Restart 9Router (supervisor loop): bunuh sisa proses, jalankan supervisor detached.
# Proses 9Router sekarang: `node custom-server.js --port 20128 ...` yang
# dijalankan start-9router.sh dari dalam folder 9router/ (bukan lagi binary
# `9router -p` dari npm). Pola kill memakai port 20128 supaya hanya instance
# Hermuse ini yang kena — pola "[.]" + "--port 20128" tidak match baris
# perintah pkill itu sendiri.
# NOTE: pola "/start-9router.sh" (dengan slash) tidak match "restart-9router.sh",
# jadi script ini aman dari self-kill.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pkill -f "custom-server[.]js --port 20128" 2>/dev/null || true
pkill -f "/start-9router.sh" 2>/dev/null || true
sleep 3
setsid nohup bash "$SCRIPT_DIR/start-9router.sh" < /dev/null > /dev/null 2>&1 &
echo "9router supervisor started"
