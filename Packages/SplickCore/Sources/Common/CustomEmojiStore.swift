import Combine
import Foundation
import SplickDomain

public final class CustomEmojiStore: ObservableObject {
    @Published public private(set) var allEmojis: [CustomEmoji] = []
    private var loadTask: Task<Void, Never>?

    public init() {}

    public func emojis(ownedBy userId: UUID) -> [CustomEmoji] {
        allEmojis.filter { $0.ownerId == userId }
    }

    public func resolve(shortcode: String) -> URL? {
        allEmojis.first(where: { $0.shortcode == shortcode })?.mediaUrl
    }

    @MainActor
    public func load(fetcher: any CustomEmojiFetching) async {
        if let existing = loadTask {
            await existing.value
            return
        }

        let task = Task { @MainActor in
            defer { loadTask = nil }
            do {
                let emojis = try await fetcher.fetchAllEmojis()
                allEmojis = emojis.sorted { $0.shortcode < $1.shortcode }
            } catch {
                // Keep cached values on failure.
            }
        }
        loadTask = task
        await task.value
    }

    @MainActor
    public func reload(fetcher: any CustomEmojiFetching) async {
        loadTask?.cancel()
        loadTask = nil
        await load(fetcher: fetcher)
    }

    @MainActor
    public func upsert(_ emoji: CustomEmoji) {
        if let index = allEmojis.firstIndex(where: { $0.id == emoji.id }) {
            allEmojis[index] = emoji
        } else {
            allEmojis.append(emoji)
        }
        allEmojis.sort { $0.shortcode < $1.shortcode }
    }

    @MainActor
    public func remove(emojiId: UUID) {
        allEmojis.removeAll { $0.id == emojiId }
    }
}
