import Foundation
import Common

public protocol KeychainServiceProtocol: Sendable {
    func save(_ data: Data, for key: String) throws
    func load(for key: String) throws -> Data?
    func delete(for key: String) throws
    func saveString(_ value: String, for key: String) throws
    func loadString(for key: String) throws -> String?
}

public final class KeychainService: KeychainServiceProtocol, Sendable {
    private let service: String

    public init(service: String = AppConstants.Keychain.serviceName) {
        self.service = service
    }

    public func save(_ data: Data, for key: String) throws {
        try delete(for: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw StorageError.keychainError("Save failed with status: \(status)")
        }
    }

    public func load(for key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw StorageError.keychainError("Load failed with status: \(status)")
        }
    }

    public func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StorageError.keychainError("Delete failed with status: \(status)")
        }
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
}
