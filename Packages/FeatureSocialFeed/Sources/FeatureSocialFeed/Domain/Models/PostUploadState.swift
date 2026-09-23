import Foundation
import Common

public enum PostUploadState: Equatable, Sendable {
    case uploading
    case failed(message: String, recovery: PostUploadRecovery = .retry)

    public var needsEdit: Bool {
        if case .failed(_, .edit) = self { return true }
        return false
    }
}
