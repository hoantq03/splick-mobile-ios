import Foundation

struct MediaUploadResponseDTO: Decodable {
    let id: UUID
    let url: String
    let thumbnailUrl: String?
    let sizeBytes: Int
}

struct InitiateUploadRequestDTO: Encodable {
    let purpose: String
    let contentType: String
    let contentLength: Int
    let context: UploadContextDTO?
}

struct UploadContextDTO: Encodable {
    let type: String
    let groupId: UUID

    init(groupId: UUID) {
        self.type = "GROUP"
        self.groupId = groupId
    }
}

struct InitiateUploadResponseDTO: Decodable {
    let uploadId: UUID
    let presignedUrl: String
    let requiredHeaders: [String: String]
    let expiresAt: Date
}

struct CompleteUploadRequestDTO: Encodable {
    let etag: String?
}
