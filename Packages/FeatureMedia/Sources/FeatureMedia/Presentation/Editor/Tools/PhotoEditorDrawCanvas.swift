import PencilKit
import SwiftUI

struct PhotoEditorDrawCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    let isEnabled: Bool
    let inkColor: UIColor
    let inkWidth: CGFloat
    let onDrawingEnded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingEnded: onDrawingEnded)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.delegate = context.coordinator
        canvas.tool = makeTool()
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
        canvas.isUserInteractionEnabled = isEnabled
        canvas.tool = makeTool()
    }

    private func makeTool() -> PKInkingTool {
        PKInkingTool(.pen, color: inkColor, width: inkWidth)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let onDrawingEnded: () -> Void
        private var isStrokeActive = false

        init(onDrawingEnded: @escaping () -> Void) {
            self.onDrawingEnded = onDrawingEnded
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            isStrokeActive = true
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            guard isStrokeActive else { return }
            isStrokeActive = false
            onDrawingEnded()
        }
    }
}

extension PhotoEditorDrawCanvas {
    init(
        viewModel: PhotoEditorViewModel,
        isEnabled: Bool,
        onDrawingEnded: @escaping () -> Void
    ) {
        self.init(
            drawing: Binding(
                get: { viewModel.drawing },
                set: { viewModel.drawing = $0 }
            ),
            isEnabled: isEnabled,
            inkColor: viewModel.inkColor,
            inkWidth: viewModel.inkWidth,
            onDrawingEnded: onDrawingEnded
        )
    }
}
