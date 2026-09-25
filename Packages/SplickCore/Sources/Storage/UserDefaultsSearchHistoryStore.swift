import Foundation
import Common

public final class UserDefaultsSearchHistoryStore: SearchHistoryLocalStore, @unchecked Sendable {
    private let defaults: UserDefaultsServiceProtocol

    public init(defaults: UserDefaultsServiceProtocol) {
        self.defaults = defaults
    }

    public func load(for key: String) -> [SearchHistoryItem] {
        defaults.get(for: key) ?? []
    }

    public func save(_ items: [SearchHistoryItem], for key: String) {
        defaults.set(items, for: key)
    }

    public func remove(for key: String) {
        defaults.remove(for: key)
    }
}
