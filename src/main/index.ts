import { app, BrowserWindow, net, powerSaveBlocker, protocol } from 'electron'
import { basename, join } from 'path'
import { pathToFileURL } from 'url'

// Kiosk: story videos play with sound without a gesture on the <video> itself.
app.commandLine.appendSwitch('autoplay-policy', 'no-user-gesture-required')

// Videos ship next to the app (electron-builder extraResources), not inside app.asar.
// `stream` lets <video> read them in chunks instead of loading 800 MB at once.
protocol.registerSchemesAsPrivileged([
  { scheme: 'media', privileges: { standard: true, secure: true, stream: true } },
])

const videoDir = app.isPackaged ? join(process.resourcesPath, 'videos') : join(app.getAppPath(), 'videos')

app.whenReady().then(() => {
  // media://videos/john-burke.mp4 -> <videoDir>/john-burke.mp4 (basename blocks ../ paths)
  // ponytail: no Range support, so seeking restarts the video; fine for play-through stories,
  // add a 206 Range handler if a scrubber is ever added.
  protocol.handle('media', (req) => {
    const file = join(videoDir, basename(decodeURIComponent(new URL(req.url).pathname)))
    return net.fetch(pathToFileURL(file).toString(), { headers: req.headers })
  })

  const win = new BrowserWindow({
    width: 1920,
    height: 1080,
    kiosk: true,
    backgroundColor: '#000',
    autoHideMenuBar: true,
  })

  // Unattended exhibit: keep the display on, and bring the page back if Chromium's renderer dies
  // (bad decode, GPU out of memory) instead of leaving a black screen.
  powerSaveBlocker.start('prevent-display-sleep')
  win.webContents.on('render-process-gone', (_e, details) => {
    console.error(`Renderer gone (${details.reason}), reloading`)
    win.reload()
  })

  if (process.env.ELECTRON_RENDERER_URL) {
    win.loadURL(process.env.ELECTRON_RENDERER_URL)
  } else {
    win.loadFile(join(__dirname, '../renderer/index.html'))
  }
})

app.on('window-all-closed', () => app.quit())
