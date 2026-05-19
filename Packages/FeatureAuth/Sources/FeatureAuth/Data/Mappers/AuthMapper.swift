import Foundation
import SplickDomain

enum AuthMapper {
    static func toUser(_ dto: UserDTO) -> User {
        let resolvedDisplayName = dto.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = (resolvedDisplayName?.isEmpty == false)
            ? resolvedDisplayName!
            : dto.username

        return User(
            id: dto.id,
            email: dto.email,
            username: dto.username,
            displayName: displayName,
            avatarURL: dto.avatarUrl.flatMap(URL.init(string:)),
            status: UserAccountStatus.from(apiValue: dto.status),
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

    static func toAuthSession(_ dto: AuthResponseDTO) -> AuthSession {
        AuthSession(
            user: toUser(dto.user),
            token: toAuthToken(dto)
        )
    }
}
