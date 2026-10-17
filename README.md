# Planowanie

Spokojny planer dnia z przypomnieniami: aplikacja webowa (PWA), którą można dodać do ekranu głównego telefonu.

- **Dzień**: oś czasu z zadaniami, karta „Teraz / Następne”, odhaczanie z postępem dnia.
- **Tydzień**: przegląd tygodnia i postęp każdego dnia.
- **Przypomnienia**: powiadomienia X minut przed zadaniem i poranne podsumowanie dnia.
- **Kalendarz**: eksport całego planu do `.ics` z alarmami. To najpewniejsze przypomnienia, bo działają też przy zamkniętej aplikacji.
- Dodawanie, edycja i usuwanie zadań (także co tydzień), kopia zapasowa JSON, działanie offline.

Plan startowy (17.10–31.12.2026) jest w `data.js`. Dane zapisują się lokalnie na urządzeniu.

Publikacja: GitHub Actions → GitHub Pages (`.github/workflows/pages.yml`).
Lokalnie: `python3 -m http.server` i otwórz `http://localhost:8000`.
