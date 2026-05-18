import Foundation
import SplickDomain
import FeatureMedia

public actor FakeMediaRepository: MediaRepositoryProtocol {
    public init() {}

    public func uploadImage(data: Data, mimeType: String) async throws -> MediaUploadResult {
        try await Task.sleep(for: .milliseconds(300))
        let id = UUID()
        return MediaUploadResult(
            id: id,
            url: URL(string: "https://picsum.photos/seed/\(id.uuidString.prefix(8))/400/500")!,
            thumbnailURL: URL(string: "https://picsum.photos/seed/\(id.uuidString.prefix(8))/200/250"),
            sizeBytes: data.count
        )
    }

    public func deleteMedia(id: UUID) async throws {
        try await Task.sleep(for: .milliseconds(100))
    }
}
