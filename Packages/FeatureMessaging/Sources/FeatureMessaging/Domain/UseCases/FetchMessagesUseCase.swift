import Foundation
import SplickDomain

public final class FetchMessagesUseCase: Sendable {
    private let repository: MessagingRepositoryProtocol

    public init(repository: MessagingRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(
        conversationId: UUID,
        page: Int = 0,
        limit: Int = 30,
        after: Int64? = nil,
        before: Int64? = nil
    ) async throws -> MessagingPage<ChatMessage> {
        try await repository.fetchMessages(
            conversationId: conversationId,
            page: page,
            limit: limit,
            after: after,
            before: before
        )
    }
}
