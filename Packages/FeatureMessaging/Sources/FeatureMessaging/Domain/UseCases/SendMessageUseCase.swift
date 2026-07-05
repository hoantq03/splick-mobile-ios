import Foundation
import SplickDomain

public final class SendMessageUseCase: Sendable {
    private let repository: MessagingRepositoryProtocol

    public init(repository: MessagingRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(
        conversationId: UUID,
        body: String,
        clientMessageId: UUID = UUID()
    ) async throws -> ChatMessage {
        try await repository.sendMessage(
            conversationId: conversationId,
            body: body,
            clientMessageId: clientMessageId
        )
    }
}
