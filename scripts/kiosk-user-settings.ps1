<#
Turns off per-account popups for the kiosk account: app notifications (including the
Windows Backup reminder), the notification panel, "Let's finish setting up your device",
the welcome screen after updates, tips and suggestions, and OneDrive starting at sign-in.

These are per-account settings, so they're written into the kiosk account's registry file
and into the Default profile (the template for new accounts, in case the kiosk account is
ever recreated).

Run from an admin PowerShell (SYSTEM also works) with the kiosk account SIGNED OUT, since its
registry file is locked while it's signed in:
  powershell -ExecutionPolicy Bypass -File <repo>\scripts\kiosk-user-settings.ps1
The kiosk account exists after it has signed in once (after setup-kiosk.ps1 and a restart).
Pass -ProfilePath if its folder isn't C:\Users\kioskUser0 (check with: dir C:\Users).
#>
param(
  [string]$ProfilePath = 'C:\Users\kioskUser0'
)
$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw 'Run this from an administrator PowerShell.' }

# Relative to the account's HKEY_CURRENT_USER.
$settings = @(
  @{ Key = 'Software\Policies\Microsoft\Windows\CurrentVersion\PushNotifications'; Name = 'NoToastApplicationNotification'; Value = 1 }
  @{ Key = 'Software\Policies\Microsoft\Windows\Explorer'; Name = 'DisableNotificationCenter'; Value = 1 }
  @{ Key = 'Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement'; Name = 'ScoobeSystemSettingEnabled'; Value = 0 }
  @{ Key = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-310093Enabled'; Value = 0 }
  @{ Key = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338389Enabled'; Value = 0 }
)

function Set-AccountSettings([string]$HiveFile, [string]$Label) {
  if (-not (Test-Path $HiveFile)) {
    Write-Warning "$Label`: $HiveFile not found, skipped."
    return
  }
  $mount = 'HKU\KioskSettingsTemp'
  reg.exe load $mount $HiveFile | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "$Label`: couldn't load $HiveFile. Make sure the account is signed out (Ctrl+Alt+Del > Sign out), then run again."
  }
  try {
    foreach ($s in $settings) {
      reg.exe add "$mount\$($s.Key)" /v $s.Name /t REG_DWORD /d $s.Value /f | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "$Label`: couldn't set $($s.Name)." }
    }

    # Remove OneDrive from the account's startup entries (the name varies: OneDrive, OneDriveSetup).
    $run = "Registry::HKEY_USERS\KioskSettingsTemp\Software\Microsoft\Windows\CurrentVersion\Run"
    if (Test-Path $run) {
      $item = Get-Item $run
      foreach ($name in ($item.GetValueNames() | Where-Object { $_ -like '*OneDrive*' })) {
        Remove-ItemProperty -Path $run -Name $name
        Write-Host "$Label`: removed startup entry '$name'."
      }
      $item.Close()
    }
    Write-Host "$Label`: popup settings applied."
  } finally {
    # Release PowerShell's handles on the hive, or reg unload fails with "Access is denied".
    [gc]::Collect()
    [gc]::WaitForPendingFinalizers()
    reg.exe unload $mount | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Write-Warning "$Label`: couldn't unload $mount. Restart the PC before signing into that account."
    }
  }
}

Set-AccountSettings (Join-Path $ProfilePath 'NTUSER.DAT') 'Kiosk account'
Set-AccountSettings 'C:\Users\Default\NTUSER.DAT' 'Default profile'
Write-Host 'Done. Restart to apply.'
