import SwiftUI
import DesignSystem

/// Matches Android `spring(dampingRatio = 0.82, stiffness = 380)` for feed → post detail.
enum FeedPostZoomMotion {
    static let navigation = SplickPageSlideMotion.animation
}

func withFeedPostNavigation(_ body: () -> Void) {
    withAnimation(FeedPostZoomMotion.navigation, body)
}

private struct FeedPostZoomNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var feedPostZoomNamespace: Namespace.ID? {
        get { self[FeedPostZoomNamespaceKey.self] }
        set { self[FeedPostZoomNamespaceKey.self] = newValue }
    }
}

/// Morphs the feed card into post detail on iOS 18+; older OS keeps the standard push.
struct FeedPostZoomSourceModifier: ViewModifier {
    let postId: UUID
    @Environment(\.feedPostZoomNamespace) private var namespace

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), let namespace {
            content.matchedTransitionSource(id: postId, in: namespace)
        } else {
            content
        }
    }
}

struct FeedPostZoomDestinationModifier: ViewModifier {
    let postId: UUID
    @Environment(\.feedPostZoomNamespace) private var namespace

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), let namespace {
            content.navigationTransition(.zoom(sourceID: postId, in: namespace))
        } else {
            content
        }
    }
}

extension View {
    func feedPostZoomSource(postId: UUID) -> some View {
        modifier(FeedPostZoomSourceModifier(postId: postId))
    }

    func feedPostZoomDestination(postId: UUID) -> some View {
        modifier(FeedPostZoomDestinationModifier(postId: postId))
    }
}
