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

        // Flush if explicitly requested (e.g. finalize or tool switch).
        if coordinator.lastFlushToken != flushToken {
            coordinator.lastFlushToken = flushToken
            coordinator.flush(canvas)
        }

        // Sync from ViewModel on undo/redo (drawingSyncRevision increments).
        if coordinator.lastAppliedSyncRevision != drawingSyncRevision,
           !coordinator.isStrokeActive {
            canvas.drawing = drawing
            coordinator.lastAppliedSyncRevision = drawingSyncRevision
            // Re-arm lastCommittedDrawing so we don't re-flush undo-restored strokes.
            coordinator.lastCommittedDrawing = drawing
        }

        let wasEnabled = coordinator.wasEnabled
        if wasEnabled, !isEnabled, !coordinator.isStrokeActive {
            coordinator.flush(canvas)
        }
        coordinator.wasEnabled = isEnabled

        // When switching back TO draw mode, restore the current ViewModel drawing so
        // the user continues on top of their existing strokes.
        // (We never bake on tool switch, so drawing may be non-empty here.)
        let switchingToEnabled = !wasEnabled && isEnabled
        if switchingToEnabled, canvas.drawing != drawing, !coordinator.isStrokeActive {
            canvas.drawing = drawing
            coordinator.lastCommittedDrawing = drawing
        }

        // Keep canvas in sync when draw tool is inactive and no stroke is live.
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
        /// Tracks the last drawing we committed to avoid redundant callbacks.
        var lastCommittedDrawing = PKDrawing()

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
            guard !canvasView.drawing.bounds.isEmpty else { return }
            isStrokeActive = false
            commit(canvasView.drawing)
        }

        private func commit(_ drawing: PKDrawing) {
            guard !drawing.bounds.isEmpty else { return }
            // Skip if we already committed this exact drawing (avoids double-bake
            // when flush is called multiple times after a tool switch without new strokes).
            guard drawing != lastCommittedDrawing else { return }
            lastCommittedDrawing = drawing
            onStrokeEnded(drawing)
        }
    }
}
