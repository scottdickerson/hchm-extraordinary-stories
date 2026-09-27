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
