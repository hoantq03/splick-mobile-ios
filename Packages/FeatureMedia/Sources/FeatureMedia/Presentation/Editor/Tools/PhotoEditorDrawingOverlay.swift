import PencilKit
import SwiftUI
import UIKit

/// Renders committed PencilKit strokes when the draw tool is inactive.
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
            return
        }

        let canvasBounds = CGRect(origin: .zero, size: canvasSize)
        imageView.image = drawing.image(from: canvasBounds, scale: UIScreen.main.scale)
    }
}
