// Kategorie i startowy plan (17 października – 31 grudnia 2026).
// Plan generuje się raz przy pierwszym uruchomieniu; potem wszystko jest edytowalne.

export const CATS = {
  atpl:  { name: "ATPL EASA",          color: "#4F7BD9", icon: "✈︎" },
  par:   { name: "PAR do PPL(A) FAA",  color: "#18A08C", icon: "🛩" },
  mech:  { name: "Projekt z mechaniki", color: "#8A63D2", icon: "⚙︎" },
  stan:  { name: "Program Stanford",   color: "#C8453F", icon: "🎓" },
  west:  { name: "Trening western",    color: "#B07A3E", icon: "🐎" },
  gym:   { name: "Siłownia",           color: "#4C9F3A", icon: "💪" },
  food:  { name: "Jedzenie",           color: "#E09A2D", icon: "🍳" },
  clean: { name: "Sprzątanie",         color: "#D06A8A", icon: "🧹" },
  life:  { name: "Życie i odpoczynek", color: "#6F8FA6", icon: "🌿" },
};

export const PLAN_START = "2026-10-17";
export const PLAN_END = "2026-12-31";

const SESS = {
  A: ["Siła A – dół + plecy", "przysiad, wiosłowanie hantlem, hip thrust, wykroki chodzone, plank"],
  B: ["Siła B – góra", "wyciskanie hantli, podciąganie/ściąganie, wyciskanie nad głowę, wiosłowanie na wyciągu, dead bug"],
  C: ["Siła C – całe ciało", "martwy ciąg rumuński, przysiad bułgarski, wyciskanie sztangi, ściąganie wąsko, pallof, unoszenie nóg"],
};
const OBW = "swing, goblet squat, pompki, wiosłowanie TRX, mountain climbers, farmer’s walk";

// tygodnie planu siłowego (od poniedziałku)
const WEEKS = [
  { s: "2026-10-19", n: "Tydz. 1", str: "4 serie główne, RIR 3", int: "8 × 30/60 s", obw: "3 rundy, 40/20" },
  { s: "2026-10-26", n: "Tydz. 2", str: "+ciężar wg progresji, RIR 3", int: "9 × 30/60 s", obw: "3 rundy, 40/20" },
  { s: "2026-11-02", n: "Tydz. 3", str: "RIR 2–3", int: "10 × 30/60 s", obw: "4 rundy, 40/20" },
  { s: "2026-11-09", n: "Tydz. 4 · lżejszy", str: "ciężar −10%, serie −1", int: "6 × 30/60 s", obw: "2 rundy" },
  { s: "2026-11-16", n: "Tydz. 5", str: "5 serii głównych, RIR 2", int: "8 × 40/80 s", obw: "4 rundy, 40/20" },
  { s: "2026-11-23", n: "Tydz. 6", str: "RIR 2", int: "9 × 40/80 s", obw: "4 rundy, 40/20" },
  { s: "2026-11-30", n: "Tydz. 7", str: "RIR 1–2", int: "10 × 40/80 s", obw: "4 rundy, 45/15" },
  { s: "2026-12-07", n: "Tydz. 8 · lżejszy", str: "ciężar −10%, serie −1", int: "6 × 30/60 s", obw: "2 rundy" },
  { s: "2026-12-14", n: "Tydz. 9", str: "główne 4×5–6, RIR 1–2", int: "6 × 60/60 s", obw: "4 rundy, 45/15" },
  { s: "2026-12-21", n: "Tydz. 10 · święta", str: "krótko, bez dociskania" },
  { s: "2026-12-28", n: "Tydz. 11 · test", str: "test: ciężar na 5 czystych powtórzeń, zapisz" },
];

export const HOLIDAYS = {
  "2026-11-26": "Święto Dziękczynienia",
  "2026-12-24": "Wigilia",
  "2026-12-25": "Boże Narodzenie",
  "2026-12-26": "Drugi dzień świąt",
  "2026-12-31": "Sylwester",
};

const pad = (n) => String(n).padStart(2, "0");
export const iso = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
export const parseDate = (s) => { const [y, m, d] = s.split("-").map(Number); return new Date(y, m - 1, d); };

const weekOf = (s) => { let w = null; for (const x of WEEKS) if (s >= x.s) w = x; return w; };
export const gymWeekLabel = (s) => (s >= WEEKS[0].s ? weekOf(s)?.n : null);

function gymFor(s, dow) {
  if (s === "2026-10-18") return { title: "Siłownia – obwód (start, lekko)", note: `${OBW} · 3 rundy, szukasz ciężarów` };
  const w = weekOf(s);
  if (!w) return null;
  const strength = (k) => ({ title: `Siłownia – ${SESS[k][0]}`, note: `${SESS[k][1]} · ${w.str}` });
  if (w.n.includes("święta")) {
    const k = { "2026-12-22": "A", "2026-12-23": "B", "2026-12-26": "C" }[s];
    return k ? strength(k) : null;
  }
  if (w.n.includes("test")) {
    const k = { "2026-12-29": "A", "2026-12-30": "B" }[s];
    if (!k) return null;
    const t = strength(k);
    t.title += " + test";
    return t;
  }
  const k = { 2: "A", 3: "B", 5: "C", 6: "I", 0: "O" }[dow];
  if (!k) return null;
  if (k === "I") return { title: "Siłownia – interwały", note: `10 min rozgrzewki, rowerek lub wioślarz: ${w.int}, 10 min spokojnie` };
  if (k === "O") return { title: "Siłownia – obwód", note: `${OBW} · ${w.obw}` };
  return strength(k);
}

function dayTemplate(s) {
  const dow = parseDate(s).getDay();
  const stan = s >= "2026-10-28" && s <= "2026-12-17";
  const gym = gymFor(s, dow);
  const weekend = dow === 0 || dow === 6;
  const T = [];
  const add = (time, dur, cat, title, note = "") => T.push({ time, dur, cat, title: title || CATS[cat].name, note });

  // Święta: lekko, bez nauki.
  if (s === "2026-12-24" || s === "2026-12-25") {
    add("9:30", 45, "food", "Spokojne śniadanie");
    add("12:00", 60, "life", "Długi spacer", "Zamiast siłowni – świeże powietrze");
    add("14:00", 60, "food", "Obiad");
    return T;
  }

  add(weekend ? "9:00" : "8:00", 45, "food", "Śniadanie – zrobić");
  switch (dow) {
    case 1:
      if (stan) add("9:00", 120, "stan", "Program Stanford");
      add("13:00", 45, "food", "Obiad – zrobić");
      add("14:30", 180, "atpl", "ATPL EASA", "3 h – dziś po południu, bo o 18:00 western");
      add("18:00", 90, "west", "Trening western");
      break;
    case 2:
      add("9:00", 120, "par", "PAR do PPL(A) FAA");
      if (gym) add("11:30", 75, "gym", gym.title, gym.note);
      add("13:30", 45, "food", "Obiad – zrobić");
      add("18:00", 180, "mech", "Projekt z mechaniki");
      break;
    case 3:
      if (stan) add("9:00", 120, "stan", "Program Stanford");
      if (gym) add("11:30", 75, "gym", gym.title, gym.note);
      add("13:30", 45, "food", "Obiad – zrobić");
      add("15:00", 60, "clean", "Sprzątanie mieszkania");
      add("18:00", 180, "atpl", "ATPL EASA");
      break;
    case 4:
      add("9:00", 120, "par", "PAR do PPL(A) FAA");
      add("12:00", 90, "west", "Trening western");
      add("14:00", 45, "food", "Obiad – zrobić");
      // Dziękczynienie i Sylwester: wieczór wolny
      if (!HOLIDAYS[s]) add("18:00", 180, "mech", "Projekt z mechaniki");
      else add("18:00", 120, "life", `${HOLIDAYS[s]} – wieczór wolny`, "Odpoczynek też jest w planie");
      break;
    case 5:
      if (stan) add("9:00", 120, "stan", "Program Stanford");
      if (gym) add("11:30", 75, "gym", gym.title, gym.note);
      add("13:30", 45, "food", "Obiad – zrobić");
      add("18:00", 180, "atpl", "ATPL EASA");
      break;
    case 6:
      add("10:00", 120, "par", "PAR do PPL(A) FAA");
      if (gym) add("12:30", 75, "gym", gym.title, gym.note);
      add("14:30", 45, "food", "Obiad – zrobić");
      add("16:00", 60, "clean", "Sprzątanie mieszkania");
      break;
    case 0:
      add("10:00", 120, "par", "PAR do PPL(A) FAA");
      if (gym) add("12:30", 75, "gym", gym.title, gym.note);
      add("14:30", 45, "food", "Obiad – zrobić");
      add("19:00", 20, "life", "Przegląd tygodnia", "Co poszło dobrze? Co przesunąć na kolejny tydzień?");
      break;
  }
  return T;
}

export function buildSeed() {
  const out = [];
  for (let d = parseDate(PLAN_START); iso(d) <= PLAN_END; d.setDate(d.getDate() + 1)) {
    const s = iso(d);
    dayTemplate(s).forEach((t, i) => {
      const [h, m] = t.time.split(":");
      out.push({ id: `${s}-${i}`, date: s, ...t, time: `${pad(h)}:${m}`, done: false });
    });
  }
  return out;
}
