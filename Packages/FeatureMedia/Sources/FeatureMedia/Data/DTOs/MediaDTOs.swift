import Foundation

struct MediaUploadResponseDTO: Decodable {
    let id: UUID
    let url: String
    let thumbnailUrl: String?
    let sizeBytes: Int
}
