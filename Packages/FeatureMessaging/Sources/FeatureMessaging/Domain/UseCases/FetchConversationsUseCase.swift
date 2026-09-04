import Foundation

public final class FetchConversationsUseCase: Sendable {
    private let repository: MessagingRepositoryProtocol

    public init(repository: MessagingRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(query: ConversationInboxQuery) async throws -> MessagingPage<Conversation> {
        try await repository.fetchConversations(query: query)
    }
}
