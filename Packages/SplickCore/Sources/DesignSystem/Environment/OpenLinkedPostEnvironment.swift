import SwiftUI

private struct OpenLinkedPostKey: EnvironmentKey {
    static let defaultValue: ((UUID, Bool) -> Void)? = nil
}

extension EnvironmentValues {
    public var openLinkedPost: ((UUID, Bool) -> Void)? {
        get { self[OpenLinkedPostKey.self] }
        set { self[OpenLinkedPostKey.self] = newValue }
    }
}
