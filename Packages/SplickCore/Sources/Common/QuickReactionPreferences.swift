import Combine
import Foundation

public final class QuickReactionPreferences: ObservableObject {
    public static let shared = QuickReactionPreferences()

    public static let slotCount = ReactionConstants.quickSlotCount
    public static let defaultEmojis = ["❤️", "😂", "😮", "😢", "👍", "🔥"]

    private let storageKey = "splick.quick_reaction_emojis"

    @Published public private(set) var quickEmojis: [String]

    private init() {
        if let saved = UserDefaults.standard.stringArray(forKey: storageKey),
           saved.count == ReactionConstants.quickSlotCount {
            quickEmojis = saved
        } else {
            quickEmojis = ["❤️", "😂", "😮", "😢", "👍", "🔥"]
        }
    }

    public func saveQuickEmojis(_ emojis: [String]) {
        guard emojis.count == ReactionConstants.quickSlotCount else { return }
        quickEmojis = emojis
        UserDefaults.standard.set(emojis, forKey: storageKey)
    }
}
