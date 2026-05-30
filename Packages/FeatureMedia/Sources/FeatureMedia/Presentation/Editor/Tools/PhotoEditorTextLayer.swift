import DesignSystem
import SwiftUI

struct PhotoEditorTextLayer: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    let displayMetrics: ImageDisplayMetrics

    var body: some View {
        ZStack {
            ForEach(viewModel.textItems) { item in
                TextOverlayItemView(
                    item: item,
                    center: displayMetrics.imageNormalizedToView(item.normalizedPosition),
                    isSelected: viewModel.selectedTextID == item.id,
                    isInteractive: viewModel.activeTool == .text,
                    displayFrame: displayMetrics.displayFrame,
                    onSelect: { viewModel.selectedTextID = item.id },
                    onMove: { viewModel.updateTextItemPosition(id: item.id, normalizedPosition: $0) },
                    onScale: { viewModel.updateTextItemScale(id: item.id, scale: $0) },
                    onRotate: { viewModel.updateTextItemRotation(id: item.id, rotation: $0) },
                    onTransformEnd: { viewModel.commitTextTransform() }
                )
            }
        }
    }
}

private struct TextOverlayItemView: View {
    let item: EditorTextItem
    let center: CGPoint
    let isSelected: Bool
    let isInteractive: Bool
    let displayFrame: CGRect
    let onSelect: () -> Void
    let onMove: (CGPoint) -> Void
    let onScale: (CGFloat) -> Void
    let onRotate: (Angle) -> Void
    let onTransformEnd: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var liveScale: CGFloat = 1
    @State private var liveRotation: Angle = .zero

    private var displayText: String {
        let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty, isSelected {
            return "Nhập chữ"
        }
        return item.text
    }

    var body: some View {
        Text(displayText)
            .font(.system(size: 32 * item.scale * liveScale, weight: .bold, design: .rounded))
            .foregroundStyle(Color(item.color))
            .opacity(displayText == "Nhập chữ" && isSelected ? 0.55 : 1)
            .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                }
            }
            .rotationEffect(item.rotation + liveRotation)
            .position(x: center.x + dragOffset.width, y: center.y + dragOffset.height)
            .allowsHitTesting(isInteractive && !isSelected)
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
                onScale(max(0.5, min(item.scale * scale, 3.5)))
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
