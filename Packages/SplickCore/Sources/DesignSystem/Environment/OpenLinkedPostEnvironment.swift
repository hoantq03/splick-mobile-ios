import SwiftUI

/// Opens a linked post overlay.
/// - Parameters:
///   - postId: Target post.
///   - expandBillSplit: Expand the bill split section on open.
///   - scrollToPendingEvidence: Jump to the first pending payment-evidence comment.
private struct OpenLinkedPostKey: EnvironmentKey {
    static let defaultValue: ((UUID, Bool, Bool) -> Void)? = nil
}

private struct IsLinkedPostPresentationKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    public var openLinkedPost: ((UUID, Bool, Bool) -> Void)? {
        get { self[OpenLinkedPostKey.self] }
        set { self[OpenLinkedPostKey.self] = newValue }
    }

    /// True when post detail is shown inside `LinkedPostDetailOverlay` (expenses, etc.).
    /// Disables full-screen interactive-pop so overlay dismiss owns the gesture.
    public var isLinkedPostPresentation: Bool {
        get { self[IsLinkedPostPresentationKey.self] }
        set { self[IsLinkedPostPresentationKey.self] = newValue }
    }
}
