<#
.SYNOPSIS
    Tests whether a remote file share supports the File Server Remote VSS Protocol (MS-FSRVP).

.DESCRIPTION
    Checks FSRVP support by calling the IsPathSupported RPC method (Opnum 8) on the
    FssagentRpc named pipe (UUID a8e0653c-2744-4389-a61d-7373df8b2292).

.PARAMETER ShareUNC
    The UNC path of the share to test (e.g. \\server\share).

.EXAMPLE
    .\Test-FsrvpSupport.ps1 -ShareUNC "\\fileserver\data"
#>
param(
    [Parameter(Mandatory)]
    [string]$ShareUNC
)

$ErrorActionPreference = 'Stop'

# Extract server name from UNC path
if ($ShareUNC -notmatch '^\\\\([^\\]+)\\(.+)$') {
    Write-Error "Invalid UNC path. Expected format: \\server\share"
    return
}
$ServerName = $Matches[1]

# Method 1: Check if the FssagentRpc named pipe endpoint is accessible
Write-Host "Testing FSRVP support for: $ShareUNC" -ForegroundColor Cyan
Write-Host "Server: $ServerName" -ForegroundColor Cyan
Write-Host ""

$pipePath = "\\$ServerName\pipe\FssagentRpc"
Write-Host "[1] Checking FssagentRpc named pipe endpoint..." -ForegroundColor Yellow

try {
    $pipeExists = Test-Path $pipePath
    if ($pipeExists) {
        Write-Host "    Named pipe exists: $pipePath" -ForegroundColor Green
    } else {
        Write-Host "    Named pipe NOT found: $pipePath" -ForegroundColor Red
        Write-Host "    The FSRVP service (File Server VSS Agent) may not be running." -ForegroundColor Red
    }
} catch {
    Write-Host "    Could not check named pipe: $_" -ForegroundColor Red
}

# Method 2: Use vssadmin or WMI to call IsPathSupported via the built-in fssagent client
Write-Host ""
Write-Host "[2] Calling IsPathSupported via WinAPI (RPC)..." -ForegroundColor Yellow

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class Fsrvp
{
    [DllImport("fssapi.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int IsPathSupported(
        string ShareName,
        [MarshalAs(UnmanagedType.Bool)] out bool SupportedByThisProvider,
        out IntPtr OwnerMachineName);

    [DllImport("ole32.dll")]
    public static extern void CoTaskMemFree(IntPtr ptr);
}
"@ -ErrorAction SilentlyContinue

$supported = $false
$ownerPtr = [IntPtr]::Zero

try {
    $hr = [Fsrvp]::IsPathSupported($ShareUNC, [ref]$supported, [ref]$ownerPtr)

    if ($hr -eq 0) {
        $ownerName = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ownerPtr)
        [Fsrvp]::CoTaskMemFree($ownerPtr)

        if ($supported) {
            Write-Host "    SUPPORTED - Share supports FSRVP shadow copies." -ForegroundColor Green
            Write-Host "    Owner Machine: $ownerName" -ForegroundColor Green
        } else {
            Write-Host "    NOT SUPPORTED - Server responded but share is not supported." -ForegroundColor Red
        }
    } else {
        $hexHr = "0x{0:X8}" -f $hr
        switch ($hexHr) {
            "0x8004230C" { Write-Host "    NOT SUPPORTED (FSRVP_E_NOT_SUPPORTED) - File store not supported." -ForegroundColor Red }
            "0x80070005" { Write-Host "    ACCESS DENIED - Insufficient permissions (requires Backup Operators or Administrators)." -ForegroundColor Red }
            "0x80042308" { Write-Host "    OBJECT NOT FOUND - Share does not exist on the server." -ForegroundColor Red }
            default      { Write-Host "    FAILED with HRESULT: $hexHr" -ForegroundColor Red }
        }
    }
    return
} catch [System.DllNotFoundException] {
    Write-Host "    fssapi.dll not available (requires Windows 8/Server 2012+)." -ForegroundColor DarkYellow
    Write-Host "    Falling back to manual RPC check..." -ForegroundColor DarkYellow
} catch {
    Write-Host "    RPC call failed: $_" -ForegroundColor DarkYellow
    Write-Host "    Falling back to manual RPC check..." -ForegroundColor DarkYellow
}

# Method 3: Fallback - attempt RPC bind to the FSRVP endpoint via named pipe
Write-Host ""
Write-Host "[3] Attempting direct RPC endpoint bind..." -ForegroundColor Yellow

try {
    # Try to open the named pipe to verify the RPC endpoint is listening
    $pipe = New-Object System.IO.Pipes.NamedPipeClientStream(
        $ServerName, "FssagentRpc", [System.IO.Pipes.PipeDirection]::InOut,
        [System.IO.Pipes.PipeOptions]::None,
        [System.Security.Principal.TokenImpersonationLevel]::Impersonation)

    $pipe.Connect(5000)  # 5 second timeout
    Write-Host "    Successfully connected to FssagentRpc pipe on $ServerName" -ForegroundColor Green
    Write-Host "    FSRVP endpoint is ACTIVE - server likely supports remote VSS." -ForegroundColor Green
    $pipe.Close()
    $pipe.Dispose()
} catch [TimeoutException] {
    Write-Host "    Connection timed out - FSRVP service may not be running." -ForegroundColor Red
} catch {
    Write-Host "    Could not connect to FssagentRpc pipe: $_" -ForegroundColor Red
    Write-Host "    FSRVP is likely NOT available on this server." -ForegroundColor Red
}

Write-Host ""
Write-Host "--- Summary ---" -ForegroundColor Cyan
Write-Host "Protocol: File Server Remote VSS Protocol (MS-FSRVP)"
Write-Host "RPC UUID: a8e0653c-2744-4389-a61d-7373df8b2292"
Write-Host "Named Pipe: \\pipe\FssagentRpc"
Write-Host "Requirement: File Server VSS Agent Service must be running on the target server."
Write-Host "Permissions: Caller needs Backup Operators or Administrators group membership."
