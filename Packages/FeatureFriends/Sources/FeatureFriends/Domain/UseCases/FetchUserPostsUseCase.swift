import Foundation
import SplickDomain

public protocol FetchUserPostsUseCaseProtocol: Sendable {
    func execute(authorId: UUID, page: Int) async throws -> [Post]
}
