# Ujicoba langsung ke HP — tanpa download APK (flutter run)
# Usage: .\run-on-phone.ps1 192.168.137.83 39559
#
# Syarat (Opsi A):
#   1. Laptop: Mobile hotspot ON
#   2. HP connect ke hotspot laptop (bukan 7142)
#   3. HP: Developer options -> Wireless debugging ON
#   4. Kirim IP:port dari layar Wireless debugging (bukan layar pairing)

param(
    [Parameter(Mandatory=$true)][string]$PhoneIp,
    [Parameter(Mandatory=$true)][int]$PhonePort
)

Write-Host ""
Write-Host "Menjalankan flutter run via WSL..." -ForegroundColor Green
wsl -e bash -lc "chmod +x /mnt/d/codex/base/ilb/scripts/run-on-phone.sh && /mnt/d/codex/base/ilb/scripts/run-on-phone.sh $PhoneIp $PhonePort"
