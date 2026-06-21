import Foundation
import Observation
import SplickDomain

@Observable
public final class CustomEmojiStore {
  public private(set) var emojisByGroup: [UUID: [CustomEmoji]] = [:]
  private var loadingTasks: [UUID: Task<Void, Never>] = [:]

  public init() {}

  public func emojis(for groupId: UUID) -> [CustomEmoji] {
    emojisByGroup[groupId] ?? []
  }

  public func resolve(shortcode: String, in groupId: UUID) -> URL? {
    emojis(for: groupId).first(where: { $0.shortcode == shortcode })?.mediaUrl
  }

  public func resolveColonCode(_ value: String, in groupId: UUID) -> URL? {
    guard case .custom(let shortcode) = EmojiKind.from(value) else { return nil }
    return resolve(shortcode: shortcode, in: groupId)
  }

  @MainActor
  public func load(groupId: UUID, fetcher: any CustomEmojiFetching) async {
    if let existing = loadingTasks[groupId] {
      await existing.value
      return
    }

    let task = Task { @MainActor in
      defer { loadingTasks[groupId] = nil }
      do {
        let emojis = try await fetcher.fetchEmojis(groupId: groupId)
        emojisByGroup[groupId] = emojis
      } catch {
        // Keep cached values on failure.
      }
    }
    loadingTasks[groupId] = task
    await task.value
  }

  @MainActor
  public func upsert(_ emoji: CustomEmoji) {
    var list = emojisByGroup[emoji.groupId] ?? []
    if let index = list.firstIndex(where: { $0.id == emoji.id }) {
      list[index] = emoji
    } else {
      list.append(emoji)
    }
    emojisByGroup[emoji.groupId] = list.sorted { $0.shortcode < $1.shortcode }
  }

  @MainActor
  public func remove(emojiId: UUID, from groupId: UUID) {
    emojisByGroup[groupId] = emojis(for: groupId).filter { $0.id != emojiId }
  }
}
