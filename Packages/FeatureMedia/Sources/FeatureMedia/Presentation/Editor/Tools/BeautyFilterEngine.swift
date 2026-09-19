import CoreImage
import Vision

/// Camera beauty pipeline (Vision face box + CI skin smooth). Wraps `BeautyFilterGroup`.
enum BeautyFilterEngine {
    static func apply(
        _ image: CIImage,
        intensity: Float,
        faceObservations: [VNFaceObservation]
    ) -> CIImage {
        BeautyFilterGroup.apply(image, intensity: intensity, faceObservations: faceObservations)
    }
}
