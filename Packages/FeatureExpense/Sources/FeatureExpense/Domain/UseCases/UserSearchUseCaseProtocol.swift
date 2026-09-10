import Foundation
import SplickDomain

public protocol UserSearchUseCaseProtocol: Sendable {
    func execute(query: String, page: Int, limit: Int) async throws -> [UserSummary]
}
