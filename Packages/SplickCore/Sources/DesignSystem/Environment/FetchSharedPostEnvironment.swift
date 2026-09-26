import SwiftUI
import SplickDomain

private struct FetchSharedPostKey: EnvironmentKey {
    static let defaultValue: ((UUID) async throws -> Post)? = nil
}

extension EnvironmentValues {
    /// Loads a feed post for in-chat shared-post preview cards.
    public var fetchSharedPost: ((UUID) async throws -> Post)? {
        get { self[FetchSharedPostKey.self] }
        set { self[FetchSharedPostKey.self] = newValue }
    }
}
