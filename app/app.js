import { DEFAULT_CATS, FALLBACK_CAT, iso, parseDate, starterTasks } from "./data.js";
import * as cloud from "./cloud.js";

const LOCAL_KEY = "planowanie.v1";          // plan bez konta
const userKey = (id) => `planowanie.v1:${id}`; // plan konta (kopia na tym urządzeniu)
const DEVICE_KEY = "planowanie.device";     // ustawienia tego urządzenia
const DOW_SHORT = ["nd", "pn", "wt", "śr", "cz", "pt", "sb"];
const DOW = ["Niedziela", "Poniedziałek", "Wtorek", "Środa", "Czwartek", "Piątek", "Sobota"];
const MON = ["stycznia", "lutego", "marca", "kwietnia", "maja", "czerwca", "lipca", "sierpnia", "września", "października", "listopada", "grudnia"];
const CHEERS = ["Brawo! ✨", "Jedno z głowy 💪", "Tak trzymaj!", "Pięknie idzie 🌟", "Kolejne odhaczone ✓", "Super robota!"];

const $ = (id) => document.getElementById(id);

// ---------- stan ----------
// state: plan (zadania + kategorie) – synchronizowany z kontem.
// device: ustawienia tego urządzenia (powiadomienia, wygląd) – nie są synchronizowane.
let user = null;
let storageKey = LOCAL_KEY;
let state = freshPlan();
let device = loadDevice();
let CATS = DEFAULT_CATS;
const cat = (k) => CATS[k] || FALLBACK_CAT;

function freshPlan() { return { tasks: starterTasks(), cats: { ...DEFAULT_CATS }, notified: {} }; }
function normalize(s) {
  if (!s || !Array.isArray(s.tasks)) return null;
  return { notified: {}, ...s, cats: { ...DEFAULT_CATS, ...(s.cats || {}) } };
}
function readJSON(key) { try { return JSON.parse(localStorage.getItem(key)); } catch { return null; } }
function loadDevice() {
  const d = readJSON(DEVICE_KEY) || {};
  // starsze wersje trzymały ustawienia razem z planem
  const legacy = readJSON(LOCAL_KEY)?.settings || {};
  return { notify: false, lead: 10, morning: "07:30", bannerDismissed: false, theme: "auto", localOnly: false, ...legacy, ...d };
}
function saveDevice() { try { localStorage.setItem(DEVICE_KEY, JSON.stringify(device)); } catch {} }
function usePlan(s, key) {
  state = normalize(s) || freshPlan();
  storageKey = key;
  CATS = state.cats;
  saveLocal();
  fillCategories();
}
/** Zapis tylko na urządzeniu (np. które powiadomienia już wysłano). */
function saveLocal() { try { localStorage.setItem(storageKey, JSON.stringify(state)); } catch {} }
/** Zmiana planu: zapis na urządzeniu i – z kontem – wysłanie na serwer. */
function save() {
  if (user) state.dirty = true;
  saveLocal();
  if (user) schedulePush();
}

const todayIso = () => iso(new Date());
let selected = todayIso();
let view = "day";

const toMin = (t) => { const [h, m] = t.split(":").map(Number); return h * 60 + m; };
const fmtMin = (m) => `${String(Math.floor(m / 60) % 24).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`;
const durTxt = (d) => (d >= 60 ? `${Math.floor(d / 60)} h${d % 60 ? ` ${d % 60}` : ""}` : `${d} min`);
const tasksOn = (s) => state.tasks.filter((t) => t.date === s).sort((a, b) => a.time.localeCompare(b.time));
const startOfWeek = (s) => { const d = parseDate(s); d.setDate(d.getDate() - ((d.getDay() + 6) % 7)); return d; };
const addDays = (s, n) => { const d = parseDate(s); d.setDate(d.getDate() + n); return iso(d); };
const escapeHtml = (s) => s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

// ---------- widok dnia ----------
function renderHeader() {
  const h = new Date().getHours();
  const name = user?.user_metadata?.name;
  const hello = h < 5 ? "Dobranoc" : h < 12 ? "Dzień dobry" : h < 18 ? "Miłego popołudnia" : "Dobry wieczór";
  $("greet").textContent = `${hello}${name ? `, ${name}` : ""} ${h < 5 || h >= 18 ? "🌙" : h < 12 ? "☀️" : "🌤"}`;
  const d = parseDate(selected);
  const rel = selected === todayIso() ? "Dziś" : selected === addDays(todayIso(), 1) ? "Jutro" : selected === addDays(todayIso(), -1) ? "Wczoraj" : DOW[d.getDay()];
  $("title").textContent = view === "day" ? `${rel}, ${d.getDate()} ${MON[d.getMonth()]}` : view === "week" ? "Twój tydzień" : "Ustawienia";
  const T = tasksOn(selected), done = T.filter((t) => t.done).length;
  const pct = T.length ? Math.round((done / T.length) * 100) : 0;
  $("ringFg").style.strokeDashoffset = String(119.4 * (1 - pct / 100));
  $("ringFg").style.opacity = pct ? "1" : "0";
  $("ringTxt").textContent = `${pct}%`;
  $("ring").hidden = view === "settings";
}

function renderStrip() {
  const strip = $("strip"); strip.innerHTML = "";
  const start = startOfWeek(selected), t = todayIso();
  for (let i = 0; i < 7; i++) {
    const d = new Date(start); d.setDate(d.getDate() + i);
    const s = iso(d), T = tasksOn(s);
    const b = document.createElement("button");
    b.type = "button"; b.setAttribute("role", "tab"); b.setAttribute("aria-selected", s === selected);
    b.className = (s === t ? "today " : "") + (s < t ? "past" : "");
    const cats = [...new Set(T.map((x) => x.cat))].slice(0, 4);
    b.innerHTML = `<span class="dw">${DOW_SHORT[d.getDay()]}</span><span class="dn">${d.getDate()}</span><span class="dots">${cats.map((c) => `<i style="background:${cat(c).color}"></i>`).join("")}</span>`;
    b.onclick = () => { selected = s; render(); };
    strip.appendChild(b);
  }
}

function currentAndNext() {
  if (selected !== todayIso()) return {};
  const now = new Date(), m = now.getHours() * 60 + now.getMinutes();
  const T = tasksOn(selected).filter((t) => !t.done);
  const cur = T.find((t) => toMin(t.time) <= m && m < toMin(t.time) + t.dur);
  const next = T.find((t) => toMin(t.time) > m);
  return { cur, next, m };
}

function renderNextCard() {
  const card = $("nextCard");
  const { cur, next, m } = currentAndNext();
  const T = tasksOn(selected);
  if (selected === todayIso() && T.length && T.every((t) => t.done)) {
    card.hidden = false; card.style.background = "linear-gradient(135deg,#4C9F3A,#18A08C)";
    card.innerHTML = `<div class="k">Dzień zamknięty</div><div class="t">Wszystko zrobione 🎉</div><div class="m">Reszta dnia jest Twoja.</div>`;
    return;
  }
  const t = cur || next;
  if (!t) { card.hidden = true; return; }
  const c = cat(t.cat).color || "#888";
  card.hidden = false;
  card.style.background = `linear-gradient(135deg, ${c}, color-mix(in srgb, ${c} 70%, #000))`;
  const left = cur ? toMin(t.time) + t.dur - m : toMin(t.time) - m;
  const when = cur ? `jeszcze ${durTxt(left)}` : left < 60 ? `za ${left} min` : `o ${t.time} · za ${durTxt(left)}`;
  card.innerHTML = `<div class="k">${cur ? "Teraz" : "Następne"}</div><div class="t">${cat(t.cat).icon || ""} ${escapeHtml(t.title)}</div><div class="m">${when}</div>`;
}

function renderTimeline() {
  const ol = $("timeline"); ol.innerHTML = "";
  const T = tasksOn(selected);
  $("empty").hidden = T.length > 0;
  const { cur } = currentAndNext();
  T.forEach((t, i) => {
    const li = document.createElement("li");
    li.className = "task" + (t.done ? " done" : "") + (cur && cur.id === t.id ? " now" : "");
    li.style.setProperty("--c", cat(t.cat).color || "#888");
    li.style.animationDelay = `${i * 30}ms`;
    li.innerHTML = `
      <div class="tm">${t.time}<small>${durTxt(t.dur)}</small></div>
      <div><div class="tt">${escapeHtml(t.title)}</div>${t.note ? `<div class="tn">${escapeHtml(t.note)}</div>` : ""}</div>
      <button class="check" type="button" aria-label="${t.done ? "Odznacz" : "Oznacz jako zrobione"}: ${escapeHtml(t.title)}"></button>`;
    li.querySelector(".check").onclick = (e) => { e.stopPropagation(); toggle(t); };
    li.onclick = () => openSheet(t);
    ol.appendChild(li);
  });
}

function toggle(t) {
  t.done = !t.done; save();
  if (t.done) {
    const T = tasksOn(t.date);
    if (T.every((x) => x.done)) { toast("Cały dzień odhaczony! 🎉"); confetti(); }
    else toast(CHEERS[Math.floor(Math.random() * CHEERS.length)]);
    navigator.vibrate?.(15);
  }
  render();
}

// ---------- widok tygodnia ----------
function renderWeek() {
  const start = startOfWeek(selected), box = $("week"); box.innerHTML = "";
  const end = new Date(start); end.setDate(end.getDate() + 6);
  $("weekTitle").textContent = `${start.getDate()} ${MON[start.getMonth()].slice(0, 3)} – ${end.getDate()} ${MON[end.getMonth()].slice(0, 3)}`;
  for (let i = 0; i < 7; i++) {
    const d = new Date(start); d.setDate(d.getDate() + i);
    const s = iso(d), T = tasksOn(s), done = T.filter((t) => t.done).length;
    const el = document.createElement("div");
    el.className = "wday" + (s === todayIso() ? " today" : "");
    el.innerHTML = `<div class="wday-h"><b>${DOW[d.getDay()]} <span>${d.getDate()} ${MON[d.getMonth()].slice(0, 3)}</span></b><span>${done}/${T.length}</span></div>
      <div class="chips">${T.map((t) => `<span class="chip${t.done ? " done" : ""}" style="--c:${cat(t.cat).color}">${t.time} ${escapeHtml(t.title.split(" – ")[0])}</span>`).join("") || '<span class="chip" style="--c:#6F8FA6">wolne</span>'}</div>
      <div class="bar"><i style="width:${T.length ? (done / T.length) * 100 : 0}%"></i></div>`;
    el.onclick = () => { selected = s; setView("day"); };
    box.appendChild(el);
  }
}

// ---------- ustawienia ----------
function renderSettings() {
  const st = device;
  $("setNotify").checked = st.notify && notifPermission() === "granted";
  $("setLead").value = String(st.lead);
  $("setMorning").value = st.morning;
  const p = notifPermission();
  $("notifyHint").textContent =
    p === "unsupported" ? "Ta przeglądarka nie obsługuje powiadomień. Na iPhonie dodaj aplikację do ekranu początkowego i otwórz ją stamtąd – albo użyj eksportu do kalendarza poniżej."
    : p === "denied" ? "Powiadomienia są zablokowane w ustawieniach przeglądarki. Odblokuj je dla tej strony albo użyj eksportu do kalendarza."
    : isDesktop ? "Przypomnienia przychodzą, dopóki aplikacja działa – także po zamknięciu okna (ikona w zasobniku / na pasku menu). W menu ikony możesz włączyć uruchamianie przy starcie komputera."
    : "Przypomnienia przychodzą, gdy aplikacja jest otwarta lub działa w tle. Żeby mieć 100% pewności przy zamkniętej aplikacji, dodaj też plan do kalendarza.";
}

function render() {
  renderHeader();
  if (view === "day") { renderStrip(); renderNextCard(); renderTimeline(); renderBanner(); }
  if (view === "week") renderWeek();
  if (view === "settings") renderSettings();
}

function setView(v) {
  view = v;
  for (const id of ["day", "week", "settings"]) $(`view-${id}`).hidden = id !== v;
  document.querySelectorAll(".tabs button").forEach((b) => {
    if (b.dataset.view === v) b.setAttribute("aria-current", "page"); else b.removeAttribute("aria-current");
  });
  $("fab").hidden = v === "settings";
  render();
  window.scrollTo({ top: 0 });
}

// ---------- edycja zadania ----------
let editing = null;
function openSheet(t) {
  editing = t || null;
  const f = $("taskForm");
  $("sheetTitle").textContent = t ? "Edytuj zadanie" : "Nowe zadanie";
  f.title.value = t?.title || "";
  f.date.value = t?.date || selected;
  f.time.value = t?.time || nextFreeTime();
  f.dur.value = String(t?.dur || 60);
  f.cat.value = t?.cat || "life";
  f.note.value = t?.note || "";
  f.repeat.checked = false;
  $("repeatRow").hidden = !!t;
  $("delBtn").hidden = !t;
  $("sheet").showModal();
  if (!t) setTimeout(() => f.title.focus(), 50);
}
function nextFreeTime() {
  const now = new Date();
  if (selected !== todayIso()) return "10:00";
  return fmtMin(Math.min(23 * 60, Math.ceil((now.getHours() * 60 + now.getMinutes() + 15) / 15) * 15));
}

$("taskForm").addEventListener("submit", (e) => {
  e.preventDefault();
  const f = e.target;
  const data = { title: f.title.value.trim(), date: f.date.value, time: f.time.value, dur: Number(f.dur.value), cat: f.cat.value, note: f.note.value.trim() };
  if (!data.title || !data.date || !data.time) return;
  if (editing) {
    if (editing.date !== data.date || editing.time !== data.time) delete state.notified[editing.id];
    Object.assign(editing, data);
    toast("Zapisano");
  } else {
    let s = data.date, n = 0;
    do {
      state.tasks.push({ ...data, date: s, id: `u${Date.now().toString(36)}${n}`, done: false });
      s = addDays(s, 7); n++;
    } while (f.repeat.checked && n < 12);
    toast(n > 1 ? `Dodano ${n} powtórzeń` : "Dodano zadanie");
  }
  save(); $("sheet").close(); selected = data.date; render();
});
$("cancelBtn").onclick = () => $("sheet").close();
$("delBtn").onclick = () => {
  if (!editing || !confirm(`Usunąć „${editing.title}”?`)) return;
  state.tasks = state.tasks.filter((t) => t !== editing);
  save(); $("sheet").close(); toast("Usunięto"); render();
};
$("sheet").addEventListener("click", (e) => { if (e.target === $("sheet")) $("sheet").close(); });

// ---------- powiadomienia ----------
let swReg = null;
const isDesktop = !!window.desktop;
const saveSettings = saveDevice;
if (isDesktop) document.documentElement.classList.add("desktop");
if ("serviceWorker" in navigator && !isDesktop) {
  navigator.serviceWorker.register("sw.js").then((r) => { swReg = r; }).catch(() => {});
}
function notifPermission() { return "Notification" in window ? Notification.permission : "unsupported"; }

async function enableNotifications() {
  if (notifPermission() === "unsupported") { toast("Brak obsługi powiadomień – użyj kalendarza"); setView("settings"); return false; }
  const p = await Notification.requestPermission();
  device.notify = p === "granted"; saveSettings();
  if (p === "granted") { toast("Przypomnienia włączone 🔔"); notify("Gotowe! 🔔", "Będę przypominać o zadaniach przed czasem."); checkReminders(); }
  else toast("Bez zgody nie mogę wysyłać powiadomień");
  render();
  return p === "granted";
}

async function notify(title, body, tag) {
  if (notifPermission() !== "granted") return;
  const opts = { body, tag, icon: "icon-192.png", badge: "icon-192.png", lang: "pl", renotify: !!tag };
  if (!isDesktop) {
    try {
      // `ready` nigdy się nie rozwiąże bez service workera, więc czekamy najwyżej sekundę.
      const reg = swReg || (await Promise.race([navigator.serviceWorker?.ready, new Promise((r) => setTimeout(r, 1000))]));
      if (reg) return reg.showNotification(title, opts);
    } catch {}
  }
  try {
    const n = new Notification(title, opts);
    n.onclick = () => (window.desktop ? window.desktop.show() : window.focus());
  } catch {}
}

function checkReminders() {
  const st = device;
  if (!st.notify || notifPermission() !== "granted") return;
  const now = new Date(), s = iso(now), m = now.getHours() * 60 + now.getMinutes();
  let changed = false;

  // poranne podsumowanie
  const mk = `morning-${s}`;
  if (st.morning && m >= toMin(st.morning) && m < toMin(st.morning) + 120 && !state.notified[mk]) {
    const T = tasksOn(s);
    const main = T.map((t) => `${t.time} ${t.title.split(" – ")[0]}`);
    notify(`Dzień dobry! Dziś ${T.length} ${T.length === 1 ? "zadanie" : T.length < 5 ? "zadania" : "zadań"} ☀️`, main.join(" · ") || "Spokojny dzień", mk);
    state.notified[mk] = 1; changed = true;
  }

  for (const t of tasksOn(s)) {
    if (t.done || state.notified[t.id]) continue;
    const start = toMin(t.time);
    if (m >= start - st.lead && m < start + 10) {
      const left = start - m;
      const when = left > 0 ? `Za ${left} min` : "Teraz";
      notify(`${cat(t.cat).icon || "⏰"} ${when}: ${t.title}`, `${t.time}–${fmtMin(start + t.dur)}${t.note ? ` · ${t.note}` : ""}`, t.id);
      toast(`${when}: ${t.title}`);
      state.notified[t.id] = 1; changed = true;
    }
  }
  // sprzątanie starych wpisów
  for (const k of Object.keys(state.notified)) {
    const d = k.startsWith("morning-") ? k.slice(8) : k.slice(0, 10);
    if (/^\d{4}-\d\d-\d\d$/.test(d) && d < addDays(s, -3)) { delete state.notified[k]; changed = true; }
  }
  if (changed) saveLocal();
}

function renderBanner() {
  const show = !device.bannerDismissed && notifPermission() === "default" && !device.notify;
  $("notifyBanner").hidden = !show;
}
$("bannerOn").onclick = () => enableNotifications();
$("bannerLater").onclick = () => { device.bannerDismissed = true; saveSettings(); render(); };

$("setNotify").onchange = async (e) => {
  if (e.target.checked) { if (!(await enableNotifications())) e.target.checked = false; }
  else { device.notify = false; saveSettings(); toast("Przypomnienia wyłączone"); }
};
$("setLead").onchange = (e) => { device.lead = Number(e.target.value); saveSettings(); };
$("setMorning").onchange = (e) => { device.morning = e.target.value; saveSettings(); };
$("testNotify").onclick = async () => {
  if (notifPermission() !== "granted" && !(await enableNotifications())) return;
  notify("⏰ Za 10 min: Twoje zadanie", "Tak będą wyglądały przypomnienia 🙂", "test");
};

// ---------- eksport ----------
function download(name, text, type) {
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob([text], { type }));
  a.download = name; document.body.appendChild(a); a.click();
  setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
}
const icsEsc = (s) => s.replace(/\\/g, "\\\\").replace(/\n/g, "\\n").replace(/([,;])/g, "\\$1");
const icsDT = (date, min) => `${date.replace(/-/g, "")}T${fmtMin(min).replace(":", "")}00`;
function fold(line) {
  const out = []; let cur = "";
  for (const ch of line) {
    if (new TextEncoder().encode(cur + ch).length > 73) { out.push(cur); cur = " " + ch; } else cur += ch;
  }
  return [...out, cur].join("\r\n");
}

$("exportIcs").onclick = () => {
  const from = todayIso(), lead = device.lead;
  const stamp = new Date().toISOString().replace(/[-:]/g, "").replace(/\.\d+/, "");
  const L = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Planowanie//PL", "CALSCALE:GREGORIAN", "X-WR-CALNAME:Planowanie"];
  const T = state.tasks.filter((t) => t.date >= from && !t.done).sort((a, b) => (a.date + a.time).localeCompare(b.date + b.time));
  for (const t of T) {
    const s = toMin(t.time);
    L.push("BEGIN:VEVENT", `UID:${t.id}@planowanie`, `DTSTAMP:${stamp}`,
      `DTSTART:${icsDT(t.date, s)}`, `DTEND:${s + t.dur >= 1440 ? icsDT(addDays(t.date, 1), s + t.dur - 1440) : icsDT(t.date, s + t.dur)}`,
      fold(`SUMMARY:${icsEsc(`${cat(t.cat).icon || ""} ${t.title}`.trim())}`),
      ...(t.note ? [fold(`DESCRIPTION:${icsEsc(t.note)}`)] : []),
      `CATEGORIES:${icsEsc(cat(t.cat).name || "Inne")}`,
      "BEGIN:VALARM", "ACTION:DISPLAY", fold(`DESCRIPTION:${icsEsc(t.title)}`), `TRIGGER:-PT${lead}M`, "END:VALARM",
      "END:VEVENT");
  }
  L.push("END:VCALENDAR");
  download("planowanie.ics", L.join("\r\n") + "\r\n", "text/calendar");
  toast(`Wyeksportowano ${T.length} wydarzeń 📅`);
};
$("exportJson").onclick = () => download(`planowanie-kopia-${todayIso()}.json`,
  JSON.stringify({ version: 2, cats: state.cats, tasks: state.tasks }, null, 1), "application/json");
$("importJson").onchange = async (e) => {
  const file = e.target.files[0]; if (!file) return;
  try {
    const s = normalize(JSON.parse(await file.text()));
    if (!s) throw 0;
    if (state.tasks.length && !confirm(`Zastąpić obecny plan planem z pliku (${s.tasks.length} zadań)?`)) return;
    state.tasks = s.tasks; state.cats = s.cats; state.notified = {};
    CATS = state.cats; fillCategories(); save(); toast("Wczytano plan 📥"); render();
  } catch { toast("To nie jest poprawna kopia planu"); }
  finally { e.target.value = ""; }
};
$("resetPlan").onclick = () => {
  if (!confirm("Usunąć wszystkie zadania z planu? Tego nie da się cofnąć.")) return;
  state.tasks = []; state.notified = {}; save(); toast("Plan wyczyszczony"); render();
};

// ---------- drobiazgi ----------
let toastTimer;
function toast(msg) {
  const el = $("toast"); el.textContent = msg; el.classList.add("show");
  clearTimeout(toastTimer); toastTimer = setTimeout(() => el.classList.remove("show"), 2200);
}

function confetti() {
  if (matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  const cv = $("confetti"), ctx = cv.getContext("2d"), dpr = devicePixelRatio || 1;
  cv.width = innerWidth * dpr; cv.height = innerHeight * dpr; ctx.scale(dpr, dpr);
  const colors = Object.values(CATS).map((c) => c.color);
  const P = Array.from({ length: 140 }, () => ({
    x: innerWidth / 2 + (Math.random() - .5) * 80, y: innerHeight * .35, vx: (Math.random() - .5) * 11, vy: -Math.random() * 11 - 4,
    r: Math.random() * 6 + 4, c: colors[Math.floor(Math.random() * colors.length)], a: Math.random() * 6, va: (Math.random() - .5) * .3,
  }));
  let f = 0;
  (function tick() {
    ctx.clearRect(0, 0, innerWidth, innerHeight);
    for (const p of P) {
      p.vy += .32; p.vx *= .99; p.x += p.vx; p.y += p.vy; p.a += p.va;
      ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.a); ctx.fillStyle = p.c; ctx.fillRect(-p.r / 2, -p.r / 4, p.r, p.r / 2); ctx.restore();
    }
    if (++f < 150) requestAnimationFrame(tick); else ctx.clearRect(0, 0, innerWidth, innerHeight);
  })();
}

// ---------- start ----------
function fillCategories() {
  $("catSelect").innerHTML = Object.entries(CATS).map(([k, c]) => `<option value="${k}">${c.icon} ${escapeHtml(c.name)}</option>`).join("");
  $("legend").innerHTML = Object.values(CATS).map((c) => `<span><i style="background:${c.color}"></i>${escapeHtml(c.name)}</span>`).join("");
}
document.querySelectorAll(".tabs button").forEach((b) => (b.onclick = () => setView(b.dataset.view)));
$("fab").onclick = () => openSheet();
const shift = (n) => { selected = addDays(selected, n); render(); };
$("prevWeek").onclick = $("prevWeek2").onclick = () => shift(-7);
$("nextWeek").onclick = $("nextWeek2").onclick = () => shift(7);

let lastDay = todayIso();
setInterval(() => {
  checkReminders();
  if (todayIso() !== lastDay) { if (selected === lastDay) selected = todayIso(); lastDay = todayIso(); }
  if (view === "day" && !$("sheet").open) { renderHeader(); renderNextCard(); }
}, 20000);
document.addEventListener("visibilitychange", () => {
  if (document.hidden) return;
  checkReminders();
  render();
  if (user) pullNow();
});

// ---------- wygląd ----------
function applyTheme() {
  if (device.theme === "auto") delete document.documentElement.dataset.theme;
  else document.documentElement.dataset.theme = device.theme;
  document.querySelectorAll("#themeSeg button").forEach((b) => b.setAttribute("aria-checked", b.dataset.theme === device.theme));
  document.querySelectorAll("#themeSeg button").forEach((b) => b.setAttribute("aria-selected", b.dataset.theme === device.theme));
}
document.querySelectorAll("#themeSeg button").forEach((b) => (b.onclick = () => { device.theme = b.dataset.theme; saveSettings(); applyTheme(); }));

// ---------- konto i synchronizacja ----------
const EMAIL_RE = /^\S+@\S+\.\S+$/;
let pushTimer = null;
let syncState = "ok"; // ok | pending | offline | error

function setSync(st) {
  syncState = st;
  const el = $("syncStatus");
  el.className = "sync" + (st === "offline" ? " off" : st === "error" ? " err" : "");
  el.textContent = {
    ok: "Plan zapisany na koncie",
    pending: "Zapisuję…",
    offline: "Brak internetu – zapiszę, gdy wróci",
    error: "Nie udało się zapisać – spróbuję ponownie",
  }[st];
}

function schedulePush() {
  setSync("pending");
  clearTimeout(pushTimer);
  pushTimer = setTimeout(pushNow, 1200);
}

/** Wysyła plan na konto – tylko gdy na tym urządzeniu coś się zmieniło (albo `force` dla nowego konta). */
async function pushNow(force = false) {
  if (!user || (!state.dirty && !force)) return;
  clearTimeout(pushTimer);
  const payload = { version: 2, cats: state.cats, tasks: state.tasks };
  try {
    state.syncedAt = await cloud.push(user.id, payload);
    state.dirty = false;
    saveLocal();
    setSync("ok");
  } catch {
    setSync(navigator.onLine ? "error" : "offline");
    pushTimer = setTimeout(pushNow, 30000);
  }
}

/** Pobiera plan z konta, jeśli inne urządzenie go zmieniło. */
async function pullNow() {
  if (!user) return;
  try {
    const remote = await cloud.pull(user.id);
    if (!remote) { await pushNow(true); return; }
    if (remote.updated_at === state.syncedAt) { if (state.dirty) await pushNow(); return; }
    // zmiany z tego urządzenia, których serwer jeszcze nie ma, są nowsze – wygrywa ostatni zapis
    if (state.dirty) { await pushNow(); return; }
    usePlan({ ...remote.data, syncedAt: remote.updated_at, dirty: false }, userKey(user.id));
    render();
    setSync("ok");
  } catch {
    setSync(navigator.onLine ? "error" : "offline");
  }
}

/** Po zalogowaniu: plan z konta, a jeśli konto jest nowe – plan z tego urządzenia. */
async function signedIn(u) {
  user = u;
  device.localOnly = false; saveSettings();
  const cached = normalize(readJSON(userKey(u.id)));
  let remote;
  try { remote = await cloud.pull(u.id); } catch { remote = undefined; }

  if (remote) {
    const offlineEdits = cached?.dirty && cached.syncedAt === remote.updated_at;
    usePlan(offlineEdits ? cached : { ...remote.data, syncedAt: remote.updated_at, dirty: false }, userKey(u.id));
    if (offlineEdits) pushNow(); else setSync("ok");
  } else if (remote === null) {
    // nowe konto: zabierz plan z tego urządzenia (sprzed logowania) albo zacznij od przykładowego
    usePlan(cached || readJSON(LOCAL_KEY) || freshPlan(), userKey(u.id));
    await pushNow(true);
  } else {
    usePlan(cached || freshPlan(), userKey(u.id));
    setSync("offline");
  }
  hideAuth();
  renderAccount();
  render();
}

function signedOut() {
  user = null;
  usePlan(readJSON(LOCAL_KEY), LOCAL_KEY);
  renderAccount();
  render();
  if (cloud.cloudEnabled) showAuth();
}

function renderAccount() {
  $("accountCard").hidden = !cloud.cloudEnabled;
  $("accountIn").hidden = !user;
  $("accountOut").hidden = !!user;
  if (user) {
    $("accName").textContent = user.user_metadata?.name || "Twoje konto";
    $("accEmail").textContent = user.email || "";
    setSync(syncState);
  }
  $("dataHint").textContent = user
    ? "Plan zapisuje się na Twoim koncie i jest taki sam na każdym urządzeniu. Kopia zapasowa to dodatkowo plik na dysku."
    : "Plan zapisuje się tylko na tym urządzeniu. Kopia zapasowa to plik, który przeniesiesz na inne.";
}

// --- ekran logowania ---
let authMode = "in";
function showAuth(mode = authMode) {
  setAuthMode(mode);
  $("auth").hidden = false;
  setTimeout(() => $("authForm").email.focus(), 50);
}
function hideAuth() { $("auth").hidden = true; authMsg(""); }
function setAuthMode(mode) {
  authMode = mode;
  const up = mode === "up";
  $("tabIn").setAttribute("aria-selected", !up);
  $("tabUp").setAttribute("aria-selected", up);
  $("nameRow").hidden = !up;
  $("authSubmit").textContent = up ? "Załóż konto" : "Zaloguj się";
  $("authForm").password.autocomplete = up ? "new-password" : "current-password";
  $("forgot").hidden = up;
  authMsg("");
}
function authMsg(text, ok = false) {
  const el = $("authMsg");
  el.textContent = text;
  el.classList.toggle("ok", ok);
}

$("tabIn").onclick = () => setAuthMode("in");
$("tabUp").onclick = () => setAuthMode("up");
$("authForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const f = e.target;
  const email = f.email.value.trim(), password = f.password.value, name = f.name.value.trim();
  if (!EMAIL_RE.test(email)) return authMsg("Wpisz poprawny adres e-mail.");
  if (password.length < 8) return authMsg("Hasło musi mieć co najmniej 8 znaków.");
  const btn = $("authSubmit");
  btn.disabled = true;
  try {
    if (authMode === "up") {
      const r = await cloud.signUp(email, password, name);
      if (r.needsConfirmation) {
        setAuthMode("in");
        f.email.value = email;
        authMsg("Prawie gotowe! Wysłaliśmy e-mail – kliknij link, a potem zaloguj się tutaj.", true);
      } else {
        await signedIn(r.user);
        toast("Konto założone 🎉");
      }
    } else {
      await signedIn(await cloud.signIn(email, password));
      toast("Zalogowano 👋");
    }
  } catch (err) {
    authMsg(cloud.friendlyError(err));
  } finally {
    btn.disabled = false;
  }
});
$("forgot").onclick = async () => {
  const email = $("authForm").email.value.trim();
  if (!EMAIL_RE.test(email)) return authMsg("Wpisz najpierw swój e-mail powyżej.");
  try {
    await cloud.resetPassword(email);
    authMsg("Wysłaliśmy link do ustawienia nowego hasła.", true);
  } catch (err) {
    authMsg(cloud.friendlyError(err));
  }
};
$("localOnly").onclick = () => { device.localOnly = true; saveSettings(); hideAuth(); renderAccount(); };
$("openAuth").onclick = () => showAuth("up");
$("signOutBtn").onclick = async () => {
  if (state.dirty) await pushNow();
  await cloud.signOut();
  signedOut();
  toast("Wylogowano");
};
$("syncNow").onclick = async () => { setSync("pending"); await pullNow(); if (syncState === "pending") setSync("ok"); };

cloud.onAuthChange(async (event, u) => {
  if (event === "PASSWORD_RECOVERY") {
    const pass = prompt("Wpisz nowe hasło (co najmniej 8 znaków):");
    if (pass && pass.length >= 8) {
      try { await cloud.setNewPassword(pass); toast("Hasło zmienione ✓"); } catch (err) { alert(cloud.friendlyError(err)); }
    }
  }
  if (event === "SIGNED_IN" && u && !user) await signedIn(u);
});
setInterval(() => { if (user && !document.hidden) pullNow(); }, 60000);
window.addEventListener("online", () => { if (user) pushNow(); });

// --- uruchomienie ---
async function boot() {
  applyTheme();
  usePlan(readJSON(LOCAL_KEY), LOCAL_KEY);
  const params = new URLSearchParams(location.search);
  if (params.get("view")) setView(params.get("view")); else render();
  renderAccount();
  checkReminders();
  if (!cloud.cloudEnabled) return;
  const u = await cloud.currentUser();
  if (u) await signedIn(u);
  else if (!device.localOnly || location.hash.startsWith("#konto")) showAuth(location.hash === "#konto-nowe" ? "up" : "in");
}
boot();
