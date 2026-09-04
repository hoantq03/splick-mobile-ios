import Foundation
import SplickDomain

public protocol ReactToMessageUseCaseProtocol: Sendable {
    func execute(conversationId: UUID, messageId: UUID, emoji: String) async throws -> Reaction
}

public final class ReactToMessageUseCase: ReactToMessageUseCaseProtocol, Sendable {
    private let repository: MessagingRepositoryProtocol

    public init(repository: MessagingRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(conversationId: UUID, messageId: UUID, emoji: String) async throws -> Reaction {
        try await repository.addReaction(conversationId: conversationId, messageId: messageId, emoji: emoji)
    }
}
