import Foundation
import Networking

enum MediaEndpoint: APIEndpoint {
    case upload
    case delete(id: UUID)

    var path: String {
        switch self {
        case .upload: return "/v1/media/upload"
        case .delete(let id): return "/v1/media/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .upload: return .post
        case .delete: return .delete
        }
    }
}
