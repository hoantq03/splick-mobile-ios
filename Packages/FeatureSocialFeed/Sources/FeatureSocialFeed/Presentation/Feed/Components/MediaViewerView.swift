import SwiftUI
import AVKit
import DesignSystem
import SplickDomain

// MARK: - MediaViewerView

/// Fullscreen media viewer: pinch-to-zoom images, swipe horizontally between items,
/// swipe down (when not zoomed) or tap X to dismiss.
struct MediaViewerView: View {
    let items: [PostMediaItem]
    let initialIndex: Int
    @Binding var isPresented: Bool

    @State private var selectedIndex: Int
    /// Tracks the current page's zoom level so the dismiss gesture knows whether to activate.
    @State private var currentPageScale: CGFloat = 1.0
    @State private var dismissDragOffset: CGFloat = 0

    init(items: [PostMediaItem], initialIndex: Int, isPresented: Binding<Bool>) {
        self.items = items
        self.initialIndex = initialIndex
        self._isPresented = isPresented
        self._selectedIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .opacity(backgroundOpacity)

            TabView(selection: $selectedIndex) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    itemView(item, index: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .offset(y: dismissDragOffset)
            .gesture(dismissGesture)

            overlayControls
        }
        .statusBarHidden(true)
        .onChange(of: selectedIndex) { _ in
            currentPageScale = 1.0
            dismissDragOffset = 0
        }
    }

    // MARK: - Background opacity dims as user swipes down

    private var backgroundOpacity: Double {
        max(0, 1 - Double(abs(dismissDragOffset)) / 350)
    }

    // MARK: - Dismiss gesture (swipe down, only when not zoomed)

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 15, coordinateSpace: .global)
            .onChanged { drag in
                guard currentPageScale <= 1.0, drag.translation.height > 0 else { return }
                dismissDragOffset = drag.translation.height
            }
            .onEnded { drag in
                if drag.translation.height > 120, currentPageScale <= 1.0 {
                    isPresented = false
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        dismissDragOffset = 0
                    }
                }
            }
    }

    // MARK: - Overlay: close button + page indicator

    private var overlayControls: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.black.opacity(0.55))
                        .clipShape(Circle())
                }
                .padding(.trailing, 16)
                .padding(.top, 56)
            }

            Spacer()

            if items.count > 1 {
                Text("\(selectedIndex + 1) / \(items.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(.bottom, 44)
            }
        }
        .offset(y: dismissDragOffset)
        .allowsHitTesting(dismissDragOffset == 0)
    }

    // MARK: - Per-item view

    @ViewBuilder
    private func itemView(_ item: PostMediaItem, index: Int) -> some View {
        switch item.mediaType {
        case .image:
            ZoomableImageView(
                url: item.thumbnailURL ?? item.mediaURL,
                onScaleChanged: { scale in
                    if index == selectedIndex { currentPageScale = scale }
                }
            )
        case .video:
            fullscreenVideoView(for: item)
        }
    }

    private func fullscreenVideoView(for item: PostMediaItem) -> some View {
        VideoPlayer(player: AVPlayer(url: item.mediaURL))
            .ignoresSafeArea()
    }
}

// MARK: - ZoomableImageView

private struct ZoomableImageView: View {
    let url: URL
    var onScaleChanged: ((CGFloat) -> Void)?

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            RemoteImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(scale)
                        .offset(panOffset)
                        .gesture(doubleTapGesture)
                        .simultaneousGesture(magnificationGesture)
                        .simultaneousGesture(panGesture)
                default:
                    Color.clear
                        .frame(width: geo.size.width, height: geo.size.height)
                        .overlay { ProgressView().tint(.white) }
                }
            }
        }
        .ignoresSafeArea()
    }

    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2).onEnded {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if scale > 1 {
                    resetZoom()
                } else {
                    scale = 2.5
                    lastScale = 2.5
                    onScaleChanged?(2.5)
                }
            }
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = max(1.0, min(5.0, lastScale * value))
                scale = newScale
                onScaleChanged?(newScale)
            }
            .onEnded { value in
                lastScale = scale
                if scale < 1.0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        resetZoom()
                    }
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { drag in
                guard scale > 1.0 else { return }
                panOffset = CGSize(
                    width: lastPanOffset.width + drag.translation.width,
                    height: lastPanOffset.height + drag.translation.height
                )
            }
            .onEnded { _ in
                lastPanOffset = panOffset
            }
    }

    private func resetZoom() {
        scale = 1.0
        lastScale = 1.0
        panOffset = .zero
        lastPanOffset = .zero
        onScaleChanged?(1.0)
    }
}
