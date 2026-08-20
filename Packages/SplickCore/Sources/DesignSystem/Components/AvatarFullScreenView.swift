import SwiftUI
import UIKit

/// Full-screen avatar viewer with pinch-to-zoom, pan, double-tap zoom, and swipe-down dismiss.
/// Loads the avatar at device-screen resolution (no downscale cap) so the image is crisp
/// on Retina/ProMotion displays.
public struct AvatarFullScreenView: View {
    public let url: URL?
    public let placeholderName: String
    public let onDismiss: () -> Void

    public init(
        url: URL?,
        placeholderName: String,
        onDismiss: @escaping () -> Void
    ) {
        self.url = url
        self.placeholderName = placeholderName
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let url {
                // maxPixelSize: nil → Nuke loads the original resolution, no downscale.
                RemoteImage(url: url, maxPixelSize: nil) { phase in
                    switch phase {
                    case .success(let image):
                        ZoomableAvatarContainer(image: image)
                    case .failure:
                        avatarInitials
                    default:
                        ProgressView().tint(.white)
                    }
                }
            } else {
                avatarInitials
            }

            closeButton
        }
        // Swipe-down to dismiss
        .gesture(
            DragGesture(minimumDistance: 60, coordinateSpace: .global)
                .onEnded { value in
                    if value.translation.height > 80 && abs(value.translation.width) < 80 {
                        onDismiss()
                    }
                }
        )
        .ignoresSafeArea()
    }

    private var avatarInitials: some View {
        ZStack {
            SplickTheme.Colors.primaryGradient
            Text(String(placeholderName.prefix(2)).uppercased())
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 180, height: 180)
        .clipShape(Circle())
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.black.opacity(0.45))
                }
                .padding(.top, 16)
                .padding(.trailing, 16)
                .accessibilityLabel("Close")
            }
            Spacer()
        }
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Zoomable container

/// SwiftUI-based pinch-zoom + pan + double-tap for a full-screen image.
/// Uses spring animations to snap back to valid bounds after gesture ends.
private struct ZoomableAvatarContainer: View {
    let image: Image

    @State private var scale: CGFloat = 1
    @State private var lastCommittedScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastCommittedOffset: CGSize = .zero

    private static let minScale: CGFloat = 1
    private static let maxScale: CGFloat = 5

    var body: some View {
        image
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .simultaneousGesture(zoomGesture)
            .simultaneousGesture(panGesture)
            .onTapGesture(count: 2) { handleDoubleTap() }
    }

    // MARK: Pinch-to-zoom

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let proposed = lastCommittedScale * value
                // Rubber-band past limits so it doesn't feel hard-clamped
                scale = rubberBand(proposed, min: Self.minScale, max: Self.maxScale)
            }
            .onEnded { value in
                let clamped = max(Self.minScale, min(lastCommittedScale * value, Self.maxScale))
                withAnimation(.spring(response: 0.30, dampingFraction: 0.66)) {
                    scale = clamped
                    if clamped <= Self.minScale {
                        offset = .zero
                        lastCommittedOffset = .zero
                    }
                }
                lastCommittedScale = clamped
            }
    }

    // MARK: Pan (only active when zoomed in)

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: lastCommittedOffset.width + value.translation.width,
                    height: lastCommittedOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                if scale <= 1 {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.70)) {
                        offset = .zero
                    }
                    lastCommittedOffset = .zero
                } else {
                    lastCommittedOffset = offset
                }
            }
    }

    // MARK: Double-tap

    private func handleDoubleTap() {
        let targetScale: CGFloat = scale > 1 ? 1 : 2.5
        withAnimation(.spring(response: 0.28, dampingFraction: 0.60)) {
            scale = targetScale
            lastCommittedScale = targetScale
            if targetScale <= 1 {
                offset = .zero
                lastCommittedOffset = .zero
            }
        }
    }

    // MARK: Helpers

    /// Applies resistance beyond the hard min/max so gestures feel elastic, not clipped.
    private func rubberBand(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        if value < min {
            let delta = min - value
            return min - delta * 0.3
        } else if value > max {
            let delta = value - max
            return max + delta * 0.3
        }
        return value
    }
}
