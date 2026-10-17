import Foundation

/// Dni jako klucze „yyyy-MM-dd” w lokalnej strefie czasowej – tak samo jak w wersji web.
enum Day {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.locale = Locale(identifier: "pl_PL")
        return c
    }()

    static let weekdayNames = ["Niedziela", "Poniedziałek", "Wtorek", "Środa", "Czwartek", "Piątek", "Sobota"]
    static let weekdayShort = ["nd", "pn", "wt", "śr", "cz", "pt", "sb"]
    static let monthGenitive = ["stycznia", "lutego", "marca", "kwietnia", "maja", "czerwca", "lipca", "sierpnia", "września", "października", "listopada", "grudnia"]
    static let monthShort = ["sty", "lut", "mar", "kwi", "maj", "cze", "lip", "sie", "wrz", "paź", "lis", "gru"]

    static var today: String { key(Date()) }

    static func key(_ d: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 1, c.day ?? 1)
    }

    static func parts(_ k: String) -> (y: Int, m: Int, d: Int) {
        let p = k.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return (2026, 1, 1) }
        return (p[0], p[1], p[2])
    }

    static func date(_ k: String, minutes: Int = 0) -> Date {
        let p = parts(k)
        let start = calendar.date(from: DateComponents(year: p.y, month: p.m, day: p.d)) ?? Date()
        return calendar.date(byAdding: .minute, value: minutes, to: start) ?? start
    }

    static func add(_ k: String, _ n: Int) -> String {
        key(calendar.date(byAdding: .day, value: n, to: date(k)) ?? Date())
    }

    /// 0 = niedziela … 6 = sobota (jak getDay() w JS).
    static func weekday(_ k: String) -> Int { calendar.component(.weekday, from: date(k)) - 1 }

    static func startOfWeek(_ k: String) -> String { add(k, -((weekday(k) + 6) % 7)) }

    static func dayNumber(_ k: String) -> Int { parts(k).d }

    static func long(_ k: String) -> String {
        let p = parts(k)
        return "\(p.d) \(monthGenitive[p.m - 1])"
    }

    static func short(_ k: String) -> String {
        let p = parts(k)
        return "\(p.d) \(monthShort[p.m - 1])"
    }

    static func minutes(_ t: String) -> Int {
        let p = t.split(separator: ":").compactMap { Int($0) }
        return p.count == 2 ? p[0] * 60 + p[1] : 0
    }

    static func time(_ minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }

    static func time(from d: Date) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: d)
        return time((c.hour ?? 0) * 60 + (c.minute ?? 0))
    }

    static func nowMinutes(_ d: Date = Date()) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func duration(_ m: Int) -> String {
        if m < 60 { return "\(m) min" }
        return m % 60 == 0 ? "\(m / 60) h" : "\(m / 60) h \(m % 60)"
    }

    /// 1 zadanie, 2 zadania, 5 zadań
    static func tasksWord(_ n: Int) -> String {
        if n == 1 { return "zadanie" }
        let r10 = n % 10, r100 = n % 100
        return (2...4).contains(r10) && !(12...14).contains(r100) ? "zadania" : "zadań"
    }
}
