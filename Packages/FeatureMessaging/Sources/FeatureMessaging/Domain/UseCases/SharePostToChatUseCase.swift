import Foundation

public enum SharePostChatTarget: Hashable, Sendable {
    case conversation(UUID)
    case friend(UUID)
}

public struct SharePostToChatOutcome: Equatable, Sendable {
    public let sentCount: Int
    public let failedCount: Int

    public init(sentCount: Int, failedCount: Int) {
        self.sentCount = sentCount
        self.failedCount = failedCount
    }

    public var didSendAny: Bool { sentCount > 0 }
}

public final class SharePostToChatUseCase: Sendable {
    private let repository: MessagingRepositoryProtocol
    private let sendMessageUseCase: SendMessageUseCase

    public init(
        repository: MessagingRepositoryProtocol,
        sendMessageUseCase: SendMessageUseCase
    ) {
        self.repository = repository
        self.sendMessageUseCase = sendMessageUseCase
    }

    public func execute(
        shareURL: URL,
        note: String,
        targets: [SharePostChatTarget]
    ) async -> SharePostToChatOutcome {
        let uniqueTargets = Array(Set(targets))
        let body = SharePostMessageComposer.composeBody(note: note, shareURL: shareURL)
        var sent = 0
        var failed = 0
        var sentConversationIds = Set<UUID>()

        for target in uniqueTargets {
            do {
                let conversationId = try await resolveConversationId(target)
                if sentConversationIds.contains(conversationId) {
                    sent += 1
                    continue
                }
                _ = try await sendMessageUseCase.execute(
                    conversationId: conversationId,
                    body: body,
                    clientMessageId: UUID()
                )
                sentConversationIds.insert(conversationId)
                sent += 1
            } catch {
                failed += 1
            }
        }

        return SharePostToChatOutcome(sentCount: sent, failedCount: failed)
    }

    private func resolveConversationId(_ target: SharePostChatTarget) async throws -> UUID {
        switch target {
        case .conversation(let id):
            return id
        case .friend(let userId):
            return try await repository.getOrCreateConversation(friendUserId: userId).id
        }
    }
}
