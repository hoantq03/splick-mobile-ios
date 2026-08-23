import Combine
import CoreImage
import Localization
import PencilKit
import SwiftUI
import UIKit

enum EditorTool: String, CaseIterable, Identifiable {
    case crop
    case rotate
    case filter
    case adjust
    case draw
    case text
    case sticker

    var id: String { rawValue }

    @MainActor
    func title(using languageService: LanguageService) -> String {
        switch self {
        case .crop: return languageService.text(.mediaToolCrop)
        case .rotate: return languageService.text(.mediaToolRotate)
        case .filter: return languageService.text(.mediaToolFilter)
        case .adjust: return languageService.text(.mediaToolAdjust)
        case .draw: return languageService.text(.mediaToolDraw)
        case .text: return languageService.text(.mediaToolText)
        case .sticker: return languageService.text(.mediaToolSticker)
        }
    }

    var icon: String {
        switch self {
        case .crop: return "crop"
        case .rotate: return "rotate.right"
        case .filter: return "camera.filters"
        case .adjust: return "slider.horizontal.3"
        case .draw: return "scribble.variable"
        case .text: return "character.textbox"
        case .sticker: return "face.smiling"
        }
    }
}

struct EditorTextItem: Identifiable, Equatable {
    /// Language-neutral sentinel for empty canvas text; UI shows `.mediaTextDefault` instead.
    static let placeholderText = "\u{FFFC}"

    @MainActor
    static func defaultText(using languageService: LanguageService) -> String {
        languageService.text(.mediaTextDefault)
    }

    let id: UUID
    var text: String
    var normalizedPosition: CGPoint
    var scale: CGFloat
    var rotation: Angle
    var color: UIColor

    init(
        id: UUID = UUID(),
        text: String = EditorTextItem.placeholderText,
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

@MainActor
final class PhotoEditorViewModel: ObservableObject {
    @Published private(set) var baseImage: UIImage
    @Published var activeTool: EditorTool?
    @Published var isChromeVisible = true
    @Published var drawing = PKDrawing()
    @Published var textItems: [EditorTextItem] = []
    @Published var stickerItems: [EditorStickerItem] = []
    @Published var normalizedCropRect: CGRect = EditState.fullImageCropRect
    @Published var selectedCropAspect: CropAspectPreset = .original
    @Published var selectedTextID: UUID?
    @Published var selectedStickerID: UUID?
    @Published var inkColor: UIColor = .white
    @Published var inkWidth: CGFloat = 5
    @Published var activeFilter: FilterPreset = .none
    @Published var adjustments: ImageAdjustments = .identity
    @Published var rotatePulse = false
    @Published private(set) var isExporting = false
    @Published private(set) var gifStickerData: [UUID: Data] = [:]
    @Published private(set) var gifGallery: [EditorGifSample] = []
    @Published private(set) var recentEmojis: [String] = []

    let preparedImage: PhotoEditorImageProcessor.PreparedImage

    private let originalCIImage: CIImage
    private let renderer = MetalImageRenderer()
    private var rotationQuarters = 0
    private var undoStack: [EditState] = []
    private var redoStack: [EditState] = []
    private var previewGeneration = 0
    private var previewTask: Task<Void, Never>?
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

    init(sourceImage: UIImage, initialFilter: FilterPreset = .none) {
        let prepared = PhotoEditorImageProcessor.prepareForEditing(sourceImage)
        preparedImage = prepared
        baseImage = prepared.editingImage
        if let ciImage = CIImage(image: prepared.editingImage) {
            originalCIImage = ciImage
        } else if let cgImage = prepared.editingImage.cgImage {
            originalCIImage = CIImage(cgImage: cgImage)
        } else {
            originalCIImage = CIImage.empty()
        }
        activeFilter = initialFilter
        activeTool = nil
        pushSnapshotIfNeeded()
        schedulePreviewRefresh()
    }

    var canUndo: Bool { undoStack.count > 1 }
    var canRedo: Bool { !redoStack.isEmpty }

    var showsFullImageForCrop: Bool { activeTool == .crop }

    func selectTool(_ tool: EditorTool) {
        if !isChromeVisible {
            isChromeVisible = true
        }

        if tool == .rotate {
            commitLeavingToolIfNeeded()
            activeTool = .rotate
            rotateClockwise()
            return
        }

        if activeTool == tool {
            enterViewMode()
            return
        }

        commitLeavingToolIfNeeded()
        finalizeFlushToken += 1
        activeTool = tool
        if tool != .text { selectedTextID = nil }
        if tool != .sticker { selectedStickerID = nil }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if tool == .crop || tool == .filter || tool == .adjust {
            schedulePreviewRefresh()
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

    var shouldToggleChromeOnImageTap: Bool {
        if !isChromeVisible { return true }
        switch activeTool {
        case .none:
            return true
        case .text, .draw, .crop, .sticker, .filter, .adjust, .rotate:
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
        schedulePreviewRefresh()
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
    }

    private func commitLeavingToolIfNeeded() {
        if activeTool == .crop {
            schedulePreviewRefresh()
        }
    }

    func undo() {
        guard undoStack.count > 1 else { return }
        redoStack.append(undoStack.removeLast())
        guard let snapshot = undoStack.last else { return }
        restore(snapshot)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func redo() {
        guard let snapshot = redoStack.popLast() else { return }
        undoStack.append(snapshot)
        restore(snapshot)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func rotateClockwise() {
        rotationQuarters += 1
        normalizedCropRect = Self.rotateRectClockwise(normalizedCropRect)
        textItems = textItems.map { item in
            var copy = item
            copy.normalizedPosition = Self.rotatePointClockwise(item.normalizedPosition)
            copy.rotation += .degrees(90)
            return copy
        }
        stickerItems = stickerItems.map { item in
            var copy = item
            copy.normalizedPosition = Self.rotatePointClockwise(item.normalizedPosition)
            copy.rotation += .degrees(90)
            return copy
        }
        drawing = drawing.transformed(using: CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1, ty: 0))
        drawingSyncRevision += 1
        rotatePulse.toggle()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        pushSnapshotIfNeeded()
        schedulePreviewRefresh()
    }

    func resetCrop() {
        selectedCropAspect = .original
        normalizedCropRect = EditState.fullImageCropRect
        pushSnapshotIfNeeded()
        schedulePreviewRefresh()
    }

    func applyCropAspect(_ preset: CropAspectPreset) {
        selectedCropAspect = preset
        if preset == .original {
            normalizedCropRect = EditState.fullImageCropRect
        } else if let pixelAspect = preset.pixelAspect {
            let imageSize = baseImage.size
            let normalizedAspect = CropGeometry.normalizedAspect(
                pixelAspect: pixelAspect,
                imageSize: imageSize
            )
            let center = CGPoint(x: normalizedCropRect.midX, y: normalizedCropRect.midY)
            normalizedCropRect = CropGeometry.fittedRect(
                normalizedAspect: normalizedAspect,
                center: center
            )
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        pushSnapshotIfNeeded()
        schedulePreviewRefresh()
    }

    func markCropAspectFreeIfNeeded() {
        if selectedCropAspect == .original {
            selectedCropAspect = .free
        }
    }

    func setFilter(_ preset: FilterPreset) {
        guard activeFilter != preset else { return }
        activeFilter = preset
        pushSnapshotIfNeeded()
        schedulePreviewRefresh()
    }

    func setAdjustments(_ value: ImageAdjustments) {
        adjustments = value
        schedulePreviewRefresh()
    }

    func commitAdjustments() {
        pushSnapshotIfNeeded()
    }

    func addText(at visibleNormalized: CGPoint) {
        let item = EditorTextItem(
            normalizedPosition: storedNormalized(fromVisible: visibleNormalized),
            color: inkColor
        )
        textItems.append(item)
        selectedTextID = item.id
        pushSnapshotIfNeeded()
    }

    func updateTextItemPosition(id: UUID, normalizedPosition: CGPoint) {
        guard let index = textItems.firstIndex(where: { $0.id == id }) else { return }
        textItems[index].normalizedPosition = storedNormalized(fromVisible: normalizedPosition)
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

    func removeTextItem(_ id: UUID) {
        textItems.removeAll { $0.id == id }
        pushSnapshotIfNeeded()
    }

    func commitTextEdit() {
        pushSnapshotIfNeeded()
    }

    func commitTextTransform() {
        pushSnapshotIfNeeded()
    }

    func addSticker(_ kind: EditorStickerKind) {
        let offset = CGFloat(stickerItems.count % 5) * 0.04
        let item = EditorStickerItem(
            kind: kind,
            normalizedPosition: storedNormalized(fromVisible: CGPoint(x: 0.5 + offset, y: 0.45 + offset))
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
            normalizedPosition: storedNormalized(fromVisible: CGPoint(x: 0.5 + offset, y: 0.45 + offset))
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
            normalizedPosition: storedNormalized(fromVisible: CGPoint(x: 0.5 + offset, y: 0.45 + offset))
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
        items[index].normalizedPosition = storedNormalized(fromVisible: normalizedPosition)
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
        let canvasSize = lastDisplayMetrics?.displayFrame.size ?? drawingCanvasSize
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }
        drawingCanvasSize = canvasSize
        drawing = storeDrawing(newDrawing, canvasSize: canvasSize)
        pushSnapshotIfNeeded()
    }

    func drawingForDisplay(canvasSize: CGSize) -> PKDrawing {
        displayDrawing(drawing, canvasSize: canvasSize)
    }

    func commitCropRect(_ rect: CGRect) {
        let clamped: CGRect
        if let pixelAspect = selectedCropAspect.pixelAspect {
            let normalizedAspect = CropGeometry.normalizedAspect(
                pixelAspect: pixelAspect,
                imageSize: baseImage.size
            )
            clamped = CropGeometry.clampLocked(rect, normalizedAspect: normalizedAspect)
        } else {
            clamped = CropGeometry.clamp(rect)
        }
        guard clamped != normalizedCropRect else { return }
        normalizedCropRect = clamped
    }

    func applyCropIfNeeded() {
        schedulePreviewRefresh()
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

    func overlayDisplayPoint(_ stored: CGPoint, metrics: ImageDisplayMetrics) -> CGPoint {
        metrics.imageNormalizedToView(visibleNormalized(fromStored: stored))
    }

    func finalize(displayMetrics: ImageDisplayMetrics? = nil) -> UIImage {
        lastDisplayMetrics = displayMetrics ?? lastDisplayMetrics
        return baseImage
    }

    func finalizeAsync() async -> UIImage {
        prepareForFinalize()
        isExporting = true
        let state = currentEditState()
        let metrics = lastDisplayMetrics
        let original = originalCIImage
        let renderer = renderer
        let base = await renderer.renderBase(state, from: original) ?? baseImage
        let composited = compositeOverlays(on: base, state: state, metrics: metrics)
        isExporting = false
        return composited
    }

    func currentEditState() -> EditState {
        EditState(
            cropRect: normalizedCropRect,
            rotationQuarters: rotationQuarters,
            drawing: drawing,
            textItems: textItems,
            stickerItems: stickerItems,
            gifStickerData: gifStickerData,
            activeFilter: activeFilter,
            adjustments: adjustments
        )
    }

    private func schedulePreviewRefresh() {
        previewTask?.cancel()
        previewGeneration += 1
        let generation = previewGeneration
        let state = currentEditState()
        let ignoreCrop = showsFullImageForCrop
        let original = originalCIImage
        previewTask = Task { [renderer] in
            let preview = await renderer.renderPreview(
                state,
                from: original,
                maxDimension: 1600,
                ignoreCrop: ignoreCrop
            )
            await MainActor.run {
                guard generation == self.previewGeneration, let preview else { return }
                self.baseImage = preview
            }
        }
    }

    private func visibleNormalized(fromStored stored: CGPoint) -> CGPoint {
        let crop = normalizedCropRect
        if showsFullImageForCrop || !isEffectiveCrop(crop) { return stored }
        return CGPoint(
            x: (stored.x - crop.minX) / max(crop.width, 0.0001),
            y: (stored.y - crop.minY) / max(crop.height, 0.0001)
        )
    }

    private func storedNormalized(fromVisible visible: CGPoint) -> CGPoint {
        let crop = normalizedCropRect
        if showsFullImageForCrop || !isEffectiveCrop(crop) { return visible }
        return CGPoint(
            x: crop.minX + visible.x * crop.width,
            y: crop.minY + visible.y * crop.height
        )
    }

    private func storeDrawing(_ canvasDrawing: PKDrawing, canvasSize: CGSize) -> PKDrawing {
        var transform = CGAffineTransform(scaleX: 1 / canvasSize.width, y: 1 / canvasSize.height)
        let crop = normalizedCropRect
        if !showsFullImageForCrop, isEffectiveCrop(crop) {
            transform = transform
                .scaledBy(x: crop.width, y: crop.height)
                .translatedBy(x: crop.minX, y: crop.minY)
        }
        return canvasDrawing.transformed(using: transform)
    }

    private func displayDrawing(_ stored: PKDrawing, canvasSize: CGSize) -> PKDrawing {
        var transform = CGAffineTransform.identity
        let crop = normalizedCropRect
        if !showsFullImageForCrop, isEffectiveCrop(crop) {
            transform = transform
                .translatedBy(x: -crop.minX, y: -crop.minY)
                .scaledBy(x: 1 / max(crop.width, 0.0001), y: 1 / max(crop.height, 0.0001))
        }
        transform = transform.scaledBy(x: canvasSize.width, y: canvasSize.height)
        return stored.transformed(using: transform)
    }

    private func compositeOverlays(on base: UIImage, state: EditState, metrics: ImageDisplayMetrics?) -> UIImage {
        let imageSize = base.size
        guard imageSize.width > 1, imageSize.height > 1 else { return base }
        let format = UIGraphicsImageRendererFormat()
        format.scale = base.scale
        format.opaque = false
        let displayFrame = metrics?.displayFrame ?? CGRect(origin: .zero, size: imageSize)

        return UIGraphicsImageRenderer(size: imageSize, format: format).image { _ in
            base.draw(in: CGRect(origin: .zero, size: imageSize))

            if !state.drawing.bounds.isEmpty {
                var transform = CGAffineTransform.identity
                if state.isEffectiveCrop {
                    transform = transform
                        .translatedBy(x: -state.cropRect.minX, y: -state.cropRect.minY)
                        .scaledBy(
                            x: 1 / max(state.cropRect.width, 0.0001),
                            y: 1 / max(state.cropRect.height, 0.0001)
                        )
                }
                transform = transform.scaledBy(x: imageSize.width, y: imageSize.height)
                let mapped = state.drawing.transformed(using: transform)
                let drawingImage = mapped.image(
                    from: CGRect(origin: .zero, size: imageSize),
                    scale: base.scale
                )
                drawingImage.draw(in: CGRect(origin: .zero, size: imageSize))
            }

            for item in state.textItems {
                drawTextItem(item, imageSize: imageSize, crop: state.cropRect, displayFrame: displayFrame)
            }
            for item in state.stickerItems {
                drawStickerItem(item, state: state, imageSize: imageSize, displayFrame: displayFrame)
            }
        }
    }

    private func overlayExportPoint(_ stored: CGPoint, crop: CGRect) -> CGPoint {
        if !isEffectiveCrop(crop) { return stored }
        return CGPoint(
            x: (stored.x - crop.minX) / max(crop.width, 0.0001),
            y: (stored.y - crop.minY) / max(crop.height, 0.0001)
        )
    }

    private func drawTextItem(
        _ item: EditorTextItem,
        imageSize: CGSize,
        crop: CGRect,
        displayFrame: CGRect
    ) {
        let normalized = overlayExportPoint(item.normalizedPosition, crop: crop)
        let imagePoint = CGPoint(x: normalized.x * imageSize.width, y: normalized.y * imageSize.height)
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

    private func drawStickerItem(
        _ item: EditorStickerItem,
        state: EditState,
        imageSize: CGSize,
        displayFrame: CGRect
    ) {
        let displayScale = imageSize.width / max(displayFrame.width, 1)
        let stickerImageScale = item.scale * displayScale
        let gifData: Data? = {
            guard case .gif(let id) = item.kind else { return nil }
            return state.gifStickerData[id]
        }()
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

        let normalized = overlayExportPoint(item.normalizedPosition, crop: state.cropRect)
        let imagePoint = CGPoint(x: normalized.x * imageSize.width, y: normalized.y * imageSize.height)
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

    private func isEffectiveCrop(_ rect: CGRect) -> Bool {
        rect.minX > 0.001 || rect.minY > 0.001 || rect.width < 0.999 || rect.height < 0.999
    }

    private func pushSnapshotIfNeeded() {
        let snapshot = currentEditState()
        if let last = undoStack.last, last == snapshot {
            return
        }
        undoStack.append(snapshot)
        redoStack.removeAll()
        if undoStack.count > 20 {
            undoStack.removeFirst()
        }
    }

    private func restore(_ snapshot: EditState) {
        normalizedCropRect = snapshot.cropRect
        rotationQuarters = snapshot.rotationQuarters
        drawing = snapshot.drawing
        textItems = snapshot.textItems
        stickerItems = snapshot.stickerItems
        gifStickerData = snapshot.gifStickerData
        activeFilter = snapshot.activeFilter
        adjustments = snapshot.adjustments
        selectedTextID = nil
        selectedStickerID = nil
        drawingSyncRevision += 1
        schedulePreviewRefresh()
    }

    private static func rotatePointClockwise(_ point: CGPoint) -> CGPoint {
        CGPoint(x: 1 - point.y, y: point.x)
    }

    private static func rotateRectClockwise(_ rect: CGRect) -> CGRect {
        CGRect(x: 1 - rect.maxY, y: rect.minX, width: rect.height, height: rect.width)
    }
}

struct ImageDisplayMetrics: Equatable {
    let imageSize: CGSize
    let displayFrame: CGRect

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
