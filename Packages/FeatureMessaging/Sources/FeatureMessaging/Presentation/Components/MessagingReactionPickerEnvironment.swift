import SwiftUI

public struct MessagingReactionPickerAction {
    public var present: (_ onPick: @escaping (String) -> Void) -> Void

    public init(present: @escaping (_ onPick: @escaping (String) -> Void) -> Void) {
        self.present = present
    }
}

private struct MessagingReactionPickerKey: EnvironmentKey {
    static let defaultValue = MessagingReactionPickerAction { _ in }
}

public extension EnvironmentValues {
    var messagingReactionPicker: MessagingReactionPickerAction {
        get { self[MessagingReactionPickerKey.self] }
        set { self[MessagingReactionPickerKey.self] = newValue }
    }
}
