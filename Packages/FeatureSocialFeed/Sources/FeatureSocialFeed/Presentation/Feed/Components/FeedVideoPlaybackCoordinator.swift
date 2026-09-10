import SwiftUI
import UIKit
import AVFoundation

/// Autoplay every on-screen feed video post (post-card visibility), with a small AVPlayer pool.
@MainActor
final class FeedVideoPlaybackCoordinator: ObservableObject {
    /// All post IDs currently allowed to autoplay (any portion of the card on screen).
    @Published private(set) var activePostIds: Set<UUID> = []

    /// Back-compat for call sites that still read a single id (first active).
    var activePostId: UUID? { activePostIds.first }

    private var visibilityByPost: [UUID: CGFloat] = [:]
    /// Any on-screen presence of the post card is enough — do not wait for the video subframe.
    private let activationThreshold: CGFloat = 0.01

    /// Concurrent AVPlayers for visible video cells (+ small warm buffer).
    private let poolCapacity = 6
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
        for report in reports where report.ratio > activationThreshold {
            visibilityByPost[report.postId] = report.ratio
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
        activePostIds.remove(postId)
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
        activePostIds = []
        for controller in pooledControllers.values {
            controller.setAutoplayActive(false)
        }
        releaseAllControllers()
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
        let next = Set(
            visibilityByPost
                .filter { $0.value >= activationThreshold }
                .map(\.key)
        )
        guard next != activePostIds else { return }
        let removed = activePostIds.subtracting(next)
        let added = next.subtracting(activePostIds)
        activePostIds = next
        for id in removed {
            pooledControllers[id]?.setAutoplayActive(false)
        }
        for id in added {
            pooledControllers[id]?.setAutoplayActive(true)
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
                coordinator?.updateVisibility(postId: postId, ratio: 1)
            }
            .onDisappear {
                coordinator?.updateVisibility(postId: postId, ratio: 0)
            }
            .onChange(of: feedTabIsActive) { isActive in
                if isActive {
                    coordinator?.updateVisibility(postId: postId, ratio: 1)
                } else {
                    coordinator?.updateVisibility(postId: postId, ratio: 0)
                }
            }
    }
}
