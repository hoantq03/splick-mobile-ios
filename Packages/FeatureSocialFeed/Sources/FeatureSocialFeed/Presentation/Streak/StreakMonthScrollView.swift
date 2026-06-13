import SwiftUI
import DesignSystem
import SplickDomain

/// Continuous vertical month list (like photo album). Free scroll while dragging;
/// on iOS 17+ snaps a full month into the viewport only when decelerating to a stop.
struct StreakMonthScrollView: View {
    let sections: [StreakMonthSection]
    let anchorMonthID: String
    let isLoadingOlder: Bool
    let onLoadOlder: (StreakMonthSection) -> Void
    let onDayTap: (StreakDay) -> Void
    let onRefresh: () async -> Void

    @State private var didInitialScroll = false

    var body: some View {
        ScrollViewReader { proxy in
            Group {
                if #available(iOS 17.0, *) {
                    ScrollView {
                        monthStack
                            .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                    .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                } else {
                    ScrollView {
                        monthStack
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(SplickTheme.Colors.background)
            .refreshable { await onRefresh() }
            .tabBarHideOnScroll()
            .feedSegmentHideOnScroll()
            .onAppear {
                scrollToCurrentMonth(using: proxy, animated: false)
            }
        }
    }

    private var monthStack: some View {
        LazyVStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
            if isLoadingOlder {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SplickTheme.Spacing.sm)
            }

            ForEach(sections) { section in
                StreakMonthSectionView(section: section, onDayTap: onDayTap)
                    .id(section.id)
                    .onAppear {
                        if section.id == sections.first?.id {
                            onLoadOlder(section)
                        }
                    }
            }
        }
        .padding(.top, SplickTheme.Spacing.xs)
        .padding(.bottom, SplickTheme.Spacing.xl)
    }

    private func scrollToCurrentMonth(using proxy: ScrollViewProxy, animated: Bool) {
        guard !didInitialScroll, !anchorMonthID.isEmpty else { return }
        DispatchQueue.main.async {
            if animated {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                    proxy.scrollTo(anchorMonthID, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(anchorMonthID, anchor: .bottom)
            }
            didInitialScroll = true
        }
    }
}