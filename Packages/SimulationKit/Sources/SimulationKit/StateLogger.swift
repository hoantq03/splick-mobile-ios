import Foundation
import Common

public final class StateLogger {
    private let module: String
    private let printToConsole: Bool

    private(set) public var logs: [LogEntry] = []

    public struct LogEntry {
        public let timestamp: Date
        public let module: String
        public let message: String
    }

    public init(module: String, printToConsole: Bool = true) {
        self.module = module
        self.printToConsole = printToConsole
    }

    public func log(_ message: String) {
        let entry = LogEntry(timestamp: .now, module: module, message: message)
        logs.append(entry)

        if printToConsole {
            let time = formatTime(entry.timestamp)
            print("[\(time)] [\(module)] \(message)")
        }
    }

    public func stateTransition<T>(from oldState: String, to newState: String, detail: T? = nil as String?) {
        if let detail {
            log("State: \(oldState) → \(newState) | \(detail)")
        } else {
            log("State: \(oldState) → \(newState)")
        }
    }

    public func apiCall(method: String, path: String, statusCode: Int, duration: Duration? = nil) {
        var msg = "API: \(method) \(path) (\(statusCode))"
        if let duration {
            msg += " [\(duration)]"
        }
        log(msg)
    }

    public func success(_ message: String) {
        log("✓ \(message)")
    }

    public func failure(_ message: String) {
        log("✗ \(message)")
    }

    public func separator() {
        if printToConsole {
            print(String(repeating: "─", count: 60))
        }
    }

    public func clear() {
        logs.removeAll()
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}
