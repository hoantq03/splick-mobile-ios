import SwiftUI

struct PhotoEditorStickerLayer: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    let displayMetrics: ImageDisplayMetrics
    let isEditing: Bool

    var body: some View {
        ZStack {
            ForEach(viewModel.stickerItems) { item in
                StickerOverlayItemView(
                    item: item,
                    center: displayMetrics.imageNormalizedToView(item.normalizedPosition),
                    isSelected: viewModel.selectedStickerID == item.id,
                    isInteractive: isEditing,
                    displayFrame: displayMetrics.displayFrame,
                    gifData: viewModel.gifData(for: item.kind),
                    onSelect: { viewModel.selectedStickerID = item.id },
                    onMove: { viewModel.updateStickerPosition(id: item.id, normalizedPosition: $0) },
                    onScale: { viewModel.updateStickerScale(id: item.id, scale: $0) },
                    onRotate: { viewModel.updateStickerRotation(id: item.id, rotation: $0) },
                    onTransformEnd: { viewModel.commitStickerTransform() }
                )
            }
        }
    }
}

private struct StickerOverlayItemView: View {
    let item: EditorStickerItem
    let center: CGPoint
    let isSelected: Bool
    let isInteractive: Bool
    let displayFrame: CGRect
    let gifData: Data?
    let onSelect: () -> Void
    let onMove: (CGPoint) -> Void
    let onScale: (CGFloat) -> Void
    let onRotate: (Angle) -> Void
    let onTransformEnd: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var liveScale: CGFloat = 1
    @State private var liveRotation: Angle = .zero

    var body: some View {
        EditorStickerContentView(kind: item.kind, gifData: gifData)
            .fixedSize(horizontal: true, vertical: true)
            .scaleEffect(item.scale * liveScale)
            .rotationEffect(item.rotation + liveRotation)
            .overlay {
                if isSelected, isInteractive {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                        .padding(-6)
                }
            }
            .position(x: center.x + dragOffset.width, y: center.y + dragOffset.height)
            .allowsHitTesting(isInteractive)
            .gesture(dragGesture)
            .simultaneousGesture(magnifyGesture)
            .simultaneousGesture(rotateGesture)
            .onTapGesture {
                guard isInteractive else { return }
                onSelect()
            }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { dragOffset = $0.translation }
            .onEnded { value in
                let location = CGPoint(
                    x: center.x + value.translation.width,
                    y: center.y + value.translation.height
                )
                onMove(normalizedPoint(for: location))
                dragOffset = .zero
                onTransformEnd()
            }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { liveScale = $0 }
            .onEnded { scale in
                onScale(max(0.4, min(item.scale * scale, 3)))
                liveScale = 1
                onTransformEnd()
            }
    }

    private var rotateGesture: some Gesture {
        RotationGesture()
            .onChanged { liveRotation = $0 }
            .onEnded { angle in
                onRotate(item.rotation + angle)
                liveRotation = .zero
                onTransformEnd()
            }
    }

    private func normalizedPoint(for location: CGPoint) -> CGPoint {
        guard displayFrame.width > 0, displayFrame.height > 0 else { return item.normalizedPosition }
        return CGPoint(
            x: min(max((location.x - displayFrame.minX) / displayFrame.width, 0), 1),
            y: min(max((location.y - displayFrame.minY) / displayFrame.height, 0), 1)
        )
    }
}
