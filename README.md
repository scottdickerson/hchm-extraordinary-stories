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
      cd C:\Tools\PSTools
      PsExec.exe -i -s powershell.exe
      ```
      The first time, accept the Sysinternals license prompt. `-s` runs as SYSTEM, and `-i` opens the window on your desktop.
   4. In the new PowerShell window, run `whoami`. It must print `nt authority\system`. If it prints your own user name, close it and repeat step 3 from an administrator Command Prompt.
3. In that SYSTEM window, run the setup script (use the path to your clone of this repo):
   ```
   powershell -ExecutionPolicy Bypass -File C:\path\to\hchm-extraordinary-stories\scripts\setup-kiosk.ps1
   ```
   If the app isn't in `C:\Program Files\Extraordinary Stories\`, add `-AppPath "D:\...\Extraordinary Stories.exe"`.
4. Restart.

Windows creates a kiosk account, signs into it at boot, and relaunches the app if it closes. Staff exit with Ctrl+Alt+Del and sign out.

If the kiosk shows "We weren't able to start your app" (0x80004005), try the restricted user experience instead by adding `-Mode Restricted` to the setup command. Windows then signs into the kiosk account, hides the taskbar, allows only this app to run, and launches it at sign-in; the app covers the screen itself. The difference is that Windows won't relaunch the app if it quits.

To undo it, sign in with an admin account, open a SYSTEM PowerShell the same way (step 2), run `powershell -ExecutionPolicy Bypass -File C:\path\to\hchm-extraordinary-stories\scripts\remove-kiosk.ps1`, and restart.

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
2. In an admin PowerShell, find what was blocked:
   ```powershell
   Get-WinEvent -LogName "Microsoft-Windows-AppLocker/EXE and DLL" -MaxEvents 30 | Where-Object Id -in 8003,8004 | Format-List TimeCreated, Message
   ```
   Each entry names the blocked program's full path. If that log is empty, check the other AppLocker logs:
   ```powershell
   Get-WinEvent -ListLog *AppLocker* | Select LogName, RecordCount
   ```
3. Stop it from launching at sign-in rather than allowing it:
   - OneDrive: `winget uninstall Microsoft.OneDrive`, or remove it under **Settings > Apps > Installed apps**.
   - Other startup apps: **Settings > Apps > Startup**, or Task Manager's **Startup apps** tab.

The app itself never needs another program allowed: all of Electron's background processes run from the same `Extraordinary Stories.exe`.

### The setup script fails

- "Run this as SYSTEM": the window isn't running as SYSTEM. `whoami` must print `nt authority\system`; see the PsExec steps above.
- `Set-CimInstance` errors: Assigned Access needs Windows 11 **Pro**, Enterprise, or Education (not Home). Check under **Settings > System > About**.
- "App not found": copy `dist\win-unpacked\` to `C:\Program Files\Extraordinary Stories\`, or pass `-AppPath`.
- "No videos found": the `resources\videos\` folder didn't come along with the app folder.

### Smart App Control

Smart App Control blocks unsigned apps and native modules, which includes this app and parts of the build tools. Check it under **Windows Security > App & browser control > Smart App Control**. For a dedicated kiosk running this unsigned app, set it to **Off**. On many Windows 11 versions it can't be turned back on without resetting Windows; Microsoft Defender antivirus keeps running either way.
