import Foundation
import Network

/// Thin wrapper around `NWPathMonitor` that publishes reachability changes.
public final class NetworkPathMonitor: @unchecked Sendable {
    public typealias PathHandler = @Sendable (Bool) -> Void

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.splick.network-path-monitor")
    private let lock = NSLock()
    private var handlers: [UUID: PathHandler] = [:]
    private var started = false
    private var lastSatisfied: Bool?

    public init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
    }

    public var isSatisfied: Bool {
        monitor.currentPath.status == .satisfied
    }

    public func start() {
        lock.lock()
        defer { lock.unlock() }
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            self?.notify(satisfied: path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard started else { return }
        started = false
        monitor.cancel()
        monitor.pathUpdateHandler = nil
        lastSatisfied = nil
    }

    @discardableResult
    public func onPathChange(_ handler: @escaping PathHandler) -> UUID {
        let id = UUID()
        lock.lock()
        handlers[id] = handler
        lock.unlock()
        start()
        return id
    }

    public func removeHandler(_ id: UUID) {
        lock.lock()
        handlers.removeValue(forKey: id)
        lock.unlock()
    }

    private func notify(satisfied: Bool) {
        lock.lock()
        let previous = lastSatisfied
        lastSatisfied = satisfied
        let callbacks = Array(handlers.values)
        lock.unlock()

        guard previous != satisfied else { return }
        for callback in callbacks {
            callback(satisfied)
        }
    }
}
