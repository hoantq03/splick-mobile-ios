import Foundation
import Common

enum SearchHistoryEndpoint: APIEndpoint {
    case list(scope: SearchHistoryScope, scopeKey: String?)
    case upsert(scope: SearchHistoryScope, query: String, scopeKey: String?)
    case delete(id: UUID)
    case clear(scope: SearchHistoryScope, scopeKey: String?)

    var path: String {
        switch self {
        case .delete(let id):
            return "/v1/social/me/search-history/\(id.uuidString)"
        case .list, .upsert, .clear:
            return "/v1/social/me/search-history"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list:
            return .get
        case .upsert:
            return .put
        case .delete, .clear:
            return .delete
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .list(let scope, let scopeKey), .clear(let scope, let scopeKey):
            var items = [URLQueryItem(name: "scope", value: scope.rawValue)]
            if let scopeKey, !scopeKey.isEmpty {
                items.append(URLQueryItem(name: "scopeKey", value: scopeKey))
            }
            return items
        default:
            return nil
        }
    }

    var body: Encodable? {
        switch self {
        case .upsert(let scope, let query, let scopeKey):
            return UpsertSearchHistoryBodyDTO(scope: scope.rawValue, query: query, scopeKey: scopeKey)
        default:
            return nil
        }
    }
}

private struct UpsertSearchHistoryBodyDTO: Encodable {
    let scope: String
    let query: String
    let scopeKey: String?
}
