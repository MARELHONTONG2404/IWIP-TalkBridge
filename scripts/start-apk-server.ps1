# Sama seperti tugas sebelumnya: server sederhana + IP laptop
# Jalankan sebagai Administrator (klik kanan PowerShell)

$apkDir = "D:\codex\base\ilb\build\app\outputs\flutter-apk"
$port = 5500

# Matikan server lama (sering jadi penyebab "tidak dapat dijangkau")
Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue |
    ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
Get-CimInstance Win32_Process -Filter "Name='python.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*http.server*$port*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

# Firewall + jaringan Private (sekali jalan)
netsh advfirewall firewall delete rule name="Flutter APK 5500" 2>$null | Out-Null
netsh advfirewall firewall delete rule name="ILB APK Server 5500" 2>$null | Out-Null
netsh advfirewall firewall add rule name="Flutter APK 5500" dir=in action=allow protocol=TCP localport=$port | Out-Null
Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -eq 'Public' } |
    ForEach-Object { Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory Private }

# Satu server saja — persis seperti dulu
Set-Location $apkDir
Start-Process python -ArgumentList "-m","http.server",$port -WindowStyle Normal
Start-Sleep -Seconds 2

$ip = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $_.InterfaceAlias -like '*Wi-Fi*' -and
        $_.IPAddress -like '192.168.*'
    } | Select-Object -First 1).IPAddress

Write-Host ""
Write-Host "=== Cara yang sama seperti tugas sebelumnya ===" -ForegroundColor Green
Write-Host "1. HP dan laptop: WiFi yang sama (7142)"
Write-Host "2. Buka Chrome di HP:"
Write-Host "   http://${ip}:${port}/" -ForegroundColor Cyan
Write-Host "3. Tap file APK untuk download"
Write-Host ""
