# Test-FsrvpSupport.ps1

## NAME

**PowerShell script to test whether a remote file share supports the File Server Remote VSS Protocol (MS-FSRVP). This tool was created with the help of generative AI.**

## SYNOPSIS

```powershell
.\\Test-FsrvpSupport.ps1 -ShareUNC <UNCPath>
```

## DESCRIPTION

**Test-FsrvpSupport** queries a remote file server to determine if a given SMB share supports shadow copy operations via the File Server Remote VSS Protocol (MS-FSRVP). This is useful for validating that a share can be used with VSS-aware backup applications that rely on remote shadow copies.

The script performs up to three checks in sequence:

1. Verifies the `FssagentRpc` named pipe exists on the target server.
2. Calls the `IsPathSupported` RPC method (Opnum 8) via `fssapi.dll`.
3. Falls back to a direct named pipe connection test if the DLL is unavailable.

## OPTIONS

**-ShareUNC** *UNCPath*
: The full UNC path of the share to test. Must be in the format `\\\\server\\share`.

## REQUIREMENTS

* Windows 8 / Windows Server 2012 or later (for `fssapi.dll` support)
* The caller must be a member of **Backup Operators** or **Administrators** on the target server.
* The **File Server VSS Agent Service** must be running on the target server.

## EXAMPLES

Test a share on a file server:

```powershell
.\\Test-FsrvpSupport.ps1 -ShareUNC "\\\\fileserver01\\projects"
```

Test an FSx for Windows File Server share:

```powershell
.\\Test-FsrvpSupport.ps1 -ShareUNC "\\\\amznfsxabc12345.corp.example.com\\share"
```

Test with a DFS namespace path:

```powershell
.\\Test-FsrvpSupport.ps1 -ShareUNC "\\\\corp.example.com\\dfsroot\\data"
```

## OUTPUT

The script prints color-coded results for each check:

* **Green** — The check passed; FSRVP is supported.
* **Red** — The check failed; FSRVP is not available or not supported.
* **Yellow** — Informational; a fallback method is being attempted.

## ERROR CODES

|HRESULT|Name|Meaning|
|-|-|-|
|`0x8004230C`|FSRVP\_E\_NOT\_SUPPORTED|The file store containing the share does not support shadow copies.|
|`0x80070005`|E\_ACCESSDENIED|Insufficient permissions. Caller needs Backup Operators or Administrators membership.|
|`0x80042308`|FSRVP\_E\_OBJECT\_NOT\_FOUND|The specified share does not exist on the server.|

## PROTOCOL DETAILS

|Property|Value|
|-|-|
|Protocol|File Server Remote VSS Protocol (MS-FSRVP)|
|RPC UUID|`a8e0653c-2744-4389-a61d-7373df8b2292`|
|Named Pipe|`\\pipe\\FssagentRpc`|
|RPC Version|3.0|
|Transport|RPC over SMB named pipes|

## SEE ALSO

* \[MS-FSRVP]: File Server Remote VSS Protocol Specification
* `vssadmin`(1), `diskshadow`(1)

***

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.
