import Foundation
import SplickDomain

public final class FetchMessagesUseCase: Sendable {
    private let repository: MessagingRepositoryProtocol

    public init(repository: MessagingRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(conversationId: UUID, page: Int = 0, limit: Int = 30) async throws -> [ChatMessage] {
        try await repository.fetchMessages(conversationId: conversationId, page: page, limit: limit)
    }
}
