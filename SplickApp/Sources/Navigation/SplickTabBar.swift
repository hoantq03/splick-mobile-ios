import SwiftUI
import DesignSystem
import Localization
import FeatureNotification

// MARK: - iOS 26+ floating notch tab bar

private struct SidePanelMaskShape: Shape {
    enum Side { case leading, trailing }

    let side: Side
    let notchRadius: CGFloat
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = trailingMaskPath(in: rect)
        if side == .leading {
            path = path.applying(
                CGAffineTransform(translationX: rect.width, y: 0)
                    .scaledBy(x: -1, y: 1)
            )
        }
        return path
    }

    private func trailingMaskPath(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: rect,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )
        let cy = rect.midY
        path.addEllipse(in: CGRect(
            x: rect.minX - 2 * notchRadius,
            y: cy - notchRadius,
            width: notchRadius * 2,
            height: notchRadius * 2
        ))
        return path
    }
}

@available(iOS 26.0, *)
private struct ModernSplickTabBar: View {
    @Binding var selectedTab: Tab
    let badgeCounts: TabBadgeCounts
    let tabBarScrollState: TabBarScrollState

    @EnvironmentObject private var languageService: LanguageService
    @State private var tappedTab: Tab?

    private let cameraSize: CGFloat = 63
    private let cameraGap: CGFloat = 5
    private var notchRadius: CGFloat { cameraSize / 2 + cameraGap }
    private let barHeight: CGFloat = 56
    private let cornerRadius: CGFloat = 26
    private let cameraIconSize: CGFloat = 27
    private let panelOuterPadding: CGFloat = 6

    var body: some View {
        let centerLaneWidth = notchRadius * 2

        ZStack {
            HStack(alignment: .center, spacing: 0) {
                sidePanel(side: .leading) {
                    tabButton(.feed, badge: badgeCounts.notifications)
                    tabButton(.expenses, badge: badgeCounts.expenses)
                }
                .frame(maxWidth: .infinity)

                Color.clear
                    .frame(width: centerLaneWidth)
                    .allowsHitTesting(false)

                sidePanel(side: .trailing) {
                    tabButton(.friends, badge: badgeCounts.friends)
                    tabButton(.messages, badge: badgeCounts.messages)
                }
                .frame(maxWidth: .infinity)
            }

            cameraButton
        }
        .frame(height: barHeight)
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.bottom, SplickTheme.Spacing.xxs)
    }

    private func sidePanel<Content: View>(
        side: SidePanelMaskShape.Side,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 0) { content() }
            .padding(.leading, side == .leading ? panelOuterPadding : cameraGap)
            .padding(.trailing, side == .leading ? cameraGap : panelOuterPadding)
            .frame(height: barHeight)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular)
                    .transaction { $0.animation = nil }
                    .clipShape(
                        SidePanelMaskShape(side: side, notchRadius: notchRadius, cornerRadius: cornerRadius),
                        style: FillStyle(eoFill: true)
                    )
            }
    }

    private var cameraButton: some View {
        let isSelected = selectedTab == .camera
        return Button {
            selectedTab = .camera
            tabBarScrollState.hide(flushToBottom: true)
        } label: {
            Circle()
                .fill(SplickTheme.Colors.tabCameraRing)
                .frame(width: cameraSize, height: cameraSize)
                .overlay {
                    Image(systemName: "camera.fill")
                        .font(.system(size: cameraIconSize, weight: .semibold))
                        .foregroundStyle(.white)
                }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel(Tab.camera.localizedTitle(using: languageService))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func tabButton(_ tab: Tab, badge: Int = 0) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            tappedTab = tab
            if selectedTab == tab {
                tabBarScrollState.handleSameTabTap()
            } else {
                selectedTab = tab
            }
            tabBarScrollState.show()
        } label: {
            tabLabel(tab: tab, isSelected: isSelected, badge: badge)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
        .accessibilityLabel(tab.localizedTitle(using: languageService))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func tabLabel(tab: Tab, isSelected: Bool, badge: Int) -> some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 21, weight: .medium))
                    .symbolEffect(.bounce, value: tappedTab == tab)
                TabBarBadgeView(count: badge)
                    .offset(x: 7, y: -5)
            }
            Text(tab.localizedTitle(using: languageService))
                .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
        }
        .foregroundStyle(
            isSelected
                ? SplickTheme.Colors.primaryGradientStart
                : SplickTheme.Colors.textTertiary
        )
        .scaleEffect(tappedTab == tab ? 1.08 : 1.0)
        .animation(.easeOut(duration: 0.16), value: tappedTab == tab)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: tappedTab) { _, _ in
            guard tappedTab == tab else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(180))
                tappedTab = nil
            }
        }
    }
}

// MARK: - iOS 17–25 notched tab bar (same 3-part layout, material instead of Liquid Glass)

private struct LegacySplickTabBar: View {
    @Binding var selectedTab: Tab
    let badgeCounts: TabBadgeCounts
    let tabBarScrollState: TabBarScrollState

    @EnvironmentObject private var languageService: LanguageService
    @State private var tappedTab: Tab?

    /// Larger than iOS 26's 63pt camera so the center action reads clearly without glass depth.
    private let cameraSize: CGFloat = 72
    private let cameraGap: CGFloat = 5
    private var notchRadius: CGFloat { cameraSize / 2 + cameraGap }
    private let barHeight: CGFloat = 56
    private let cornerRadius: CGFloat = 26
    private let cameraIconSize: CGFloat = 30
    private let panelOuterPadding: CGFloat = 6

    var body: some View {
        let centerLaneWidth = notchRadius * 2

        ZStack {
            HStack(alignment: .center, spacing: 0) {
                sidePanel(side: .leading) {
                    tabButton(.feed, badge: badgeCounts.notifications)
                    tabButton(.expenses, badge: badgeCounts.expenses)
                }
                .frame(maxWidth: .infinity)

                Color.clear
                    .frame(width: centerLaneWidth)
                    .allowsHitTesting(false)

                sidePanel(side: .trailing) {
                    tabButton(.friends, badge: badgeCounts.friends)
                    tabButton(.messages, badge: badgeCounts.messages)
                }
                .frame(maxWidth: .infinity)
            }

            cameraButton
        }
        .frame(height: barHeight)
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.bottom, SplickTheme.Spacing.xxs)
    }

    private func sidePanel<Content: View>(
        side: SidePanelMaskShape.Side,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 0) { content() }
            .padding(.leading, side == .leading ? panelOuterPadding : cameraGap)
            .padding(.trailing, side == .leading ? cameraGap : panelOuterPadding)
            .frame(height: barHeight)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(SplickTheme.Colors.secondaryBackground.opacity(0.92))
                    }
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                    .clipShape(
                        SidePanelMaskShape(side: side, notchRadius: notchRadius, cornerRadius: cornerRadius),
                        style: FillStyle(eoFill: true)
                    )
            }
    }

    private var cameraButton: some View {
        let isSelected = selectedTab == .camera
        return Button {
            selectedTab = .camera
            tabBarScrollState.hide(flushToBottom: true)
        } label: {
            Circle()
                .fill(SplickTheme.Colors.tabCameraRing)
                .frame(width: cameraSize, height: cameraSize)
                .overlay {
                    Image(systemName: "camera.fill")
                        .font(.system(size: cameraIconSize, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: SplickTheme.Colors.tabCameraRing.opacity(0.35), radius: 10, y: 3)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel(Tab.camera.localizedTitle(using: languageService))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func tabButton(_ tab: Tab, badge: Int = 0) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            tappedTab = tab
            if selectedTab == tab {
                tabBarScrollState.handleSameTabTap()
            } else {
                selectedTab = tab
            }
            tabBarScrollState.show()
        } label: {
            tabLabel(tab: tab, isSelected: isSelected, badge: badge)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
        .accessibilityLabel(tab.localizedTitle(using: languageService))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func tabLabel(tab: Tab, isSelected: Bool, badge: Int) -> some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 21, weight: .medium))
                TabBarBadgeView(count: badge)
                    .offset(x: 7, y: -5)
            }
            Text(tab.localizedTitle(using: languageService))
                .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(
            isSelected
                ? SplickTheme.Colors.primaryGradientStart
                : SplickTheme.Colors.textTertiary
        )
        .scaleEffect(tappedTab == tab ? 1.08 : 1.0)
        .animation(.easeOut(duration: 0.16), value: tappedTab == tab)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: tappedTab) { _ in
            guard tappedTab == tab else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(180))
                tappedTab = nil
            }
        }
    }
}

// MARK: - Public entry

struct SplickTabBar: View, Equatable {
    @Binding var selectedTab: Tab
    let badgeCounts: TabBadgeCounts
    let tabBarScrollState: TabBarScrollState

    static func == (lhs: SplickTabBar, rhs: SplickTabBar) -> Bool {
        lhs.selectedTab == rhs.selectedTab
            && lhs.badgeCounts == rhs.badgeCounts
    }

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                ModernSplickTabBar(
                    selectedTab: $selectedTab,
                    badgeCounts: badgeCounts,
                    tabBarScrollState: tabBarScrollState
                )
            } else {
                LegacySplickTabBar(
                    selectedTab: $selectedTab,
                    badgeCounts: badgeCounts,
                    tabBarScrollState: tabBarScrollState
                )
            }
        }
    }
}
