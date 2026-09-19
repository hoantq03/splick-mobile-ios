import Foundation

public protocol LinkPhoneAccountUseCaseProtocol: Sendable {
    func requestOtp(phoneNumber: String) async throws
    func execute(phoneNumber: String, otpCode: String) async throws
}

public final class LinkPhoneAccountUseCase: LinkPhoneAccountUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func requestOtp(phoneNumber: String) async throws {
        try await repository.requestLinkPhoneOtp(phoneNumber: phoneNumber)
    }

    public func execute(phoneNumber: String, otpCode: String) async throws {
        try await repository.linkPhoneAccount(phoneNumber: phoneNumber, otpCode: otpCode)
    }
}
