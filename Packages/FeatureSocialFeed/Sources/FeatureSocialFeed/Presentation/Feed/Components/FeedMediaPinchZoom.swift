import SwiftUI

/// Instagram-style two-finger pinch zoom for feed media.
/// Zooms in place, locks feed scroll while active, then springs back on release.
struct FeedMediaPinchZoomModifier: ViewModifier {
    @Binding var isActive: Bool

    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    private let minimumScale: CGFloat = 1
    private let maximumScale: CGFloat = 4
    private let activationThreshold: CGFloat = 1.02

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale, anchor: .center)
            .offset(offset)
            .shadow(
                color: .black.opacity(isActivelyZooming ? 0.28 : 0),
                radius: isActivelyZooming ? 18 : 0,
                y: isActivelyZooming ? 8 : 0
            )
            .simultaneousGesture(magnificationGesture)
            .simultaneousGesture(dragGesture, including: isActivelyZooming ? .all : .none)
            .onDisappear {
                resetZoom(animated: false)
            }
    }

    private var isActivelyZooming: Bool {
        scale > activationThreshold
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let next = min(max(baseScale * value, minimumScale), maximumScale)
                scale = next
                updateActiveState(for: next)
            }
            .onEnded { _ in
                // Feed peek zoom always settles back — open detail for persistent zoom.
                resetZoom(animated: true)
            }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                offset = CGSize(
                    width: baseOffset.width + value.translation.width,
                    height: baseOffset.height + value.translation.height
                )
            }
            .onEnded { value in
                baseOffset = CGSize(
                    width: baseOffset.width + value.translation.width,
                    height: baseOffset.height + value.translation.height
                )
            }
    }

    private func updateActiveState(for scale: CGFloat) {
        let active = scale > activationThreshold
        guard active != isActive else { return }
        isActive = active
        FeedScrollLock.setLocked(active)
    }

    private func resetZoom(animated: Bool) {
        let apply = {
            scale = 1
            baseScale = 1
            offset = .zero
            baseOffset = .zero
        }
        if animated {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                apply()
            }
        } else {
            apply()
        }
        if isActive {
            isActive = false
            FeedScrollLock.setLocked(false)
        }
    }
}

extension View {
    func feedMediaPinchZoom(isActive: Binding<Bool>) -> some View {
        modifier(FeedMediaPinchZoomModifier(isActive: isActive))
    }
}
