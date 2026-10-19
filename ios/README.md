# Planowanie na iPhone'a, iPada i Maca

Natywna aplikacja w SwiftUI (iOS 17+, macOS 14+ przez Mac Catalyst). To jedna aplikacja: w App Store pobiera się ją na iPhone'a i na Maca z tego samego wpisu. Ma ten sam plan startowy co wersja web, a powiadomienia działają też przy zamkniętej aplikacji.

## Pobieranie z App Store / TestFlight

Wszystko robi GitHub: buduje, podpisuje i wysyła aplikację do App Store Connect. Najpierw trzeba to jednorazowo przygotować.

### 1. Wpis aplikacji w App Store Connect (raz)

1. Wejdź na [App Store Connect](https://appstoreconnect.apple.com) → **Aplikacje → + → Nowa aplikacja**.
2. Zaznacz platformy **iOS** i **macOS**, nazwa: **Planowanie**, język główny: polski.
3. W polu **Identyfikator pakietu** wybierz `com.julkapajak.planowanie`.
   Jeśli go nie ma na liście, dodaj go najpierw na [developer.apple.com → Identifiers → +](https://developer.apple.com/account/resources/identifiers/list) (App ID, Explicit, `com.julkapajak.planowanie`).
4. SKU: dowolny tekst, np. `planowanie`.

### 2. Klucz API dla GitHuba (raz)

1. App Store Connect → **Użytkownicy i dostęp → Integracje → App Store Connect API → Klucze zespołu → +**.
2. Nazwa: `GitHub`, dostęp: **Admin**. Ta rola jest potrzebna, żeby GitHub mógł sam tworzyć certyfikaty do podpisu.
3. Pobierz plik `AuthKey_XXXX.p8`. Można go pobrać tylko raz! Zapisz też **Key ID** i **Issuer ID** (widoczny nad listą kluczy).
4. **Team ID** znajdziesz na [developer.apple.com → Membership details](https://developer.apple.com/account#MembershipDetailsCard).

### 3. Sekrety w GitHubie (raz)

W repo: **Settings → Secrets and variables → Actions → New repository secret**. Dodaj cztery sekrety:

| Nazwa | Wartość |
|---|---|
| `APPLE_TEAM_ID` | Team ID (10 znaków) |
| `ASC_KEY_ID` | Key ID klucza |
| `ASC_ISSUER_ID` | Issuer ID |
| `ASC_KEY_P8` | cała zawartość pliku `.p8` (otwórz go w TextEdit i skopiuj wszystko) |

### 4. Wysyłka nowej wersji (za każdym razem)

W repo: **Actions → „Wyślij do App Store Connect (iPhone i Mac)” → Run workflow**. Po około 15 minutach wersje na iPhone'a i Maca pojawią się w App Store Connect w zakładce **TestFlight**.

### 5. Instalacja

**Prywatnie, przez TestFlight (najszybciej, bez recenzji Apple):**
1. App Store Connect → aplikacja → **TestFlight → Testerzy wewnętrzni → +**, dodaj siebie.
2. Zainstaluj aplikację **TestFlight** z App Store na iPhonie i na Macu.
3. W TestFlight pojawi się Planowanie. Kliknij **Zainstaluj**. Kolejne wersje przychodzą jak aktualizacje.

Każda wersja w TestFlight działa 90 dni. Wystarczy co jakiś czas wysłać nową (krok 4).

**Publicznie, w App Store:**
1. App Store Connect → aplikacja → wersja iOS i wersja macOS: dodaj zrzuty ekranu, opis i słowa kluczowe.
   Jako adres polityki prywatności wpisz `https://julkapajak.github.io/planowanie/privacy.html`.
2. W sekcji **Prywatność aplikacji** zaznacz, że aplikacja **nie zbiera danych**.
3. Wybierz build z TestFlight i kliknij **Wyślij do weryfikacji**. Recenzja Apple trwa zwykle 1–3 dni.

Jeśli aplikacja ma być w App Store, ale niewidoczna w wyszukiwarce (dostęp tylko przez link), poproś Apple o [Unlisted App Distribution](https://developer.apple.com/support/unlisted-app-distribution/).

## Praca w Xcode na Macu

```bash
git clone https://github.com/julkapajak/planowanie.git
cd planowanie
git checkout claude/focused-hamilton-ocf757
brew install xcodegen
cd ios
xcodegen generate
open Planowanie.xcodeproj
```

Projekt Xcode generuje się z `project.yml`, więc po każdym `git pull` uruchom ponownie `xcodegen generate`.

Żeby odpalić aplikację z kabla: **Signing & Capabilities → Team**, wybierz iPhone'a albo **My Mac (Mac Catalyst)** na górnym pasku i naciśnij **▶︎**. Na iPhonie trzeba włączyć **Ustawienia → Prywatność i ochrona → Tryb dewelopera**.

## Struktura

- `Planowanie/Model`: zadania, plan startowy (`Seed.swift`), zapis danych
- `Planowanie/NotificationManager.swift`: przypomnienia (iOS planuje najbliższe 60 i odświeża listę przy każdym otwarciu)
- `Planowanie/Views`: ekrany Dzień, Tydzień, Ustawienia, edycja zadania
- `.github/workflows/ios.yml`: sprawdza przy każdym pushu, czy aplikacja kompiluje się na iPhone'a i Maca
- `.github/workflows/app-store.yml`: buduje, podpisuje i wysyła do App Store Connect
