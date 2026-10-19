import Foundation

/// Profil użytkownika na tym urządzeniu. Każdy profil ma własny plan zadań.
struct Profile: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var emoji: String
    var color: UInt32

    static let emojis = ["🙂", "😊", "🌸", "🌿", "✈️", "🐎", "💪", "📚", "🎓", "⭐️", "🌙", "☀️", "🦋", "🐱", "🐶", "🍀"]
    static let colors: [UInt32] = [0xE07A5F, 0x4F7BD9, 0x18A08C, 0x8A63D2, 0xD06A8A, 0xE09A2D, 0x4C9F3A, 0x6F8FA6]
}
