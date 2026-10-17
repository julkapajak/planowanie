import SwiftUI

enum Category: String, Codable, CaseIterable, Identifiable {
    case atpl, par, mech, stan, west, gym, food, clean, life

    var id: String { rawValue }

    var name: String {
        switch self {
        case .atpl: "ATPL EASA"
        case .par: "PAR do PPL(A) FAA"
        case .mech: "Projekt z mechaniki"
        case .stan: "Program Stanford"
        case .west: "Trening western"
        case .gym: "Siłownia"
        case .food: "Jedzenie"
        case .clean: "Sprzątanie"
        case .life: "Życie i odpoczynek"
        }
    }

    var symbol: String {
        switch self {
        case .atpl: "airplane"
        case .par: "airplane.departure"
        case .mech: "gearshape.2.fill"
        case .stan: "graduationcap.fill"
        case .west: "figure.equestrian.sports"
        case .gym: "dumbbell.fill"
        case .food: "fork.knife"
        case .clean: "sparkles"
        case .life: "leaf.fill"
        }
    }

    var emoji: String {
        switch self {
        case .atpl: "✈️"
        case .par: "🛩"
        case .mech: "⚙️"
        case .stan: "🎓"
        case .west: "🐎"
        case .gym: "💪"
        case .food: "🍳"
        case .clean: "🧹"
        case .life: "🌿"
        }
    }

    var color: Color {
        switch self {
        case .atpl: Color(hex: 0x4F7BD9)
        case .par: Color(hex: 0x18A08C)
        case .mech: Color(hex: 0x8A63D2)
        case .stan: Color(hex: 0xC8453F)
        case .west: Color(hex: 0xB07A3E)
        case .gym: Color(hex: 0x4C9F3A)
        case .food: Color(hex: 0xE09A2D)
        case .clean: Color(hex: 0xD06A8A)
        case .life: Color(hex: 0x6F8FA6)
        }
    }

    // Nieznana kategoria (np. z kopii z wersji web) nie psuje wczytywania.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Category(rawValue: raw) ?? .life
    }
}

struct TaskItem: Codable, Identifiable, Hashable {
    var id: String
    var date: String   // yyyy-MM-dd
    var time: String   // HH:mm
    var dur: Int       // minuty
    var cat: Category
    var title: String
    var note: String
    var done: Bool

    init(id: String = TaskItem.newID(), date: String, time: String, dur: Int, cat: Category, title: String, note: String = "", done: Bool = false) {
        self.id = id
        self.date = date
        self.time = time
        self.dur = dur
        self.cat = cat
        self.title = title
        self.note = note
        self.done = done
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        date = try c.decode(String.self, forKey: .date)
        time = try c.decode(String.self, forKey: .time)
        dur = try c.decodeIfPresent(Int.self, forKey: .dur) ?? 60
        cat = try c.decodeIfPresent(Category.self, forKey: .cat) ?? .life
        title = try c.decode(String.self, forKey: .title)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
    }

    static func newID() -> String { "u" + UUID().uuidString.prefix(8).lowercased() }

    var startMinutes: Int { Day.minutes(time) }
    var endMinutes: Int { startMinutes + dur }
    var startDate: Date { Day.date(date, minutes: startMinutes) }
    /// Krótka nazwa do podsumowań: „Siłownia – Siła A – …” → „Siłownia”.
    var shortTitle: String { title.components(separatedBy: " – ").first ?? title }
}
