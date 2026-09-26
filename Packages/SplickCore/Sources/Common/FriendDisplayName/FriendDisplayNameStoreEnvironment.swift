import Foundation
import SwiftUI

private struct FriendDisplayNameStoreKey: EnvironmentKey {
    static let defaultValue: FriendDisplayNameStore? = nil
}

private struct FriendDisplayNamesKey: EnvironmentKey {
    static let defaultValue: [UUID: String] = [:]
}

extension EnvironmentValues {
    public var friendDisplayNameStore: FriendDisplayNameStore? {
        get { self[FriendDisplayNameStoreKey.self] }
        set { self[FriendDisplayNameStoreKey.self] = newValue }
    }

    public var friendDisplayNames: [UUID: String] {
        get { self[FriendDisplayNamesKey.self] }
        set { self[FriendDisplayNamesKey.self] = newValue }
    }
}
