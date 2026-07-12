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

    func applyVisibilityReports(_ reports: [FeedVideoVisibilityReport]) {
        visibilityByPost.removeAll(keepingCapacity: true)
        for report in reports where report.ratio > 0.01 {
            visibilityByPost[report.postId] = report.ratio
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

    /// Stops autoplay when the feed tab is hidden (other tabs / background).
    func suspendPlayback() {
        visibilityByPost.removeAll()
        activePostId = nil
    }

    private func pickActivePost() {
        guard let best = visibilityByPost.max(by: { $0.value < $1.value }),
              best.value >= activationThreshold else {
            if activePostId != nil {
                activePostId = nil
            }
            return
        }
        if activePostId != best.key {
            activePostId = best.key
        }
    }
}

struct FeedVideoVisibilityReport: Equatable {
    let postId: UUID
    let ratio: CGFloat
}

private struct FeedVideoVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: [FeedVideoVisibilityReport] = []

    static func reduce(value: inout [FeedVideoVisibilityReport], nextValue: () -> [FeedVideoVisibilityReport]) {
        value.append(contentsOf: nextValue())
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

private struct FeedTabIsActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// When false, feed video visibility reporting and autoplay are disabled.
    var feedTabIsActive: Bool {
        get { self[FeedTabIsActiveKey.self] }
        set { self[FeedTabIsActiveKey.self] = newValue }
    }
}

extension View {
    /// Collects per-post visibility ratios without `onChange(of: CGRect)` (fatal on iOS 26+).
    func feedVideoVisibilityHandling(coordinator: FeedVideoPlaybackCoordinator) -> some View {
        onPreferenceChange(FeedVideoVisibilityPreferenceKey.self) { reports in
            Task { @MainActor in
                coordinator.applyVisibilityReports(reports)
            }
        }
    }
}

struct FeedVideoVisibilityReporter: View {
    let postId: UUID
    @Environment(\.feedTabIsActive) private var feedTabIsActive

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: FeedVideoVisibilityPreferenceKey.self,
                    value: feedTabIsActive ? [visibilityReport(for: proxy)] : []
                )
        }
        .frame(height: 0)
        .allowsHitTesting(false)
    }

    private func visibilityReport(for proxy: GeometryProxy) -> FeedVideoVisibilityReport {
        let frame = proxy.frame(in: .global)
        let bounds = UIScreen.main.bounds
        let intersection = frame.intersection(bounds)
        guard intersection.width > 0, intersection.height > 0, frame.width > 0, frame.height > 0 else {
            return FeedVideoVisibilityReport(postId: postId, ratio: 0)
        }
        let visibleArea = intersection.width * intersection.height
        let totalArea = frame.width * frame.height
        return FeedVideoVisibilityReport(postId: postId, ratio: visibleArea / totalArea)
    }
}
