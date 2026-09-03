import SwiftUI
import UIKit
import DesignSystem
import Localization

struct FeedNewPostsPillOverlay: View {
    let count: Int
    let onTap: () -> Void

    var body: some View {
        GeometryReader { geometry in
            // Mirror the same coordinate origin as FeedScrollTopFadeOverlay:
            // ignoresSafeArea(.top) → frame starts at y=0 → safeAreaInsets.top includes
            // the actual status-bar + navigation-bar height reported by the OS.
            let topInset = geometry.safeAreaInsets.top
                + FeedSegmentChromeMetrics.navigationBarHeight
                + FeedSegmentChromeMetrics.segmentRowHeight
                + SplickTheme.Spacing.sm

            VStack(spacing: 0) {
                FeedNewPostsPill(count: count, onTap: onTap)
                    .padding(.top, topInset)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(count > 0)
    }
}

struct FeedNewPostsPill: View {
    @EnvironmentObject private var languageService: LanguageService
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Group {
            if count > 0 {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onTap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .bold))
                        Text(languageService.format(.feedNewPostsCount, count))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .contentTransition(.numericText())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(SplickTheme.Colors.primaryGradientStart)
                            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                    )
                }
                .buttonStyle(FeedNewPostsPillButtonStyle())
                .accessibilityLabel(languageService.format(.feedNewPostsCount, count))
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .top)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.94, anchor: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                    )
                )
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: count)
    }
}

private struct FeedNewPostsPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
