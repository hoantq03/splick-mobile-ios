import SwiftUI
import UIKit
import AVFoundation

/// Picks the most visible feed video post for autoplay and owns a small AVPlayer pool.
@MainActor
final class FeedVideoPlaybackCoordinator: ObservableObject {
    @Published private(set) var activePostId: UUID?

    private var visibilityByPost: [UUID: CGFloat] = [:]
    private let activationThreshold: CGFloat = 0.35

    /// Max concurrent AVPlayers kept alive for feed cells (active + one warm neighbor).
    private let poolCapacity = 2
    private var pooledControllers: [UUID: FeedVideoPlaybackController] = [:]
    private var pooledURLs: [UUID: URL] = [:]
    private var lruOrder: [UUID] = []

    private var pendingVisibilityReports: [FeedVideoVisibilityReport]?
    private var visibilityFlushTask: Task<Void, Never>?
    private static let visibilityDebounceNanos: UInt64 = 100_000_000 // 100ms

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
        if activePostId == postId {
            activePostId = nil
        }
        releaseController(for: postId)
        pickActivePost()
    }

    /// Stops autoplay when the feed tab is hidden (other tabs / background).
    func suspendPlayback() {
        visibilityFlushTask?.cancel()
        visibilityFlushTask = nil
        pendingVisibilityReports = nil
        visibilityByPost.removeAll()
        activePostId = nil
        for controller in pooledControllers.values {
            controller.setAutoplayActive(false)
        }
        releaseAllControllers()
    }

    /// Returns a pooled controller only when this post is the autoplay target (or already pooled).
    func controller(for postId: UUID, url: URL) -> FeedVideoPlaybackController? {
        guard activePostId == postId || pooledControllers[postId] != nil else {
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
            let victim = lruOrder.first(where: { $0 != reservedId && $0 != activePostId })
                ?? lruOrder.first(where: { $0 != reservedId })
            guard let victim else { break }
            releaseController(for: victim)
        }
    }

    private func touchLRU(_ postId: UUID) {
        lruOrder.removeAll { $0 == postId }
        lruOrder.append(postId)
    }

    private func pickActivePost() {
        guard let best = visibilityByPost.max(by: { $0.value < $1.value }),
              best.value >= activationThreshold else {
            if activePostId != nil {
                let previous = activePostId
                activePostId = nil
                if let previous, let controller = pooledControllers[previous] {
                    controller.setAutoplayActive(false)
                }
            }
            return
        }
        if activePostId != best.key {
            let previous = activePostId
            activePostId = best.key
            if let previous, let controller = pooledControllers[previous] {
                controller.setAutoplayActive(false)
            }
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
                coordinator?.clearPost(postId)
            }
            .onChange(of: feedTabIsActive) { isActive in
                if isActive {
                    coordinator?.updateVisibility(postId: postId, ratio: 1)
                } else {
                    coordinator?.clearPost(postId)
                }
            }
    }
}
