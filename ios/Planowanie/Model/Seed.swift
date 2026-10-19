import Foundation

/// Plan startowy 17 października – 31 grudnia 2026 (ten sam co w wersji web, data.js).
enum Seed {
    static let start = "2026-10-17"
    static let end = "2026-12-31"

    static let holidays: [String: String] = [
        "2026-11-26": "Święto Dziękczynienia",
        "2026-12-24": "Wigilia",
        "2026-12-25": "Boże Narodzenie",
        "2026-12-26": "Drugi dzień świąt",
        "2026-12-31": "Sylwester",
    ]

    private static let sessions: [String: (String, String)] = [
        "A": ("Siła A – dół + plecy", "przysiad, wiosłowanie hantlem, hip thrust, wykroki chodzone, plank"),
        "B": ("Siła B – góra", "wyciskanie hantli, podciąganie/ściąganie, wyciskanie nad głowę, wiosłowanie na wyciągu, dead bug"),
        "C": ("Siła C – całe ciało", "martwy ciąg rumuński, przysiad bułgarski, wyciskanie sztangi, ściąganie wąsko, pallof, unoszenie nóg"),
    ]
    private static let circuit = "swing, goblet squat, pompki, wiosłowanie TRX, mountain climbers, farmer’s walk"

    private struct GymWeek {
        let s: String, n: String, str: String
        var int: String = "", obw: String = ""
    }

    private static let weeks: [GymWeek] = [
        GymWeek(s: "2026-10-19", n: "Tydz. 1", str: "4 serie główne, RIR 3", int: "8 × 30/60 s", obw: "3 rundy, 40/20"),
        GymWeek(s: "2026-10-26", n: "Tydz. 2", str: "+ciężar wg progresji, RIR 3", int: "9 × 30/60 s", obw: "3 rundy, 40/20"),
        GymWeek(s: "2026-11-02", n: "Tydz. 3", str: "RIR 2–3", int: "10 × 30/60 s", obw: "4 rundy, 40/20"),
        GymWeek(s: "2026-11-09", n: "Tydz. 4 · lżejszy", str: "ciężar −10%, serie −1", int: "6 × 30/60 s", obw: "2 rundy"),
        GymWeek(s: "2026-11-16", n: "Tydz. 5", str: "5 serii głównych, RIR 2", int: "8 × 40/80 s", obw: "4 rundy, 40/20"),
        GymWeek(s: "2026-11-23", n: "Tydz. 6", str: "RIR 2", int: "9 × 40/80 s", obw: "4 rundy, 40/20"),
        GymWeek(s: "2026-11-30", n: "Tydz. 7", str: "RIR 1–2", int: "10 × 40/80 s", obw: "4 rundy, 45/15"),
        GymWeek(s: "2026-12-07", n: "Tydz. 8 · lżejszy", str: "ciężar −10%, serie −1", int: "6 × 30/60 s", obw: "2 rundy"),
        GymWeek(s: "2026-12-14", n: "Tydz. 9", str: "główne 4×5–6, RIR 1–2", int: "6 × 60/60 s", obw: "4 rundy, 45/15"),
        GymWeek(s: "2026-12-21", n: "Tydz. 10 · święta", str: "krótko, bez dociskania"),
        GymWeek(s: "2026-12-28", n: "Tydz. 11 · test", str: "test: ciężar na 5 czystych powtórzeń, zapisz"),
    ]

    private static func weekOf(_ s: String) -> GymWeek? { weeks.last { s >= $0.s } }

    static func gymWeekLabel(_ s: String) -> String? {
        guard let first = weeks.first, s >= first.s, s <= end else { return nil }
        return weekOf(s)?.n
    }

    private static func gym(_ s: String, _ dow: Int) -> (title: String, note: String)? {
        if s == "2026-10-18" { return ("Siłownia – obwód (start, lekko)", "\(circuit) · 3 rundy, szukasz ciężarów") }
        guard let w = weekOf(s) else { return nil }
        func strength(_ k: String) -> (title: String, note: String) {
            let x = sessions[k]!
            return ("Siłownia – \(x.0)", "\(x.1) · \(w.str)")
        }
        if w.n.contains("święta") {
            guard let k = ["2026-12-22": "A", "2026-12-23": "B", "2026-12-26": "C"][s] else { return nil }
            return strength(k)
        }
        if w.n.contains("test") {
            guard let k = ["2026-12-29": "A", "2026-12-30": "B"][s] else { return nil }
            let t = strength(k)
            return (t.0 + " + test", t.1)
        }
        switch dow {
        case 2: return strength("A")
        case 3: return strength("B")
        case 5: return strength("C")
        case 6: return ("Siłownia – interwały", "10 min rozgrzewki, rowerek lub wioślarz: \(w.int), 10 min spokojnie")
        case 0: return ("Siłownia – obwód", "\(circuit) · \(w.obw)")
        default: return nil
        }
    }

    static func tasks(for s: String) -> [TaskItem] {
        let dow = Day.weekday(s)
        let stanford = s >= "2026-10-28" && s <= "2026-12-17"
        let g = gym(s, dow)
        let weekend = dow == 0 || dow == 6
        var out: [TaskItem] = []
        func add(_ time: String, _ dur: Int, _ cat: Category, _ title: String? = nil, _ note: String = "") {
            let id = "\(s)-\(out.count)"
            let steps = defaultSteps(cat, dur).enumerated().map { Step(id: "\(id)-s\($0.offset)", title: $0.element) }
            out.append(TaskItem(id: id, date: s, time: time, dur: dur, cat: cat, title: title ?? cat.name, note: note, steps: steps))
        }

        // Święta: lekko, bez nauki.
        if s == "2026-12-24" || s == "2026-12-25" {
            add("09:30", 45, .food, "Spokojne śniadanie")
            add("12:00", 60, .life, "Długi spacer", "Zamiast siłowni – świeże powietrze")
            add("14:00", 60, .food, "Obiad")
            return out
        }

        add(weekend ? "09:00" : "08:00", 45, .food, "Śniadanie – zrobić")
        switch dow {
        case 1:
            if stanford { add("09:00", 120, .stan) }
            add("13:00", 45, .food, "Obiad – zrobić")
            add("14:30", 180, .atpl, nil, "3 h – dziś po południu, bo o 18:00 western")
            add("18:00", 90, .west)
        case 2:
            add("09:00", 120, .par)
            if let g { add("11:30", 75, .gym, g.title, g.note) }
            add("13:30", 45, .food, "Obiad – zrobić")
            add("18:00", 180, .mech)
        case 3:
            if stanford { add("09:00", 120, .stan) }
            if let g { add("11:30", 75, .gym, g.title, g.note) }
            add("13:30", 45, .food, "Obiad – zrobić")
            add("15:00", 60, .clean, "Sprzątanie mieszkania")
            add("18:00", 180, .atpl)
        case 4:
            add("09:00", 120, .par)
            add("12:00", 90, .west)
            add("14:00", 45, .food, "Obiad – zrobić")
            if let h = holidays[s] {
                add("18:00", 120, .life, "\(h) – wieczór wolny", "Odpoczynek też jest w planie")
            } else {
                add("18:00", 180, .mech)
            }
        case 5:
            if stanford { add("09:00", 120, .stan) }
            if let g { add("11:30", 75, .gym, g.title, g.note) }
            add("13:30", 45, .food, "Obiad – zrobić")
            add("18:00", 180, .atpl)
        case 6:
            add("10:00", 120, .par)
            if let g { add("12:30", 75, .gym, g.title, g.note) }
            add("14:30", 45, .food, "Obiad – zrobić")
            add("16:00", 60, .clean, "Sprzątanie mieszkania")
        default:
            add("10:00", 120, .par)
            if let g { add("12:30", 75, .gym, g.title, g.note) }
            add("14:30", 45, .food, "Obiad – zrobić")
            add("19:00", 20, .life, "Przegląd tygodnia", "Co poszło dobrze? Co przesunąć na kolejny tydzień?")
        }
        return out
    }

    /// Duże bloki rozbite na małe kroki: łatwiej zacząć i widać postęp.
    static func defaultSteps(_ cat: Category, _ dur: Int) -> [String] {
        switch cat {
        case .atpl, .par, .mech, .stan:
            let prep = "Przygotuj miejsce: woda, telefon na bok"
            let end = "Zapisz, na czym kończysz"
            return dur >= 180
                ? [prep, "Blok 1 – 50 min", "Przerwa 10 min – wstań i się rozciągnij", "Blok 2 – 50 min", "Przerwa 10 min", "Blok 3 – 50 min", end]
                : [prep, "Blok 1 – 50 min", "Przerwa 10 min – wstań i się rozciągnij", "Blok 2 – 50 min", end]
        case .gym:
            return ["Ubierz się i spakuj wodę", "Rozgrzewka 10 min", "Trening główny", "Rozciąganie 5 min"]
        case .clean:
            return ["Włącz ulubioną muzykę 🎵", "Zbierz rzeczy z podłogi", "Kuchnia i zlew", "Odkurzanie", "Wynieś śmieci"]
        case .west:
            return ["Przygotuj strój i sprzęt"]
        case .food, .life:
            return []
        }
    }

    static func build() -> [TaskItem] {
        var out: [TaskItem] = []
        var s = start
        while s <= end {
            out += tasks(for: s)
            s = Day.add(s, 1)
        }
        return out
    }
}
