import Foundation
import SplickDomain

enum MessagingRecentPeopleStore {
    private static let prefix = "messaging.recentSearchPeople."

    static func load(userId: UUID?) -> [UserSummary] {
        guard let userId,
              let data = UserDefaults.standard.data(forKey: key(userId)),
              let people = try? JSONDecoder().decode([UserSummary].self, from: data) else {
            return []
        }
        return people
    }

    static func save(_ people: [UserSummary], userId: UUID?) {
        guard let userId else { return }
        let data = try? JSONEncoder().encode(people)
        UserDefaults.standard.set(data, forKey: key(userId))
    }

    private static func key(_ userId: UUID) -> String {
        prefix + userId.uuidString
    }
}
