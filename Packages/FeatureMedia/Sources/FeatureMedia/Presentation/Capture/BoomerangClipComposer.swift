import AVFoundation
import CoreVideo
import UIKit

enum BoomerangClipComposer {
    enum ComposerError: Error {
        case empty
        case writerFailed
    }

    static func writeLoopingClip(
        images: [UIImage],
        fps: Int = BoomerangTimeline.targetFPS,
        aspectRatio: CGFloat = CameraChromeLayout.previewAspect
    ) async throws -> URL {
        try await writeClip(images: images, fps: fps, aspectRatio: aspectRatio, pingPong: true)
    }

    /// Forward-only clip for hold-to-record video in photo mode (max ~5s).
    static func writeForwardClip(
        images: [UIImage],
        fps: Int = BoomerangTimeline.targetFPS,
        aspectRatio: CGFloat = CameraChromeLayout.previewAspect
    ) async throws -> URL {
        try await writeClip(images: images, fps: fps, aspectRatio: aspectRatio, pingPong: false)
    }

    /// Normalize + crop + downscale once (call during capture so encode stays light).
    static func prepareFrame(
        _ image: UIImage,
        aspectRatio: CGFloat = CameraChromeLayout.previewAspect
    ) -> UIImage {
        downscale(
            PhotoEditorImageProcessor.cropToAspectFill(
                PhotoEditorImageProcessor.normalizeOrientation(image),
                aspectRatio: aspectRatio
            ),
            maxLongSide: BoomerangTimeline.maxLongSide
        )
    }

    private static func writeClip(
        images: [UIImage],
        fps: Int,
        aspectRatio: CGFloat,
        pingPong: Bool
    ) async throws -> URL {
        // Frames are usually already prepared during capture; only reprocess if oversized.
        let prepared: [UIImage] = try await Task.detached(priority: .userInitiated) {
            images.map { image in
                let longest = max(image.size.width * image.scale, image.size.height * image.scale)
                if longest <= BoomerangTimeline.maxLongSide + 1 {
                    return image
                }
                return prepareFrame(image, aspectRatio: aspectRatio)
            }
        }.value
        guard prepared.count >= BoomerangTimeline.minFrames else {
            throw ComposerError.empty
        }

        let first = prepared[0]
        let width = evenPixel(first.size.width * first.scale)
        let height = evenPixel(first.size.height * first.scale)
        guard width >= 16, height >= 16 else { throw ComposerError.empty }

        let filePrefix = pingPong ? "splick-boomerang" : "splick-clip"
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(filePrefix)-\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: destination)
        }

        let writer = try AVAssetWriter(outputURL: destination, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 1_200_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel,
                AVVideoExpectedSourceFrameRateKey: fps,
            ],
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
            ]
        )
        guard writer.canAdd(input) else { throw ComposerError.writerFailed }
        writer.add(input)
        guard writer.startWriting() else { throw ComposerError.writerFailed }
        writer.startSession(atSourceTime: .zero)

        let indices = pingPong
            ? BoomerangTimeline.pingPongIndices(frameCount: prepared.count)
            : Array(0..<prepared.count)
        let timescale = CMTimeScale(fps)

        // Build unique pixel buffers once; ping-pong reuses them.
        var bufferCache = [Int: CVPixelBuffer](minimumCapacity: prepared.count)
        for frameIndex in Set(indices) {
            if let buffer = pixelBuffer(from: prepared[frameIndex], width: width, height: height) {
                bufferCache[frameIndex] = buffer
            }
        }

        for (index, frameIndex) in indices.enumerated() {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(1))
            }
            guard let buffer = bufferCache[frameIndex] else { continue }
            let time = CMTime(value: CMTimeValue(index), timescale: timescale)
            if !adaptor.append(buffer, withPresentationTime: time) {
                throw ComposerError.writerFailed
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw ComposerError.writerFailed }
        return destination
    }

    static func downscale(_ image: UIImage, maxLongSide: CGFloat) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longest = max(pixelWidth, pixelHeight)
        guard longest > maxLongSide else { return image }
        let scale = maxLongSide / longest
        let size = CGSize(width: pixelWidth * scale, height: pixelHeight * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    static func evenPixel(_ value: CGFloat) -> Int {
        max(Int(value.rounded()) / 2 * 2, 2)
    }

    private static func pixelBuffer(from image: UIImage, width: Int, height: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer = buffer else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let data = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let context = CGContext(
            data: data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImage.bitmapInfo
        )
        guard let context, let cgImage = image.cgImage else { return nil }
        // CGImage + CGContext share bottom-left origin — do not UIKit-flip or the clip is upside-down.
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelBuffer
    }
}

private extension CGImage {
    static let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
}
