import UIKit
import SplickDomain

public struct CommentAttachmentDraft: Identifiable {
    public enum Phase: Equatable {
        case loading
        case ready
        case failed(String)
    }

    public let id: UUID
    public let kind: CommentAttachmentKind
    public var phase: Phase
    public var previewImage: UIImage?
    public var submission: CommentSubmissionAttachment?

    public init(
        id: UUID,
        kind: CommentAttachmentKind,
        phase: Phase,
        previewImage: UIImage? = nil,
        submission: CommentSubmissionAttachment? = nil
    ) {
        self.id = id
        self.kind = kind
        self.phase = phase
        self.previewImage = previewImage
        self.submission = submission
    }
}

public extension CommentAttachmentDraft.Phase {
    var failureMessage: String? {
        if case .failed(let message) = self { return message }
        return nil
    }
}
