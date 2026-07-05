import SwiftUI

struct MessageReactionAnchorFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct MessageReactionFocusContext: Equatable {
    let messageId: UUID
    let isOutgoing: Bool
    let frame: CGRect
}
