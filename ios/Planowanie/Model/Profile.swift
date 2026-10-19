import Foundation

/// Profil użytkownika na tym urządzeniu. Każdy profil ma własny plan zadań.
struct Profile: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var emoji: String
    var color: UInt32
    /// Profil chroniony Face ID / kodem telefonu.
    var locked = false

    init(id: String, name: String, emoji: String, color: UInt32, locked: Bool = false) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.color = color
        self.locked = locked
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        emoji = try c.decode(String.self, forKey: .emoji)
        color = try c.decode(UInt32.self, forKey: .color)
        locked = try c.decodeIfPresent(Bool.self, forKey: .locked) ?? false
    }

    static let emojis = ["🙂", "😊", "🌸", "🌿", "✈️", "🐎", "💪", "📚", "🎓", "⭐️", "🌙", "☀️", "🦋", "🐱", "🐶", "🍀"]
    static let colors: [UInt32] = [0xE07A5F, 0x4F7BD9, 0x18A08C, 0x8A63D2, 0xD06A8A, 0xE09A2D, 0x4C9F3A, 0x6F8FA6]
}
