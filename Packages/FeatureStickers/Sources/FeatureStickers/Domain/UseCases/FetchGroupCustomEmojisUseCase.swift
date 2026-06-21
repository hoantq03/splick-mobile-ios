import Foundation
import SplickDomain

public protocol FetchAllCustomEmojisUseCaseProtocol: Sendable {
    func execute() async throws -> [CustomEmoji]
}

public final class FetchAllCustomEmojisUseCase: FetchAllCustomEmojisUseCaseProtocol, Sendable {
    private let repository: CustomEmojiRepositoryProtocol

    public init(repository: CustomEmojiRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> [CustomEmoji] {
        try await repository.fetchAllEmojis()
    }
}
