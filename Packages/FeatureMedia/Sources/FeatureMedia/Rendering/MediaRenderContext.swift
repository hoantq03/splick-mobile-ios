import CoreImage
import Metal

/// Shared GPU `CIContext` for camera preview and the photo editor.
enum MediaRenderContext {
    static let ciContext: CIContext = {
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(
                mtlDevice: device,
                options: [
                    .cacheIntermediates: false,
                    .useSoftwareRenderer: false,
                ]
            )
        }
        return CIContext(options: [
            .useSoftwareRenderer: false,
            .cacheIntermediates: false,
        ])
    }()
}
