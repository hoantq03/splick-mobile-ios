import CoreImage
import UIKit
import Vision

/// Live-camera filter applicator. Detects faces off the render path for beauty.
final class CameraFilterEngine {
    private let visionQueue = DispatchQueue(label: "com.splick.media.vision", qos: .userInitiated)
    private var latestFaces: [VNFaceObservation] = []
    private var isDetectingFaces = false

    func apply(
        _ image: CIImage,
        preset: CameraFilterPreset,
        intensity: Float
    ) -> CIImage {
        if preset == .beauty {
            requestFacesIfNeeded(image)
        }
        return FilterEngine.apply(
            image,
            cameraPreset: preset,
            intensity: intensity,
            faceObservations: latestFaces
        )
    }

    func renderUIImage(from image: CIImage) -> UIImage? {
        FilterEngine.renderUIImage(from: image)
    }

    private func requestFacesIfNeeded(_ image: CIImage) {
        if isDetectingFaces { return }
        isDetectingFaces = true
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        visionQueue.async { [weak self] in
            let request = VNDetectFaceRectanglesRequest()
            try? handler.perform([request])
            let faces = request.results ?? []
            DispatchQueue.main.async {
                self?.latestFaces = faces
                self?.isDetectingFaces = false
            }
        }
    }
}
