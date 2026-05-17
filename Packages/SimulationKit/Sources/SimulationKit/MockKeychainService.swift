import Foundation
import Storage
import Common

public final class MockKeychainService: KeychainServiceProtocol, @unchecked Sendable {
    private var store: [String: Data] = [:]
    private let logger: StateLogger?

    public init(logger: StateLogger? = nil) {
        self.logger = logger
    }

    public func save(_ data: Data, for key: String) throws {
        store[key] = data
        logger?.log("Keychain: saved \(data.count) bytes for '\(key)'")
    }

    public func load(for key: String) throws -> Data? {
        let data = store[key]
        logger?.log("Keychain: load '\(key)' → \(data != nil ? "\(data!.count) bytes" : "nil")")
        return data
    }

    public func delete(for key: String) throws {
        store.removeValue(forKey: key)
        logger?.log("Keychain: deleted '\(key)'")
    }

    public func saveString(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw StorageError.saveFailed("Failed to encode string")
        }
        try save(data, for: key)
    }

    public func loadString(for key: String) throws -> String? {
        guard let data = try load(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func reset() {
        store.removeAll()
        logger?.log("Keychain: all entries cleared")
    }
}
