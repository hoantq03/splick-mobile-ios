import SwiftUI

struct PhotoEditorStickerLayer: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    let displayMetrics: ImageDisplayMetrics
    let isEditing: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(viewModel.stickerItems) { item in
                StickerOverlayItemView(
                    item: item,
                    center: viewModel.overlayDisplayPoint(item.normalizedPosition, metrics: displayMetrics),
                    isSelected: viewModel.selectedStickerID == item.id,
                    isInteractive: isEditing,
                    displayFrame: displayMetrics.displayFrame,
                    gifData: viewModel.gifData(for: item.kind),
                    baseSize: EditorStickerRenderer.baseSize(for: item.kind, gifData: viewModel.gifData(for: item.kind)),
                    onSelect: { viewModel.selectedStickerID = item.id },
                    onDelete: { viewModel.deleteSelectedSticker() },
                    onMove: { viewModel.updateStickerPosition(id: item.id, normalizedPosition: $0) },
                    onScale: { viewModel.updateStickerScale(id: item.id, scale: $0) },
                    onRotate: { viewModel.updateStickerRotation(id: item.id, rotation: $0) },
                    onTransformEnd: { viewModel.commitStickerTransform() }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .coordinateSpace(name: Self.canvasSpace)
        .allowsHitTesting(isEditing)
    }

    static let canvasSpace = "editorStickerCanvas"
}

private struct StickerOverlayItemView: View {
    let item: EditorStickerItem
    let center: CGPoint
    let isSelected: Bool
    let isInteractive: Bool
    let displayFrame: CGRect
    let gifData: Data?
    let baseSize: CGSize
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onMove: (CGPoint) -> Void
    let onScale: (CGFloat) -> Void
    let onRotate: (Angle) -> Void
    let onTransformEnd: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var liveScale: CGFloat = 1
    @State private var liveRotation: Angle = .zero

    var body: some View {
        visual
            .frame(width: baseSize.width, height: baseSize.height)
            .contentShape(Rectangle())
            .highPriorityGesture(
                dragGesture,
                including: isInteractive && isSelected ? .all : .none
            )
            .simultaneousGesture(
                magnifyGesture,
                including: isInteractive && isSelected ? .all : .none
            )
            .simultaneousGesture(
                rotateGesture,
                including: isInteractive && isSelected ? .all : .none
            )
            .onTapGesture {
                guard isInteractive else { return }
                onSelect()
            }
            .allowsHitTesting(isInteractive)
            .offset(
                x: center.x + dragOffset.width - baseSize.width / 2,
                y: center.y + dragOffset.height - baseSize.height / 2
            )
            .transaction { $0.animation = nil }
    }

    private var visual: some View {
        EditorStickerContentView(kind: item.kind, gifData: gifData)
            .scaleEffect(item.scale * liveScale)
            .rotationEffect(item.rotation + liveRotation)
            .overlay {
                if isSelected, isInteractive {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                        .padding(-6)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isSelected, isInteractive {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .background(Circle().fill(Color.black.opacity(0.55)))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 8, y: -8)
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(PhotoEditorStickerLayer.canvasSpace))
            .onChanged { value in
                dragOffset = value.translation
            }
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
                onScale(max(0.25, min(item.scale * scale, 8)))
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
