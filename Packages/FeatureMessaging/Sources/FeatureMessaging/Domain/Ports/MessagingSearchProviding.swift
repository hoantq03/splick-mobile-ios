import Foundation

public protocol MessagingSearchProviding: Sendable {
    func search(query: String) async throws -> [MessagingSearchResult]
}
