import SwiftUI
import Common
import DesignSystem
import Localization
import FeatureNotification

// MARK: - Mask shape (replaces per-frame Canvas — cheaper on iOS 17 / older GPUs)

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

    /// Bite on the left inner edge; circle center sits `notchRadius` outside the panel.
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

// MARK: - Tab bar

struct SplickTabBar: View, Equatable {
    @Binding var selectedTab: Tab
    let badgeCounts: TabBadgeCounts
    let tabBarIsVisible: Bool

    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.tabBarScrollState) private var tabBarScrollState

    private let cameraSize: CGFloat = 63
    private let cameraGap: CGFloat = 5
    private var cameraRadius: CGFloat { cameraSize / 2 }
    private var notchRadius: CGFloat { cameraRadius + cameraGap }
    private let barHeight: CGFloat = 56
    private let cornerRadius: CGFloat = 26
    private let cameraIconSize: CGFloat = 27
    private let panelOuterPadding: CGFloat = 6

    static func == (lhs: SplickTabBar, rhs: SplickTabBar) -> Bool {
        lhs.selectedTab == rhs.selectedTab
            && lhs.badgeCounts == rhs.badgeCounts
            && lhs.tabBarIsVisible == rhs.tabBarIsVisible
    }

    var body: some View {
        let centerLaneWidth = notchRadius * 2

        ZStack {
            HStack(alignment: .center, spacing: 0) {
                sidePanel(side: .leading) {
                    tabButton(.feed)
                    tabButton(.expenses, badge: badgeCounts.expenses)
                }
                .frame(maxWidth: .infinity)

                Color.clear
                    .frame(width: centerLaneWidth)
                    .allowsHitTesting(false)

                sidePanel(side: .trailing) {
                    tabButton(.friends, badge: badgeCounts.friends)
                    tabButton(.notifications, badge: badgeCounts.notifications)
                }
                .frame(maxWidth: .infinity)
            }

            cameraButton
        }
        .frame(height: barHeight)
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.bottom, SplickTheme.Spacing.xxs)
        .compositingGroup()
    }

    private func sidePanel<Content: View>(
        side: SidePanelMaskShape.Side,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 0) {
            content()
        }
        .padding(.leading, side == .leading ? panelOuterPadding : cameraGap)
        .padding(.trailing, side == .leading ? cameraGap : panelOuterPadding)
        .frame(height: barHeight)
        .frame(maxWidth: .infinity)
        .background { sidePanelBackground }
        .clipShape(
            SidePanelMaskShape(
                side: side,
                notchRadius: notchRadius,
                cornerRadius: cornerRadius
            ),
            style: FillStyle(eoFill: true)
        )
    }

    @ViewBuilder
    private var sidePanelBackground: some View {
        if #available(iOS 26.0, *) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(SplickTheme.Colors.secondaryBackground.opacity(0.96))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        }
    }

    private var cameraButton: some View {
        let isSelected = selectedTab == .camera
        return Button {
            selectedTab = .camera
            tabBarScrollState?.show()
        } label: {
            Circle()
                .fill(SplickTheme.Colors.tabCameraRing)
                .frame(width: cameraSize, height: cameraSize)
                .overlay {
                    Image(systemName: "camera.fill")
                        .font(.system(size: cameraIconSize, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: SplickTheme.Colors.tabCameraRing.opacity(0.35), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel(Tab.camera.localizedTitle(using: languageService))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func tabButton(_ tab: Tab, badge: Int = 0) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
            tabBarScrollState?.show()
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 3) {
                    Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 21, weight: .medium))
                        .symbolRenderingMode(.monochrome)
                    Text(tab.localizedTitle(using: languageService))
                        .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .allowsTightening(true)
                }
                .foregroundStyle(
                    isSelected
                        ? SplickTheme.Colors.primaryGradientStart
                        : SplickTheme.Colors.textTertiary
                )

                TabBarBadgeView(count: badge)
                    .offset(x: 10, y: -6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
        .accessibilityLabel(tab.localizedTitle(using: languageService))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
