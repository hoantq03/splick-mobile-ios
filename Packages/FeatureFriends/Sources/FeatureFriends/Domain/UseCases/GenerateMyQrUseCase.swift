import Foundation

public protocol GenerateMyQrUseCaseProtocol: Sendable {
    func execute() async throws -> PersonalQRCode
}

public struct GenerateMyQrUseCase: GenerateMyQrUseCaseProtocol {
    private let repository: FriendsManagementRepositoryProtocol

    public init(repository: FriendsManagementRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> PersonalQRCode {
        try await repository.generateMyQr()
    }
}
