import SwiftUI
import UIKit

struct FeedPostVisibilityReport: Equatable {
    let postId: UUID
    let ratio: CGFloat
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

/// Reports how much of a feed card sits in the window, without `onChange(of: CGRect)`.
struct FeedPostVisibilityReporter: View {
    let postId: UUID

    var body: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .global)
            let screen = UIScreen.main.bounds
            let visibleHeight = max(0, min(frame.maxY, screen.maxY) - max(frame.minY, screen.minY))
            let ratio = frame.height > 0 ? visibleHeight / frame.height : 0
            Color.clear
                .preference(
                    key: FeedPostVisibilityPreferenceKey.self,
                    value: [FeedPostVisibilityReport(postId: postId, ratio: ratio)]
                )
        }
        .allowsHitTesting(false)
    }
}

extension View {
    func onFeedPostVisibilityChange(
        threshold: CGFloat = 0.35,
        _ action: @escaping (Set<UUID>) -> Void
    ) -> some View {
        onPreferenceChange(FeedPostVisibilityPreferenceKey.self) { reports in
            DispatchQueue.main.async {
                let visibleIds = Set(reports.filter { $0.ratio >= threshold }.map(\.postId))
                action(visibleIds)
            }
        }
    }
}
