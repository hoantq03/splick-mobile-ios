import Foundation

/// Owns scroll-chrome `ObservableObject`s without republishing their changes.
///
/// Parent screens should hold this as a `@StateObject`. Because it has no
/// `@Published` properties, `objectWillChange` never fires and the parent
/// tree is not invalidated on every scroll-frame chrome update.
@MainActor
public final class ScrollChromeStateHolder: ObservableObject {
    public let feedSegment = FeedSegmentScrollState()

    public init() {}
}

/// Same isolation pattern for the shared tab-bar scroll state at the app root.
@MainActor
public final class TabBarScrollStateHolder: ObservableObject {
    public let tabBar = TabBarScrollState()

    public init() {}
}
