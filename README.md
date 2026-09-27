# The Theater of Extraordinary Stories

Electron + React + TypeScript kiosk for the Harrison County Historical Museum. A pull screen shows four comic covers; tapping one reveals that story's video through a comic-burst transition mask, and the video starts once the transition finishes. When the video ends (or is tapped, or Escape is pressed) the app returns to the pull screen.

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
