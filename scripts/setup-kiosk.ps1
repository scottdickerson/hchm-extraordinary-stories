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

Both modes also set machine-wide policies (every account, including admins):
  - Touch lockdown: no swipe-in from any screen edge (AllowEdgeSwipe=0), no Search UI (DisableSearch=1).
  - Windows Update: no update notifications or restart warnings; updates install and the PC
    restarts daily at -UpdateHour (default 3 = 3 AM). The kiosk signs back in on its own.
  - No Windows Security notifications (Defender keeps running) and no crash dialogs.
  - Power: never sleep, never turn off the display, hibernate off.
-Remove clears the policies (power settings are left as they are).

Per-account popups (notifications, backup reminder, "finish setting up", OneDrive) are handled
by kiosk-user-settings.ps1, which runs while the kiosk account is signed out.

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
  [ValidateRange(0, 23)]
  [int]$UpdateHour = 3,
  [switch]$Remove
)
$ErrorActionPreference = 'Stop'

if ([Security.Principal.WindowsIdentity]::GetCurrent().Name -ne 'NT AUTHORITY\SYSTEM') {
  throw 'Run this as SYSTEM: open an admin Command Prompt, run "PsExec.exe -i -s powershell.exe", and run the script from that window.'
}

$obj = Get-CimInstance -Namespace 'root\cimv2\mdm\dmmap' -ClassName 'MDM_AssignedAccess'

$wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$policies = @(
  # Touch gestures can't open the Windows shell.
  @{ Key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI'; Name = 'AllowEdgeSwipe'; Value = 0 }
  @{ Key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'DisableSearch'; Value = 1 }
  # Windows Update: no notifications (2 = none, including restart warnings) ...
  @{ Key = $wu; Name = 'SetUpdateNotificationLevel'; Value = 1 }
  @{ Key = $wu; Name = 'UpdateNotificationLevel'; Value = 2 }
  # ... and auto-install with a daily (0 = every day) restart at $UpdateHour.
  @{ Key = "$wu\AU"; Name = 'AUOptions'; Value = 4 }
  @{ Key = "$wu\AU"; Name = 'ScheduledInstallDay'; Value = 0 }
  @{ Key = "$wu\AU"; Name = 'ScheduledInstallTime'; Value = $UpdateHour }
  # No Windows Security popups (protection stays on) and no "has stopped working" dialogs.
  @{ Key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications'; Name = 'DisableNotifications'; Value = 1 }
  @{ Key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'; Name = 'DontShowUI'; Value = 1 }
)

if ($Remove) {
  $obj.Configuration = $null
  Set-CimInstance -CimInstance $obj
  foreach ($p in $policies) {
    Remove-ItemProperty -Path $p.Key -Name $p.Name -ErrorAction SilentlyContinue
  }
  Write-Host 'Kiosk mode and kiosk policies removed. Restart to apply.'
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

# Never sleep or blank the screen on AC power; the app also holds the display awake while running.
powercfg /change standby-timeout-ac 0
powercfg /change monitor-timeout-ac 0
powercfg /hibernate off

Write-Host "$Mode mode configured to run $AppPath. Kiosk policies set; updates restart the PC daily at ${UpdateHour}:00. Restart to apply."
