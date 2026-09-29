const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('captions', {
  onCaption: (fn) => ipcRenderer.on('caption', (_e, c) => fn(c)),
  reportSize: (box) => ipcRenderer.send('captions:size', box),
});
