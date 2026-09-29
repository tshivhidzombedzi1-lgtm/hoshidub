// Dub It main process: one window = glass UI (the window's own page) + the browser view + a captions view.
const { app, BrowserWindow, WebContentsView, components, ipcMain, nativeTheme, net, protocol, session, shell } = require('electron');
const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');
const log = require('./log');
const { Store } = require('./store');
const { Engine } = require('./engine');
const subtitles = require('./subtitles');
const { License } = require('./license');
const { Setup } = require('./setup');

const CHECKOUT_URL = process.env.KOE_CHECKOUT_URL || '';   // Lemon Squeezy checkout link, set once the store exists

if (process.env.KOE_USER_DATA) app.setPath('userData', process.env.KOE_USER_DATA);
if (!app.requestSingleInstanceLock()) {
  app.quit();
  process.exit(0);
}

const UI_DIR = path.join(__dirname, '..', 'ui');
const PRELOAD = path.join(__dirname, '..', 'preload');
const BROWSER_PARTITION = 'persist:koe';
const HOME_URLS = { crunchyroll: 'https://www.crunchyroll.com/', youtube: 'https://www.youtube.com/' };

protocol.registerSchemesAsPrivileged([
  { scheme: 'koe', privileges: { standard: true, secure: true, supportFetchAPI: true } },
]);

let win, browser, captions, store, engine, license, setup;
let viewport = { x: 0, y: 0, width: 800, height: 600 };
let captionBox = { width: 0, height: 0 };
let captionTimer = null;
let showingBrowser = false;
let htmlFullscreen = false;
let subs = null;               // { lines, format, url } — the English subtitle track the player loaded

// ---------------------------------------------------------------- helpers
function toUrl(input) {
  const s = String(input || '').trim();
  if (!s) return null;
  if (/^https?:\/\//i.test(s)) return s;
  if (/^[\w-]+(\.[\w-]+)+(\/\S*)?$/.test(s) && !/\s/.test(s)) return 'https://' + s;
  return 'https://duckduckgo.com/?q=' + encodeURIComponent(s);
}

function isWebUrl(u) {
  try { return ['http:', 'https:'].includes(new URL(u).protocol); } catch { return false; }
}

function sendUi(channel, payload) {
  if (win && !win.isDestroyed()) win.webContents.send(channel, payload);
}

function navState() {
  const wc = browser.webContents;
  return {
    url: showingBrowser ? wc.getURL() : '',
    title: showingBrowser ? wc.getTitle() : '',
    loading: wc.isLoading(),
    canGoBack: wc.navigationHistory.canGoBack(),
    canGoForward: wc.navigationHistory.canGoForward(),
    showingBrowser,
  };
}

function pushNav() { sendUi('nav:state', navState()); }

function contentArea() {
  const [width, height] = win.getContentSize();
  return { x: 0, y: 0, width, height };
}

function layout() {
  if (!win) return;
  const area = htmlFullscreen ? contentArea() : viewport;
  browser.setBounds(area);
  browser.setBorderRadius(htmlFullscreen ? 0 : 18);
  browser.setVisible(showingBrowser);
  placeCaptions(area);
}

function placeCaptions(area = htmlFullscreen ? contentArea() : viewport) {
  // keep the (hidden) view sized even with no caption, so the page can measure text at its real width
  const w = Math.min(900, area.width - 32);
  const h = Math.round(captionBox.height) || 160;
  if (!captionBox.width) captions.setVisible(false);
  captions.setBounds({
    x: Math.round(area.x + (area.width - w) / 2),
    y: Math.round(area.y + area.height - h - Math.max(72, area.height * 0.12)),  // clear of player controls
    width: w, height: h,
  });
}

function showBrowser(url) {
  showingBrowser = true;
  browser.webContents.loadURL(url).catch((e) => log.warn('load failed', { url, err: e.message }));
  store.set('lastUrl', url);
  layout();
  pushNav();
}

// ---------------------------------------------------------------- shortcuts (work while the video has focus too)
function handleShortcut(input) {
  if (input.type !== 'keyDown') return false;
  const ctrl = input.control || input.meta;
  const k = input.key.toLowerCase();
  const act = (name) => { sendUi('app:shortcut', name); return true; };
  if (ctrl && k === 'd') return act('toggle-dub');
  if (ctrl && k === 'l') return act('focus-address');
  if (ctrl && k === ',') return act('settings');
  if (ctrl && k === 'j') return act('toggle-panel');
  if (ctrl && k === 'r') { browser.webContents.reload(); return true; }
  if (input.alt && k === 'arrowleft') { browser.webContents.navigationHistory.goBack(); return true; }
  if (input.alt && k === 'arrowright') { browser.webContents.navigationHistory.goForward(); return true; }
  if (k === 'f11') { win.setFullScreen(!win.isFullScreen()); return true; }
  return false;
}

// ---------------------------------------------------------------- window
const windowButtonColor = () => (nativeTheme.shouldUseDarkColors ? '#f5f5f7' : '#1d1d1f');

function createWindow() {
  nativeTheme.on('updated', () => {
    if (win && !win.isDestroyed()) win.setTitleBarOverlay({ color: '#00000000', symbolColor: windowButtonColor(), height: 72 });
  });
  const ws = store.get('window');
  const testing = !!process.env.KOE_TEST_INACTIVE;          // automated tests: keep windows out of the user's way
  win = new BrowserWindow({
    width: ws.width, height: ws.height, x: testing ? -30000 : ws.x, y: testing ? 0 : ws.y,
    skipTaskbar: testing,
    minWidth: 980, minHeight: 620,
    title: 'Dub It',
    icon: path.join(UI_DIR, 'icon.png'),
    show: false,
    backgroundColor: '#00000000',
    backgroundMaterial: 'acrylic',
    titleBarStyle: 'hidden',
    // 72 = 10px top padding + 52px toolbar + 10px: the window buttons sit centred on the toolbar row
    titleBarOverlay: { color: '#00000000', symbolColor: windowButtonColor(), height: 72 },
    webPreferences: {
      preload: path.join(PRELOAD, 'ui-preload.js'),
      contextIsolation: true, sandbox: true, nodeIntegration: false, spellcheck: false,
    },
  });
  if (ws.maximized) win.maximize();

  browser = new WebContentsView({
    webPreferences: { partition: BROWSER_PARTITION, contextIsolation: true, sandbox: true, nodeIntegration: false },
  });
  browser.setBackgroundColor('#000000');
  browser.setVisible(false);
  win.contentView.addChildView(browser);

  captions = new WebContentsView({
    webPreferences: { preload: path.join(PRELOAD, 'captions-preload.js'), contextIsolation: true, sandbox: true },
  });
  captions.setBackgroundColor('#00000000');
  captions.setVisible(false);
  win.contentView.addChildView(captions);
  captions.webContents.loadURL('koe://app/captions.html');

  wireBrowser(browser.webContents);
  watchPlayerData(browser.webContents);
  wireUiSession();

  win.webContents.on('before-input-event', (e, input) => { if (handleShortcut(input)) e.preventDefault(); });
  win.on('resize', () => htmlFullscreen && layout());
  win.on('enter-full-screen', () => sendUi('app:fullscreen', true));
  win.on('leave-full-screen', () => {
    if (htmlFullscreen) browser.webContents.executeJavaScript('document.fullscreenElement && document.exitFullscreen()').catch(() => {});
    htmlFullscreen = false;
    sendUi('app:fullscreen', false);
    layout();
  });
  win.on('close', () => {
    const maximized = win.isMaximized();
    const b = maximized ? store.get('window') : { ...store.get('window'), ...win.getNormalBounds() };
    store.set('window', { ...b, maximized });
    store.saveNow();
  });
  win.webContents.on('render-process-gone', (_e, d) => {
    log.error('ui renderer gone', d);
    win.webContents.reload();
  });

  win.once('ready-to-show', () => {
    if (process.env.KOE_TEST_INACTIVE) win.showInactive(); else win.show();
    log.info('window shown', { ms: Math.round(performance.now()) });
  });
  win.loadURL('koe://app/index.html');
}

function wireBrowser(wc) {
  wc.setWindowOpenHandler(({ url }) => {
    if (isWebUrl(url)) wc.loadURL(url);           // popups open in place: one browser, one video
    return { action: 'deny' };
  });
  wc.on('will-navigate', (e, url) => { if (!isWebUrl(url)) e.preventDefault(); });
  for (const ev of ['did-navigate', 'did-navigate-in-page', 'page-title-updated', 'did-start-loading', 'did-stop-loading']) {
    wc.on(ev, pushNav);
  }
  let lastPath = '';
  wc.on('did-navigate', (_e, url) => {
    try { lastPath = new URL(url).pathname; } catch { lastPath = ''; }
    setSubs(null);
    sendUi('dub:reset');
  });
  wc.on('did-navigate-in-page', (_e, url) => {     // single-page sites: a new episode is an in-page navigation
    const p = (() => { try { return new URL(url).pathname; } catch { return url; } })();
    if (p !== lastPath) { lastPath = p; setSubs(null); sendUi('dub:reset'); }
  });
  wc.on('did-fail-load', (_e, code, desc, url, isMain) => {
    if (isMain && code !== -3) sendUi('nav:error', { code, desc, url });   // -3 = aborted by a new navigation
  });
  wc.on('enter-html-full-screen', () => {
    htmlFullscreen = true;
    win.setFullScreen(true);
    sendUi('app:fullscreen', true);
    layout();
  });
  wc.on('leave-html-full-screen', () => {
    htmlFullscreen = false;
    win.setFullScreen(false);
    layout();
  });
  wc.on('render-process-gone', (_e, d) => {
    log.error('browser renderer gone', d);
    sendUi('nav:error', { code: 'crashed', desc: 'The page stopped working.', url: wc.getURL() });
  });
  wc.on('before-input-event', (e, input) => { if (handleShortcut(input)) e.preventDefault(); });

  const ses = wc.session;
  ses.setUserAgent(ses.getUserAgent().replace(/ (Electron|koe)\/\S+/gi, ''));   // look like plain Chrome

  // Notice the subtitle file the player downloads, and read it ourselves (it is plain text, not protected video).
  ses.webRequest.onCompleted({ urls: ['https://*/*', 'http://*/*'] }, (d) => {
    // Players often fetch subtitles from a web worker, which has no webContents id, so those must count too.
    // Our own re-download also has none; loadSubtitles() ignores URLs it has already read, which ends that loop.
    if (d.statusCode !== 200 || (d.webContentsId !== undefined && d.webContentsId !== wc.id)) return;
    const h = d.responseHeaders || {};
    const ct = (h['content-type'] || h['Content-Type'] || [''])[0];
    if (subtitles.looksLikeSubtitles(d.url, ct)) loadSubtitles(ses, d.url);
  });
  const allowed = new Set(['fullscreen', 'mediaKeySystem', 'clipboard-sanitized-write', 'pointerLock']);
  ses.setPermissionRequestHandler((_wc, perm, cb) => cb(allowed.has(perm)));
  ses.setPermissionCheckHandler((_wc, perm) => allowed.has(perm));
}

// Streaming players receive their subtitle list inside JSON (even when the video has burned-in subtitles).
// Read the bodies of JSON responses the page already got, via the DevTools protocol: no extra requests.
function watchPlayerData(wc) {
  const dbg = wc.debugger;
  try { dbg.attach('1.3'); } catch (e) { log.warn('player data watch unavailable', { err: e.message }); return; }
  const pending = new Map();
  // the main page's events carry an empty session id, which sendCommand rejects: send those without one
  const send = (method, params = {}, sessionId) => dbg.sendCommand(method, params, sessionId || undefined).catch(() => null);
  const autoAttach = { autoAttach: true, waitForDebuggerOnStart: false, flatten: true };
  send('Network.enable', { maxTotalBufferSize: 20e6 });
  send('Target.setAutoAttach', autoAttach);               // player iframes run in their own processes
  dbg.on('message', async (_e, method, params, sessionId) => {
    if (method === 'Target.attachedToTarget') {
      send('Network.enable', {}, params.sessionId);
      send('Target.setAutoAttach', autoAttach, params.sessionId);
    } else if (method === 'Network.responseReceived') {
      const r = params.response;
      if (r.status === 200 && /json|dash\+xml|mpegurl/i.test(r.mimeType) && ['XHR', 'Fetch'].includes(params.type)) {
        pending.set(params.requestId, { sessionId, url: r.url });
      }
    } else if (method === 'Network.loadingFinished' && pending.has(params.requestId)) {
      const { sessionId: sid, url } = pending.get(params.requestId);
      pending.delete(params.requestId);
      let res = null;
      for (let attempt = 0; attempt < 4 && !res; attempt++) {    // the body can lag loadingFinished slightly
        if (attempt) await new Promise((r) => setTimeout(r, 150 * attempt));
        res = await send('Network.getResponseBody', { requestId: params.requestId }, sid);
      }
      if (!res || res.body.length > 3e6) return;
      const body = res.base64Encoded ? Buffer.from(res.body, 'base64').toString('utf8') : res.body;
      if (!/\.(ass|ssa|vtt|srt)|subtitle|caption/i.test(body)) return;
      const found = subtitles.findSubtitleUrls(body);
      if (!found.length) return;
      log.info('subtitle list found', { from: new URL(url).hostname, tracks: found.map((f) => f.trail).slice(0, 12) });
      const en = found.find((f) => f.english);
      if (en) loadSubtitles(wc.session, en.url);
    }
  });
  dbg.on('detach', (_e, reason) => log.info('player data watch detached', { reason }));
}

function setSubs(next) {
  if (!next && !subs) return;
  if (!next) seenSubtitleUrls.clear();        // new page: the same track may legitimately load again
  subs = next;
  sendUi('subs:state', subs ? { count: subs.lines.length, format: subs.format } : null);
}

const seenSubtitleUrls = new Set();

async function loadSubtitles(ses, url) {
  if (seenSubtitleUrls.has(url)) return;
  seenSubtitleUrls.add(url);
  try {
    const res = await ses.fetch(url);
    if (!res.ok) return;
    const text = await res.text();
    const parsed = subtitles.parse(text, url);
    log.info('subtitles seen', { host: new URL(url).hostname, format: parsed?.format, lines: parsed?.lines.length, english: parsed?.english });
    if (parsed && parsed.english && parsed.lines.length >= 5) {
      setSubs({ ...parsed, url });
      // kept locally so a session can be checked afterwards: what was said vs the official lines
      fs.writeFile(path.join(app.getPath('userData'), 'logs', 'last-subtitles.json'),
        JSON.stringify({ page: browser.webContents.getURL(), format: parsed.format, lines: parsed.lines }, null, 1), () => {});
    }
  } catch (e) {
    log.warn('subtitles fetch failed', { err: e.message });
  }
}

// Where is the video? Look through every frame (players usually live in an iframe) for a playing <video>.
const VIDEO_PROBE = `(() => {
  const v = [...document.querySelectorAll('video')].find((v) => v.duration > 0 && v.readyState > 0);
  return v ? { t: v.currentTime, paused: v.paused, rate: v.playbackRate, duration: v.duration } : null;
})()`;
let probeFrame = null;

async function playerState() {
  if (!showingBrowser) return null;
  const frames = browser.webContents.mainFrame.framesInSubtree;
  const order = probeFrame && frames.includes(probeFrame) ? [probeFrame, ...frames.filter((f) => f !== probeFrame)] : frames;
  for (const f of order) {
    try {
      const s = await f.executeJavaScript(VIDEO_PROBE);
      if (s) { probeFrame = f; return s; }
    } catch { /* frame navigated away */ }
  }
  return null;
}

function wireUiSession() {
  // The UI page asks for the player's audio; hand it the browser view's frame and keep that audio off the
  // speakers (enableLocalEcho: false) so the UI can play its own mix: Japanese (ducked) + English.
  win.webContents.session.setDisplayMediaRequestHandler((req, cb) => {
    if (!req.frame || !req.frame.url.startsWith('koe://') || !showingBrowser) return cb({});
    const frame = browser.webContents.mainFrame;
    cb({ video: frame, audio: frame, enableLocalEcho: false });
  });
  win.webContents.session.setPermissionRequestHandler((_wc, perm, cb) => cb(perm === 'media' || perm === 'display-capture'));
}

// ---------------------------------------------------------------- IPC
const SETTING_CHECKS = {
  onboarded: (v) => typeof v === 'boolean',
  englishVolume: (v) => typeof v === 'number' && v >= 0 && v <= 1.5,
  duckLevel: (v) => typeof v === 'number' && v >= 0 && v <= 1,
  captions: (v) => typeof v === 'boolean',
  captionSize: (v) => ['small', 'medium', 'large'].includes(v),
  dubPanelOpen: (v) => typeof v === 'boolean',
  reduceTransparency: (v) => typeof v === 'boolean',
  preferSubtitles: (v) => typeof v === 'boolean',
};

function wireIpc() {
  const fromUi = (e) => e.sender === win.webContents;
  const handle = (ch, fn) => ipcMain.handle(ch, (e, ...a) => (fromUi(e) ? fn(...a) : undefined));

  handle('settings:get', () => store.all());
  handle('settings:set', (key, value) => {
    if (!SETTING_CHECKS[key] || !SETTING_CHECKS[key](value)) throw new Error(`invalid setting ${key}`);
    store.set(key, value);
    return true;
  });
  handle('engine:info', () => engine.info());
  handle('nav:go', (input) => { const u = toUrl(input); if (u) showBrowser(u); });
  handle('nav:open', (name) => HOME_URLS[name] && showBrowser(HOME_URLS[name]));
  handle('nav:back', () => browser.webContents.navigationHistory.goBack());
  handle('nav:forward', () => browser.webContents.navigationHistory.goForward());
  handle('nav:reload', () => browser.webContents.reload());
  handle('nav:stop', () => browser.webContents.stop());
  handle('nav:home', () => { showingBrowser = false; layout(); pushNav(); });
  handle('nav:resume', () => { if (browser.webContents.getURL()) { showingBrowser = true; layout(); pushNav(); } });
  handle('nav:state', () => navState());
  handle('layout:viewport', (r) => {
    viewport = { x: Math.round(r.x), y: Math.round(r.y), width: Math.max(1, Math.round(r.width)), height: Math.max(1, Math.round(r.height)) };
    layout();
  });
  handle('captions:show', ({ text, ms, size }) => {
    captions.webContents.send('caption', { text: String(text).slice(0, 400), size });
    clearTimeout(captionTimer);
    captionTimer = setTimeout(() => { captions.setVisible(false); captions.webContents.send('caption', { text: '' }); }, Math.min(ms, 15000));
  });
  handle('captions:hide', () => { clearTimeout(captionTimer); captions.setVisible(false); });
  handle('browsing:clear', async () => {
    await session.fromPartition(BROWSER_PARTITION).clearStorageData();
    showingBrowser = false;
    browser.webContents.loadURL('about:blank');
    layout();
    pushNav();
  });
  handle('dub:log', (entry) => log.info('dub', entry));
  handle('setup:status', () => setup.status || setup.check());
  handle('setup:start', (packs) => setup.start(Array.isArray(packs) ? packs.filter((p) => /^[a-z-]+$/.test(p)) : []));
  handle('license:get', () => { license.refresh().then((s) => sendUi('license:state', s)); return license.summary(); });
  handle('license:activate', async (key) => { const r = await license.activate(key); sendUi('license:state', license.summary()); return r; });
  handle('license:deactivate', async () => { const s = await license.deactivate(); sendUi('license:state', s); return s; });
  handle('license:usage', (seconds) => license.addUsage(Number(seconds) || 0));
  handle('app:checkout', () => { if (CHECKOUT_URL) shell.openExternal(CHECKOUT_URL); return !!CHECKOUT_URL; });
  handle('subs:get', () => (subs ? { lines: subs.lines, format: subs.format } : null));
  handle('player:state', () => playerState());
  handle('app:open-logs', () => shell.openPath(path.join(app.getPath('userData'), 'logs')));
  handle('app:info', () => ({ version: app.getVersion(), electron: process.versions.electron, chrome: process.versions.chrome,
    testMute: !!process.env.KOE_TEST_MUTE, canCheckout: !!CHECKOUT_URL }));

  // captions page reports the size of its text box so the overlay covers only the text, not the player controls
  ipcMain.on('captions:size', (e, box) => {
    if (e.sender !== captions.webContents) return;
    captionBox = { width: box.width, height: box.height };
    placeCaptions();
    captions.setVisible(showingBrowser && box.width > 0);
  });
}

// ---------------------------------------------------------------- lifecycle
app.on('second-instance', () => {
  if (!win) return;
  if (win.isMinimized()) win.restore();
  win.focus();
});

app.whenReady().then(async () => {
  log.init(path.join(app.getPath('userData'), 'logs'));
  log.info('starting', { version: app.getVersion() });
  store = new Store(app.getPath('userData'));
  license = new License(app.getPath('userData'));

  protocol.handle('koe', (req) => {
    const { pathname } = new URL(req.url);
    const file = path.normalize(path.join(UI_DIR, decodeURIComponent(pathname)));
    if (!file.startsWith(UI_DIR)) return new Response('forbidden', { status: 403 });
    return net.fetch(pathToFileURL(file).toString());
  });

  engine = new Engine();
  engine.on('status', (info) => sendUi('engine:status', info));
  setup = new Setup(engine.python);
  setup.on('progress', (p) => sendUi('setup:progress', p));
  setup.on('runtime', (python) => { engine.python = python; });
  setup.on('error', (e) => sendUi('setup:error', e));
  setup.on('done', (s) => {
    sendUi('setup:done', s);
    engine.proc ? engine.restart() : engine.start();     // pick up newly downloaded packs
  });
  wireIpc();
  createWindow();
  setup.check().then((s) => {                              // the engine starts once its voices are on disk
    if (s.ready) engine.start();
    else engine.setStatus('setup', 'Voices need to be downloaded');
  });

  components.whenReady().then(
    () => log.info('widevine ready', components.status()),
    (e) => { log.error('widevine failed', { err: String(e) }); sendUi('nav:error', { code: 'drm', desc: 'Video protection module failed to load.' }); },
  );
});

app.on('window-all-closed', () => app.quit());
app.on('before-quit', () => { engine?.stop(); store?.saveNow(); });
process.on('uncaughtException', (e) => log.error('uncaught', { err: e.stack }));
