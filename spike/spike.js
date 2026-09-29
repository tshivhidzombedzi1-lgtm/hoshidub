// Go/no-go spike: can castLabs Electron play Crunchyroll, and can we hear only the player's audio?
// Logs to spike/spike.log. Run: npm run spike
const { app, BrowserWindow, components, session } = require('electron');
const fs = require('fs');
const path = require('path');

const LOG = path.join(__dirname, 'spike.log');
fs.writeFileSync(LOG, '');
const log = (...a) => {
  const line = `[${new Date().toISOString().slice(11, 19)}] ${a.join(' ')}`;
  console.log(line);
  fs.appendFileSync(LOG, line + '\n');
};

const EME_CHECK = `(async () => {
  const cfg = [{ initDataTypes: ['cenc'], videoCapabilities: [{ contentType: 'video/mp4; codecs="avc1.42E01E"' }],
                 audioCapabilities: [{ contentType: 'audio/mp4; codecs="mp4a.40.2"' }] }];
  const out = {};
  for (const ks of ['com.widevine.alpha', 'com.microsoft.playready.recommendation']) {
    try { await navigator.requestMediaKeySystemAccess(ks, cfg); out[ks] = 'yes'; } catch (e) { out[ks] = 'no'; }
  }
  return JSON.stringify(out);
})()`;

app.whenReady().then(async () => {
  await components.whenReady();
  log('components', JSON.stringify(components.status()));

  const player = new BrowserWindow({
    width: 1280, height: 800, title: 'Koe spike — log in and play an episode',
    webPreferences: { partition: 'persist:koe', contextIsolation: true, sandbox: true },
  });
  player.webContents.on('did-finish-load', async () => {
    log('loaded', player.webContents.getURL());
    try { log('EME', await player.webContents.executeJavaScript(EME_CHECK)); } catch (e) { log('EME err', e.message); }
  });
  player.webContents.on('console-message', (_e, level, msg) => {
    if (/drm|widevine|license|eme|keysystem|playback/i.test(msg)) log('page', msg.slice(0, 300));
  });
  player.webContents.on('render-process-gone', (_e, d) => log('renderer gone', JSON.stringify(d)));
  player.loadURL('https://www.crunchyroll.com/');

  // Monitor: captures ONLY the player window's audio and logs its loudness.
  const monitorSession = session.fromPartition('koe-monitor');
  monitorSession.setDisplayMediaRequestHandler((_req, cb) => {
    cb({ video: player.webContents.mainFrame, audio: player.webContents.mainFrame, enableLocalEcho: true });
  });
  const monitor = new BrowserWindow({
    show: false, webPreferences: { partition: 'koe-monitor', contextIsolation: true },
  });
  monitor.webContents.on('console-message', (_e, _l, msg) => log('monitor', msg));
  await monitor.loadFile(path.join(__dirname, 'monitor.html'));  // file:// is a secure context
  setTimeout(() => monitor.webContents.executeJavaScript('startCapture()', true), 4000);
});

app.on('window-all-closed', () => app.quit());
