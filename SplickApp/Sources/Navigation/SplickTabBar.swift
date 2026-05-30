import SwiftUI
import DesignSystem
import Localization

// MARK: - Mask (trailing geometry mirrored for leading)

private struct SidePanelMask: View {
    enum Side { case leading, trailing }

    let side: Side
    let notchRadius: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        Canvas { context, size in
            var path = trailingMaskPath(in: size)
            if side == .leading {
                path = path.applying(
                    CGAffineTransform(translationX: size.width, y: 0)
                        .scaledBy(x: -1, y: 1)
                )
            }
            context.fill(path, with: .color(.white), style: FillStyle(eoFill: true))
        }
    }

    /// Bite on the left inner edge; circle center sits `notchRadius` outside the panel.
    private func trailingMaskPath(in size: CGSize) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: CGRect(origin: .zero, size: size),
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )

        let cy = size.height / 2
        path.addEllipse(in: CGRect(
            x: -2 * notchRadius,
            y: cy - notchRadius,
            width: notchRadius * 2,
            height: notchRadius * 2
        ))
        return path
    }
}

// MARK: - Tab bar

struct SplickTabBar: View {
    @Binding var selectedTab: Tab
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

    var body: some View {
        GeometryReader { geo in
            let centerLaneWidth = notchRadius * 2
            let sideWidth = max(0, (geo.size.width - centerLaneWidth) / 2)

            ZStack {
                HStack(alignment: .center, spacing: 0) {
                    sidePanel(side: .leading) {
                        tabButton(.feed)
                        tabButton(.expenses)
                    }
                    .frame(width: sideWidth)

                    Color.clear
                        .frame(width: centerLaneWidth)
                        .allowsHitTesting(false)

                    sidePanel(side: .trailing) {
                        tabButton(.friends)
                        tabButton(.notifications)
                    }
                    .frame(width: sideWidth)
                }

                cameraButton
            }
        }
        .frame(height: barHeight)
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.bottom, SplickTheme.Spacing.xxs)
    }

    private func sidePanel<Content: View>(
        side: SidePanelMask.Side,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 0) {
            content()
        }
        .padding(.leading, side == .leading ? panelOuterPadding : cameraGap)
        .padding(.trailing, side == .leading ? cameraGap : panelOuterPadding)
        .frame(height: barHeight)
        .frame(maxWidth: .infinity)
        .background { sideGlassBackground }
        .mask {
            SidePanelMask(
                side: side,
                notchRadius: notchRadius,
                cornerRadius: cornerRadius
            )
        }
    }

    @ViewBuilder
    private var sideGlassBackground: some View {
        if #available(iOS 26.0, *) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
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

    private func tabButton(_ tab: Tab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
            tabBarScrollState?.show()
        } label: {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
        .accessibilityLabel(tab.localizedTitle(using: languageService))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
