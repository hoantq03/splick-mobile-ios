import Foundation
import Common
import SplickDomain
import FeatureSocialFeed

public actor FakeFriendsRepository: FriendsRepositoryProtocol {
    private var friends: [UserSummary] = []
    private let logger: StateLogger

    public init(logger: StateLogger) {
        self.logger = logger
    }

    public func seed() {
        let core: [UserSummary] = [
            UserSummary(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                username: "namtran",
                displayName: "Nam Tran",
                avatarURL: nil
            ),
            UserSummary(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                username: "linhpham",
                displayName: "Linh Pham",
                avatarURL: nil
            ),
            UserSummary(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                username: "ducnguyen",
                displayName: "Duc Nguyen",
                avatarURL: nil
            ),
            UserSummary(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
                username: "minhthu",
                displayName: "Minh Thu",
                avatarURL: nil
            ),
        ]

        let generated = (0..<48).map { index in
            UserSummary(
                id: UUID(),
                username: "friend\(index)",
                displayName: "Friend \(index + 1)",
                avatarURL: nil
            )
        }

        friends = core + generated
        logger.log("Seeded \(friends.count) friends for mentions")
    }

    public func fetchFriends(query: String, page: Int, limit: Int) async throws -> [UserSummary] {
        try await Task.sleep(for: .milliseconds(120))

        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered: [UserSummary]
        if normalized.isEmpty {
            filtered = friends
        } else {
            filtered = friends.filter {
                $0.username.lowercased().contains(normalized)
                    || $0.displayName.lowercased().contains(normalized)
            }
        }

        let start = page * limit
        guard start < filtered.count else { return [] }
        let end = min(start + limit, filtered.count)
        let batch = Array(filtered[start..<end])
        logger.log("Mention friends page=\(page) query=\"\(query)\" → \(batch.count) items")
        return batch
    }
}
