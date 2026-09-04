import Foundation
import os.log

public enum LogCategory: String {
    case network = "Network"
    case storage = "Storage"
    case auth = "Auth"
    case ui = "UI"
    case lifecycle = "Lifecycle"
    case media = "Media"
    case expense = "Expense"
    case feed = "Feed"
    case notification = "Notification"
    case friends = "Friends"
}

public struct Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.splick.app"

    private static func logger(for category: LogCategory) -> os.Logger {
        os.Logger(subsystem: subsystem, category: category.rawValue)
    }

    private static func formattedMessage(_ message: String, metadata: [String: String]) -> String {
        guard !metadata.isEmpty else { return message }
        let meta = metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        return "\(message) [\(meta)]"
    }

    public static func debug(
        _ message: String,
        category: LogCategory = .lifecycle,
        metadata: [String: String] = [:]
    ) {
        #if DEBUG
        logger(for: category).debug("\(formattedMessage(message, metadata: metadata), privacy: .public)")
        #endif
    }

    public static func info(
        _ message: String,
        category: LogCategory = .lifecycle,
        metadata: [String: String] = [:]
    ) {
        logger(for: category).info("\(formattedMessage(message, metadata: metadata), privacy: .public)")
    }

    public static func warning(
        _ message: String,
        category: LogCategory = .lifecycle,
        metadata: [String: String] = [:]
    ) {
        logger(for: category).warning("\(formattedMessage(message, metadata: metadata), privacy: .public)")
    }

    public static func error(
        _ message: String,
        category: LogCategory = .lifecycle,
        metadata: [String: String] = [:]
    ) {
        logger(for: category).error("\(formattedMessage(message, metadata: metadata), privacy: .public)")
    }

    public static func error(
        _ error: Error,
        category: LogCategory = .lifecycle,
        metadata: [String: String] = [:]
    ) {
        logger(for: category).error(
            "\(formattedMessage(error.localizedDescription, metadata: metadata), privacy: .public)"
        )
    }
}
