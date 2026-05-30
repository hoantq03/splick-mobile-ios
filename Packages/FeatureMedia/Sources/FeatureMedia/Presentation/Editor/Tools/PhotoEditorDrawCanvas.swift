import PencilKit
import SwiftUI

struct PhotoEditorDrawCanvas: UIViewRepresentable {
    let drawing: PKDrawing
    let isEnabled: Bool
    let inkColor: UIColor
    let inkWidth: CGFloat
    var flushToken: Int = 0
    var drawingSyncRevision: Int = 0
    let onStrokeEnded: (PKDrawing) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onStrokeEnded: onStrokeEnded)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.delegate = context.coordinator
        canvas.drawing = drawing
        canvas.tool = PKInkingTool(.pen, color: inkColor, width: inkWidth)
        context.coordinator.wasEnabled = isEnabled
        context.coordinator.lastAppliedSyncRevision = drawingSyncRevision
        return canvas
    }

    static func dismantleUIView(_ canvas: PKCanvasView, coordinator: Coordinator) {
        coordinator.flush(canvas)
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onStrokeEnded = onStrokeEnded

        if coordinator.lastFlushToken != flushToken {
            coordinator.lastFlushToken = flushToken
            coordinator.flush(canvas)
        }

        if coordinator.lastAppliedSyncRevision != drawingSyncRevision,
           !coordinator.isStrokeActive {
            canvas.drawing = drawing
            coordinator.lastAppliedSyncRevision = drawingSyncRevision
        }

        let wasEnabled = coordinator.wasEnabled
        if wasEnabled, !isEnabled, !coordinator.isStrokeActive {
            coordinator.flush(canvas)
        }
        coordinator.wasEnabled = isEnabled

        // While the draw tool is active, PKCanvasView owns live strokes — never overwrite from SwiftUI.
        if !isEnabled, !coordinator.isStrokeActive, canvas.drawing != drawing {
            canvas.drawing = drawing
        }

        canvas.isUserInteractionEnabled = isEnabled
        canvas.tool = PKInkingTool(.pen, color: inkColor, width: inkWidth)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var onStrokeEnded: (PKDrawing) -> Void
        var isStrokeActive = false
        var wasEnabled = true
        var lastFlushToken = 0
        var lastAppliedSyncRevision = 0

        init(onStrokeEnded: @escaping (PKDrawing) -> Void) {
            self.onStrokeEnded = onStrokeEnded
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            isStrokeActive = true
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            guard isStrokeActive else { return }
            isStrokeActive = false
            commit(canvasView.drawing)
        }

        func flush(_ canvasView: PKCanvasView) {
            if !canvasView.drawing.bounds.isEmpty {
                isStrokeActive = false
                commit(canvasView.drawing)
            }
        }

        private func commit(_ drawing: PKDrawing) {
            guard !drawing.bounds.isEmpty else { return }
            onStrokeEnded(drawing)
        }
    }
}
