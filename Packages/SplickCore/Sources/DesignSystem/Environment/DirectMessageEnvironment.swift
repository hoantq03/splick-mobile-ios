import SwiftUI
import Foundation

/// Environment closure to open a direct message thread with a user.
/// Returns the conversationId if created/found, nil on failure.
private struct OpenDirectMessageKey: EnvironmentKey {
    static let defaultValue: ((UUID) async -> UUID?)? = nil
}

extension EnvironmentValues {
    public var openDirectMessage: ((UUID) async -> UUID?)? {
        get { self[OpenDirectMessageKey.self] }
        set { self[OpenDirectMessageKey.self] = newValue }
    }
}
