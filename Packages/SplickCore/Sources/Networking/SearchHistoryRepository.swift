import Foundation
import Common

public protocol SearchHistoryRepositoryProtocol: Sendable {
    func cachedList(scope: SearchHistoryScope, scopeKey: String?) -> [SearchHistoryItem]
    func list(scope: SearchHistoryScope, scopeKey: String?) async throws -> [SearchHistoryItem]
    func record(scope: SearchHistoryScope, query: String, scopeKey: String?) async throws -> SearchHistoryItem
    func delete(id: UUID, scope: SearchHistoryScope, scopeKey: String?) async throws
    func clear(scope: SearchHistoryScope, scopeKey: String?) async throws
}

public final class SearchHistoryRepository: SearchHistoryRepositoryProtocol, @unchecked Sendable {
    private let apiClient: APIClientProtocol
    private let localStore: SearchHistoryLocalStore
    private let userIdProvider: @Sendable () -> UUID?

    public init(
        apiClient: APIClientProtocol,
        localStore: SearchHistoryLocalStore,
        userIdProvider: @escaping @Sendable () -> UUID?
    ) {
        self.apiClient = apiClient
        self.localStore = localStore
        self.userIdProvider = userIdProvider
    }

    public func list(scope: SearchHistoryScope, scopeKey: String?) async throws -> [SearchHistoryItem] {
        let remote: [SearchHistoryItemDTO] = try await apiClient.request(
            SearchHistoryEndpoint.list(scope: scope, scopeKey: scopeKey)
        )
        let items = remote.map(\.asDomain)
        persist(items, scope: scope, scopeKey: scopeKey)
        return items
    }

    public func cachedList(scope: SearchHistoryScope, scopeKey: String?) -> [SearchHistoryItem] {
        localStore.load(for: cacheKey(scope: scope, scopeKey: scopeKey))
    }

    public func record(scope: SearchHistoryScope, query: String, scopeKey: String?) async throws -> SearchHistoryItem {
        let trimmed = SearchHistoryQueryNormalizer.displayForm(query)
        guard !trimmed.isEmpty else {
            throw NetworkError.invalidURL
        }
        let dto: SearchHistoryItemDTO = try await apiClient.request(
            SearchHistoryEndpoint.upsert(scope: scope, query: trimmed, scopeKey: scopeKey)
        )
        let item = dto.asDomain
        var current = cachedList(scope: scope, scopeKey: scopeKey)
        current.removeAll { $0.id == item.id || SearchHistoryQueryNormalizer.normalized($0.query) == SearchHistoryQueryNormalizer.normalized(item.query) }
        current.insert(item, at: 0)
        if current.count > 20 {
            current = Array(current.prefix(20))
        }
        persist(current, scope: scope, scopeKey: scopeKey)
        return item
    }

    public func delete(id: UUID, scope: SearchHistoryScope, scopeKey: String?) async throws {
        try await apiClient.request(SearchHistoryEndpoint.delete(id: id))
        var current = cachedList(scope: scope, scopeKey: scopeKey)
        current.removeAll { $0.id == id }
        persist(current, scope: scope, scopeKey: scopeKey)
    }

    public func clear(scope: SearchHistoryScope, scopeKey: String?) async throws {
        try await apiClient.request(SearchHistoryEndpoint.clear(scope: scope, scopeKey: scopeKey))
        persist([], scope: scope, scopeKey: scopeKey)
    }

    private func persist(_ items: [SearchHistoryItem], scope: SearchHistoryScope, scopeKey: String?) {
        localStore.save(items, for: cacheKey(scope: scope, scopeKey: scopeKey))
    }

    private func cacheKey(scope: SearchHistoryScope, scopeKey: String?) -> String {
        let user = userIdProvider()?.uuidString ?? "anonymous"
        let key = scopeKey ?? ""
        return "com.splick.searchHistory.\(user).\(scope.rawValue).\(key)"
    }
}

enum SearchHistoryQueryNormalizer {
    static func displayForm(_ raw: String) -> String {
        let collapsed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return String(collapsed.prefix(100))
    }

    static func normalized(_ raw: String) -> String {
        displayForm(raw).lowercased()
    }
}

struct SearchHistoryItemDTO: Decodable {
    let id: UUID
    let scope: SearchHistoryScope
    let scopeKey: String?
    let query: String
    let lastUsedAt: Date

    var asDomain: SearchHistoryItem {
        SearchHistoryItem(id: id, scope: scope, scopeKey: scopeKey, query: query, lastUsedAt: lastUsedAt)
    }
}
