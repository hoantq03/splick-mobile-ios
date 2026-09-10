import Foundation
import Networking

enum AuthEndpoint: APIEndpoint {
    case checkIdentifier(CheckIdentifierRequestDTO)
    case checkUsername(CheckUsernameRequestDTO)
    case googleSignIn(GoogleSignInRequestDTO)
    case appleSignIn(AppleSignInRequestDTO)
    case login(LoginRequestDTO)
    case requestEmailOtp(EmailOtpRequestDTO)
    case requestPhoneOtp(PhoneOtpRequestDTO)
    case verifyPhoneOtp(PhoneOtpVerifyRequestDTO)
    case registerEmail(EmailRegisterRequestDTO)
    case registerPhone(PhoneRegisterRequestDTO)
    case refreshToken(RefreshTokenRequestDTO)
    case forgotPassword(ForgotPasswordRequestDTO)
    case verifyResetPasswordOtp(VerifyResetPasswordOtpRequestDTO)
    case resetPassword(ResetPasswordRequestDTO)
    case changePassword(ChangePasswordRequestDTO)
    case verifyPasswordChange(AccountActionRequestDTO)
    case logout(LogoutRequestDTO)
    case me
    case patchMe(UpdateUserProfileRequestDTO)
    case paymentProfile
    case upsertPaymentProfile(UpsertPaymentProfileRequestDTO)
    case deletePaymentProfile
    case listSessions
    case revokeAllSessions
    case revokeSession(UUID)
    case deactivateAccount(AccountActionRequestDTO)
    case reactivateAccount(ReactivateAccountRequestDTO)
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
        case .checkIdentifier: return "/v1/auth/identifier/check"
        case .checkUsername: return "/v1/auth/username/check"
        case .googleSignIn: return "/v1/auth/google"
        case .appleSignIn: return "/v1/auth/apple"
        case .login: return "/v1/auth/login"
        case .requestEmailOtp: return "/v1/auth/email/otp/request"
        case .requestPhoneOtp: return "/v1/auth/phone/otp/request"
        case .verifyPhoneOtp: return "/v1/auth/phone/otp/verify"
        case .registerEmail, .registerPhone: return "/v1/auth/register"
        case .refreshToken: return "/v1/auth/refresh"
        case .forgotPassword: return "/v1/auth/password/forgot"
        case .verifyResetPasswordOtp: return "/v1/auth/password/reset/verify"
        case .resetPassword: return "/v1/auth/password/reset"
        case .changePassword: return "/v1/auth/password/change"
        case .verifyPasswordChange: return "/v1/auth/password/verify"
        case .logout: return "/v1/auth/logout"
        case .me, .patchMe: return "/v1/auth/me"
        case .paymentProfile, .upsertPaymentProfile, .deletePaymentProfile:
            return "/v1/auth/me/payment-profile"
        case .listSessions: return "/v1/auth/sessions"
        case .revokeAllSessions: return "/v1/auth/sessions/revoke-all"
        case .revokeSession(let id): return "/v1/auth/sessions/\(id.uuidString.lowercased())"
        case .deactivateAccount: return "/v1/auth/account/deactivate"
        case .reactivateAccount: return "/v1/auth/account/reactivate"
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
        case .checkIdentifier, .googleSignIn, .appleSignIn, .login, .requestEmailOtp, .requestPhoneOtp, .verifyPhoneOtp,
             .registerEmail, .registerPhone, .refreshToken,
             .forgotPassword, .verifyResetPasswordOtp, .resetPassword, .changePassword, .verifyPasswordChange, .logout, .revokeAllSessions,
             .deactivateAccount, .reactivateAccount, .linkGoogle, .requestLinkPhoneOtp, .linkPhone,
             .requestLinkEmailOtp, .linkEmail, .checkUsername:
            return .post
        case .me, .listSessions, .connectedAccounts, .paymentProfile:
            return .get
        case .patchMe:
            return .patch
        case .upsertPaymentProfile:
            return .put
        case .revokeSession, .deleteAccount, .unlinkGoogle, .deletePaymentProfile:
            return .delete
        }
    }

    var body: Encodable? {
        switch self {
        case .checkIdentifier(let dto): return dto
        case .checkUsername(let dto): return dto
        case .googleSignIn(let dto): return dto
        case .appleSignIn(let dto): return dto
        case .login(let dto): return dto
        case .requestEmailOtp(let dto): return dto
        case .requestPhoneOtp(let dto): return dto
        case .verifyPhoneOtp(let dto): return dto
        case .registerEmail(let dto): return dto
        case .registerPhone(let dto): return dto
        case .refreshToken(let dto): return dto
        case .forgotPassword(let dto): return dto
        case .verifyResetPasswordOtp(let dto): return dto
        case .resetPassword(let dto): return dto
        case .changePassword(let dto): return dto
        case .verifyPasswordChange(let dto): return dto
        case .logout(let dto): return dto
        case .deactivateAccount(let dto): return dto
        case .reactivateAccount(let dto): return dto
        case .deleteAccount(let dto): return dto
        case .linkGoogle(let dto): return dto
        case .unlinkGoogle(let dto): return dto
        case .requestLinkPhoneOtp(let dto): return dto
        case .linkPhone(let dto): return dto
        case .requestLinkEmailOtp(let dto): return dto
        case .linkEmail(let dto): return dto
        case .patchMe(let dto): return dto
        case .upsertPaymentProfile(let dto): return dto
        case .me, .listSessions, .revokeAllSessions, .revokeSession, .connectedAccounts, .paymentProfile,
             .deletePaymentProfile:
            return nil
        }
    }

    var headers: [String: String]? {
        nil
    }

    var sendsRefreshTokenHeader: Bool {
        switch self {
        case .listSessions:
            return true
        default:
            return false
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .checkIdentifier, .googleSignIn, .appleSignIn, .login, .requestEmailOtp, .requestPhoneOtp, .verifyPhoneOtp,
             .registerEmail, .registerPhone, .refreshToken,
             .forgotPassword, .verifyResetPasswordOtp, .resetPassword, .reactivateAccount:
            return false
        case .checkUsername:
            return true
        case .changePassword, .verifyPasswordChange, .logout, .me, .patchMe, .listSessions, .revokeAllSessions, .revokeSession,
             .deactivateAccount, .deleteAccount, .connectedAccounts, .linkGoogle, .unlinkGoogle,
             .requestLinkPhoneOtp, .linkPhone, .requestLinkEmailOtp, .linkEmail, .paymentProfile,
             .upsertPaymentProfile, .deletePaymentProfile:
            return true
        }
    }
}
