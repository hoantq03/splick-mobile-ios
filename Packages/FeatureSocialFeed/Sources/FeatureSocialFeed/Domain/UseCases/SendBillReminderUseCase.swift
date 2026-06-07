import Foundation

public struct SendBillReminderResult: Sendable {
    public let sentCount: Int
    public let skippedCount: Int

    public init(sentCount: Int, skippedCount: Int) {
        self.sentCount = sentCount
        self.skippedCount = skippedCount
    }
}

public protocol SendBillReminderUseCaseProtocol: Sendable {
    func execute(postId: UUID, targetUserIds: [UUID]?, message: String) async throws -> SendBillReminderResult
}

public final class SendBillReminderUseCase: SendBillReminderUseCaseProtocol, Sendable {
    private let repository: FeedRepositoryProtocol

    public init(repository: FeedRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(
        postId: UUID,
        targetUserIds: [UUID]?,
        message: String
    ) async throws -> SendBillReminderResult {
        try await repository.sendBillReminder(
            postId: postId,
            targetUserIds: targetUserIds,
            message: message
        )
    }
}
