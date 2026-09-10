import SwiftUI
import SplickDomain

public typealias ImageAttachmentUploadHandler = @Sendable (Data, String) async throws -> UploadedMediaReference

private struct ImageAttachmentUploadKey: EnvironmentKey {
    static let defaultValue: ImageAttachmentUploadHandler? = nil
}

public extension EnvironmentValues {
    var imageAttachmentUpload: ImageAttachmentUploadHandler? {
        get { self[ImageAttachmentUploadKey.self] }
        set { self[ImageAttachmentUploadKey.self] = newValue }
    }
}
