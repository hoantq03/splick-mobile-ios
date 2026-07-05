import Combine
import Foundation

public final class QuickReactionPreferences: ObservableObject {
    public static let shared = QuickReactionPreferences()

    public static let slotCount = ReactionConstants.quickSlotCount
    public static let defaultEmojis = ["❤️", "😂", "😮", "😢", "👍", "🔥"]

    private let storageKey = "splick.quick_reaction_emojis"

    @Published public private(set) var quickEmojis: [String] = QuickReactionPreferences.defaultEmojis

    private init() {
        if let saved = UserDefaults.standard.stringArray(forKey: storageKey),
           saved.count == Self.slotCount {
            quickEmojis = saved
        }
    }

    public func saveQuickEmojis(_ emojis: [String]) {
        guard emojis.count == Self.slotCount else { return }
        quickEmojis = emojis
        UserDefaults.standard.set(emojis, forKey: storageKey)
    }
}
