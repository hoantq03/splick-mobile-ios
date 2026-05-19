import Foundation

public protocol LinkEmailAccountUseCaseProtocol: Sendable {
    func requestOtp(email: String?) async throws
    func execute(email: String?, otpCode: String, password: String) async throws
}

public final class LinkEmailAccountUseCase: LinkEmailAccountUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func requestOtp(email: String?) async throws {
        try await repository.requestLinkEmailOtp(email: email)
    }

    public func execute(email: String?, otpCode: String, password: String) async throws {
        try await repository.linkEmailAccount(email: email, otpCode: otpCode, password: password)
    }
}
