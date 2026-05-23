import Foundation
import SplickDomain
import FeatureMedia

public actor FakeMediaRepository: MediaRepositoryProtocol {
    public init() {}

    public func uploadImage(
        data: Data,
        mimeType: String,
        purpose: MediaUploadPurpose,
        groupId: UUID?
    ) async throws -> MediaUploadResult {
        try await Task.sleep(for: .milliseconds(300))
        let id = UUID()
        let pathPrefix = purpose == .groupAvatar ? "groups" : "users"
        let contextSegment = groupId.map { "/\($0.uuidString)" } ?? ""
        let base = "https://media.dev.splick.example/\(pathPrefix)\(contextSegment)/avatars/\(id).jpg"
        return MediaUploadResult(
            id: id,
            url: URL(string: base)!,
            thumbnailURL: nil,
            sizeBytes: data.count
        )
    }

    public func deleteMedia(id: UUID) async throws {
        try await Task.sleep(for: .milliseconds(100))
    }
}
