import AVFoundation
import Combine
import CoreImage
import UIKit
import Vision

enum CameraFlashMode: Equatable {
    case off, on, auto
}

final class AVCameraSessionModel: NSObject, ObservableObject {
    @Published var previewImage: CIImage?
    @Published var isRunning = false
    @Published var flashMode: CameraFlashMode = .off
    @Published var isFrontCamera = false
    @Published var filterPreset: CameraFilterPreset = .none
    @Published var filterIntensity: Float = 0.75
    @Published var primaryFaceBounds: CGRect?
    @Published var lastErrorMessage: String?
    @Published var zoomFactor: CGFloat = 1
    @Published var minZoom: CGFloat = 1
    @Published var maxZoom: CGFloat = 1

    let filterEngine = CameraFilterEngine()

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.splick.media.capture")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var photoContinuation: CheckedContinuation<UIImage, Error>?
    private var isDetectingFace = false
    private var pinchBase: CGFloat = 1
    private var isPinching = false
    private var panBase: CGFloat = 1
    private var isPanning = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted { self?.startSession() }
            }
        default:
            DispatchQueue.main.async { self.lastErrorMessage = "camera_denied" }
        }
    }

    private func startSession() {
        sessionQueue.async { [weak self] in
            self?.configureIfNeeded()
            self?.session.startRunning()
            DispatchQueue.main.async { self?.isRunning = true }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    func flipCamera() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let next: AVCaptureDevice.Position = self.isFrontCamera ? .back : .front
            self.setCamera(position: next)
        }
    }

    func cycleFlash() {
        DispatchQueue.main.async {
            switch self.flashMode {
            case .off: self.flashMode = .auto
            case .auto: self.flashMode = .on
            case .on: self.flashMode = .off
            }
        }
    }

    func updatePinch(magnification: CGFloat) {
        isPanning = false
        if !isPinching {
            isPinching = true
            pinchBase = zoomFactor
        }
        setZoom(CameraZoom.applyPinch(base: pinchBase, scale: magnification, min: minZoom, max: maxZoom), animated: false)
    }

    func endPinch() {
        isPinching = false
        pinchBase = zoomFactor
    }

    func updatePan(translationX: CGFloat, translationY: CGFloat) {
        guard !isPinching, abs(translationX) >= abs(translationY) else { return }
        if !isPanning {
            isPanning = true
            panBase = zoomFactor
        }
        let width = max(UIScreen.main.bounds.width, 1)
        setZoom(
            CameraZoom.applyPan(base: panBase, deltaPx: translationX, viewWidth: width, min: minZoom, max: maxZoom),
            animated: false
        )
    }

    func endPan() {
        isPanning = false
        panBase = zoomFactor
    }

    func cycleZoomStep() {
        setZoom(CameraZoom.nextStep(current: zoomFactor, min: minZoom, max: maxZoom), animated: true)
    }

    func setZoom(_ factor: CGFloat, animated: Bool) {
        let clamped = CameraZoom.clamp(factor, min: minZoom, max: maxZoom)
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if animated {
                    device.ramp(toVideoZoomFactor: clamped, withRate: 8)
                } else {
                    device.videoZoomFactor = clamped
                }
                device.unlockForConfiguration()
                DispatchQueue.main.async { self.zoomFactor = clamped }
            } catch {
                // Keep the last successful zoom.
            }
        }
    }

    func capturePhoto() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                if self.photoContinuation != nil {
                    continuation.resume(throwing: CameraSessionError.busy)
                    return
                }
                self.photoContinuation = continuation
                let settings = AVCapturePhotoSettings()
                let flash = self.flashMode
                if self.photoOutput.supportedFlashModes.contains(.on) {
                    switch flash {
                    case .off: settings.flashMode = .off
                    case .on: settings.flashMode = .on
                    case .auto: settings.flashMode = .auto
                    }
                }
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    private var didConfigure = false

    private func configureIfNeeded() {
        guard !didConfigure else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo

        setCamera(position: .back, inConfiguration: true)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ]
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        configureConnections()
        session.commitConfiguration()
        didConfigure = true
    }

    private func setCamera(position: AVCaptureDevice.Position, inConfiguration: Bool = false) {
        if !inConfiguration { session.beginConfiguration() }
        if let currentInput {
            session.removeInput(currentInput)
        }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
            ?? AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            if !inConfiguration { session.commitConfiguration() }
            return
        }
        session.addInput(input)
        currentInput = input
        configureConnections()
        applyZoomLimits(for: device)
        if !inConfiguration { session.commitConfiguration() }
        DispatchQueue.main.async { self.isFrontCamera = position == .front }
    }

    private func configureConnections() {
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = isFrontCamera || currentInput?.device.position == .front
            }
        }
        if let connection = photoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = currentInput?.device.position == .front
            }
        }
    }

    private func applyZoomLimits(for device: AVCaptureDevice) {
        let minFactor = max(device.minAvailableVideoZoomFactor, 1)
        let maxFactor = min(device.maxAvailableVideoZoomFactor, CameraZoom.uxMax)
        let reset = CameraZoom.clamp(1, min: minFactor, max: maxFactor)
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = reset
            device.unlockForConfiguration()
        } catch {
            // Device may still be configuring.
        }
        DispatchQueue.main.async {
            self.minZoom = minFactor
            self.maxZoom = maxFactor
            self.zoomFactor = reset
            self.pinchBase = reset
            self.panBase = reset
            self.isPinching = false
            self.isPanning = false
        }
    }
}

enum CameraSessionError: Error {
    case busy
    case captureFailed
}

extension AVCameraSessionModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let raw = previewCIImage(from: pixelBuffer, connection: connection)
        let preset = filterPreset
        let intensity = filterIntensity
        let filtered = filterEngine.apply(raw, preset: preset, intensity: intensity)
        if preset == .ar {
            detectFaceIfNeeded(pixelBuffer)
        }
        DispatchQueue.main.async {
            self.previewImage = filtered
        }
    }

    private func detectFaceIfNeeded(_ pixelBuffer: CVPixelBuffer) {
        if isDetectingFace { return }
        isDetectingFace = true
        let request = VNDetectFaceRectanglesRequest { [weak self] request, _ in
            let box = (request.results as? [VNFaceObservation])?
                .max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })?
                .boundingBox
            DispatchQueue.main.async {
                self?.primaryFaceBounds = box
                self?.isDetectingFace = false
            }
        }
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: visionOrientation(for: videoOutput.connection(with: .video)),
            options: [:]
        )
        sessionQueue.async {
            try? handler.perform([request])
        }
    }
}

private extension AVCameraSessionModel {
    /// Video connection is locked to portrait, so buffers are already upright.
    /// Applying `.right` again stretched/rotated the finder preview.
    func previewCIImage(from pixelBuffer: CVPixelBuffer, connection: AVCaptureConnection) -> CIImage {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        if connection.isVideoOrientationSupported, connection.videoOrientation == .portrait {
            return image
        }
        return image.oriented(previewExifOrientation(for: connection))
    }

    func visionOrientation(for connection: AVCaptureConnection?) -> CGImagePropertyOrientation {
        guard let connection else { return .up }
        if connection.isVideoOrientationSupported, connection.videoOrientation == .portrait {
            return .up
        }
        return previewExifOrientation(for: connection)
    }

    func previewExifOrientation(for connection: AVCaptureConnection?) -> CGImagePropertyOrientation {
        guard let connection else { return .right }
        let mirrored = connection.isVideoMirrored
        switch connection.videoOrientation {
        case .portrait:
            return mirrored ? .leftMirrored : .right
        case .portraitUpsideDown:
            return mirrored ? .rightMirrored : .left
        case .landscapeRight:
            return mirrored ? .downMirrored : .up
        case .landscapeLeft:
            return mirrored ? .upMirrored : .down
        @unknown default:
            return .right
        }
    }
}

extension AVCameraSessionModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let continuation = photoContinuation
        photoContinuation = nil
        if let error {
            continuation?.resume(throwing: error)
            return
        }
        if let cgImage = photo.cgImageRepresentation() {
            continuation?.resume(returning: UIImage(cgImage: cgImage, scale: 1, orientation: .up))
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let uiImage = UIImage(data: data)
        else {
            continuation?.resume(throwing: CameraSessionError.captureFailed)
            return
        }
        continuation?.resume(returning: PhotoEditorImageProcessor.normalizeOrientation(uiImage))
    }
}
