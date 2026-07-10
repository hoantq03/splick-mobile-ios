import SwiftUI
import FeatureMedia

public typealias CommentImageUploadHandler = @Sendable (Data, String) async throws -> MediaUploadResult

private struct CommentImageUploadKey: EnvironmentKey {
    static let defaultValue: CommentImageUploadHandler? = nil
}

extension EnvironmentValues {
    public var commentImageUpload: CommentImageUploadHandler? {
        get { self[CommentImageUploadKey.self] }
        set { self[CommentImageUploadKey.self] = newValue }
    }
}
