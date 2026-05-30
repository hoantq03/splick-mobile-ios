import Foundation
import Networking

enum MediaEndpoint: APIEndpoint {
    case initiateUpload(InitiateUploadRequestDTO)
    case completeUpload(uploadId: UUID, body: CompleteUploadRequestDTO?)
    case delete(id: UUID)

    var path: String {
        switch self {
        case .initiateUpload:
            return "/v1/media/uploads"
        case .completeUpload(let uploadId, _):
            return "/v1/media/uploads/\(uploadId)/complete"
        case .delete(let id):
            return "/v1/media/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .initiateUpload, .completeUpload:
            return .post
        case .delete:
            return .delete
        }
    }

    var body: Encodable? {
        switch self {
        case .initiateUpload(let request):
            return request
        case .completeUpload(_, let body):
            return body
        case .delete:
            return nil
        }
    }
}
