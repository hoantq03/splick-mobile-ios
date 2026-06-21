import Combine
import Foundation

final class QuickReactionPreferences: ObservableObject {
    static let shared = QuickReactionPreferences()

    static let slotCount = 6
    static let defaultEmojis = ["❤️", "😂", "😮", "😢", "👍", "🔥"]

    private let storageKey = "feed.quick_reaction_emojis"

    @Published private(set) var quickEmojis: [String] = defaultEmojis

    private init() {
        if let saved = UserDefaults.standard.stringArray(forKey: storageKey),
           saved.count == Self.slotCount {
            quickEmojis = saved
        }
    }

    func saveQuickEmojis(_ emojis: [String]) {
        guard emojis.count == Self.slotCount else { return }
        quickEmojis = emojis
        UserDefaults.standard.set(emojis, forKey: storageKey)
    }
}
