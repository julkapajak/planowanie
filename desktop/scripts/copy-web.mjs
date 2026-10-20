// Kopiuje wersję web (z katalogu głównego repo) do desktop/web, skąd ładuje ją Electron.
import { cpSync, mkdirSync, rmSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const out = join(root, "desktop", "web");
// Aplikacja z app/ (bez service workera i manifestu – niepotrzebne w Electronie) oraz ikony z katalogu głównego.
// W Electronie index.html leży w katalogu głównym, więc odnośniki „../icon.svg” trafiają do tych samych ikon.
const skip = new Set(["sw.js", "manifest.webmanifest"]);
const icons = ["icon.svg", "icon-180.png", "icon-192.png", "icon-512.png"];

rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
cpSync(join(root, "app"), out, { recursive: true, filter: (src) => !skip.has(src.split(/[\\/]/).pop()) });
for (const f of icons) cpSync(join(root, f), join(out, f));
console.log("Skopiowano aplikację do desktop/web");
