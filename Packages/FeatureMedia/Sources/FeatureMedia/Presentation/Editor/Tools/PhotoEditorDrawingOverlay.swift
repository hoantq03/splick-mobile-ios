import PencilKit
import SwiftUI
import UIKit

/// Renders committed PencilKit strokes when the draw tool is inactive.
///
/// Renders synchronously on the main thread so the image is available the instant
/// the overlay appears — async rendering caused a brief blank flash during the
/// draw→text transition, making the last stroke appear to vanish.
/// PKDrawing.image(from:scale:) is fast (~1ms for typical drawings) so main-thread
/// rendering is safe here.
struct PhotoEditorDrawingOverlay: UIViewRepresentable {
    let drawing: PKDrawing
    let canvasSize: CGSize

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        imageView.backgroundColor = .clear
        imageView.isUserInteractionEnabled = false
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        guard !drawing.bounds.isEmpty,
              canvasSize.width > 0,
              canvasSize.height > 0 else {
            imageView.image = nil
            context.coordinator.cachedKey = nil
            return
        }

        let newKey = CacheKey(drawing: drawing, canvasSize: canvasSize)
        guard newKey != context.coordinator.cachedKey else { return }
        context.coordinator.cachedKey = newKey

        // Synchronous render: image is set before the view is displayed,
        // eliminating the blank frame that caused the apparent stroke disappearance.
        imageView.image = drawing.image(
            from: CGRect(origin: .zero, size: canvasSize),
            scale: UIScreen.main.scale
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var cachedKey: CacheKey?
    }

    struct CacheKey: Equatable {
        let drawingData: Data
        let canvasSize: CGSize

        init(drawing: PKDrawing, canvasSize: CGSize) {
            drawingData = drawing.dataRepresentation()
            self.canvasSize = canvasSize
        }
    }
}
