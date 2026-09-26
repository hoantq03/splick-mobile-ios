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
    private let secItemUpdate: @Sendable (CFDictionary, CFDictionary) -> OSStatus
    private let secItemAdd: @Sendable (CFDictionary, UnsafeMutablePointer<AnyObject?>?) -> OSStatus
    private let secItemCopyMatching: @Sendable (CFDictionary, UnsafeMutablePointer<AnyObject?>?) -> OSStatus
    private let secItemDelete: @Sendable (CFDictionary) -> OSStatus

    public convenience init(service: String = AppConstants.Keychain.serviceName) {
        self.init(
            service: service,
            secItemUpdate: { SecItemUpdate($0, $1) },
            secItemAdd: { SecItemAdd($0, $1) },
            secItemCopyMatching: { SecItemCopyMatching($0, $1) },
            secItemDelete: { SecItemDelete($0) }
        )
    }

    init(
        service: String,
        secItemUpdate: @escaping @Sendable (CFDictionary, CFDictionary) -> OSStatus,
        secItemAdd: @escaping @Sendable (CFDictionary, UnsafeMutablePointer<AnyObject?>?) -> OSStatus,
        secItemCopyMatching: @escaping @Sendable (CFDictionary, UnsafeMutablePointer<AnyObject?>?) -> OSStatus,
        secItemDelete: @escaping @Sendable (CFDictionary) -> OSStatus
    ) {
        self.service = service
        self.secItemUpdate = secItemUpdate
        self.secItemAdd = secItemAdd
        self.secItemCopyMatching = secItemCopyMatching
        self.secItemDelete = secItemDelete
    }

    public func save(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        // Prefer update-in-place to avoid delete/add races under concurrent refresh.
        let updateStatus = secItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = secItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw StorageError.keychainError("Save failed with status: \(addStatus)")
            }
        default:
            throw StorageError.keychainError("Save failed with status: \(updateStatus)")
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
        let status = secItemCopyMatching(query as CFDictionary, &result)

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

        let status = secItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StorageError.keychainError("Delete failed with status: \(status)")
        }
    }

    public func saveString(_ value: String, for key: String) throws {
        try save(Data(value.utf8), for: key)
    }

    public func loadString(for key: String) throws -> String? {
        guard let data = try load(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
