import Foundation
import Common

/// Deferred wiring for token refresh to break APIClient ↔ AuthRepository cycles.
/// Concurrent 401 handlers share one in-flight refresh (single-flight).
public final class TokenRefreshCoordinator: TokenRefreshHandling, @unchecked Sendable {
    private let lock = NSLock()
    private var refreshHandler: (@Sendable () async throws -> Void)?
    private var inFlight: Task<Void, Error>?

    public init() {}

    public func configure(refreshHandler: @escaping @Sendable () async throws -> Void) {
        lock.lock()
        defer { lock.unlock() }
        self.refreshHandler = refreshHandler
    }

    public func refreshSession() async throws {
        let task: Task<Void, Error>

        lock.lock()
        if let existing = inFlight {
            lock.unlock()
            try await existing.value
            return
        }
        guard let refreshHandler else {
            lock.unlock()
            throw AuthError.refreshFailed
        }
        let created = Task {
            try await refreshHandler()
        }
        inFlight = created
        task = created
        lock.unlock()

        do {
            try await task.value
            clearInFlight(ifSameAs: task)
        } catch {
            clearInFlight(ifSameAs: task)
            throw error
        }
    }

    private func clearInFlight(ifSameAs task: Task<Void, Error>) {
        lock.lock()
        if inFlight == task {
            inFlight = nil
        }
        lock.unlock()
    }
}
