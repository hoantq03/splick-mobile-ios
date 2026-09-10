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

    @State private var popScale: CGFloat = 0.55
    @State private var popOffset: CGFloat = -18
    @State private var popOpacity: Double = 0
    @State private var lastAnimatedCount = 0

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
                            .fill(SplickTheme.Colors.success)
                            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                    )
                }
                .buttonStyle(FeedNewPostsPillButtonStyle())
                .scaleEffect(popScale)
                .opacity(popOpacity)
                .offset(y: popOffset)
                .accessibilityLabel(languageService.format(.feedNewPostsCount, count))
            }
        }
        .onAppear {
            if count > 0 {
                handleCountChange(count)
            }
        }
        .onChange(of: count) { newCount in
            handleCountChange(newCount)
        }
    }

    private func playEntranceAnimation() {
        popScale = 0.55
        popOffset = -18
        popOpacity = 0
        withAnimation(.spring(response: 0.48, dampingFraction: 0.56)) {
            popScale = 1
            popOffset = 0
            popOpacity = 1
        }
    }

    private func playCountBumpAnimation() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.48)) {
            popScale = 1.1
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.62).delay(0.07)) {
            popScale = 1
        }
    }

    private func handleCountChange(_ newCount: Int) {
        if newCount > 0 {
            if lastAnimatedCount == 0 {
                playEntranceAnimation()
            } else if newCount != lastAnimatedCount {
                playCountBumpAnimation()
            }
            lastAnimatedCount = newCount
        } else {
            lastAnimatedCount = 0
            withAnimation(.easeOut(duration: 0.2)) {
                popScale = 0.9
                popOffset = -10
                popOpacity = 0
            }
        }
    }
}

private struct FeedNewPostsPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
