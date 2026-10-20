// Połączenie z kontami (Supabase). Oba klucze są publiczne z założenia –
// dostęp do danych chronią reguły w bazie (supabase/schema.sql): każdy widzi tylko swój plan.
// Puste wartości = aplikacja działa bez kont, tylko na tym urządzeniu.
export const SUPABASE_URL = "";
export const SUPABASE_ANON_KEY = "";

// Adres aplikacji w sieci – tu prowadzą linki z e-maili (potwierdzenie konta, nowe hasło).
export const APP_URL = "https://julkapajak.github.io/planowanie/app/";
