import Foundation
import Networking

enum AuthEndpoint: APIEndpoint {
    case login(LoginRequestDTO)
    case register(RegisterRequestDTO)
    case refreshToken(RefreshTokenRequestDTO)
    case logout
    case me

    var path: String {
        switch self {
        case .login: return "/v1/auth/login"
        case .register: return "/v1/auth/register"
        case .refreshToken: return "/v1/auth/refresh"
        case .logout: return "/v1/auth/logout"
        case .me: return "/v1/auth/me"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .login, .register, .refreshToken, .logout:
            return .post
        case .me:
            return .get
        }
    }

    var body: Encodable? {
        switch self {
        case .login(let dto): return dto
        case .register(let dto): return dto
        case .refreshToken(let dto): return dto
        case .logout, .me: return nil
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login, .register, .refreshToken:
            return false
        case .logout, .me:
            return true
        }
    }
}
