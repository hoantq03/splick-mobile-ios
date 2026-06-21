import SwiftUI
import DesignSystem

enum FeedPagerTopInsetMetrics {
    /// Counteracts excess system scroll inset inside the feed pager; tuned below the old 42pt lift.
    private static let contentLift: CGFloat = SplickTheme.Spacing.sm + 22

    static var defaultScrollTopMargin: CGFloat { -contentLift }

    static func resolvedTopMargin(for geometry: GeometryProxy) -> CGFloat {
        let globalMinY = geometry.frame(in: .global).minY
        let safeTop = geometry.safeAreaInsets.top
        let navBarBottom = safeTop + FeedSegmentChromeMetrics.navigationBarHeight

        if globalMinY >= navBarBottom - SplickTheme.Spacing.sm {
            return -contentLift
        }

        return max(-contentLift, navBarBottom - globalMinY - contentLift)
    }
}

extension View {
    /// Restores navigation spacing for scroll views nested inside the feed/album pager `TabView`.
    func feedPagerScrollInsets() -> some View {
        modifier(FeedPagerScrollInsetsModifier())
    }

    /// Restores navigation spacing for non-scroll pager pages (e.g. album filter header stack).
    func feedPagerPageTopInset(isEnabled: Bool) -> some View {
        modifier(FeedPagerPageTopInsetModifier(isEnabled: isEnabled))
    }
}

private struct FeedPagerScrollInsetsModifier: ViewModifier {
    @State private var topMargin: CGFloat = FeedPagerTopInsetMetrics.defaultScrollTopMargin

    func body(content: Content) -> some View {
        Group {
            if #available(iOS 17.0, *) {
                content.contentMargins(.top, topMargin, for: .scrollContent)
            } else {
                content.padding(.top, topMargin)
            }
        }
        .scrollContentBackground(.hidden)
        .background(SplickTheme.Colors.background)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        applyTopMargin(from: geometry)
                    }
                    .onChange(of: geometry.frame(in: .global).minY) { _ in
                        applyTopMargin(from: geometry)
                    }
            }
        }
    }

    private func applyTopMargin(from geometry: GeometryProxy) {
        let next = FeedPagerTopInsetMetrics.resolvedTopMargin(for: geometry)
        guard abs(next - topMargin) > 0.5 else { return }
        topMargin = next
    }
}

private struct FeedPagerPageTopInsetModifier: ViewModifier {
    let isEnabled: Bool
    @State private var topPadding: CGFloat = FeedPagerTopInsetMetrics.defaultScrollTopMargin

    func body(content: Content) -> some View {
        content
            .padding(.top, isEnabled ? topPadding : 0)
            .background {
                if isEnabled {
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                applyTopPadding(from: geometry)
                            }
                            .onChange(of: geometry.frame(in: .global).minY) { _ in
                                applyTopPadding(from: geometry)
                            }
                    }
                }
            }
    }

    private func applyTopPadding(from geometry: GeometryProxy) {
        let next = FeedPagerTopInsetMetrics.resolvedTopMargin(for: geometry)
        guard abs(next - topPadding) > 0.5 else { return }
        topPadding = next
    }
}
