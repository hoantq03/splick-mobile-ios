import Foundation
import Combine

@MainActor
final class QuickReactionPreferences: ObservableObject {
    static let shared = QuickReactionPreferences()

    static let defaultEmojis = ["❤️", "😂", "😮", "😢", "😡", "👏"]
    static let slotCount = 6

    private static let storageKey = "feed.quick_reaction_emojis"

    @Published private(set) var quickEmojis: [String]

    private init() {
        if let saved = UserDefaults.standard.array(forKey: Self.storageKey) as? [String],
           saved.count == Self.slotCount,
           saved.allSatisfy({ $0.isSingleEmoji }) {
            quickEmojis = saved
        } else {
            quickEmojis = Self.defaultEmojis
        }
    }

    func saveQuickEmojis(_ emojis: [String]) {
        let normalized = Self.normalized(emojis)
        quickEmojis = normalized
        UserDefaults.standard.set(normalized, forKey: Self.storageKey)
    }

    func updateSlot(at index: Int, emoji: String) {
        guard (0..<Self.slotCount).contains(index), emoji.isSingleEmoji else { return }
        var next = quickEmojis
        next[index] = emoji
        saveQuickEmojis(next)
    }

    private static func normalized(_ emojis: [String]) -> [String] {
        var result = emojis.filter(\.isSingleEmoji)
        while result.count < slotCount {
            result.append(defaultEmojis[result.count])
        }
        return Array(result.prefix(slotCount))
    }
}

private extension String {
    var isSingleEmoji: Bool {
        count == 1 && containsEmojiScalar
    }

    var containsEmojiScalar: Bool {
        unicodeScalars.contains { $0.properties.isEmojiPresentation || $0.properties.isEmoji }
    }
}
