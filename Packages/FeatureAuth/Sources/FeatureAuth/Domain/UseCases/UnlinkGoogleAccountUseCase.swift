import Foundation

public protocol UnlinkGoogleAccountUseCaseProtocol: Sendable {
    func execute(currentPassword: String?, otpCode: String?) async throws
}

public final class UnlinkGoogleAccountUseCase: UnlinkGoogleAccountUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(currentPassword: String?, otpCode: String?) async throws {
        try await repository.unlinkGoogleAccount(currentPassword: currentPassword, otpCode: otpCode)
    }
}
