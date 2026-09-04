import Foundation

public protocol VerifyPasswordChangeUseCaseProtocol: Sendable {
    func execute(currentPassword: String?, otpCode: String?) async throws
}

public final class VerifyPasswordChangeUseCase: VerifyPasswordChangeUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(currentPassword: String?, otpCode: String?) async throws {
        try await repository.verifyPasswordChange(
            currentPassword: currentPassword,
            otpCode: otpCode
        )
    }
}
