import Foundation
import Networking

enum AuthEndpoint: APIEndpoint {
    case googleSignIn(GoogleSignInRequestDTO)
    case login(LoginRequestDTO)
    case requestEmailOtp(EmailOtpRequestDTO)
    case requestPhoneOtp(PhoneOtpRequestDTO)
    case verifyPhoneOtp(PhoneOtpVerifyRequestDTO)
    case registerEmail(EmailRegisterRequestDTO)
    case registerPhone(PhoneRegisterRequestDTO)
    case refreshToken(RefreshTokenRequestDTO)
    case forgotPassword(ForgotPasswordRequestDTO)
    case resetPassword(ResetPasswordRequestDTO)
    case changePassword(ChangePasswordRequestDTO)
    case logout(LogoutRequestDTO)
    case me
    case listSessions(refreshToken: String?)
    case revokeAllSessions
    case revokeSession(UUID)
    case deactivateAccount(AccountActionRequestDTO)
    case deleteAccount(AccountActionRequestDTO)
    case connectedAccounts
    case linkGoogle(LinkGoogleRequestDTO)
    case unlinkGoogle(AccountActionRequestDTO)
    case requestLinkPhoneOtp(PhoneOtpRequestDTO)
    case linkPhone(LinkPhoneAccountRequestDTO)
    case requestLinkEmailOtp(EmailOtpRequestDTO)
    case linkEmail(LinkEmailAccountRequestDTO)

    var path: String {
        switch self {
        case .googleSignIn: return "/v1/auth/google"
        case .login: return "/v1/auth/login"
        case .requestEmailOtp: return "/v1/auth/email/otp/request"
        case .requestPhoneOtp: return "/v1/auth/phone/otp/request"
        case .verifyPhoneOtp: return "/v1/auth/phone/otp/verify"
        case .registerEmail, .registerPhone: return "/v1/auth/register"
        case .refreshToken: return "/v1/auth/refresh"
        case .forgotPassword: return "/v1/auth/password/forgot"
        case .resetPassword: return "/v1/auth/password/reset"
        case .changePassword: return "/v1/auth/password/change"
        case .logout: return "/v1/auth/logout"
        case .me: return "/v1/auth/me"
        case .listSessions: return "/v1/auth/sessions"
        case .revokeAllSessions: return "/v1/auth/sessions/revoke-all"
        case .revokeSession(let id): return "/v1/auth/sessions/\(id.uuidString)"
        case .deactivateAccount: return "/v1/auth/account/deactivate"
        case .deleteAccount: return "/v1/auth/account"
        case .connectedAccounts: return "/v1/auth/connected-accounts"
        case .linkGoogle: return "/v1/auth/connected-accounts/google"
        case .unlinkGoogle: return "/v1/auth/connected-accounts/google"
        case .requestLinkPhoneOtp: return "/v1/auth/connected-accounts/phone/otp/request"
        case .linkPhone: return "/v1/auth/connected-accounts/phone"
        case .requestLinkEmailOtp: return "/v1/auth/connected-accounts/email/otp/request"
        case .linkEmail: return "/v1/auth/connected-accounts/email"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .googleSignIn, .login, .requestEmailOtp, .requestPhoneOtp, .verifyPhoneOtp,
             .registerEmail, .registerPhone, .refreshToken,
             .forgotPassword, .resetPassword, .changePassword, .logout, .revokeAllSessions,
             .deactivateAccount, .linkGoogle, .requestLinkPhoneOtp, .linkPhone,
             .requestLinkEmailOtp, .linkEmail:
            return .post
        case .me, .listSessions, .connectedAccounts:
            return .get
        case .revokeSession, .deleteAccount, .unlinkGoogle:
            return .delete
        }
    }

    var body: Encodable? {
        switch self {
        case .googleSignIn(let dto): return dto
        case .login(let dto): return dto
        case .requestEmailOtp(let dto): return dto
        case .requestPhoneOtp(let dto): return dto
        case .verifyPhoneOtp(let dto): return dto
        case .registerEmail(let dto): return dto
        case .registerPhone(let dto): return dto
        case .refreshToken(let dto): return dto
        case .forgotPassword(let dto): return dto
        case .resetPassword(let dto): return dto
        case .changePassword(let dto): return dto
        case .logout(let dto): return dto
        case .deactivateAccount(let dto): return dto
        case .deleteAccount(let dto): return dto
        case .linkGoogle(let dto): return dto
        case .unlinkGoogle(let dto): return dto
        case .requestLinkPhoneOtp(let dto): return dto
        case .linkPhone(let dto): return dto
        case .requestLinkEmailOtp(let dto): return dto
        case .linkEmail(let dto): return dto
        case .me, .listSessions, .revokeAllSessions, .revokeSession, .connectedAccounts:
            return nil
        }
    }

    var headers: [String: String]? {
        switch self {
        case .listSessions(let refreshToken):
            guard let refreshToken, !refreshToken.isEmpty else { return nil }
            return ["X-Refresh-Token": refreshToken]
        default:
            return nil
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .googleSignIn, .login, .requestEmailOtp, .requestPhoneOtp, .verifyPhoneOtp,
             .registerEmail, .registerPhone, .refreshToken,
             .forgotPassword, .resetPassword:
            return false
        case .changePassword, .logout, .me, .listSessions, .revokeAllSessions, .revokeSession,
             .deactivateAccount, .deleteAccount, .connectedAccounts, .linkGoogle, .unlinkGoogle,
             .requestLinkPhoneOtp, .linkPhone, .requestLinkEmailOtp, .linkEmail:
            return true
        }
    }
}
