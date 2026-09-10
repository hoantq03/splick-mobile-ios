import Foundation

public protocol LinkGoogleAccountUseCaseProtocol: Sendable {
    func execute(idToken: String) async throws
}

public final class LinkGoogleAccountUseCase: LinkGoogleAccountUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(idToken: String) async throws {
        try await repository.linkGoogleAccount(idToken: idToken)
    }
}
