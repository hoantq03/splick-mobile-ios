import CoreImage
import SwiftUI
import UIKit

/// Pins image to SwiftUI layout bounds — prevents oversized intrinsic content from zooming the preview.
struct EditorImageView: UIViewRepresentable {
    let image: UIImage
    var adjustments: ImageAdjustments = .identity

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.clipsToBounds = true

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        context.coordinator.imageView = imageView
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard let imageView = context.coordinator.imageView else { return }
        if adjustments.isIdentity {
            imageView.image = image
            return
        }
        guard let ciImage = CIImage(image: image) else {
            imageView.image = image
            return
        }
        imageView.image = FilterEngine.renderUIImage(from: FilterEngine.applyAdjustments(ciImage, adjustments)) ?? image
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var imageView: UIImageView?
    }
}
