import Foundation
import SplickDomain

enum AuthMapper {
    static func toUser(_ dto: UserDTO) -> User {
        User(
            id: dto.id,
            email: dto.email,
            username: dto.username,
            displayName: dto.displayName,
            avatarURL: dto.avatarUrl.flatMap(URL.init(string:)),
            createdAt: dto.createdAt
        )
    }

    static func toAuthToken(_ dto: AuthResponseDTO) -> AuthToken {
        AuthToken(
            accessToken: dto.accessToken,
            refreshToken: dto.refreshToken,
            expiresIn: dto.expiresIn,
            tokenType: dto.tokenType
        )
    }

    static func toAuthToken(_ dto: TokenResponseDTO) -> AuthToken {
        AuthToken(
            accessToken: dto.accessToken,
            refreshToken: dto.refreshToken,
            expiresIn: dto.expiresIn,
            tokenType: dto.tokenType
        )
    }

    static func toAuthSession(_ dto: AuthResponseDTO) -> AuthSession {
        AuthSession(
            user: toUser(dto.user),
            token: toAuthToken(dto)
        )
    }
}
