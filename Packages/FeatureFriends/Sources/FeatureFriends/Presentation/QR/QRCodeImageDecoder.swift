import UIKit
import Vision

enum QRCodeImageDecoder {
    static func decode(from image: UIImage) -> String? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            return request.results?
                .compactMap { $0.payloadStringValue }
                .first { !$0.isEmpty }
        } catch {
            return nil
        }
    }
}
