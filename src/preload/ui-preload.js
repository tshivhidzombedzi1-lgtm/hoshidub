// The only doorway between the glass UI and the main process. No Node APIs leak into the page.
const { contextBridge, ipcRenderer } = require('electron');

const call = (ch) => (...a) => ipcRenderer.invoke(ch, ...a);
const on = (ch) => (fn) => {
  const h = (_e, v) => fn(v);
  ipcRenderer.on(ch, h);
  return () => ipcRenderer.removeListener(ch, h);
};

contextBridge.exposeInMainWorld('koe', {
  settings: { get: call('settings:get'), set: call('settings:set') },
  engine: { info: call('engine:info'), onStatus: on('engine:status') },
  nav: {
    go: call('nav:go'), open: call('nav:open'), back: call('nav:back'), forward: call('nav:forward'),
    reload: call('nav:reload'), stop: call('nav:stop'), home: call('nav:home'), resume: call('nav:resume'),
    state: call('nav:state'), onState: on('nav:state'), onError: on('nav:error'),
  },
  layout: { viewport: call('layout:viewport') },
  captions: { show: call('captions:show'), hide: call('captions:hide') },
  subs: { get: call('subs:get'), onState: on('subs:state') },
  player: { state: call('player:state') },
  dubLog: call('dub:log'),
  adblock: {
    state: call('adblock:state'), toggleSite: call('adblock:toggle-site'),
    setEnabled: call('adblock:set-enabled'), onState: on('adblock:state'),
  },
  setup: {
    status: call('setup:status'), start: call('setup:start'),
    onProgress: on('setup:progress'), onDone: on('setup:done'), onError: on('setup:error'),
  },
  license: {
    get: call('license:get'), activate: call('license:activate'), deactivate: call('license:deactivate'),
    usage: call('license:usage'), onState: on('license:state'), checkout: call('app:checkout'),
  },
  browsing: { clear: call('browsing:clear') },
  app: {
    info: call('app:info'), openLogs: call('app:open-logs'),
    onShortcut: on('app:shortcut'), onFullscreen: on('app:fullscreen'), onDubReset: on('dub:reset'),
  },
});
