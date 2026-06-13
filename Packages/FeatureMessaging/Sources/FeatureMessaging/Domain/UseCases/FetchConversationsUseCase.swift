import Foundation

public final class FetchConversationsUseCase: Sendable {
    private let repository: MessagingRepositoryProtocol

    public init(repository: MessagingRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(page: Int = 0, limit: Int = 20) async throws -> [Conversation] {
        try await repository.fetchConversations(page: page, limit: limit)
    }
}
