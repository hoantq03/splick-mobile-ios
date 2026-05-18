import SwiftUI

/// Picks the most visible feed video post for autoplay while scrolling.
@MainActor
final class FeedVideoPlaybackCoordinator: ObservableObject {
    @Published private(set) var activePostId: UUID?

    private var visibilityByPost: [UUID: CGFloat] = [:]
    private let activationThreshold: CGFloat = 0.35

    func updateVisibility(postId: UUID, ratio: CGFloat) {
        if ratio <= 0.01 {
            visibilityByPost.removeValue(forKey: postId)
        } else {
            visibilityByPost[postId] = ratio
        }
        pickActivePost()
    }

    func clearPost(_ postId: UUID) {
        visibilityByPost.removeValue(forKey: postId)
        if activePostId == postId {
            activePostId = nil
        }
        pickActivePost()
    }

    private func pickActivePost() {
        guard let best = visibilityByPost.max(by: { $0.value < $1.value }),
              best.value >= activationThreshold else {
            activePostId = nil
            return
        }
        activePostId = best.key
    }
}

private struct FeedVideoCoordinatorKey: EnvironmentKey {
    static let defaultValue: FeedVideoPlaybackCoordinator? = nil
}

extension EnvironmentValues {
    var feedVideoCoordinator: FeedVideoPlaybackCoordinator? {
        get { self[FeedVideoCoordinatorKey.self] }
        set { self[FeedVideoCoordinatorKey.self] = newValue }
    }
}

struct FeedVideoVisibilityReporter: View {
    let postId: UUID
    @Environment(\.feedVideoCoordinator) private var coordinator

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { report(proxy) }
                .onChange(of: proxy.frame(in: .global)) { _ in report(proxy) }
                .onDisappear { coordinator?.clearPost(postId) }
        }
    }

    private func report(_ proxy: GeometryProxy) {
        guard let coordinator else { return }
        let frame = proxy.frame(in: .global)
        let bounds = UIScreen.main.bounds
        let intersection = frame.intersection(bounds)
        guard intersection.width > 0, intersection.height > 0, frame.width > 0, frame.height > 0 else {
            coordinator.updateVisibility(postId: postId, ratio: 0)
            return
        }
        let visibleArea = intersection.width * intersection.height
        let totalArea = frame.width * frame.height
        coordinator.updateVisibility(postId: postId, ratio: visibleArea / totalArea)
    }
}
