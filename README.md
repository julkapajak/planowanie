# Planowanie

Spokojny planer dnia z przypomnieniami. Zawiera plan startowy do końca 2026 roku: ATPL, PAR, mechanika, Stanford, western, siłownia.

| Wersja | Skąd pobrać | Kod |
|---|---|---|
| **iPhone, iPad i Mac** | App Store / TestFlight, instrukcja w [`ios/README.md`](ios/README.md) | `ios/` (SwiftUI) |
| **Linux** | [Releases](https://github.com/julkapajak/planowanie/releases/latest): `.AppImage` albo `.deb` | `desktop/` (Electron) |
| **Przeglądarka** | https://julkapajak.github.io/planowanie/ | katalog główny |

Wszystkie wersje mają te same funkcje:
- **Dzień**: oś czasu, karta „Teraz / Następne”, odhaczanie z postępem dnia.
- **Tydzień**: przegląd tygodnia.
- **Przypomnienia** przed zadaniami i poranne podsumowanie dnia.
- Dodawanie i edycja zadań (także co tydzień).
- Kopia zapasowa JSON, którą można przenosić między wersjami.

Dane zapisują się tylko na urządzeniu ([polityka prywatności](https://julkapajak.github.io/planowanie/privacy.html)).

## Linux

- **AppImage**: pobierz, kliknij prawym → Właściwości → „Zezwól na uruchamianie”, a potem otwórz.
- **Ubuntu/Debian**: `sudo apt install ./Planowanie-linux-amd64.deb`

Zamknięcie okna chowa aplikację do zasobnika, a przypomnienia dalej przychodzą. W menu ikony możesz włączyć „Uruchamiaj przy starcie komputera”.

Lokalnie: `cd desktop && npm install && npm start`.

## Przeglądarka

`python3 -m http.server` w katalogu głównym, potem otwórz `http://localhost:8000`. Na GitHub Pages strona publikuje się sama po każdym pushu.
