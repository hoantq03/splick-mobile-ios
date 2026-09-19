import SwiftUI

private struct OpenPostCaptureKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    public var openPostCaptureFlow: (() -> Void)? {
        get { self[OpenPostCaptureKey.self] }
        set { self[OpenPostCaptureKey.self] = newValue }
    }
}
