import SwiftUI
import DesignSystem

/// Feed → post detail uses iOS 18 zoom, not the 160ms page slide.
/// Wrapping `NavigationPath.append` in `withAnimation` fights `navigationTransition(.zoom)`
/// and makes the push look like a flash (pop still morphs).
func withFeedPostNavigation(_ body: () -> Void) {
    if #available(iOS 18.0, *) {
        SplickZoomNavigation.preparePush()
        var transaction = Transaction()
        transaction.disablesAnimations = false
        withTransaction(transaction, body)
    } else {
        withAnimation(SplickPageSlideMotion.animation, body)
    }
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

/// Morphs the feed card into post detail on iOS 18+; older OS keeps a source
/// anchor so the custom interactive pop can land in the list hole.
/// Hiding the in-list card is UIKit-only (`source.alpha` + hole overlay). A
/// SwiftUI `@ObservedObject` opacity here would invalidate every feed cell
/// mid-gesture and hitch on land.
struct FeedPostZoomSourceModifier: ViewModifier {
    let postId: UUID
    @Environment(\.feedPostZoomNamespace) private var namespace

    func body(content: Content) -> some View {
        let card = content
            .overlay {
                SplickZoomPopSourceAnchor(postId: postId)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        if #available(iOS 18.0, *), let namespace {
            card.matchedTransitionSource(id: postId, in: namespace)
        } else {
            card
        }
    }
}

struct FeedPostZoomDestinationModifier: ViewModifier {
    let postId: UUID
    var namespaceOverride: Namespace.ID?
    @Environment(\.feedPostZoomNamespace) private var environmentNamespace

    private var namespace: Namespace.ID? { namespaceOverride ?? environmentNamespace }

    func body(content: Content) -> some View {
        Group {
            if #available(iOS 18.0, *), let namespace {
                content.navigationTransition(.zoom(sourceID: postId, in: namespace))
            } else {
                content
            }
        }
        .background { SplickZoomPopDestinationAnchor(postId: postId) }
    }
}

extension View {
    func feedPostZoomSource(postId: UUID) -> some View {
        modifier(FeedPostZoomSourceModifier(postId: postId))
    }

    func feedPostZoomDestination(postId: UUID, namespace: Namespace.ID? = nil) -> some View {
        modifier(FeedPostZoomDestinationModifier(postId: postId, namespaceOverride: namespace))
    }
}
