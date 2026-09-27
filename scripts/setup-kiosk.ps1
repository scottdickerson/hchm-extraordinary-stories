<#
Configures Windows Assigned Access to run Extraordinary Stories as a single-app kiosk.
Windows creates its own kiosk account and signs into it automatically at boot.

Must run as SYSTEM (not just Administrator). From an admin Command Prompt:
  PsExec.exe -i -s powershell.exe
then in that window:
  powershell -ExecutionPolicy Bypass -File <repo>\scripts\setup-kiosk.ps1
Restart afterwards. Staff exit: Ctrl+Alt+Del, sign out.

To remove kiosk mode, run the same way with -Remove, then restart.
#>
param(
  [string]$AppPath = 'C:\Program Files\Extraordinary Stories\Extraordinary Stories.exe',
  [switch]$Remove
)
$ErrorActionPreference = 'Stop'

if ([Security.Principal.WindowsIdentity]::GetCurrent().Name -ne 'NT AUTHORITY\SYSTEM') {
  throw 'Run this as SYSTEM: open an admin Command Prompt, run "PsExec.exe -i -s powershell.exe", and run the script from that window.'
}

$obj = Get-CimInstance -Namespace 'root\cimv2\mdm\dmmap' -ClassName 'MDM_AssignedAccess'

if ($Remove) {
  $obj.Configuration = $null
  Set-CimInstance -CimInstance $obj
  Write-Host 'Kiosk mode removed. Restart to apply.'
  return
}

if (-not (Test-Path $AppPath)) {
  throw "App not found at $AppPath. Copy dist\win-unpacked to C:\Program Files\Extraordinary Stories, or pass -AppPath."
}
$videos = Join-Path (Split-Path $AppPath) 'resources\videos'
if (-not (Test-Path (Join-Path $videos '*.mp4'))) {
  Write-Warning "No videos found in $videos. The app will stay on the pull screen when a cover is tapped."
}

$escapedPath = [System.Security.SecurityElement]::Escape($AppPath)
$config = @"
<?xml version="1.0" encoding="utf-8"?>
<AssignedAccessConfiguration xmlns="http://schemas.microsoft.com/AssignedAccess/2017/config" xmlns:rs5="http://schemas.microsoft.com/AssignedAccess/201810/config" xmlns:v4="http://schemas.microsoft.com/AssignedAccess/2021/config">
  <Profiles>
    <Profile Id="{6A1D3F52-8E0B-4C77-9F7E-2B5D1E4A9C31}">
      <KioskModeApp v4:ClassicAppPath="$escapedPath" />
    </Profile>
  </Profiles>
  <Configs>
    <Config>
      <AutoLogonAccount rs5:DisplayName="Extraordinary Stories" />
      <DefaultProfile Id="{6A1D3F52-8E0B-4C77-9F7E-2B5D1E4A9C31}" />
    </Config>
  </Configs>
</AssignedAccessConfiguration>
"@

$obj.Configuration = [System.Net.WebUtility]::HtmlEncode($config)
Set-CimInstance -CimInstance $obj
Write-Host "Kiosk configured to run $AppPath. Restart to apply."
