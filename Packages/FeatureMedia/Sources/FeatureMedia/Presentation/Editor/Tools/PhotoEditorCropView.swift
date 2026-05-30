import SwiftUI

struct PhotoEditorCropView: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    let displayMetrics: ImageDisplayMetrics

    @State private var liveCropRect: CGRect?
    @State private var dragStartRect: CGRect?

    private enum CropHandle: Hashable, CaseIterable {
        case move
        case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
    }

    private let minNormalizedSize: CGFloat = 0.15
    private let handleHitSize: CGFloat = 44

    var body: some View {
        let cropFrame = cropFrameInView

        ZStack {
            dimmedOverlay(cropFrame: cropFrame)
            cropGrid(cropFrame: cropFrame)
            cropBorder(cropFrame: cropFrame)
            cropMoveArea(cropFrame: cropFrame)

            ForEach(CropHandle.allCases.filter { $0 != .move }, id: \.self) { handle in
                handleView(handle, cropFrame: cropFrame)
            }
        }
        .onDisappear {
            if let liveCropRect {
                viewModel.commitCropRect(liveCropRect)
            }
        }
    }

    private var activeNormalizedRect: CGRect {
        liveCropRect ?? viewModel.normalizedCropRect
    }

    private var cropFrameInView: CGRect {
        let normalized = activeNormalizedRect
        let frame = displayMetrics.displayFrame
        return CGRect(
            x: frame.minX + normalized.minX * frame.width,
            y: frame.minY + normalized.minY * frame.height,
            width: normalized.width * frame.width,
            height: normalized.height * frame.height
        )
    }

    @ViewBuilder
    private func dimmedOverlay(cropFrame: CGRect) -> some View {
        Color.black.opacity(0.55)
            .mask {
                Rectangle()
                    .overlay {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .frame(width: cropFrame.width, height: cropFrame.height)
                            .position(x: cropFrame.midX, y: cropFrame.midY)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
            }
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func cropGrid(cropFrame: CGRect) -> some View {
        let w = cropFrame.width / 3
        let h = cropFrame.height / 3
        ZStack {
            ForEach(1..<3, id: \.self) { index in
                Rectangle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 0.5, height: cropFrame.height)
                    .position(x: cropFrame.minX + w * CGFloat(index), y: cropFrame.midY)
                Rectangle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: cropFrame.width, height: 0.5)
                    .position(x: cropFrame.midX, y: cropFrame.minY + h * CGFloat(index))
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func cropBorder(cropFrame: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .strokeBorder(Color.white, lineWidth: 1.5)
            .frame(width: cropFrame.width, height: cropFrame.height)
            .position(x: cropFrame.midX, y: cropFrame.midY)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func cropMoveArea(cropFrame: CGRect) -> some View {
        let inset = handleHitSize * 0.55
        let moveWidth = max(cropFrame.width - inset * 2, 24)
        let moveHeight = max(cropFrame.height - inset * 2, 24)

        Color.clear
            .frame(width: moveWidth, height: moveHeight)
            .contentShape(Rectangle())
            .position(x: cropFrame.midX, y: cropFrame.midY)
            .highPriorityGesture(cropDragGesture(for: .move))
    }

    @ViewBuilder
    private func handleView(_ handle: CropHandle, cropFrame: CGRect) -> some View {
        let point = handlePoint(handle, in: cropFrame)
        let visual = handleSize(handle)

        Color.clear
            .frame(width: handleHitSize, height: handleHitSize)
            .contentShape(Rectangle())
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.white)
                    .frame(width: visual.width, height: visual.height)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            }
            .position(point)
            .highPriorityGesture(cropDragGesture(for: handle))
    }

    private func cropDragGesture(for handle: CropHandle) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStartRect == nil {
                    dragStartRect = activeNormalizedRect
                }
                guard let start = dragStartRect else { return }
                liveCropRect = computeCrop(
                    handle: handle,
                    translation: value.translation,
                    startRect: start
                )
            }
            .onEnded { _ in
                if let liveCropRect {
                    viewModel.commitCropRect(liveCropRect)
                }
                liveCropRect = nil
                dragStartRect = nil
            }
    }

    private func handleSize(_ handle: CropHandle) -> CGSize {
        switch handle {
        case .top, .bottom: return CGSize(width: 28, height: 4)
        case .left, .right: return CGSize(width: 4, height: 28)
        case .move: return .zero
        default: return CGSize(width: 22, height: 22)
        }
    }

    private func handlePoint(_ handle: CropHandle, in rect: CGRect) -> CGPoint {
        switch handle {
        case .move: return CGPoint(x: rect.midX, y: rect.midY)
        case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .top: return CGPoint(x: rect.midX, y: rect.minY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .right: return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom: return CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .left: return CGPoint(x: rect.minX, y: rect.midY)
        }
    }

    private func computeCrop(handle: CropHandle, translation: CGSize, startRect: CGRect) -> CGRect {
        let frame = displayMetrics.displayFrame
        guard frame.width > 0, frame.height > 0 else { return startRect }

        var rect = startRect
        let dx = translation.width / frame.width
        let dy = translation.height / frame.height

        switch handle {
        case .move:
            rect.origin.x += dx
            rect.origin.y += dy
        case .topLeft:
            rect.origin.x += dx
            rect.origin.y += dy
            rect.size.width -= dx
            rect.size.height -= dy
        case .top:
            rect.origin.y += dy
            rect.size.height -= dy
        case .topRight:
            rect.size.width += dx
            rect.origin.y += dy
            rect.size.height -= dy
        case .right:
            rect.size.width += dx
        case .bottomRight:
            rect.size.width += dx
            rect.size.height += dy
        case .bottom:
            rect.size.height += dy
        case .bottomLeft:
            rect.origin.x += dx
            rect.size.width -= dx
            rect.size.height += dy
        case .left:
            rect.origin.x += dx
            rect.size.width -= dx
        }

        if handle != .move {
            if rect.size.width < minNormalizedSize {
                if handle == .left || handle == .topLeft || handle == .bottomLeft {
                    rect.origin.x = startRect.maxX - minNormalizedSize
                }
                rect.size.width = minNormalizedSize
            }
            if rect.size.height < minNormalizedSize {
                if handle == .top || handle == .topLeft || handle == .topRight {
                    rect.origin.y = startRect.maxY - minNormalizedSize
                }
                rect.size.height = minNormalizedSize
            }
        }

        rect.origin.x = min(max(rect.origin.x, 0), 1 - rect.size.width)
        rect.origin.y = min(max(rect.origin.y, 0), 1 - rect.size.height)
        return rect
    }
}
