import Foundation

public protocol VerifyResetPasswordOtpUseCaseProtocol: Sendable {
    func execute(email: String, otpCode: String) async throws
}

public final class VerifyResetPasswordOtpUseCase: VerifyResetPasswordOtpUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(email: String, otpCode: String) async throws {
        try await repository.verifyResetPasswordOtp(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            otpCode: otpCode
        )
    }
}
