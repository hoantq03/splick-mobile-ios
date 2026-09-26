import Foundation

public protocol RequestEmailOtpUseCaseProtocol: Sendable {
    func execute(email: String) async throws
}

public final class RequestEmailOtpUseCase: RequestEmailOtpUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(email: String) async throws {
        try await repository.requestEmailOtp(email: email)
    }
}
