# Planowanie na iPhone'a

Aplikacja w SwiftUI (iOS 17+).

## Uruchomienie na symulatorze (bez Terminala)

1. Pobierz projekt jako ZIP:
   https://github.com/julkapajak/planowanie/archive/refs/heads/claude/focused-hamilton-ocf757.zip
2. Kliknij dwa razy pobrany plik ZIP, żeby go rozpakować.
3. W rozpakowanym folderze wejdź do **`ios`** i kliknij dwa razy **`Planowanie.xcodeproj`**. Otworzy się Xcode.
4. Na górnym pasku Xcode, obok nazwy „Planowanie”, wybierz symulator, np. **iPhone 16**.
5. Naciśnij **▶︎** (albo Cmd+R). Pierwsze uruchomienie symulatora trwa chwilę.

Na symulatorze nie musisz się logować ani nic podpisywać.

Powiadomienia możesz sprawdzić tak: Ustawienia w aplikacji → włącz Powiadomienia → „Wyślij testowe powiadomienie”. Potem wróć na ekran główny symulatora (Cmd+Shift+H).

## Co jest w środku

- `Planowanie.xcodeproj`: projekt Xcode, który otwierasz
- `Planowanie/Model`: zadania, plan startowy (`Seed.swift`), zapis danych
- `Planowanie/NotificationManager.swift`: przypomnienia
- `Planowanie/Views`: ekrany Dzień, Tydzień, Ustawienia, edycja zadania
- `project.yml`: z niego GitHub sam generuje `Planowanie.xcodeproj`, nie trzeba go ruszać
