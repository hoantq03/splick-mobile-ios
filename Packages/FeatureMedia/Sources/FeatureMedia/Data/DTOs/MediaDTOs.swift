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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(purpose, forKey: .purpose)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(contentLength, forKey: .contentLength)
        try container.encodeIfPresent(context, forKey: .context)
    }

    private enum CodingKeys: String, CodingKey {
        case purpose
        case contentType
        case contentLength
        case context
    }
}

struct UploadContextDTO: Encodable {
    let groupId: UUID
}

struct InitiateUploadResponseDTO: Decodable {
    let uploadId: UUID
    let presignedUrl: String
    let requiredHeaders: [String: String]
    let expiresAt: Date
}

struct CompleteUploadRequestDTO: Encodable {
    let etag: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(etag, forKey: .etag)
    }

    private enum CodingKeys: String, CodingKey {
        case etag
    }
}
