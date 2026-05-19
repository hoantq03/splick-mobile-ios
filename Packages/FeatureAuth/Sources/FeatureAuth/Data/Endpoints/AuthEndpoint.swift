import Foundation
import Networking

enum AuthEndpoint: APIEndpoint {
    case login(LoginRequestDTO)
    case requestEmailOtp(EmailOtpRequestDTO)
    case requestPhoneOtp(PhoneOtpRequestDTO)
    case verifyPhoneOtp(PhoneOtpVerifyRequestDTO)
    case registerEmail(EmailRegisterRequestDTO)
    case registerPhone(PhoneRegisterRequestDTO)
    case refreshToken(RefreshTokenRequestDTO)
    case logout
    case me

    var path: String {
        switch self {
        case .login: return "/v1/auth/login"
        case .requestEmailOtp: return "/v1/auth/email/otp/request"
        case .requestPhoneOtp: return "/v1/auth/phone/otp/request"
        case .verifyPhoneOtp: return "/v1/auth/phone/otp/verify"
        case .registerEmail, .registerPhone: return "/v1/auth/register"
        case .refreshToken: return "/v1/auth/refresh"
        case .logout: return "/v1/auth/logout"
        case .me: return "/v1/auth/me"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .login, .requestEmailOtp, .requestPhoneOtp, .verifyPhoneOtp,
             .registerEmail, .registerPhone, .refreshToken, .logout:
            return .post
        case .me:
            return .get
        }
    }

    var body: Encodable? {
        switch self {
        case .login(let dto): return dto
        case .requestEmailOtp(let dto): return dto
        case .requestPhoneOtp(let dto): return dto
        case .verifyPhoneOtp(let dto): return dto
        case .registerEmail(let dto): return dto
        case .registerPhone(let dto): return dto
        case .refreshToken(let dto): return dto
        case .logout, .me: return nil
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login, .requestEmailOtp, .requestPhoneOtp, .verifyPhoneOtp,
             .registerEmail, .registerPhone, .refreshToken:
            return false
        case .logout, .me:
            return true
        }
    }
}
