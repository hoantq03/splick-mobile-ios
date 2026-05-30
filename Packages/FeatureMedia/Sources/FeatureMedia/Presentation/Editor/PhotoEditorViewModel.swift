import Combine
import PencilKit
import SwiftUI
import UIKit

enum EditorTool: String, CaseIterable, Identifiable {
    case crop
    case draw
    case text
    case sticker

    var id: String { rawValue }

    var label: String {
        switch self {
        case .crop: return "Cắt"
        case .draw: return "Vẽ"
        case .text: return "Chữ"
        case .sticker: return "Sticker"
        }
    }

    var icon: String {
        switch self {
        case .crop: return "crop.rotate"
        case .draw: return "scribble.variable"
        case .text: return "character.textbox"
        case .sticker: return "face.smiling"
        }
    }
}

struct EditorTextItem: Identifiable, Equatable {
    let id: UUID
    var text: String
    var normalizedPosition: CGPoint
    var scale: CGFloat
    var rotation: Angle
    var color: UIColor

    init(
        id: UUID = UUID(),
        text: String = "Nhập chữ",
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

private struct EditorSnapshot {
    var baseImage: UIImage
    var drawing: PKDrawing
    var textItems: [EditorTextItem]
    var stickerItems: [EditorStickerItem]
    var gifStickerData: [UUID: Data]
    var normalizedCropRect: CGRect

    var fingerprint: Data {
        var data = drawing.dataRepresentation()
        data.append(contentsOf: withUnsafeBytes(of: normalizedCropRect.origin.x) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: normalizedCropRect.origin.y) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: normalizedCropRect.size.width) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: normalizedCropRect.size.height) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: baseImage.size.width) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: baseImage.size.height) { Array($0) })

        for item in textItems {
            data.append(item.id.uuidString.data(using: .utf8) ?? Data())
            data.append(item.text.data(using: .utf8) ?? Data())
            data.append(contentsOf: withUnsafeBytes(of: item.normalizedPosition.x) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: item.normalizedPosition.y) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: item.scale) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: item.rotation.radians) { Array($0) })
        }
        for item in stickerItems {
            data.append(item.id.uuidString.data(using: .utf8) ?? Data())
            data.append(String(describing: item.kind).data(using: .utf8) ?? Data())
            data.append(contentsOf: withUnsafeBytes(of: item.normalizedPosition.x) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: item.normalizedPosition.y) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: item.scale) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: item.rotation.radians) { Array($0) })
        }
        for id in gifStickerData.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
            data.append(id.uuidString.data(using: .utf8) ?? Data())
            data.append(String(gifStickerData[id]?.count ?? 0).data(using: .utf8) ?? Data())
        }
        return data
    }
}

private let fullImageCropRect = CGRect(x: 0, y: 0, width: 1, height: 1)

@MainActor
final class PhotoEditorViewModel: ObservableObject {
    @Published private(set) var baseImage: UIImage
    @Published var activeTool: EditorTool?
    @Published var isChromeVisible = true
    @Published var drawing = PKDrawing()
    @Published var textItems: [EditorTextItem] = []
    @Published var stickerItems: [EditorStickerItem] = []
    @Published var normalizedCropRect: CGRect = fullImageCropRect
    @Published var selectedTextID: UUID?
    @Published var selectedStickerID: UUID?
    @Published var inkColor: UIColor = .white
    @Published var inkWidth: CGFloat = 5
    @Published private(set) var gifStickerData: [UUID: Data] = [:]
    @Published private(set) var gifGallery: [EditorGifSample] = []
    @Published private(set) var recentEmojis: [String] = []

    let preparedImage: PhotoEditorImageProcessor.PreparedImage

    private var undoStack: [EditorSnapshot] = []
    private var redoStack: [EditorSnapshot] = []
    private(set) var lastDisplayMetrics: ImageDisplayMetrics?
    private(set) var drawingCanvasSize: CGSize = .zero
    private(set) var finalizeFlushToken = 0
    private(set) var drawingSyncRevision = 0

    static let inkPalette: [UIColor] = [
        .white, .black,
        UIColor(red: 1, green: 0.3, blue: 0.35, alpha: 1),
        UIColor(red: 1, green: 0.82, blue: 0.2, alpha: 1),
        UIColor(red: 0.35, green: 0.78, blue: 0.98, alpha: 1),
        UIColor(red: 0.42, green: 0.85, blue: 0.55, alpha: 1),
    ]

    init(sourceImage: UIImage) {
        let prepared = PhotoEditorImageProcessor.prepareForEditing(sourceImage)
        preparedImage = prepared
        baseImage = prepared.editingImage
        activeTool = .draw
        pushSnapshotIfNeeded()
    }

    var canUndo: Bool {
        undoStack.count > 1
    }

    var canRedo: Bool {
        !redoStack.isEmpty
    }

    func selectTool(_ tool: EditorTool) {
        if !isChromeVisible {
            isChromeVisible = true
        }

        if activeTool == tool {
            enterViewMode()
            return
        }

        commitLeavingToolIfNeeded()
        finalizeFlushToken += 1
        activeTool = tool
        if tool != .text {
            selectedTextID = nil
        }
        if tool != .sticker {
            selectedStickerID = nil
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        DispatchQueue.main.async { [weak self] in
            self?.bakeAllOverlaysIntoBaseImage()
        }
    }

    func toggleChromeFromImageTap() {
        guard shouldToggleChromeOnImageTap else { return }
        if isChromeVisible {
            enterViewMode()
        } else {
            showChrome()
        }
    }

    /// Image tap hides chrome only in neutral/view mode — not while a tool needs canvas interaction.
    var shouldToggleChromeOnImageTap: Bool {
        if !isChromeVisible { return true }
        switch activeTool {
        case .none:
            return true
        case .text, .draw, .crop, .sticker:
            return false
        }
    }

    func enterViewMode() {
        commitLeavingToolIfNeeded()
        finalizeFlushToken += 1
        activeTool = nil
        selectedTextID = nil
        selectedStickerID = nil
        isChromeVisible = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        DispatchQueue.main.async { [weak self] in
            self?.bakeAllOverlaysIntoBaseImage()
        }
    }

    func showChrome() {
        guard !isChromeVisible else { return }
        isChromeVisible = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func updateDisplayMetrics(_ metrics: ImageDisplayMetrics) {
        guard metrics.displayFrame.width > 0, metrics.displayFrame.height > 0 else { return }
        lastDisplayMetrics = metrics
    }

    func prepareForFinalize() {
        finalizeFlushToken += 1
        commitLeavingToolIfNeeded()
        bakeAllOverlaysIntoBaseImage()
    }

    private func commitLeavingToolIfNeeded() {
        if activeTool == .crop {
            applyCropIfNeeded()
        }
    }

    func undo() {
        guard undoStack.count > 1 else { return }
        redoStack.append(copySnapshot(undoStack.removeLast()))
        guard let snapshot = undoStack.last else { return }
        restore(snapshot)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func redo() {
        guard let snapshot = redoStack.popLast() else { return }
        undoStack.append(copySnapshot(snapshot))
        restore(snapshot)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func addText(at normalizedPosition: CGPoint) {
        let item = EditorTextItem(
            normalizedPosition: normalizedPosition,
            color: inkColor
        )
        textItems.append(item)
        selectedTextID = item.id
        pushSnapshotIfNeeded()
    }

    func updateTextItemPosition(id: UUID, normalizedPosition: CGPoint) {
        guard let index = textItems.firstIndex(where: { $0.id == id }) else { return }
        textItems[index].normalizedPosition = normalizedPosition
    }

    func updateTextItemScale(id: UUID, scale: CGFloat) {
        guard let index = textItems.firstIndex(where: { $0.id == id }) else { return }
        textItems[index].scale = scale
    }

    func updateTextItemRotation(id: UUID, rotation: Angle) {
        guard let index = textItems.firstIndex(where: { $0.id == id }) else { return }
        textItems[index].rotation = rotation
    }

    func updateText(_ id: UUID, text: String) {
        guard let index = textItems.firstIndex(where: { $0.id == id }) else { return }
        var items = textItems
        items[index].text = text
        textItems = items
    }

    func commitTextEdit() {
        bakeAllOverlaysIntoBaseImage()
        pushSnapshotIfNeeded()
    }

    func commitTextTransform() {
        pushSnapshotIfNeeded()
    }

    func addSticker(_ kind: EditorStickerKind) {
        let offset = CGFloat(stickerItems.count % 5) * 0.04
        let item = EditorStickerItem(
            kind: kind,
            normalizedPosition: CGPoint(x: 0.5 + offset, y: 0.45 + offset)
        )
        stickerItems.append(item)
        selectedStickerID = item.id
        if case .emoji(let value) = kind {
            recordEmojiUsage(value)
        }
        pushSnapshotIfNeeded()
    }

    func addGifSticker(data: Data) {
        guard EditorGifDecoder.isGif(data) else { return }
        let stickerID = UUID()
        gifStickerData[stickerID] = data
        if !gifGallery.contains(where: { $0.data == data }) {
            gifGallery.insert(EditorGifSample(data: data), at: 0)
        }
        let offset = CGFloat(stickerItems.count % 5) * 0.04
        let item = EditorStickerItem(
            kind: .gif(stickerID),
            normalizedPosition: CGPoint(x: 0.5 + offset, y: 0.45 + offset)
        )
        stickerItems.append(item)
        selectedStickerID = item.id
        pushSnapshotIfNeeded()
    }

    func addGifStickerFromGallery(_ sample: EditorGifSample) {
        let stickerID = UUID()
        gifStickerData[stickerID] = sample.data
        let offset = CGFloat(stickerItems.count % 5) * 0.04
        let item = EditorStickerItem(
            kind: .gif(stickerID),
            normalizedPosition: CGPoint(x: 0.5 + offset, y: 0.45 + offset)
        )
        stickerItems.append(item)
        selectedStickerID = item.id
        pushSnapshotIfNeeded()
    }

    func recordEmojiUsage(_ emoji: String) {
        recentEmojis.removeAll { $0 == emoji }
        recentEmojis.insert(emoji, at: 0)
        if recentEmojis.count > 24 {
            recentEmojis = Array(recentEmojis.prefix(24))
        }
    }

    func gifData(for kind: EditorStickerKind) -> Data? {
        guard case .gif(let id) = kind else { return nil }
        return gifStickerData[id]
    }

    func updateStickerPosition(id: UUID, normalizedPosition: CGPoint) {
        guard let index = stickerItems.firstIndex(where: { $0.id == id }) else { return }
        var items = stickerItems
        items[index].normalizedPosition = normalizedPosition
        stickerItems = items
    }

    func updateStickerScale(id: UUID, scale: CGFloat) {
        guard let index = stickerItems.firstIndex(where: { $0.id == id }) else { return }
        var items = stickerItems
        items[index].scale = scale
        stickerItems = items
    }

    func updateStickerRotation(id: UUID, rotation: Angle) {
        guard let index = stickerItems.firstIndex(where: { $0.id == id }) else { return }
        var items = stickerItems
        items[index].rotation = rotation
        stickerItems = items
    }

    func commitStickerTransform() {
        pushSnapshotIfNeeded()
    }

    func deleteSelectedSticker() {
        guard let id = selectedStickerID else { return }
        if let item = stickerItems.first(where: { $0.id == id }),
           case .gif(let gifID) = item.kind {
            gifStickerData.removeValue(forKey: gifID)
        }
        stickerItems.removeAll { $0.id == id }
        selectedStickerID = nil
        pushSnapshotIfNeeded()
    }

    func commitDrawing(_ newDrawing: PKDrawing) {
        guard drawing != newDrawing else { return }
        drawing = newDrawing
        if let canvasSize = lastDisplayMetrics?.displayFrame.size, canvasSize.width > 0 {
            drawingCanvasSize = canvasSize
        }
        pushSnapshotIfNeeded()
    }

    func commitCropRect(_ rect: CGRect) {
        normalizedCropRect = rect
    }

    func applyCropIfNeeded() {
        guard isEffectiveCrop(normalizedCropRect) else { return }

        bakeDrawingIntoBaseImageIfNeeded()

        let cropNormalized = normalizedCropRect
        let imageSizeBefore = baseImage.size
        let rect = pixelCropRect(for: imageSizeBefore)
        guard rect.width > 1, rect.height > 1,
              let cgImage = baseImage.cgImage?.cropping(to: rect.integral) else {
            return
        }

        baseImage = UIImage(cgImage: cgImage, scale: baseImage.scale, orientation: baseImage.imageOrientation)
        normalizedCropRect = fullImageCropRect
        remapTextItemsAfterCrop(cropNormalized: cropNormalized)
        remapStickerItemsAfterCrop(cropNormalized: cropNormalized)
        pushSnapshotIfNeeded()
    }

    func pixelCropRect(for imageSize: CGSize) -> CGRect {
        CGRect(
            x: normalizedCropRect.minX * imageSize.width,
            y: normalizedCropRect.minY * imageSize.height,
            width: normalizedCropRect.width * imageSize.width,
            height: normalizedCropRect.height * imageSize.height
        )
    }

    func finalize(displayMetrics: ImageDisplayMetrics? = nil) -> UIImage {
        let metrics = resolvedDisplayMetrics(displayMetrics)
        bakeAllOverlaysIntoBaseImage(using: metrics)
        applyCropIfNeeded()

        let imageSize = baseImage.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = baseImage.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)
        let edited = renderer.image { _ in
            baseImage.draw(in: CGRect(origin: .zero, size: imageSize))
        }

        return PhotoEditorImageProcessor.upscaleForExport(edited, prepared: preparedImage)
    }

    func bakeAllOverlaysIntoBaseImage(using metrics: ImageDisplayMetrics? = nil) {
        let resolvedMetrics = metrics ?? resolvedDisplayMetrics(nil)
        guard resolvedMetrics.displayFrame.width > 0 else { return }
        bakeDrawingIntoBaseImageIfNeeded(using: resolvedMetrics)
        bakeTextItemsIntoBaseImageIfNeeded(using: resolvedMetrics)
        bakeStickerItemsIntoBaseImageIfNeeded(using: resolvedMetrics)
    }

    private func resolvedDisplayMetrics(_ override: ImageDisplayMetrics?) -> ImageDisplayMetrics {
        if let override, override.displayFrame.width > 0 {
            return override
        }
        if let lastDisplayMetrics, lastDisplayMetrics.displayFrame.width > 0 {
            return lastDisplayMetrics
        }

        let screen = UIScreen.main.bounds.size
        let canvasSize = CGSize(
            width: screen.width,
            height: max(screen.height - EditorLayout.topBarHeight - EditorLayout.bottomBarHeight, 1)
        )
        return ImageDisplayMetrics.aspectFit(imageSize: baseImage.size, in: canvasSize)
    }

    private func isEffectiveCrop(_ rect: CGRect) -> Bool {
        rect.minX > 0.001
            || rect.minY > 0.001
            || rect.width < 0.999
            || rect.height < 0.999
    }

    private func bakeDrawingIntoBaseImageIfNeeded(using metrics: ImageDisplayMetrics? = nil) {
        guard !drawing.bounds.isEmpty else { return }

        let resolvedMetrics = metrics ?? resolvedDisplayMetrics(nil)
        let canvasSize = drawingCanvasSize.width > 0 ? drawingCanvasSize : resolvedMetrics.displayFrame.size
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }

        let imageSize = baseImage.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = baseImage.scale
        format.opaque = false

        let canvasBounds = CGRect(origin: .zero, size: canvasSize)
        let drawingImage = drawing.image(from: canvasBounds, scale: baseImage.scale)

        baseImage = UIGraphicsImageRenderer(size: imageSize, format: format).image { _ in
            baseImage.draw(in: CGRect(origin: .zero, size: imageSize))
            drawingImage.draw(in: CGRect(origin: .zero, size: imageSize))
        }
        drawing = PKDrawing()
        drawingCanvasSize = .zero
    }

    private func bakeTextItemsIntoBaseImageIfNeeded(using metrics: ImageDisplayMetrics) {
        guard !textItems.isEmpty else { return }

        let imageSize = baseImage.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = baseImage.scale
        format.opaque = false

        baseImage = UIGraphicsImageRenderer(size: imageSize, format: format).image { _ in
            baseImage.draw(in: CGRect(origin: .zero, size: imageSize))
            for item in textItems {
                drawTextItem(item, imageSize: imageSize, displayFrame: metrics.displayFrame)
            }
        }
        textItems = []
        selectedTextID = nil
    }

    private func bakeStickerItemsIntoBaseImageIfNeeded(using metrics: ImageDisplayMetrics) {
        guard !stickerItems.isEmpty else { return }

        let imageSize = baseImage.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = baseImage.scale
        format.opaque = false

        baseImage = UIGraphicsImageRenderer(size: imageSize, format: format).image { _ in
            baseImage.draw(in: CGRect(origin: .zero, size: imageSize))
            for item in stickerItems {
                drawStickerItem(item, imageSize: imageSize, displayFrame: metrics.displayFrame)
            }
        }
        stickerItems = []
        selectedStickerID = nil
        gifStickerData = [:]
    }

    private func drawTextItem(_ item: EditorTextItem, imageSize: CGSize, displayFrame: CGRect) {
        let imagePoint = CGPoint(
            x: item.normalizedPosition.x * imageSize.width,
            y: item.normalizedPosition.y * imageSize.height
        )
        let fontSize = 32 * item.scale * (imageSize.width / max(displayFrame.width, 1))

        let shadow = NSShadow()
        shadow.shadowColor = UIColor.black.withAlphaComponent(0.45)
        shadow.shadowOffset = CGSize(width: 0, height: 1)
        shadow.shadowBlurRadius = 3

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: item.color,
            .shadow: shadow,
        ]
        let attributed = NSAttributedString(string: item.text, attributes: attributes)
        let textSize = attributed.size()

        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        context?.translateBy(x: imagePoint.x, y: imagePoint.y)
        context?.rotate(by: CGFloat(item.rotation.radians))
        attributed.draw(at: CGPoint(x: -textSize.width / 2, y: -textSize.height / 2))
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

    private func remapStickerItemsAfterCrop(cropNormalized: CGRect) {
        guard cropNormalized.width > 0, cropNormalized.height > 0 else { return }
        stickerItems = stickerItems.map { item in
            var copy = item
            copy.normalizedPosition = CGPoint(
                x: (item.normalizedPosition.x - cropNormalized.minX) / cropNormalized.width,
                y: (item.normalizedPosition.y - cropNormalized.minY) / cropNormalized.height
            )
            return copy
        }
    }

    private func drawStickerItem(_ item: EditorStickerItem, imageSize: CGSize, displayFrame: CGRect) {
        let displayScale = imageSize.width / max(displayFrame.width, 1)
        let stickerImageScale = item.scale * displayScale
        let gifData = gifData(for: item.kind)
        let layoutSize = EditorStickerRenderer.baseSize(for: item.kind, gifData: gifData)
        let targetPixelSize = CGSize(
            width: layoutSize.width * stickerImageScale,
            height: layoutSize.height * stickerImageScale
        )
        guard let stickerImage = EditorStickerRenderer.render(
            item.kind,
            targetPixelSize: targetPixelSize,
            gifData: gifData
        ), let cgImage = stickerImage.cgImage else { return }

        let imagePoint = CGPoint(
            x: item.normalizedPosition.x * imageSize.width,
            y: item.normalizedPosition.y * imageSize.height
        )
        let rect = CGRect(
            x: -targetPixelSize.width / 2,
            y: -targetPixelSize.height / 2,
            width: targetPixelSize.width,
            height: targetPixelSize.height
        )

        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        context?.translateBy(x: imagePoint.x, y: imagePoint.y)
        context?.rotate(by: CGFloat(item.rotation.radians))
        context?.interpolationQuality = .high
        context?.draw(cgImage, in: rect)
        context?.restoreGState()
    }

    private func pushSnapshotIfNeeded() {
        let snapshot = EditorSnapshot(
            baseImage: baseImage,
            drawing: drawing,
            textItems: textItems,
            stickerItems: stickerItems,
            gifStickerData: gifStickerData,
            normalizedCropRect: normalizedCropRect
        )
        if let last = undoStack.last, last.fingerprint == snapshot.fingerprint {
            return
        }
        undoStack.append(snapshot)
        redoStack.removeAll()
        if undoStack.count > 20 {
            undoStack.removeFirst()
        }
    }

    private func copySnapshot(_ snapshot: EditorSnapshot) -> EditorSnapshot {
        EditorSnapshot(
            baseImage: snapshot.baseImage,
            drawing: snapshot.drawing,
            textItems: snapshot.textItems,
            stickerItems: snapshot.stickerItems,
            gifStickerData: snapshot.gifStickerData,
            normalizedCropRect: snapshot.normalizedCropRect
        )
    }

    private func restore(_ snapshot: EditorSnapshot) {
        baseImage = snapshot.baseImage
        drawing = snapshot.drawing
        textItems = snapshot.textItems
        stickerItems = snapshot.stickerItems
        gifStickerData = snapshot.gifStickerData
        normalizedCropRect = snapshot.normalizedCropRect
        selectedTextID = nil
        selectedStickerID = nil
        drawingSyncRevision += 1
    }
}

struct ImageDisplayMetrics: Equatable {
    let imageSize: CGSize
    let displayFrame: CGRect

    /// Fits `imageSize` inside `canvasSize`, then offsets the frame within the full container.
    static func aspectFit(
        imageSize: CGSize,
        in canvasSize: CGSize,
        containerOrigin: CGPoint = .zero
    ) -> ImageDisplayMetrics {
        guard imageSize.width > 0, imageSize.height > 0,
              canvasSize.width > 0, canvasSize.height > 0 else {
            return ImageDisplayMetrics(imageSize: imageSize, displayFrame: .zero)
        }

        let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        let origin = CGPoint(
            x: containerOrigin.x + (canvasSize.width - width) / 2,
            y: containerOrigin.y + (canvasSize.height - height) / 2
        )
        return ImageDisplayMetrics(
            imageSize: imageSize,
            displayFrame: CGRect(origin: origin, size: CGSize(width: width, height: height))
        )
    }

    /// Backward-compatible helper when canvas fills the container.
    static func aspectFit(imageSize: CGSize, in containerSize: CGSize) -> ImageDisplayMetrics {
        aspectFit(imageSize: imageSize, in: containerSize, containerOrigin: .zero)
    }

    func imageNormalizedToView(_ normalized: CGPoint) -> CGPoint {
        CGPoint(
            x: displayFrame.minX + normalized.x * displayFrame.width,
            y: displayFrame.minY + normalized.y * displayFrame.height
        )
    }
}
