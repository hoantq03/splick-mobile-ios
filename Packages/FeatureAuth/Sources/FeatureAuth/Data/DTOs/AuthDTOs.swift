import Foundation

struct GoogleSignInRequestDTO: Encodable {
    let idToken: String
    let deviceInfo: String?
}

struct LoginRequestDTO: Encodable {
    let email: String
    let password: String
    let deviceInfo: String?
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
}

struct EmailRegisterRequestDTO: Encodable {
    let email: String
    let username: String
    let password: String
    let otpCode: String
    let displayName: String?
}

struct PhoneRegisterRequestDTO: Encodable {
    let phoneNumber: String
    let username: String
    let password: String
    let otpCode: String
    let displayName: String?
}

struct AuthResponseDTO: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
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
}

struct ChangePasswordRequestDTO: Encodable {
    let currentPassword: String?
    let otpCode: String?
    let newPassword: String
    let deviceInfo: String?
}
