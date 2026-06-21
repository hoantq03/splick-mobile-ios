import Foundation
import SplickDomain

public protocol CustomEmojiFetching: Sendable {
    func fetchEmojis(groupId: UUID) async throws -> [CustomEmoji]
    func addEmoji(groupId: UUID, shortcode: String, mediaId: UUID) async throws -> CustomEmoji
    func deleteEmoji(groupId: UUID, emojiId: UUID) async throws
}
