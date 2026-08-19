import CoreImage
import UIKit
import Vision

/// Applies the live capture filter chain (LUT + beauty) to each camera frame.
final class FilterEngine {
    private let visionQueue = DispatchQueue(label: "com.splick.media.vision", qos: .userInitiated)
    private var latestFaces: [VNFaceObservation] = []
    private var isDetectingFaces = false
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    func apply(
        _ image: CIImage,
        preset: CameraFilterPreset,
        intensity: Float
    ) -> CIImage {
        switch preset {
        case .none, .ar:
            return image
        case .cinematic, .vintage, .vivid:
            guard let name = preset.cubeResourceName else { return image }
            return LUTFilterProcessor.apply(image, cubeName: name, intensity: intensity)
        case .beauty:
            requestFacesIfNeeded(image)
            return BeautyFilterGroup.apply(image, intensity: intensity, faceObservations: latestFaces)
        }
    }

    func renderUIImage(from image: CIImage) -> UIImage? {
        let extent = image.extent.integral
        guard extent.width > 1, extent.height > 1,
              let cg = ciContext.createCGImage(image, from: extent)
        else { return nil }
        return UIImage(cgImage: cg)
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
