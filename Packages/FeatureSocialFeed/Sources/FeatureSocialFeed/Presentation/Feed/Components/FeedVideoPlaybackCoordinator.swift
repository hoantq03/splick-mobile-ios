import SwiftUI
import UIKit
import AVFoundation
import Common

/// Stops feed autoplay without rebuilding `FeedView` on the tab-tap frame.
public enum FeedVideoPlaybackControl {
    public static let suspendNotification = Notification.Name("splick.feedVideo.suspend")

    public static func suspend() {
        NotificationCenter.default.post(name: suspendNotification, object: nil)
    }
}

/// Autoplay the single on-screen feed video that covers the most viewport.
@MainActor
final class FeedVideoPlaybackCoordinator: ObservableObject {
    /// At most one post id — the current autoplay target.
    @Published private(set) var activePostIds: Set<UUID> = []

    /// Back-compat for call sites that still read a single id (first active).
    var activePostId: UUID? { activePostIds.first }

    private var visibilityByPost: [UUID: CGFloat] = [:]
    /// Minimum viewport coverage before a video may start. Peeking headers stay posters.
    private let activationThreshold: CGFloat = 0.08
    /// Keep the current video unless another covers this much more of the screen.
    private let switchHysteresis: CGFloat = 0.08

    /// One decoder only — extra pooled players were the feed-tab CPU spike.
    private let poolCapacity = 1
    private var pooledControllers: [UUID: FeedVideoPlaybackController] = [:]
    private var pooledURLs: [UUID: URL] = [:]
    private var lruOrder: [UUID] = []

    private var pendingVisibilityReports: [FeedVideoVisibilityReport]?
    private var visibilityFlushTask: Task<Void, Never>?
    private static let visibilityDebounceNanos: UInt64 = 50_000_000 // 50ms

    func updateVisibility(postId: UUID, ratio: CGFloat) {
        if ratio <= 0.01 {
            visibilityByPost.removeValue(forKey: postId)
        } else {
            visibilityByPost[postId] = ratio
        }
        refreshActivePosts()
    }

    /// Drive autoplay from post-card visibility (not video subframe).
    func setVisiblePostIds(_ ids: Set<UUID>) {
        visibilityByPost = Dictionary(uniqueKeysWithValues: ids.map { ($0, 1) })
        refreshActivePosts()
    }

    func applyVisibilityReports(_ reports: [FeedVideoVisibilityReport]) {
        visibilityByPost.removeAll(keepingCapacity: true)
        for report in reports where report.ratio > 0.01 {
            let existing = visibilityByPost[report.postId] ?? 0
            visibilityByPost[report.postId] = max(existing, report.ratio)
        }
        refreshActivePosts()
    }

    /// Coalesces high-frequency PreferenceKey updates during fast scroll.
    func scheduleVisibilityUpdate(_ reports: [FeedVideoVisibilityReport]) {
        pendingVisibilityReports = reports
        guard visibilityFlushTask == nil else { return }
        visibilityFlushTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.visibilityDebounceNanos)
            visibilityFlushTask = nil
            guard let pending = pendingVisibilityReports else { return }
            pendingVisibilityReports = nil
            applyVisibilityReports(pending)
        }
    }

    func clearPost(_ postId: UUID) {
        visibilityByPost.removeValue(forKey: postId)
        releaseController(for: postId)
        refreshActivePosts()
    }

    func isAutoplayTarget(_ postId: UUID) -> Bool {
        activePostIds.contains(postId)
    }

    /// Stops autoplay when the feed tab is hidden (other tabs / background).
    func suspendPlayback() {
        visibilityFlushTask?.cancel()
        visibilityFlushTask = nil
        pendingVisibilityReports = nil
        visibilityByPost.removeAll()
        SplickViewUpdate.after { [weak self] in
            guard let self else { return }
            self.activePostIds = []
            for controller in self.pooledControllers.values {
                controller.setAutoplayActive(false)
            }
            self.releaseAllControllers()
        }
    }

    /// Returns a pooled controller only when this post is an autoplay target (or already pooled).
    func controller(for postId: UUID, url: URL) -> FeedVideoPlaybackController? {
        guard activePostIds.contains(postId) || pooledControllers[postId] != nil else {
            return nil
        }
        return acquireController(for: postId, url: url)
    }

    func acquireController(for postId: UUID, url: URL) -> FeedVideoPlaybackController {
        if let existing = pooledControllers[postId] {
            touchLRU(postId)
            if pooledURLs[postId] != url {
                existing.replaceURL(url)
                pooledURLs[postId] = url
            }
            return existing
        }

        evictIfNeeded(reserving: postId)
        let controller = FeedVideoPlaybackController(url: url)
        pooledControllers[postId] = controller
        pooledURLs[postId] = url
        touchLRU(postId)
        return controller
    }

    func releaseController(for postId: UUID) {
        guard let controller = pooledControllers.removeValue(forKey: postId) else { return }
        pooledURLs.removeValue(forKey: postId)
        lruOrder.removeAll { $0 == postId }
        controller.tearDown()
    }

    private func releaseAllControllers() {
        for id in Array(pooledControllers.keys) {
            releaseController(for: id)
        }
    }

    private func evictIfNeeded(reserving reservedId: UUID) {
        while pooledControllers.count >= poolCapacity {
            let victim = lruOrder.first(where: { $0 != reservedId && !activePostIds.contains($0) })
                ?? lruOrder.first(where: { $0 != reservedId })
            guard let victim else { break }
            releaseController(for: victim)
        }
    }

    private func touchLRU(_ postId: UUID) {
        lruOrder.removeAll { $0 == postId }
        lruOrder.append(postId)
    }

    private func refreshActivePosts() {
        let next = Set(selectedAutoplayPostId().map { [$0] } ?? [])
        guard next != activePostIds else { return }
        SplickViewUpdate.after { [weak self] in
            guard let self, next != self.activePostIds else { return }
            let removed = self.activePostIds.subtracting(next)
            let added = next.subtracting(self.activePostIds)
            self.activePostIds = next
            for id in removed {
                self.pooledControllers[id]?.setAutoplayActive(false)
                self.releaseController(for: id)
            }
            for id in added {
                self.pooledControllers[id]?.setAutoplayActive(true)
            }
        }
    }

    /// The video covering the most of the screen. Hysteresis avoids flicker when two cards are close.
    private func selectedAutoplayPostId() -> UUID? {
        let ranked = visibilityByPost
            .filter { $0.value >= activationThreshold }
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key.uuidString < rhs.key.uuidString
            }
        guard let best = ranked.first else { return nil }

        if let current = activePostIds.first,
           current != best.key,
           let currentRatio = visibilityByPost[current],
           currentRatio >= activationThreshold,
           best.value < currentRatio + switchHysteresis {
            return current
        }
        return best.key
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
    /// Debounced off the PreferenceKey pass to avoid layout thrash during fast scroll.
    func feedVideoVisibilityHandling(coordinator: FeedVideoPlaybackCoordinator) -> some View {
        onPreferenceChange(FeedVideoVisibilityPreferenceKey.self) { reports in
            DispatchQueue.main.async {
                coordinator.scheduleVisibilityUpdate(reports)
            }
        }
    }
}

/// Marks a feed video cell as an autoplay candidate while it is on-screen.
/// Soft leave only — hard tearDown is pool eviction / suspendPlayback.
struct FeedVideoVisibilityReporter: View {
    let postId: UUID
    @Environment(\.feedTabIsActive) private var feedTabIsActive
    @Environment(\.feedVideoCoordinator) private var coordinator

    var body: some View {
        Color.clear
            .frame(height: 0)
            .allowsHitTesting(false)
            .onAppear {
                guard feedTabIsActive else { return }
                SplickViewUpdate.after {
                    coordinator?.updateVisibility(postId: postId, ratio: 1)
                }
            }
            .onDisappear {
                SplickViewUpdate.after {
                    coordinator?.updateVisibility(postId: postId, ratio: 0)
                }
            }
            .onChange(of: feedTabIsActive) { isActive in
                SplickViewUpdate.after {
                    coordinator?.updateVisibility(postId: postId, ratio: isActive ? 1 : 0)
                }
            }
    }
}
