import SwiftUI
import UIKit

struct FeedPostVisibilityReport: Equatable {
    let postId: UUID
    /// max(card coverage, viewport coverage) — used for "is this card on screen".
    let ratio: CGFloat
    /// Fraction of the screen height this card occupies. Used for video autoplay.
    let viewportRatio: CGFloat
}

private struct FeedPostVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: [FeedPostVisibilityReport] = []

    static func reduce(
        value: inout [FeedPostVisibilityReport],
        nextValue: () -> [FeedPostVisibilityReport]
    ) {
        value.append(contentsOf: nextValue())
    }
}

/// Continuous geometry reporting — only attach to video cards (autoplay needs ratios).
/// Photo cards use appear/disappear so leave-from-top scroll isn't flooded with PreferenceKeys.
struct FeedPostVisibilityReporter: View {
    let postId: UUID

    var body: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .global)
            let screen = UIScreen.main.bounds
            let visibleHeight = max(0, min(frame.maxY, screen.maxY) - max(frame.minY, screen.minY))
            let cardRatio = frame.height > 0 ? visibleHeight / frame.height : 0
            let viewportRatio = screen.height > 0 ? visibleHeight / screen.height : 0
            let ratio = max(cardRatio, viewportRatio)
            Color.clear
                .preference(
                    key: FeedPostVisibilityPreferenceKey.self,
                    value: [
                        FeedPostVisibilityReport(
                            postId: postId,
                            ratio: ratio,
                            viewportRatio: viewportRatio
                        )
                    ]
                )
        }
        .allowsHitTesting(false)
    }
}

extension View {
    func onFeedPostVisibilityChange(
        threshold: CGFloat = 0.35,
        _ action: @escaping (_ visibleIds: Set<UUID>, _ reports: [FeedPostVisibilityReport]) -> Void
    ) -> some View {
        modifier(
            FeedPostVisibilityChangeModifier(threshold: threshold, action: action)
        )
    }
}

/// Coalesces PreferenceKey floods while scrolling so leave-from-top doesn't hitch the main thread.
private struct FeedPostVisibilityChangeModifier: ViewModifier {
    let threshold: CGFloat
    let action: (_ visibleIds: Set<UUID>, _ reports: [FeedPostVisibilityReport]) -> Void
    @State private var pendingReports: [FeedPostVisibilityReport]?
    @State private var flushTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content.onPreferenceChange(FeedPostVisibilityPreferenceKey.self) { reports in
            pendingReports = reports
            guard flushTask == nil else { return }
            flushTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 48_000_000)
                flushTask = nil
                guard let pending = pendingReports else { return }
                pendingReports = nil
                let visibleIds = Set(pending.filter { $0.ratio >= threshold }.map(\.postId))
                action(visibleIds, pending)
            }
        }
    }
}
