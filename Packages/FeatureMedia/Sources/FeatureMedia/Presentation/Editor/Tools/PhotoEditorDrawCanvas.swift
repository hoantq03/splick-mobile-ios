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
        context.coordinator.lastCommittedDrawing = drawing
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

        if coordinator.lastAppliedSyncRevision != drawingSyncRevision {
            coordinator.lastAppliedSyncRevision = drawingSyncRevision
            coordinator.applyProgrammaticDrawing(drawing, on: canvas)
        }

        let wasEnabled = coordinator.wasEnabled
        if wasEnabled, !isEnabled {
            coordinator.flush(canvas)
        }
        coordinator.wasEnabled = isEnabled

        let switchingToEnabled = !wasEnabled && isEnabled
        if switchingToEnabled {
            coordinator.applyProgrammaticDrawing(drawing, on: canvas)
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
        var lastCommittedDrawing = PKDrawing()
        private var isApplyingProgrammaticDrawing = false

        init(onStrokeEnded: @escaping (PKDrawing) -> Void) {
            self.onStrokeEnded = onStrokeEnded
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingProgrammaticDrawing else { return }
            isStrokeActive = true
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            guard !isApplyingProgrammaticDrawing else { return }
            guard isStrokeActive else { return }
            isStrokeActive = false
            commit(canvasView.drawing)
        }

        func flush(_ canvasView: PKCanvasView) {
            isStrokeActive = false
            commit(canvasView.drawing)
        }

        func applyProgrammaticDrawing(_ drawing: PKDrawing, on canvasView: PKCanvasView) {
            isApplyingProgrammaticDrawing = true
            canvasView.drawing = drawing
            lastCommittedDrawing = drawing
            isStrokeActive = false
            isApplyingProgrammaticDrawing = false
        }

        private func commit(_ drawing: PKDrawing) {
            guard !drawing.bounds.isEmpty else { return }
            guard drawing != lastCommittedDrawing else { return }
            lastCommittedDrawing = drawing
            onStrokeEnded(drawing)
        }
    }
}
