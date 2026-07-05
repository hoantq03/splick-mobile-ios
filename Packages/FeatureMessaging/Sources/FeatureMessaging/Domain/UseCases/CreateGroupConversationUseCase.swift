import Foundation

public struct CreateGroupConversationUseCase: Sendable {
    private let repository: MessagingRepositoryProtocol

    public init(repository: MessagingRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(name: String, avatarUrl: String?, memberUserIds: [UUID]) async throws -> Conversation {
        try await repository.createGroup(
            name: name,
            avatarUrl: avatarUrl,
            memberUserIds: memberUserIds
        )
    }
}
