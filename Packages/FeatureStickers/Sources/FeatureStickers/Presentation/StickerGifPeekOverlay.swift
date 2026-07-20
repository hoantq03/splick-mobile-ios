import SwiftUI
import UIKit
import DesignSystem
import Localization
import SplickDomain

/// Long-press peek: 2× animated GIF + favorite action.
/// Opens with a quick spring pop (iOS context-menu style) after the cell's press grow.
struct StickerGifPeekOverlay: View {
    @EnvironmentObject private var languageService: LanguageService

    let sticker: Sticker
    let isFavorite: Bool
    let isTogglingFavorite: Bool
    let addFavoriteTitle: String
    let removeFavoriteTitle: String
    let onToggleFavorite: () -> Void
    let onDismiss: () -> Void
    let onSelect: () -> Void

    private enum Metrics {
        static let scale: CGFloat = 2
        static let columnsPerRow: CGFloat = 4
        static let gridSpacing: CGFloat = 10
        static let horizontalPadding: CGFloat = SplickTheme.Spacing.md * 2
        static let cornerRadius: CGFloat = SplickTheme.CornerRadius.tile
        /// Cell is already ~1.1× from press; peek is 2× cell → start near pressed size.
        static let initialCardScale: CGFloat = 0.55
    }

    @State private var appeared = false
    @State private var showsFavorite = false

    var body: some View {
        GeometryReader { geo in
            let cellSide = max(
                64,
                (geo.size.width - Metrics.horizontalPadding - Metrics.gridSpacing * (Metrics.columnsPerRow - 1))
                    / Metrics.columnsPerRow
            )
            let peekSize = cellSide * Metrics.scale

            ZStack {
                Color.black.opacity(appeared ? 0.48 : 0)
                    .ignoresSafeArea()
                    .onTapGesture(perform: dismiss)

                VStack(spacing: 16) {
                    peekCard(size: peekSize)
                        .scaleEffect(appeared ? 1 : Metrics.initialCardScale)
                        .opacity(appeared ? 1 : 0.92)

                    favoriteButton
                        .scaleEffect(showsFavorite ? 1 : 0.72)
                        .opacity(showsFavorite ? 1 : 0)
                        .offset(y: showsFavorite ? 0 : 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, SplickTheme.Spacing.lg)
            }
        }
        .onAppear(perform: playAppearAnimation)
    }

    private func playAppearAnimation() {
        // Snappy overshoot — closer to UIKit context-menu / peek presentation.
        withAnimation(.interpolatingSpring(stiffness: 320, damping: 22)) {
            appeared = true
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.7).delay(0.06)) {
            showsFavorite = true
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.16)) {
            showsFavorite = false
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            onDismiss()
        }
    }

    private func peekCard(size: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
        let maxPixel = RemoteImageMetrics.inlineAttachmentMaxPixelWidth(pointWidth: size)

        return shape
            .fill(SplickTheme.Colors.secondaryBackground)
            .frame(width: size, height: size)
            .overlay {
                AnimatedRemoteImage(
                    url: sticker.url,
                    contentMode: .fill,
                    maxPixelSize: maxPixel,
                    isAnimating: true
                )
                .frame(width: size, height: size)
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.4), radius: 22, x: 0, y: 12)
            .contentShape(shape)
            .onTapGesture(perform: onSelect)
            .accessibilityLabel(languageService.text(.stickersGifPreviewA11y))
            .accessibilityHint(languageService.text(.stickersGifDoubleTapSend))
    }

    private var favoriteButton: some View {
        Button(action: onToggleFavorite) {
            HStack(spacing: 8) {
                if isTogglingFavorite {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isFavorite ? Color.yellow : Color.white)
                }

                Text(isFavorite ? removeFavoriteTitle : addFavoriteTitle)
                    .font(SplickTheme.Typography.captionBold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFavorite ? removeFavoriteTitle : addFavoriteTitle)
    }
}
