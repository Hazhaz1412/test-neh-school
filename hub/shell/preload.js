const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('browser', {
  go: (input) => ipcRenderer.send('go', input),
  nav: (action) => ipcRenderer.send('nav', action),
  tab: (action, id) => ipcRenderer.send('tab', action, id),
  windowAction: (action) => ipcRenderer.send('window', action),
  toggleBookmark: () => ipcRenderer.send('bookmark'),
  toggleMenu: () => ipcRenderer.send('menu'),
  ready: () => ipcRenderer.send('ready'),
  onState: (callback) => ipcRenderer.on('state', (_event, state) => callback(state)),
  onThought: (callback) => ipcRenderer.on('thought', (_event, text) => callback(text)),
  onFocusAddress: (callback) => ipcRenderer.on('focus-address', () => callback()),
});
