import Foundation
import Networking

enum DeviceEndpoint: APIEndpoint {
    case register(RegisterPushDeviceRequestDTO)
    case unregister(token: String)

    var path: String {
        switch self {
        case .register:
            return "/v1/devices"
        case .unregister(let token):
            return "/v1/devices/\(token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .register:
            return .post
        case .unregister:
            return .delete
        }
    }

    var body: Encodable? {
        switch self {
        case .register(let dto):
            return dto
        case .unregister:
            return nil
        }
    }
}
