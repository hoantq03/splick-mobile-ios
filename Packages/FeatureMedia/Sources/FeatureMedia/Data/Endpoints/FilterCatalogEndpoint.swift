import Foundation
import Networking

enum FilterCatalogEndpoint: APIEndpoint {
    case list

    var path: String {
        switch self {
        case .list:
            return "/v1/media/filters"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list:
            return .get
        }
    }

    var body: Encodable? { nil }
}
