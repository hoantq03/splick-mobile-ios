import Foundation

struct LoginRequestDTO: Encodable {
    let email: String
    let password: String
}

struct RegisterRequestDTO: Encodable {
    let email: String
    let username: String
    let password: String
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
    let displayName: String
    let avatarUrl: String?
    let createdAt: Date
}

struct RefreshTokenRequestDTO: Encodable {
    let refreshToken: String
}

struct TokenResponseDTO: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
}
