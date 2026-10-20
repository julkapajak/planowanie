// Domyślne kategorie i przykładowy start dla nowego planu.
// Własne kategorie i zadania każdej osoby są w jej danych (na urządzeniu albo na koncie), nie w kodzie.

export const DEFAULT_CATS = {
  study:  { name: "Nauka",      color: "#4F7BD9", icon: "📚" },
  work:   { name: "Praca",      color: "#8A63D2", icon: "💼" },
  sport:  { name: "Ruch",       color: "#4C9F3A", icon: "💪" },
  food:   { name: "Jedzenie",   color: "#E09A2D", icon: "🍳" },
  home:   { name: "Dom",        color: "#D06A8A", icon: "🏠" },
  people: { name: "Ludzie",     color: "#18A08C", icon: "💬" },
  health: { name: "Zdrowie",    color: "#C8453F", icon: "🩺" },
  life:   { name: "Odpoczynek", color: "#6F8FA6", icon: "🌿" },
};

export const FALLBACK_CAT = { name: "Inne", color: "#8A8190", icon: "•" };

const pad = (n) => String(n).padStart(2, "0");
export const iso = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
export const parseDate = (s) => { const [y, m, d] = s.split("-").map(Number); return new Date(y, m - 1, d); };

/** Trzy przykładowe zadania na dziś, żeby nowy plan nie był pusty. */
export function starterTasks() {
  const today = iso(new Date());
  return [
    { id: "start-1", date: today, time: "09:00", dur: 15, cat: "life", title: "Spokojny start dnia", note: "Woda, kawa, zerknij na plan", done: false },
    { id: "start-2", date: today, time: "10:00", dur: 50, cat: "study", title: "Skupienie – 50 min", note: "Jedna rzecz naraz, telefon na bok", done: false },
    { id: "start-3", date: today, time: "16:00", dur: 30, cat: "sport", title: "Spacer", note: "", done: false },
  ];
}
