import Foundation
import SplickDomain

public struct SubmitPaymentEvidenceResult: Sendable {
    public let evidenceId: UUID
    public let commentId: UUID

    public init(evidenceId: UUID, commentId: UUID) {
        self.evidenceId = evidenceId
        self.commentId = commentId
    }
}

public protocol SubmitPaymentEvidenceUseCaseProtocol: Sendable {
    func execute(
        postId: UUID,
        splitId: UUID,
        message: String?,
        submissionAttachments: [CommentSubmissionAttachment]
    ) async throws -> SubmitPaymentEvidenceResult
}

public final class SubmitPaymentEvidenceUseCase: SubmitPaymentEvidenceUseCaseProtocol, Sendable {
    private let repository: FeedRepositoryProtocol

    public init(repository: FeedRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(
        postId: UUID,
        splitId: UUID,
        message: String?,
        submissionAttachments: [CommentSubmissionAttachment]
    ) async throws -> SubmitPaymentEvidenceResult {
        try await repository.submitPaymentEvidence(
            postId: postId,
            splitId: splitId,
            message: message,
            submissionAttachments: submissionAttachments
        )
    }
}

public protocol ApprovePaymentEvidenceUseCaseProtocol: Sendable {
    func execute(postId: UUID, evidenceId: UUID) async throws
}

public final class ApprovePaymentEvidenceUseCase: ApprovePaymentEvidenceUseCaseProtocol, Sendable {
    private let repository: FeedRepositoryProtocol

    public init(repository: FeedRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(postId: UUID, evidenceId: UUID) async throws {
        try await repository.approvePaymentEvidence(postId: postId, evidenceId: evidenceId)
    }
}

public protocol RejectPaymentEvidenceUseCaseProtocol: Sendable {
    func execute(postId: UUID, evidenceId: UUID, reason: String) async throws
}

public final class RejectPaymentEvidenceUseCase: RejectPaymentEvidenceUseCaseProtocol, Sendable {
    private let repository: FeedRepositoryProtocol

    public init(repository: FeedRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(postId: UUID, evidenceId: UUID, reason: String) async throws {
        try await repository.rejectPaymentEvidence(postId: postId, evidenceId: evidenceId, reason: reason)
    }
}
