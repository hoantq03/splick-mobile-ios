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
}

public struct Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.splick.app"

    private static func logger(for category: LogCategory) -> os.Logger {
        os.Logger(subsystem: subsystem, category: category.rawValue)
    }

    public static func debug(_ message: String, category: LogCategory = .lifecycle) {
        #if DEBUG
        logger(for: category).debug("\(message, privacy: .public)")
        #endif
    }

    public static func info(_ message: String, category: LogCategory = .lifecycle) {
        logger(for: category).info("\(message, privacy: .public)")
    }

    public static func warning(_ message: String, category: LogCategory = .lifecycle) {
        logger(for: category).warning("\(message, privacy: .public)")
    }

    public static func error(_ message: String, category: LogCategory = .lifecycle) {
        logger(for: category).error("\(message, privacy: .public)")
    }

    public static func error(_ error: Error, category: LogCategory = .lifecycle) {
        logger(for: category).error("\(error.localizedDescription, privacy: .public)")
    }
}
