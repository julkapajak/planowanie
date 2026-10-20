# Planowanie

Spokojny planer dnia z przypomnieniami, przyjazny dla osób z ADHD.

**Strona:** https://julkapajak.github.io/planowanie/ (konto, pobieranie aplikacji i wersja w przeglądarce)

| Wersja | Skąd | Kod |
|---|---|---|
| **Przeglądarka** | https://julkapajak.github.io/planowanie/app/ | `app/` |
| **macOS** | [Planowanie-mac.dmg](https://github.com/julkapajak/planowanie/releases/latest/download/Planowanie-mac.dmg) | `desktop/` (Electron, ładuje `app/`) |
| **Linux** | [AppImage](https://github.com/julkapajak/planowanie/releases/latest/download/Planowanie-linux-x86_64.AppImage) · [.deb](https://github.com/julkapajak/planowanie/releases/latest/download/Planowanie-linux-amd64.deb) | `desktop/` |
| **iPhone** | na razie z Xcode: [`ios/README.md`](ios/README.md) | `ios/` (SwiftUI) |

## Konta

Logowanie e-mailem i hasłem. Plan zapisuje się na koncie (Supabase) i jest taki sam w przeglądarce, na Macu i na Linuksie. Bez konta aplikacja działa tylko na danym urządzeniu.
Konfiguracja serwera: [`supabase/README.md`](supabase/README.md). Klucze wpisuje się w `app/config.js`.

## Struktura

- `index.html`, `site.css`: strona główna z pobieraniem
- `app/`: aplikacja (plan, przypomnienia, konto, synchronizacja: `cloud.js`)
- `desktop/`: aplikacja na komputer. GitHub Actions buduje `.dmg`, `.AppImage` i `.deb` i publikuje je w Releases (`.github/workflows/desktop.yml`).
- `ios/`: aplikacja na iPhone'a
- `supabase/schema.sql`: tabela planów z regułami dostępu (każdy widzi tylko swój plan)

Lokalnie: `python3 -m http.server`, potem otwórz `http://localhost:8000`. Aplikacja na komputer: `cd desktop && npm install && npm start`.
