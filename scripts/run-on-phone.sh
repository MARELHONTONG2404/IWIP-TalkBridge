#!/usr/bin/env bash
# Ujicoba langsung ke HP — tanpa download APK (flutter run)
# Usage: ./scripts/run-on-phone.sh 192.168.137.83 39559
#
# Syarat (Opsi A):
#   1. Laptop: Mobile hotspot ON
#   2. HP connect ke hotspot laptop (bukan 7142)
#   3. HP: Developer options -> Wireless debugging ON
#   4. IP:port dari layar utama Wireless debugging

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 PHONE_IP PORT"
  echo "Example: $0 192.168.137.83 39559"
  exit 1
fi

PHONE_IP="$1"
PHONE_PORT="$2"

source ~/.bashrc 2>/dev/null || true

echo ""
echo "Connecting to ${PHONE_IP}:${PHONE_PORT}..."
adb connect "${PHONE_IP}:${PHONE_PORT}"
sleep 2
adb devices

if ! adb devices | grep -qE "${PHONE_IP}:${PHONE_PORT}[[:space:]]+device"; then
  echo ""
  echo "GAGAL connect. Cek:"
  echo "  1. Hotspot LAPTOP ON, HP connect ke hotspot laptop"
  echo "  2. Wireless debugging ON di HP"
  echo "  3. IP:port BARU dari layar utama Wireless debugging"
  echo "  4. Mobile data OFF di HP"
  exit 1
fi

echo ""
echo "Menjalankan flutter run ke HP..."
cd "$(dirname "$0")/.."
flutter run -d "${PHONE_IP}:${PHONE_PORT}"
