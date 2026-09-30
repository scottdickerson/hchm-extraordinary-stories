# The Theater of Extraordinary Stories

Electron + React + TypeScript kiosk for the Harrison County Historical Museum. A pull screen shows four comic covers; tapping one reveals that story's video through a comic-burst transition mask, and the video starts once the transition finishes. When the video ends the app returns to the pull screen on its own. Visitors' touches can't skip out of a story; staff can mouse-click the video or press Escape.

```bash
npm install
npm run dev        # hot reload
npm run build      # bundle to out/
npm start          # run the built app
npm run typecheck
npm run dist:win   # Windows app folder in dist/win-unpacked/ + a zip of it (run on Windows)
npm run dist:mac   # macOS .dmg in dist/
```

## Layout

- `src/main/index.ts` — Electron main process (kiosk window)
- `src/renderer/src/App.tsx` — pull screen + story video
- `src/renderer/src/stories.ts` — the four stories, cover images, and cover positions
- `src/renderer/src/styles.css` — stage, covers, burst transition

## Videos

The story videos live in `videos/` at the project root and are stored with Git LFS (~800 MB each). After cloning, run `git lfs pull` if the files are small pointer stubs.

- `john-burke.mp4`
- `mack-hopkins.mp4`
- `ma-sanders.mp4`
- `perry-bonner.mp4`

They are not bundled by Vite. The main process serves them to the page as `media://videos/<id>.mp4`: from `videos/` in development, and from the installed app's `resources/videos/` in a packaged build (electron-builder `extraResources`, kept out of `app.asar`).

The app always opens fullscreen in kiosk mode; quit with Cmd+Q (macOS) or Alt+F4 (Windows).

If a video is missing, the app logs an error and stays on the pull screen.

## Windows kiosk setup

Windows' Settings > Set up a kiosk only lists Store apps and Edge, so the kiosk is configured with a script instead.

1. `npm run dist:win`, then copy `dist\win-unpacked\` to `C:\Program Files\Extraordinary Stories\`.
2. Open a PowerShell window running as SYSTEM. The kiosk configuration can only be written by Windows' built-in SYSTEM account, not by an Administrator, so use PsExec:
   1. Download [PsTools](https://learn.microsoft.com/sysinternals/downloads/psexec) and unzip it, for example to `C:\Tools\PSTools`.
   2. Open **Command Prompt** with **Run as administrator**.
   3. Run:
      ```
      cd C:\GitHub\hchm-extraordinary-stories\PSTools
      PsExec.exe -i -s powershell.exe
      ```
      The first time, accept the Sysinternals license prompt. `-s` runs as SYSTEM, and `-i` opens the window on your desktop.
   4. In the new PowerShell window, run `whoami`. It must print `nt authority\system`. If it prints your own user name, close it and repeat step 3 from an administrator Command Prompt.
3. In that SYSTEM window, run the setup script (use the path to your clone of this repo):
   ```
   powershell -ExecutionPolicy Bypass -File C:\GitHub\hchm-extraordinary-stories\scripts\setup-kiosk.ps1
   ```
   If the app isn't in `C:\Program Files\Extraordinary Stories\`, add `-AppPath "D:\...\Extraordinary Stories.exe"`. To restart for updates at a different hour than 3 AM, add `-UpdateHour 5` (0–23). To turn automatic updates off instead, add `-NoUpdates` (see [Windows Update](#windows-update-nightly-off-or-offline)).
4. Restart. The kiosk account signs in for the first time, which creates it.
5. Turn off the kiosk account's own popups. Press Ctrl+Alt+Del, sign out, sign in with an admin account, and in an **administrator** PowerShell (SYSTEM isn't needed) run:
   ```
   powershell -ExecutionPolicy Bypass -File C:\GitHub\hchm-extraordinary-stories\scripts\kiosk-user-settings.ps1
   ```
   If the kiosk account's folder isn't `C:\Users\kioskUser0` (check with `dir C:\Users`), add `-ProfilePath C:\Users\<folder>`.
6. Restart.

Windows creates a kiosk account, signs into it at boot, and relaunches the app if it closes. Staff exit with Ctrl+Alt+Del and sign out.

`setup-kiosk.ps1` also sets these for every account on the PC, including admin accounts. The remove script clears them, except the power settings.

- **Touch gestures can't open Windows:** no swipe-in from any screen edge (`AllowEdgeSwipe` = 0), and no Widgets board (`AllowNewsAndInterests` = 0).
- **No Xbox Game Bar:** game recording is off (`AllowGameDVR` = 0) and the Game Bar app (`Microsoft.XboxGamingOverlay`) is uninstalled for every account. Game Bar treats the fullscreen kiosk app as a game, and its background task causes "blocked" popups in restricted mode. The remove script doesn't reinstall it; get it from the Microsoft Store if you ever need it.
- **No Store apps running in the background** (`LetAppsRunInBackground` = 2, Force Deny), and in restricted mode Windows' background-task host (`backgroundTaskHost.exe`) is allowed. Both are there to stop "blocked" popups from Store apps' background tasks.

Search stays available to admin accounts. Earlier versions of the script turned Search off for every account (`DisableSearch`); running the current script clears that.
- **Windows Update without popups:** no update notifications or restart warnings. By default updates install automatically and the PC restarts every day at 3 AM (`-UpdateHour`); the kiosk signs back in on its own. With `-NoUpdates`, automatic updates are off instead.
- **No Windows Security popups** (Defender keeps protecting the PC) and **no "has stopped working" crash dialogs**.
- **Power:** never sleep, never turn off the display, hibernate off.

`kiosk-user-settings.ps1` handles popups that belong to the kiosk account itself, in that account and in the Default profile (the template for new accounts): app notifications (including the Windows Backup reminder), the notification panel, "Let's finish setting up your device", the welcome screen after updates, tips and suggestions, the search box, and OneDrive starting at sign-in.

### Before leaving it unattended

These can't be scripted:

- **Power back on after an outage:** turn on *Restore on AC power loss* (or similar) in the BIOS.
- **BitLocker / device encryption:** if it's on, a BIOS or firmware change can stop the PC at a recovery-key screen at boot. Save the key from account.microsoft.com/devices/recoverykey, or turn it off under **Settings > Privacy & security > Device encryption**.
- **Vendor startup apps** (graphics or audio control panels) trigger the "blocked by your system administrator" popup in restricted mode. Find them with the AppLocker command under Troubleshooting and remove them from **Settings > Apps > Startup** or uninstall them.
- **Volume:** set it once while signed in as the kiosk account.
- **Remote maintenance (optional):** set up a remote tool such as Quick Assist if the PC is hard to reach.
- **Test:** restart twice, then leave it running overnight. With the default update schedule, check it after the first 3 AM update restart.

### Windows Update: nightly, off, or offline

Pick one:

- **Nightly (default).** Updates install automatically and the PC restarts at 3 AM (`-UpdateHour` to change the hour). Keeps the PC patched with no one involved; the screen is dark for a few minutes each night.
- **Off (`-NoUpdates`).** Rerun the setup script with `-NoUpdates`:
  ```
  powershell -ExecutionPolicy Bypass -File C:\GitHub\hchm-extraordinary-stories\scripts\setup-kiosk.ps1 -Mode Restricted -NoUpdates
  ```
  This sets `NoAutoUpdate` = 1, the supported "Configure Automatic Updates: Disabled" policy. Windows stops downloading and installing updates on its own, so the PC no longer gets security fixes unless someone signs in to the admin account and runs **Settings > Windows Update** by hand; plan to do that every month or two if the kiosk is online. Don't disable the Windows Update *service* instead: Windows' repair service turns it back on. Rerunning the script without `-NoUpdates` switches back to the nightly schedule.
- **Offline.** The app never needs the internet (the videos are on the PC), so the most reliable option is to disconnect the kiosk from the network: unplug the network cable, or forget the Wi-Fi network in the admin account. No updates, no update restarts, and Microsoft Store can't reinstall apps such as Game Bar or OneDrive. Reconnect when you want to update it by hand. This works with either setting above.

If you use `-NoUpdates` or offline, the care guide's note about the screen going dark around 3 AM no longer applies.

If the kiosk shows "We weren't able to start your app" (0x80004005), try the restricted user experience instead by adding `-Mode Restricted` to the setup command. Windows then signs into the kiosk account, hides the taskbar, allows only this app to run, and launches it at sign-in; the app covers the screen itself. The difference is that Windows won't relaunch the app if it quits.

To undo it, sign in with an admin account, open a SYSTEM PowerShell the same way (step 2), run `powershell -ExecutionPolicy Bypass -File C:\GitHub\hchm-extraordinary-stories\scripts\remove-kiosk.ps1`, and restart.

## Troubleshooting on Windows

### `npm run dev` fails: `node_modules\electron\dist` is missing

The `electron` package downloads the real Electron app in an install script. If that step was skipped or failed, check:

- Node is 64-bit: `node -p "process.arch"` should print `x64`.
- npm isn't skipping scripts: `npm config get ignore-scripts` should print `false`.
- Nothing is skipping the download: `echo $env:ELECTRON_SKIP_BINARY_DOWNLOAD` should print nothing.

If `node node_modules\electron\install.js` fails with "Cannot find native binding for @electron-internal/extract-zip", Windows (usually Smart App Control) is blocking Electron's unzip helper. Install Electron by hand instead, from the repo folder:

```powershell
Invoke-WebRequest "https://github.com/electron/electron/releases/download/v44.4.5/electron-v44.4.5-win32-x64.zip" -OutFile electron.zip
Expand-Archive electron.zip -DestinationPath node_modules\electron\dist -Force
Set-Content node_modules\electron\path.txt "electron.exe" -NoNewline
Remove-Item electron.zip
```

The version must match `node_modules\electron\package.json`.

### `npm run dist:win` fails with `ERR_ELECTRON_BUILDER_CANNOT_EXECUTE`

The lines after the error name the helper program that failed.

- "Cannot create symbolic link": turn on **Settings > System > For developers > Developer Mode**, or build from an administrator terminal.
- A helper was blocked (Windows shows a Smart App Control notice): turn Smart App Control off (below).

### The kiosk shows "We weren't able to start your app" (0x80004005)

Press Ctrl+Alt+Del, sign out, and sign in with an admin account.

1. **Run the app outside the kiosk.** Double-click `C:\Program Files\Extraordinary Stories\Extraordinary Stories.exe`.
   - A SmartScreen or Smart App Control warning means Windows is blocking the unsigned app; in kiosk mode that warning can't be shown, so the launch fails. If the files came from a download or zip, clear the "downloaded from the internet" mark in an admin PowerShell:
     ```powershell
     Get-ChildItem "C:\Program Files\Extraordinary Stories" -Recurse | Unblock-File
     ```
     and turn Smart App Control off (below).
   - If it closes right away or shows an error, the app itself is failing, not the kiosk setup.
2. **Ask Windows why.** In an admin PowerShell, list the kiosk and code-blocking logs:
   ```powershell
   Get-WinEvent -ListLog *AssignedAccess*, *CodeIntegrity* | Select LogName, RecordCount
   ```
   Then read each one, for example:
   ```powershell
   Get-WinEvent -LogName "Microsoft-Windows-CodeIntegrity/Operational" -MaxEvents 15 | Format-List TimeCreated, Id, Message
   ```
   CodeIntegrity events that mention `Extraordinary Stories.exe` mean Windows blocked the unsigned app. AssignedAccess errors usually name the reason.
3. **Try the restricted user experience:** rerun `setup-kiosk.ps1 -Mode Restricted` from a SYSTEM PowerShell and restart.

### Restricted mode: "This app has been blocked by your system administrator"

In restricted mode only Extraordinary Stories may run, so this popup means something *else* tried to start when the kiosk account signed in and Windows blocked it. Usual suspects on a fresh account: OneDrive setup (runs on every new account's first sign-in), a startup app installed for all users (hardware utilities, Teams, updaters), or Microsoft Edge's background launch.

1. Sign out of the kiosk account (Ctrl+Alt+Del) and sign in with an admin account.
2. Find out what was blocked. Windows logs every block with the program's full path.

   **PowerShell** (admin). This checks all three AppLocker logs: desktop programs (event 8004), installers and scripts (8007), and Store apps (8022):
   ```powershell
   Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-AppLocker/EXE and DLL', 'Microsoft-Windows-AppLocker/MSI and Script', 'Microsoft-Windows-AppLocker/Packaged app-Execution'; Id = 8004, 8007, 8022 } -MaxEvents 20 -ErrorAction SilentlyContinue | Format-List TimeCreated, Id, Message
   ```
   Or **Event Viewer**: press Win+R, run `eventvwr.msc`, then open **Applications and Services Logs > Microsoft > Windows > AppLocker** and check **EXE and DLL**, **MSI and Script**, and **Packaged app-Execution** for Error entries.

   Reading the result:
   - Each entry's message reads like `%OSDRIVE%\USERS\KIOSKUSER0\APPDATA\LOCAL\MICROSOFT\ONEDRIVE\ONEDRIVE.EXE was prevented from running.` The path is the program to deal with.
   - Match `TimeCreated` to when the kiosk last signed in (the most recent restart), since older entries may be from earlier attempts.
   - No output means nothing was logged as blocked in those logs. Restart into the kiosk once more so the popup appears, then sign out and run the command again.
3. Stop it from launching at sign-in rather than allowing it:
   - OneDrive: see below.
   - Other startup apps: **Settings > Apps > Startup**, or Task Manager's **Startup apps** tab.

#### Stopping OneDrive in the kiosk account

`kiosk-user-settings.ps1` does this automatically (setup step 5). The manual steps below do the same thing.

OneDrive is installed separately in each account ("user scope"), so `winget uninstall Microsoft.OneDrive` fails from an administrator terminal ("Package installed for user scope cannot be uninstalled when running with administrator privileges"). Uninstalling it from your own account wouldn't help anyway: the kiosk account gets its own copy at first sign-in. Remove its startup entry instead, from your admin account with the kiosk account **signed out** (its registry file is locked while it's signed in):

1. Find the kiosk account's folder (Assigned Access usually names it `kioskUser0`):
   ```powershell
   dir C:\Users
   ```
2. Load its registry and list its startup entries (admin PowerShell):
   ```powershell
   reg load HKU\KioskUser "C:\Users\kioskUser0\NTUSER.DAT"
   reg query HKU\KioskUser\Software\Microsoft\Windows\CurrentVersion\Run
   ```
3. Delete the OneDrive entry, using the exact name from the query output (usually `OneDrive` or `OneDriveSetup`):
   ```powershell
   reg delete HKU\KioskUser\Software\Microsoft\Windows\CurrentVersion\Run /v OneDrive /f
   ```
4. Unload the registry. Don't skip this: a hive left loaded can break the kiosk account's sign-in.
   ```powershell
   reg unload HKU\KioskUser
   ```
5. Repeat steps 2–4 for `C:\Users\Default\NTUSER.DAT`, the template for new accounts, so a recreated kiosk account doesn't get OneDrive back.
6. Optional: turn OneDrive off machine-wide.
   ```powershell
   reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v DisableFileSyncNGSC /t REG_DWORD /d 1 /f
   ```

Restart; the kiosk should sign in without the popup.

#### `WidgetBoard.exe` or `backgroundTaskHost.exe` is blocked

Both are part of Windows, not the app. Rerun `setup-kiosk.ps1 -Mode Restricted` from a SYSTEM PowerShell and restart; it handles both:

- **`WidgetBoard.exe`** is the Widgets board. The script tries to turn Widgets off for every account, but on some PCs Windows refuses that write ("Couldn't set AllowNewsAndInterests in ...\Dsh"). If so, use the Group Policy Editor instead, which has permission to set it:
  1. Press Win+R, run `gpedit.msc` (included in Windows 11 Pro).
  2. Go to **Computer Configuration > Administrative Templates > Windows Components > Widgets**.
  3. Open **Allow widgets**, set it to **Disabled**, and click OK.
  4. Open **Disable Widgets Board**, set it to **Enabled**, and click OK.
  5. Restart.

  To undo, set both back to **Not Configured**. (**Allow widgets = Disabled** is the same setting the script tries to write, `AllowNewsAndInterests` = 0 under `HKLM\SOFTWARE\Policies\Microsoft\Dsh`.)
- **`backgroundTaskHost.exe`** runs background tasks for Store apps and Windows features. The script adds it to the kiosk's allowed apps and stops Store apps from running in the background. If it's still blocked, see the next section.

#### `backgroundTaskHost.exe` is still blocked

**Seen on this kiosk:** the Store app behind it was **Xbox Game Bar** (`Microsoft.XboxGamingOverlay`). Current versions of `setup-kiosk.ps1` remove it and turn off game recording; rerun the script and restart. If the script warns that it couldn't, do it by hand in an admin PowerShell, then restart:

```powershell
Get-AppxPackage -AllUsers Microsoft.XboxGamingOverlay | Remove-AppxPackage -AllUsers
Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq 'Microsoft.XboxGamingOverlay' | Remove-AppxProvisionedPackage -Online
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f
```

If Windows refuses the `reg add`, use `gpedit.msc`: **Computer Configuration > Administrative Templates > Windows Components > Windows Game Recording and Broadcasting > Enables or disables Windows Game Recording and Broadcasting > Disabled**. If another Xbox app appears in the logs next (for example `Microsoft.GamingApp` or `Microsoft.XboxIdentityProvider`), remove it the same way and add its name to `$removeApps` in `setup-kiosk.ps1`.

The popup names `backgroundTaskHost.exe`, but the block is usually on the Store app it's running a task for, so allowing `backgroundTaskHost.exe` alone doesn't stop it.

If there's no popup on screen any more, you can ignore new log entries: Windows keeps retrying some background tasks and they're blocked silently. Only a popup needs fixing.

To see everything at once, run this in an admin PowerShell. It lists recent blocks from both the desktop-program log (event 8004) and the Store-app log (event 8022), with the account each one was for (`UserId`) and, for Store apps, the package name:

```powershell
Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-AppLocker/EXE and DLL', 'Microsoft-Windows-AppLocker/Packaged app-Execution'; Id = 8004, 8022 } -MaxEvents 10 -ErrorAction SilentlyContinue | Format-List TimeCreated, LogName, Id, UserId, Message
```

Read it as:

- **A Store-app entry (8022) at the same time as a `backgroundTaskHost.exe` entry**: that package is behind the popup. Uninstall it (step 4).
- **Only `backgroundTaskHost.exe` entries, no matching Store app**: a part of Windows itself (the Start menu or notifications, for example) is running a background task. These can't be uninstalled.
- **A `UserId` that isn't the kiosk account**: the block happened in another account, such as the admin account. Some restricted-mode policies also apply to admins.

**No new entries, but the popup still appears?** The block is being logged somewhere else: another AppLocker log (scripts and installers, or Store apps being *installed or updated*, which Windows often does at a new account's first sign-in), or Code Integrity (Smart App Control / Windows Defender Application Control). This checks all of them and lists the newest entries first:

```powershell
Get-WinEvent -ListLog *AppLocker*, *CodeIntegrity* | Where-Object RecordCount | ForEach-Object { Get-WinEvent -LogName $_.LogName -MaxEvents 5 } | Sort-Object TimeCreated -Descending | Select-Object -First 15 | Format-List TimeCreated, LogName, Id, Message
```

To catch the right moment: restart and let the kiosk sign in until the popup appears, note the time and the popup's exact wording, then press Ctrl+Alt+Del, sign out, sign in as admin, run the command, and look for entries from that time.

The popup's wording tells you which part of Windows is blocking:

- "This app has been blocked by your system administrator": AppLocker (restricted mode).
- "Your organization used Device Guard to block this app", or a Smart App Control notice: Code Integrity.
- "This app has been blocked for your protection": User Account Control, usually an untrusted or revoked signature on the program.
- "This operation has been cancelled due to restrictions in effect on this computer": a Windows Explorer restriction, which doesn't write an AppLocker entry.

Or work through the checks one at a time, in an admin PowerShell:

1. **Check that the entries are new.** Compare `TimeCreated` with your last restart after running the script; older entries are from before the fix.
   ```powershell
   Get-WinEvent -LogName "Microsoft-Windows-AppLocker/EXE and DLL" -MaxEvents 20 -ErrorAction SilentlyContinue | Where-Object Message -like '*BACKGROUNDTASKHOST*' | Format-List TimeCreated, Message
   ```
   The path should be `System32`. If it's `SysWOW64`, that's the 32-bit copy, which the script doesn't allow.
2. **Find the Store app behind it.** Look for entries at the same times as step 1; the message names the package (for example `Microsoft.YourPhone`):
   ```powershell
   Get-WinEvent -LogName "Microsoft-Windows-AppLocker/Packaged app-Execution" -MaxEvents 20 -ErrorAction SilentlyContinue | Format-List TimeCreated, Id, Message
   ```
3. **Stop all Store apps from running in the background.** The script tries to set this; if its output warned that it couldn't, use the Group Policy Editor:
   1. Press Win+R, run `gpedit.msc`.
   2. Go to **Computer Configuration > Administrative Templates > Windows Components > App Privacy**.
   3. Open **Let Windows apps run in the background**, set it to **Enabled**, and under **Default for all apps** choose **Force Deny**.
   4. Restart.

   This applies to every account, including admins; on a dedicated kiosk that's harmless. It's the same setting as `LetAppsRunInBackground` = 2 under `HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy`. To undo, set it back to **Not Configured**.
4. **Uninstall the app from step 2** if the popup continues. Replace `Microsoft.YourPhone` with the package name from the log:
   ```powershell
   Get-AppxPackage -AllUsers Microsoft.YourPhone | Remove-AppxPackage -AllUsers
   Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq 'Microsoft.YourPhone' | Remove-AppxProvisionedPackage -Online
   ```
   The second line stops Windows reinstalling it for new accounts. Some packages are part of Windows and can't be removed; if the command refuses, note the package name for the technical contact.

The app itself never needs another program allowed: all of Electron's background processes run from the same `Extraordinary Stories.exe`.

### Swiping from an edge opens the taskbar, Start, or Search

`setup-kiosk.ps1` turns off edge swipes for every account; restart after running it. To set it by hand (admin PowerShell, then restart):

```powershell
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" /v AllowEdgeSwipe /t REG_DWORD /d 0 /f
```

Undo with `reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" /v AllowEdgeSwipe /f`.

Search is only turned off for the kiosk account: with edge swipes off, the taskbar hidden, and no keyboard out, there's no way to reach it, and `kiosk-user-settings.ps1` also hides the search box there. Windows' own `DisableSearch` policy can't be limited to one account, so it isn't used. If an earlier version of the script set it and admin accounts have no Search, remove it:

```powershell
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v DisableSearch /f
```

If a gesture still gets through, check these in the kiosk account (restricted mode may hide Settings there, so set them before setting up the kiosk):

- **Settings > Bluetooth & devices > Touch > Three- and four-finger touch gestures**: off.
- **Settings > Personalization > Taskbar > Taskbar behaviors**: turn off any swipe-to-open-Start or swipe-to-show-taskbar option (the name varies between Windows 11 versions).

### The setup script fails

- A warning that a setting couldn't be set, or "Attempted to perform an unauthorized operation": Windows refused that one registry setting, and the script carried on with the rest. The usual case is the Windows Security notifications setting, which **Tamper Protection** blocks even for SYSTEM. To apply it, turn off **Windows Security > Virus & threat protection > Manage settings > Tamper Protection**, rerun the script, then turn Tamper Protection back on. Or leave it: the only effect is that Windows Security notifications can still appear.

- "Run this as SYSTEM": the window isn't running as SYSTEM. `whoami` must print `nt authority\system`; see the PsExec steps above.
- `Set-CimInstance` errors: Assigned Access needs Windows 11 **Pro**, Enterprise, or Education (not Home). Check under **Settings > System > About**.
- "App not found": copy `dist\win-unpacked\` to `C:\Program Files\Extraordinary Stories\`, or pass `-AppPath`.
- "No videos found": the `resources\videos\` folder didn't come along with the app folder.

### Smart App Control

Smart App Control blocks unsigned apps and native modules, which includes this app and parts of the build tools. Check it under **Windows Security > App & browser control > Smart App Control**. For a dedicated kiosk running this unsigned app, set it to **Off**. On many Windows 11 versions it can't be turned back on without resetting Windows; Microsoft Defender antivirus keeps running either way.
