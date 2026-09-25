import Foundation
import Combine
import Common

@MainActor
public final class SearchHistorySession: ObservableObject {
    @Published public private(set) var items: [SearchHistoryItem] = []

    private let repository: SearchHistoryRepositoryProtocol
    private let scope: SearchHistoryScope
    private let scopeKey: String?

    public init(
        repository: SearchHistoryRepositoryProtocol,
        scope: SearchHistoryScope,
        scopeKey: String? = nil
    ) {
        self.repository = repository
        self.scope = scope
        self.scopeKey = scopeKey
        items = repository.cachedList(scope: scope, scopeKey: scopeKey)
    }

    public func refresh() async {
        items = repository.cachedList(scope: scope, scopeKey: scopeKey)
        do {
            items = try await repository.list(scope: scope, scopeKey: scopeKey)
        } catch {
            // Keep cached rows when offline.
        }
    }

    public func record(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            _ = try? await repository.record(scope: scope, query: trimmed, scopeKey: scopeKey)
            items = repository.cachedList(scope: scope, scopeKey: scopeKey)
        }
    }

    public func delete(_ item: SearchHistoryItem) {
        items.removeAll { $0.id == item.id }
        Task {
            try? await repository.delete(id: item.id, scope: scope, scopeKey: scopeKey)
            items = repository.cachedList(scope: scope, scopeKey: scopeKey)
        }
    }

    public func clear() {
        items = []
        Task {
            try? await repository.clear(scope: scope, scopeKey: scopeKey)
        }
    }
}
