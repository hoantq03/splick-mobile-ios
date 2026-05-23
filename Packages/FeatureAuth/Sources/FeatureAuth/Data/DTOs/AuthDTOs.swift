import Foundation

struct GoogleSignInRequestDTO: Encodable {
    let idToken: String
    let deviceInfo: String?
    let deviceName: String?
    let loginLocation: String?
}

struct LoginRequestDTO: Encodable {
    let email: String
    let password: String
    let deviceInfo: String?
    let deviceName: String?
    let loginLocation: String?
}

struct EmailOtpRequestDTO: Encodable {
    let email: String
}

struct PhoneOtpRequestDTO: Encodable {
    let phoneNumber: String
}

struct PhoneOtpVerifyRequestDTO: Encodable {
    let phoneNumber: String
    let otpCode: String
    let deviceInfo: String?
    let deviceName: String?
    let loginLocation: String?
}

struct EmailRegisterRequestDTO: Encodable {
    let email: String
    let username: String
    let password: String
    let otpCode: String
    let displayName: String?
    let deviceInfo: String?
    let deviceName: String?
    let loginLocation: String?
}

struct PhoneRegisterRequestDTO: Encodable {
    let phoneNumber: String
    let username: String
    let password: String
    let otpCode: String
    let displayName: String?
    let deviceInfo: String?
    let deviceName: String?
    let loginLocation: String?
}

struct AuthResponseDTO: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    let sessionId: UUID?
    let user: UserDTO
}

struct UserDTO: Decodable {
    let id: UUID
    let email: String
    let username: String
    let displayName: String?
    let avatarUrl: String?
    let status: String?
    let createdAt: Date
}

struct UpdateUserProfileRequestDTO: Encodable {
    let displayName: String?
    let avatarUrl: String?
}

struct RefreshTokenRequestDTO: Encodable {
    let refreshToken: String
}

struct ForgotPasswordRequestDTO: Encodable {
    let email: String
}

struct ResetPasswordRequestDTO: Encodable {
    let email: String
    let otpCode: String
    let newPassword: String
    let deviceInfo: String?
    let deviceName: String?
    let loginLocation: String?
}

struct ChangePasswordRequestDTO: Encodable {
    let currentPassword: String?
    let otpCode: String?
    let newPassword: String
    let deviceInfo: String?
    let deviceName: String?
    let loginLocation: String?
}

struct LogoutRequestDTO: Encodable {
    let refreshToken: String
}

struct AccountActionRequestDTO: Encodable {
    let currentPassword: String?
    let otpCode: String?
}

struct LinkGoogleRequestDTO: Encodable {
    let idToken: String
}

struct SessionDTO: Decodable {
    let id: UUID
    let deviceInfo: String?
    let deviceName: String?
    let loginIp: String?
    let loginLocation: String?
    let createdAt: Date
    let expiresAt: Date
    let current: Bool
}

struct LinkPhoneAccountRequestDTO: Encodable {
    let phoneNumber: String
    let otpCode: String
}

struct LinkEmailAccountRequestDTO: Encodable {
    let email: String?
    let otpCode: String
    let password: String
}

struct ConnectedAccountsDTO: Decodable {
    let google: ProviderDTO
    let emailPassword: ProviderDTO
    let phone: ProviderDTO

    struct ProviderDTO: Decodable {
        let linked: Bool
        let detail: String?
    }
}
