import Foundation
import SplickDomain

public protocol CustomEmojiFetching: Sendable {
    func fetchAllEmojis() async throws -> [CustomEmoji]
    func fetchMyEmojis() async throws -> [CustomEmoji]
    func addEmoji(alias: String?, mediaId: UUID) async throws -> CustomEmoji
    func deleteEmoji(emojiId: UUID) async throws
}
