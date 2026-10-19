// Kopiuje wersję web (z katalogu głównego repo) do desktop/web, skąd ładuje ją Electron.
import { cpSync, mkdirSync, rmSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const out = join(root, "desktop", "web");
const files = ["index.html", "styles.css", "app.js", "data.js", "icon.svg", "icon-192.png", "icon-512.png"];

rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
for (const f of files) cpSync(join(root, f), join(out, f));
console.log(`Skopiowano ${files.length} plików do desktop/web`);
