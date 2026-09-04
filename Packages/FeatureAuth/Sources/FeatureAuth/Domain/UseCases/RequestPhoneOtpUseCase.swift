import Foundation

public protocol RequestPhoneOtpUseCaseProtocol: Sendable {
    func execute(phoneNumber: String) async throws
}

public final class RequestPhoneOtpUseCase: RequestPhoneOtpUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(phoneNumber: String) async throws {
        try await repository.requestPhoneOtp(phoneNumber: phoneNumber)
    }
}
