<#
Removes the Extraordinary Stories kiosk configuration (Assigned Access).
Run as SYSTEM, the same way as setup-kiosk.ps1:
  PsExec.exe -i -s powershell.exe
  powershell -ExecutionPolicy Bypass -File <repo>\scripts\remove-kiosk.ps1
Restart afterwards; the PC then boots to the normal sign-in screen.
#>
& (Join-Path $PSScriptRoot 'setup-kiosk.ps1') -Remove
