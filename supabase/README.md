# Konta w Planowaniu – jednorazowa konfiguracja Supabase

Konta i synchronizacja planu działają na darmowym planie Supabase. Konfiguracja zajmuje około 5 minut.

## 1. Załóż projekt

1. Wejdź na https://supabase.com i kliknij **Start your project**. Najprościej zalogować się przez **GitHub**.
2. Kliknij **New project**:
   - **Name:** `planowanie`
   - **Database Password:** kliknij **Generate a password** i zapisz je, np. w Pęku kluczy. Nie podawaj go nikomu.
   - **Region:** **Central EU (Frankfurt)**
3. Kliknij **Create new project** i poczekaj około 2 minut.

## 2. Utwórz tabelę na plany

1. W menu po lewej wybierz **SQL Editor** i kliknij **New query**.
2. Wklej całą zawartość pliku [`schema.sql`](schema.sql) i kliknij **Run**.
   Ma się pojawić komunikat „Success. No rows returned”.

## 3. Ustaw adres aplikacji (linki w e-mailach)

**Authentication → URL Configuration**:
- **Site URL:** `https://julkapajak.github.io/planowanie/app/`
- **Redirect URLs** → **Add URL:** `https://julkapajak.github.io/planowanie/app/`

## 4. Skopiuj dwa klucze

Kliknij **Connect** (u góry) albo wejdź w **Project Settings → API**. Skopiuj:
- **Project URL**, np. `https://abcdefgh.supabase.co`
- klucz **anon public** (długi ciąg znaków zaczynający się od `eyJ…`)

Te dwie wartości wpisuje się do [`app/config.js`](../app/config.js). Oba klucze są publiczne z założenia, bo dostęp do danych chronią reguły z `schema.sql`. **Nie** kopiuj klucza `service_role`, ten musi zostać tajny.

## Ograniczenia darmowego planu

- Supabase wysyła maksymalnie kilka e-maili na godzinę (potwierdzenia kont, reset hasła). Dla kilku osób to wystarczy.
- Projekt nieużywany przez 7 dni zostaje wstrzymany. Wznawia się go jednym kliknięciem w panelu Supabase.
