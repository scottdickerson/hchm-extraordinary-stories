<#
Configures Windows Assigned Access for Extraordinary Stories.
Windows creates its own kiosk account and signs into it automatically at boot.

-Mode Kiosk (default)  Single-app kiosk: Windows runs only the app, fullscreen, and relaunches
                       it if it closes.
-Mode Restricted       Restricted user experience: Windows auto-launches the app on a locked-down
                       desktop (taskbar hidden, empty Start, only this app allowed to run). The
                       app covers the screen itself. Use this if Kiosk mode reports
                       "We weren't able to start your app". Windows does not relaunch the app
                       if it quits.

Both modes also set two machine-wide policies (every account, including admins) so touch
gestures can't open the Windows shell: AllowEdgeSwipe=0 (no swipe-in from any screen edge)
and DisableSearch=1 (no Search UI). -Remove clears them.

Must run as SYSTEM (not just Administrator). From an admin Command Prompt:
  PsExec.exe -i -s powershell.exe
then in that window:
  powershell -ExecutionPolicy Bypass -File <repo>\scripts\setup-kiosk.ps1 [-Mode Restricted]
Restart afterwards. Staff exit: Ctrl+Alt+Del, sign out.

To remove it, run the same way with -Remove (or run remove-kiosk.ps1), then restart.
#>
param(
  [string]$AppPath = 'C:\Program Files\Extraordinary Stories\Extraordinary Stories.exe',
  [ValidateSet('Kiosk', 'Restricted')]
  [string]$Mode = 'Kiosk',
  [switch]$Remove
)
$ErrorActionPreference = 'Stop'

if ([Security.Principal.WindowsIdentity]::GetCurrent().Name -ne 'NT AUTHORITY\SYSTEM') {
  throw 'Run this as SYSTEM: open an admin Command Prompt, run "PsExec.exe -i -s powershell.exe", and run the script from that window.'
}

$obj = Get-CimInstance -Namespace 'root\cimv2\mdm\dmmap' -ClassName 'MDM_AssignedAccess'

# Touch lockdown policies, so gestures can't open the Windows shell.
$policies = @(
  @{ Key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI'; Name = 'AllowEdgeSwipe'; Value = 0 }
  @{ Key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'DisableSearch'; Value = 1 }
)

if ($Remove) {
  $obj.Configuration = $null
  Set-CimInstance -CimInstance $obj
  foreach ($p in $policies) {
    Remove-ItemProperty -Path $p.Key -Name $p.Name -ErrorAction SilentlyContinue
  }
  Write-Host 'Kiosk mode and touch lockdown policies removed. Restart to apply.'
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

if ($Mode -eq 'Kiosk') {
  $profileXml = @"
      <KioskModeApp v4:ClassicAppPath="$escapedPath" />
"@
} else {
  # Element order follows Microsoft's Windows 11 sample: AllAppsList, StartPins, Taskbar.
  $profileXml = @"
      <AllAppsList>
        <AllowedApps>
          <App DesktopAppPath="$escapedPath" rs5:AutoLaunch="true" />
        </AllowedApps>
      </AllAppsList>
      <v5:StartPins><![CDATA[{ "pinnedList": [] }]]></v5:StartPins>
      <Taskbar ShowTaskbar="false" />
"@
}

$config = @"
<?xml version="1.0" encoding="utf-8"?>
<AssignedAccessConfiguration xmlns="http://schemas.microsoft.com/AssignedAccess/2017/config" xmlns:rs5="http://schemas.microsoft.com/AssignedAccess/201810/config" xmlns:v4="http://schemas.microsoft.com/AssignedAccess/2021/config" xmlns:v5="http://schemas.microsoft.com/AssignedAccess/2022/config">
  <Profiles>
    <Profile Id="{6A1D3F52-8E0B-4C77-9F7E-2B5D1E4A9C31}">
$profileXml
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

foreach ($p in $policies) {
  # Only create a missing key: New-Item -Force on an existing key wipes its other values.
  if (-not (Test-Path $p.Key)) { New-Item -Path $p.Key -Force | Out-Null }
  New-ItemProperty -Path $p.Key -Name $p.Name -Value $p.Value -PropertyType DWord -Force | Out-Null
}

Write-Host "$Mode mode configured to run $AppPath, with edge swipes and Search disabled. Restart to apply."
