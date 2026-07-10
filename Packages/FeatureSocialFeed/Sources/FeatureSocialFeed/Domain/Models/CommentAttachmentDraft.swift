import UIKit
import SplickDomain

struct CommentAttachmentDraft: Identifiable {
    enum Phase: Equatable {
        case loading
        case ready
        case failed(String)
    }

    let id: UUID
    let kind: CommentAttachmentKind
    var phase: Phase
    var previewImage: UIImage?
    var submission: CommentSubmissionAttachment?
}
