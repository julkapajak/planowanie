# Planowanie na iPhone'a

Natywna aplikacja w SwiftUI (iOS 17+). Ma ten sam plan startowy co wersja web. Powiadomienia działają też przy zamkniętej aplikacji.

## Otwieranie w Xcode

Wpisz w Terminalu na Macu:

```bash
git clone https://github.com/julkapajak/planowanie.git
cd planowanie
git checkout claude/focused-hamilton-ocf757
brew install xcodegen
cd ios
xcodegen generate
open Planowanie.xcodeproj
```

Jeśli nie masz Homebrew, zainstaluj go najpierw ze strony https://brew.sh.

Projekt Xcode generuje się z pliku `project.yml`, więc nie ma go w repo. Po każdym `git pull` uruchom ponownie `xcodegen generate`.

## Instalacja na iPhonie

1. W Xcode kliknij projekt **Planowanie** → **Signing & Capabilities** → **Team** i wybierz swoje konto Apple Developer.
   Jeśli Xcode zgłosi, że identyfikator `com.julkapajak.planowanie` jest zajęty, zmień go na inny (np. dopisz coś na końcu).
2. Podłącz iPhone'a kablem i wybierz go na górnym pasku Xcode.
3. Na iPhonie włącz **Ustawienia → Prywatność i ochrona → Tryb dewelopera** (telefon się zrestartuje).
4. W Xcode naciśnij **▶︎ (Cmd+R)**.

Z płatnym kontem aplikacja zainstalowana w ten sposób działa przez rok.

## TestFlight (instalacja bez kabla, łatwe aktualizacje)

1. W [App Store Connect](https://appstoreconnect.apple.com) → **Aplikacje → +** utwórz aplikację z tym samym identyfikatorem pakietu.
2. W Xcode wybierz **Any iOS Device**, potem **Product → Archive → Distribute App → TestFlight & App Store**.
3. W App Store Connect → **TestFlight → Testerzy wewnętrzni** dodaj siebie, a na iPhonie zainstaluj aplikację TestFlight.

Wewnętrzni testerzy TestFlight to tylko osoby z Twojego konta, więc aplikacja jest prywatna. Nie trafi do App Store, dopóki sama jej tam nie wyślesz. Każda wersja w TestFlight działa 90 dni.

## Struktura

- `Planowanie/Model`: zadania, plan startowy (`Seed.swift`), zapis danych
- `Planowanie/NotificationManager.swift`: przypomnienia (iOS planuje najbliższe 60 i odświeża listę przy każdym otwarciu)
- `Planowanie/Views`: ekrany Dzień, Tydzień, Ustawienia, edycja zadania
- `.github/workflows/ios.yml`: sprawdza w GitHub Actions, czy aplikacja się kompiluje
