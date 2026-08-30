import CoreImage
import MetalKit
import SwiftUI

struct MetalCameraPreviewView: UIViewRepresentable {
    var image: CIImage?

    func makeUIView(context: Context) -> MetalPreviewMTKView {
        let view = MetalPreviewMTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.framebufferOnly = false
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = 30
        view.contentMode = .scaleAspectFill
        return view
    }

    func updateUIView(_ uiView: MetalPreviewMTKView, context: Context) {
        uiView.ciImage = image
    }
}

final class MetalPreviewMTKView: MTKView, MTKViewDelegate {
    var ciImage: CIImage? {
        didSet { /* drawn on next frame */ }
    }

    private var commandQueue: MTLCommandQueue?
    private var ciContext: CIContext?

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        colorPixelFormat = .bgra8Unorm
        delegate = self
        commandQueue = device?.makeCommandQueue()
        if let device {
            ciContext = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
        }
        isOpaque = true
        backgroundColor = .black
        isUserInteractionEnabled = false
    }

    required init(coder: NSCoder) { fatalError() }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let image = ciImage,
              let drawable = currentDrawable,
              let commandBuffer = commandQueue?.makeCommandBuffer(),
              let ciContext
        else { return }

        let drawableSize = drawableSize
        guard drawableSize.width > 1, drawableSize.height > 1 else { return }

        let imageRect = image.extent
        guard imageRect.width > 1, imageRect.height > 1 else { return }

        let scale = max(drawableSize.width / imageRect.width, drawableSize.height / imageRect.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let originX = (scaled.extent.width - drawableSize.width) / 2
        let originY = (scaled.extent.height - drawableSize.height) / 2
        let cropped = scaled.transformed(by: CGAffineTransform(translationX: -originX, y: -originY))

        ciContext.render(
            cropped,
            to: drawable.texture,
            commandBuffer: commandBuffer,
            bounds: CGRect(origin: .zero, size: drawableSize),
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
