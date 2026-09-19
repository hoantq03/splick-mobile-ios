import Foundation
import SplickDomain

public struct UpsertPaymentProfileInput: Sendable {
    public let qrImageUrl: String?
    public let accountName: String?
    public let accountNumber: String?
    public let bankName: String?

    public init(
        qrImageUrl: String?,
        accountName: String?,
        accountNumber: String?,
        bankName: String?
    ) {
        self.qrImageUrl = qrImageUrl
        self.accountName = accountName
        self.accountNumber = accountNumber
        self.bankName = bankName
    }
}

public protocol UpsertMyPaymentProfileUseCaseProtocol: Sendable {
    func execute(_ input: UpsertPaymentProfileInput) async throws -> PaymentProfile
}

public struct UpsertMyPaymentProfileUseCase: UpsertMyPaymentProfileUseCaseProtocol {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(_ input: UpsertPaymentProfileInput) async throws -> PaymentProfile {
        try await repository.upsertMyPaymentProfile(
            qrImageUrl: input.qrImageUrl,
            accountName: input.accountName,
            accountNumber: input.accountNumber,
            bankName: input.bankName
        )
    }
}
