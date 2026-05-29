import SwiftUI

struct PhotoEditorCropView: View {
    @Bindable var viewModel: PhotoEditorViewModel
    let displayMetrics: ImageDisplayMetrics

    @State private var cropDragStart: CGRect?

    private enum CropHandle: Hashable, CaseIterable {
        case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
    }

    var body: some View {
        let cropFrame = cropFrameInView

        ZStack {
            Color.black.opacity(0.45)
                .mask {
                    Rectangle()
                        .overlay {
                            Rectangle()
                                .frame(width: cropFrame.width, height: cropFrame.height)
                                .position(x: cropFrame.midX, y: cropFrame.midY)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }
                .allowsHitTesting(false)

            Rectangle()
                .strokeBorder(Color.white, lineWidth: 2)
                .frame(width: cropFrame.width, height: cropFrame.height)
                .position(x: cropFrame.midX, y: cropFrame.midY)

            ForEach(CropHandle.allCases, id: \.self) { handle in
                handleView(handle, cropFrame: cropFrame)
            }
        }
    }

    private var cropFrameInView: CGRect {
        let normalized = viewModel.normalizedCropRect
        let frame = displayMetrics.displayFrame
        return CGRect(
            x: frame.minX + normalized.minX * frame.width,
            y: frame.minY + normalized.minY * frame.height,
            width: normalized.width * frame.width,
            height: normalized.height * frame.height
        )
    }

    @ViewBuilder
    private func handleView(_ handle: CropHandle, cropFrame: CGRect) -> some View {
        let point = handlePoint(handle, in: cropFrame)
        Circle()
            .fill(Color.white)
            .frame(width: 22, height: 22)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .position(point)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if cropDragStart == nil {
                            cropDragStart = viewModel.normalizedCropRect
                        }
                        guard let start = cropDragStart else { return }
                        updateCrop(handle: handle, translation: value.translation, startRect: start)
                    }
                    .onEnded { _ in
                        cropDragStart = nil
                    }
            )
    }

    private func handlePoint(_ handle: CropHandle, in rect: CGRect) -> CGPoint {
        switch handle {
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

    private func updateCrop(handle: CropHandle, translation: CGSize, startRect: CGRect) {
        let frame = displayMetrics.displayFrame
        guard frame.width > 0, frame.height > 0 else { return }

        var rect = startRect
        let dx = translation.width / frame.width
        let dy = translation.height / frame.height
        let minSize: CGFloat = 0.12

        switch handle {
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

        rect.size.width = max(rect.size.width, minSize)
        rect.size.height = max(rect.size.height, minSize)
        rect.origin.x = min(max(rect.origin.x, 0), 1 - rect.size.width)
        rect.origin.y = min(max(rect.origin.y, 0), 1 - rect.size.height)
        viewModel.normalizedCropRect = rect
    }
}
