const { contextBridge, ipcRenderer } = require("electron");

// Wersja web sprawdza `window.desktop`, żeby wiedzieć, że działa jako aplikacja na komputer.
contextBridge.exposeInMainWorld("desktop", {
  platform: process.platform,
  show: () => ipcRenderer.send("show"),
});
