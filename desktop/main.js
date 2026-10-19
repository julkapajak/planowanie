// Planowanie na komputer: okno z wersją web, ikona w zasobniku i przypomnienia w tle.
const { app, BrowserWindow, Menu, Tray, ipcMain, nativeImage, net, protocol, shell } = require("electron");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { pathToFileURL } = require("node:url");

const WEB = path.join(__dirname, "web");
const ICON = path.join(__dirname, "web", "icon-512.png");

// Własny adres app://planowanie zamiast file:// – moduły JS i localStorage działają jak na stronie.
protocol.registerSchemesAsPrivileged([
  { scheme: "app", privileges: { standard: true, secure: true, supportFetchAPI: true } },
]);

let win = null;
let tray = null;
let quitting = false;

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on("second-instance", show);
  app.whenReady().then(start);
}

function start() {
  app.setAppUserModelId("com.julkapajak.planowanie.desktop");

  protocol.handle("app", (req) => {
    const { pathname } = new URL(req.url);
    const file = path.normalize(path.join(WEB, decodeURIComponent(pathname === "/" ? "/index.html" : pathname)));
    if (!file.startsWith(WEB)) return new Response("Not found", { status: 404 });
    return net.fetch(pathToFileURL(file).toString());
  });

  setupMenu();
  createWindow();
  createTray();

  ipcMain.on("show", show);

  app.on("activate", show);
  app.on("before-quit", () => { quitting = true; });
}

function createWindow() {
  win = new BrowserWindow({
    width: 500,
    height: 900,
    minWidth: 380,
    minHeight: 560,
    title: "Planowanie",
    icon: ICON,
    backgroundColor: "#F6F1EA",
    autoHideMenuBar: true,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      // przypomnienia sprawdzane co 20 s muszą działać także przy schowanym oknie
      backgroundThrottling: false,
    },
  });

  win.loadURL("app://planowanie/index.html");
  win.once("ready-to-show", () => {
    if (!process.argv.includes("--hidden")) win.show();
  });

  // Zamknięcie okna chowa je – aplikacja dalej przypomina z zasobnika.
  win.on("close", (e) => {
    if (quitting) return;
    e.preventDefault();
    win.hide();
  });

  // Linki zewnętrzne otwieraj w przeglądarce.
  win.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: "deny" };
  });
}

function show() {
  if (!win) return;
  if (win.isMinimized()) win.restore();
  win.show();
  win.focus();
}

function createTray() {
  const img = nativeImage.createFromPath(ICON).resize({ width: process.platform === "darwin" ? 18 : 22 });
  tray = new Tray(img);
  tray.setToolTip("Planowanie");
  tray.on("click", show);
  updateTrayMenu();
}

function updateTrayMenu() {
  tray.setContextMenu(Menu.buildFromTemplate([
    { label: "Pokaż Planowanie", click: show },
    { type: "separator" },
    {
      label: "Uruchamiaj przy starcie komputera",
      type: "checkbox",
      checked: getAutostart(),
      click: (item) => { setAutostart(item.checked); updateTrayMenu(); },
    },
    { type: "separator" },
    { label: "Zakończ", click: () => { quitting = true; app.quit(); } },
  ]));
}

// --- autostart: macOS przez system, Linux przez ~/.config/autostart ---
const linuxAutostart = path.join(os.homedir(), ".config", "autostart", "planowanie.desktop");

function getAutostart() {
  if (process.platform === "linux") return fs.existsSync(linuxAutostart);
  return app.getLoginItemSettings().openAtLogin;
}

function setAutostart(on) {
  if (process.platform !== "linux") {
    app.setLoginItemSettings({ openAtLogin: on, openAsHidden: true, args: ["--hidden"] });
    return;
  }
  if (!on) {
    fs.rmSync(linuxAutostart, { force: true });
    return;
  }
  const exec = process.env.APPIMAGE || process.execPath;
  fs.mkdirSync(path.dirname(linuxAutostart), { recursive: true });
  fs.writeFileSync(linuxAutostart, [
    "[Desktop Entry]",
    "Type=Application",
    "Name=Planowanie",
    `Exec="${exec}" --hidden`,
    "X-GNOME-Autostart-enabled=true",
    "",
  ].join("\n"));
}

function setupMenu() {
  if (process.platform !== "darwin") {
    Menu.setApplicationMenu(null);
    return;
  }
  Menu.setApplicationMenu(Menu.buildFromTemplate([
    {
      label: "Planowanie",
      submenu: [
        { role: "about", label: "O aplikacji Planowanie" },
        { type: "separator" },
        { role: "hide", label: "Ukryj" },
        { role: "unhide", label: "Pokaż wszystko" },
        { type: "separator" },
        { label: "Zakończ", accelerator: "Cmd+Q", click: () => { quitting = true; app.quit(); } },
      ],
    },
    {
      label: "Edycja",
      submenu: [
        { role: "undo", label: "Cofnij" }, { role: "redo", label: "Ponów" }, { type: "separator" },
        { role: "cut", label: "Wytnij" }, { role: "copy", label: "Kopiuj" }, { role: "paste", label: "Wklej" },
        { role: "selectAll", label: "Zaznacz wszystko" },
      ],
    },
    { role: "windowMenu", label: "Okno" },
  ]));
}
