import Foundation
import Networking

enum AppStartupEndpoint: APIEndpoint {
    case startup

    var path: String { "/v1/app/startup" }
    var method: HTTPMethod { .get }
    var queryItems: [URLQueryItem]? { nil }
    var body: Encodable? { nil }
}
