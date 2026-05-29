import Observation
import PencilKit
import SwiftUI
import UIKit

enum EditorTool: String, CaseIterable, Identifiable {
    case crop
    case draw
    case text

    var id: String { rawValue }

    var label: String {
        switch self {
        case .crop: return "Crop"
        case .draw: return "Draw"
        case .text: return "Text"
        }
    }

    var icon: String {
        switch self {
        case .crop: return "crop"
        case .draw: return "pencil.tip"
        case .text: return "textformat"
        }
    }
}

struct EditorTextItem: Identifiable, Equatable {
    let id: UUID
    var text: String
    /// Normalized position within the image (0...1).
    var normalizedPosition: CGPoint
    var scale: CGFloat
    var rotation: Angle
    var color: UIColor

    init(
        id: UUID = UUID(),
        text: String = "Text",
        normalizedPosition: CGPoint = CGPoint(x: 0.5, y: 0.5),
        scale: CGFloat = 1,
        rotation: Angle = .zero,
        color: UIColor = .white
    ) {
        self.id = id
        self.text = text
        self.normalizedPosition = normalizedPosition
        self.scale = scale
        self.rotation = rotation
        self.color = color
    }
}

struct EditorState {
    var baseImage: UIImage
    var drawing: PKDrawing
    var textItems: [EditorTextItem]
    var normalizedCropRect: CGRect

    func isEquivalent(to other: EditorState) -> Bool {
        baseImage.pngData() == other.baseImage.pngData()
            && drawing.dataRepresentation() == other.drawing.dataRepresentation()
            && textItems == other.textItems
            && normalizedCropRect == other.normalizedCropRect
    }
}

@Observable
@MainActor
final class PhotoEditorViewModel {
    private(set) var baseImage: UIImage
    var activeTool: EditorTool = .draw
    var drawing = PKDrawing()
    var textItems: [EditorTextItem] = []
    var normalizedCropRect: CGRect = CGRect(x: 0.05, y: 0.05, width: 0.9, height: 0.9)
    var selectedTextID: UUID?
    var inkColor: UIColor = .white
    var inkWidth: CGFloat = 4

    private var undoStack: [EditorState] = []

    init(sourceImage: UIImage) {
        baseImage = sourceImage
        pushUndoSnapshot()
    }

    var canUndo: Bool {
        undoStack.count > 1
    }

    func setActiveTool(_ tool: EditorTool) {
        if activeTool == .crop, tool != .crop {
            applyCropIfNeeded()
        }
        activeTool = tool
    }

    func undo() {
        guard undoStack.count > 1 else { return }
        undoStack.removeLast()
        guard let snapshot = undoStack.last else { return }
        restore(snapshot)
    }

    func addText(at normalizedPosition: CGPoint) {
        let item = EditorTextItem(
            text: "Text",
            normalizedPosition: normalizedPosition,
            scale: 1,
            rotation: .zero,
            color: inkColor
        )
        textItems.append(item)
        selectedTextID = item.id
        pushUndoSnapshot()
    }

    func updateText(_ id: UUID, text: String) {
        guard let index = textItems.firstIndex(where: { $0.id == id }) else { return }
        textItems[index].text = text
    }

    func commitTextEdit() {
        pushUndoSnapshot()
    }

    func drawingDidChange() {
        pushUndoSnapshot()
    }

    func applyCropIfNeeded() {
        let cropNormalized = normalizedCropRect
        let imageSizeBefore = baseImage.size
        let rect = pixelCropRect(for: imageSizeBefore)
        guard rect.width > 1, rect.height > 1,
              rect.width < imageSizeBefore.width - 1 || rect.height < imageSizeBefore.height - 1,
              let cgImage = baseImage.cgImage?.cropping(to: rect.integral) else {
            return
        }

        let cropped = UIImage(
            cgImage: cgImage,
            scale: baseImage.scale,
            orientation: baseImage.imageOrientation
        )
        baseImage = cropped
        normalizedCropRect = CGRect(x: 0.05, y: 0.05, width: 0.9, height: 0.9)
        drawing = PKDrawing()
        remapTextItemsAfterCrop(cropNormalized: cropNormalized)
        pushUndoSnapshot()
    }

    func pixelCropRect(for imageSize: CGSize) -> CGRect {
        CGRect(
            x: normalizedCropRect.minX * imageSize.width,
            y: normalizedCropRect.minY * imageSize.height,
            width: normalizedCropRect.width * imageSize.width,
            height: normalizedCropRect.height * imageSize.height
        )
    }

    func finalize(displayMetrics: ImageDisplayMetrics) -> UIImage {
        applyCropIfNeeded()

        let imageSize = baseImage.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = baseImage.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)
        return renderer.image { _ in
            baseImage.draw(in: CGRect(origin: .zero, size: imageSize))

            if !drawing.bounds.isEmpty {
                let drawingImage = drawing.image(from: drawing.bounds, scale: baseImage.scale)
                let scaleX = imageSize.width / displayMetrics.displayFrame.width
                let scaleY = imageSize.height / displayMetrics.displayFrame.height
                let drawRect = CGRect(
                    x: (drawing.bounds.origin.x - displayMetrics.displayFrame.minX) * scaleX,
                    y: (drawing.bounds.origin.y - displayMetrics.displayFrame.minY) * scaleY,
                    width: drawing.bounds.width * scaleX,
                    height: drawing.bounds.height * scaleY
                )
                drawingImage.draw(in: drawRect)
            }

            for item in textItems {
                drawTextItem(item, imageSize: imageSize, displayFrame: displayMetrics.displayFrame)
            }
        }
    }

    private func drawTextItem(_ item: EditorTextItem, imageSize: CGSize, displayFrame: CGRect) {
        let imagePoint = CGPoint(
            x: item.normalizedPosition.x * imageSize.width,
            y: item.normalizedPosition.y * imageSize.height
        )
        let fontSize = 28 * item.scale * (imageSize.width / max(displayFrame.width, 1))

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: item.color,
        ]
        let attributed = NSAttributedString(string: item.text, attributes: attributes)
        let textSize = attributed.size()

        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        context?.translateBy(x: imagePoint.x, y: imagePoint.y)
        context?.rotate(by: CGFloat(item.rotation.radians))
        attributed.draw(
            at: CGPoint(x: -textSize.width / 2, y: -textSize.height / 2)
        )
        context?.restoreGState()
    }

    private func remapTextItemsAfterCrop(cropNormalized: CGRect) {
        guard cropNormalized.width > 0, cropNormalized.height > 0 else { return }
        textItems = textItems.map { item in
            var copy = item
            copy.normalizedPosition = CGPoint(
                x: (item.normalizedPosition.x - cropNormalized.minX) / cropNormalized.width,
                y: (item.normalizedPosition.y - cropNormalized.minY) / cropNormalized.height
            )
            return copy
        }
    }

    private func pushUndoSnapshot() {
        let snapshot = EditorState(
            baseImage: baseImage,
            drawing: drawing,
            textItems: textItems,
            normalizedCropRect: normalizedCropRect
        )
        if let last = undoStack.last, last.isEquivalent(to: snapshot) {
            return
        }
        undoStack.append(snapshot)
        if undoStack.count > 20 {
            undoStack.removeFirst()
        }
    }

    private func restore(_ snapshot: EditorState) {
        baseImage = snapshot.baseImage
        drawing = snapshot.drawing
        textItems = snapshot.textItems
        normalizedCropRect = snapshot.normalizedCropRect
        selectedTextID = nil
    }
}

struct ImageDisplayMetrics: Equatable {
    let imageSize: CGSize
    let displayFrame: CGRect

    static func aspectFit(imageSize: CGSize, in containerSize: CGSize) -> ImageDisplayMetrics {
        guard imageSize.width > 0, imageSize.height > 0,
              containerSize.width > 0, containerSize.height > 0 else {
            return ImageDisplayMetrics(imageSize: imageSize, displayFrame: .zero)
        }

        let scale = min(
            containerSize.width / imageSize.width,
            containerSize.height / imageSize.height
        )
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        let origin = CGPoint(
            x: (containerSize.width - width) / 2,
            y: (containerSize.height - height) / 2
        )
        return ImageDisplayMetrics(
            imageSize: imageSize,
            displayFrame: CGRect(origin: origin, size: CGSize(width: width, height: height))
        )
    }

    func viewToImage(_ point: CGPoint) -> CGPoint {
        guard displayFrame.width > 0, displayFrame.height > 0 else { return .zero }
        let normalizedX = (point.x - displayFrame.minX) / displayFrame.width
        let normalizedY = (point.y - displayFrame.minY) / displayFrame.height
        return CGPoint(
            x: normalizedX * imageSize.width,
            y: normalizedY * imageSize.height
        )
    }

    func imageNormalizedToView(_ normalized: CGPoint) -> CGPoint {
        CGPoint(
            x: displayFrame.minX + normalized.x * displayFrame.width,
            y: displayFrame.minY + normalized.y * displayFrame.height
        )
    }
}
