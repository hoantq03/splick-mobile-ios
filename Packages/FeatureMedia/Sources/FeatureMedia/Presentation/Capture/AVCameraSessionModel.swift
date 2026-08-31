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
    /// Display zoom (0.5× / 1× / 2×), not raw `videoZoomFactor`.
    @Published var zoomFactor: CGFloat = 1
    @Published var minZoom: CGFloat = 1
    @Published var maxZoom: CGFloat = 1
    @Published var focusIndicator: CameraFocusIndicator?
    @Published private(set) var zoomHardware = CameraZoom.hardware(minVideo: 1, maxVideo: 1, switchOverVideo: [])

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
    private var hideFocusTask: Task<Void, Never>?
    private var subjectAreaObserver: NSObjectProtocol?
    private var ignoreSubjectAreaUntil: Date = .distantPast

    deinit {
        if let subjectAreaObserver {
            NotificationCenter.default.removeObserver(subjectAreaObserver)
        }
    }

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
        hideFocusTask?.cancel()
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
                self.focusIndicator = nil
            }
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
        if !isPinching {
            isPinching = true
            pinchBase = zoomFactor
        }
        setDisplayZoom(
            CameraZoom.applyPinch(base: pinchBase, scale: magnification, hardware: zoomHardware),
            animated: false
        )
    }

    func endPinch() {
        isPinching = false
        pinchBase = zoomFactor
    }

    func selectPreset(_ display: CGFloat) {
        setDisplayZoom(display, animated: true)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func cycleZoomStep() {
        selectPreset(CameraZoom.nextPreset(current: zoomFactor, hardware: zoomHardware))
    }

    func setDisplayZoom(_ display: CGFloat, animated: Bool) {
        let clampedDisplay = CameraZoom.clampDisplay(display, hardware: zoomHardware)
        let video = zoomHardware.video(fromDisplay: clampedDisplay)
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentInput?.device else { return }
            do {
                try device.lockForConfiguration()
                let capped = min(
                    max(video, device.minAvailableVideoZoomFactor),
                    min(device.maxAvailableVideoZoomFactor, zoomHardware.maxVideo)
                )
                if animated {
                    device.ramp(toVideoZoomFactor: capped, withRate: 8)
                } else {
                    device.videoZoomFactor = capped
                }
                device.unlockForConfiguration()
                DispatchQueue.main.async { self.zoomFactor = clampedDisplay }
            } catch {
                // Keep the last successful zoom.
            }
        }
    }

    func focus(at viewPoint: CGPoint, viewSize: CGSize) {
        guard viewSize.width > 1, viewSize.height > 1 else { return }
        let poi = CameraFocusMapping.devicePointOfInterest(
            viewPoint: viewPoint,
            viewSize: viewSize,
            mirrored: false
        )
        presentFocusIndicator(at: viewPoint)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        ignoreSubjectAreaUntil = Date().addingTimeInterval(1.6)
        sessionQueue.async { [weak self] in
            self?.applyFocusAndExposure(at: poi)
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
        guard let device = preferredCamera(position: position),
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
            disableVideoMirroring(connection)
        }
        if let connection = photoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            disableVideoMirroring(connection)
        }
    }

    /// Finder is shown unmirrored; keep buffers matching tap-to-focus POI space.
    private func disableVideoMirroring(_ connection: AVCaptureConnection) {
        guard connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = false
    }

    private func preferredCamera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType]
        if position == .back {
            types = [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera,
            ]
        } else {
            types = [
                .builtInTrueDepthCamera,
                .builtInWideAngleCamera,
            ]
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: position
        )
        for type in types {
            if let match = discovery.devices.first(where: { $0.deviceType == type }) {
                return match
            }
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
            ?? AVCaptureDevice.default(for: .video)
    }

    private func applyZoomLimits(for device: AVCaptureDevice) {
        let switchOvers = device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }
        var systemMultiplier: CGFloat?
        if #available(iOS 18.0, *) {
            systemMultiplier = device.displayVideoZoomFactorMultiplier
        }
        let hardware = CameraZoom.hardware(
            minVideo: device.minAvailableVideoZoomFactor,
            maxVideo: device.maxAvailableVideoZoomFactor,
            switchOverVideo: switchOvers,
            systemDisplayMultiplier: systemMultiplier
        )
        let oneX = CameraZoom.clampDisplay(1, hardware: hardware)
        let video = min(
            max(hardware.video(fromDisplay: oneX), device.minAvailableVideoZoomFactor),
            device.maxAvailableVideoZoomFactor
        )
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = video
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.isSubjectAreaChangeMonitoringEnabled = true
            device.unlockForConfiguration()
        } catch {
            // Device may still be configuring.
        }
        observeSubjectArea(device)
        DispatchQueue.main.async {
            self.zoomHardware = hardware
            self.minZoom = hardware.minDisplay
            self.maxZoom = hardware.maxDisplay
            self.zoomFactor = oneX
            self.pinchBase = oneX
            self.isPinching = false
        }
    }

    private func observeSubjectArea(_ device: AVCaptureDevice) {
        if let subjectAreaObserver {
            NotificationCenter.default.removeObserver(subjectAreaObserver)
        }
        subjectAreaObserver = NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceSubjectAreaDidChange,
            object: device,
            queue: .main
        ) { [weak self] _ in
            guard let self, Date() >= self.ignoreSubjectAreaUntil else { return }
            self.resetFocusToContinuous()
        }
    }

    private func resetFocusToContinuous() {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                device.unlockForConfiguration()
            } catch {
                // Ignore — next tap can re-focus.
            }
        }
        DispatchQueue.main.async {
            self.focusIndicator = nil
        }
    }

    private func presentFocusIndicator(at point: CGPoint) {
        hideFocusTask?.cancel()
        focusIndicator = CameraFocusIndicator(point: point)
        hideFocusTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled else { return }
            self.focusIndicator = nil
        }
    }

    private func applyFocusAndExposure(at poi: CGPoint) {
        guard let device = currentInput?.device else { return }
        do {
            try device.lockForConfiguration()
            if device.isSmoothAutoFocusSupported {
                device.isSmoothAutoFocusEnabled = false
            }
            if device.isFocusPointOfInterestSupported {
                if device.focusMode == .autoFocus {
                    device.focusMode = .locked
                }
                device.focusPointOfInterest = poi
                if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                } else if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = poi
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                } else if device.isExposureModeSupported(.autoExpose) {
                    device.exposureMode = .autoExpose
                }
            }
            device.isSubjectAreaChangeMonitoringEnabled = true
            device.unlockForConfiguration()
        } catch {
            // Device may still be configuring.
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
        guard let image = Self.uprightImage(from: photo) else {
            continuation?.resume(throwing: CameraSessionError.captureFailed)
            return
        }
        continuation?.resume(returning: image)
    }

    /// `cgImageRepresentation()` is unrotated sensor pixels. Tagging it `.up` shows
    /// portrait captures on their side. Prefer JPEG (EXIF) and bake orientation.
    static func uprightImage(from photo: AVCapturePhoto) -> UIImage? {
        if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) {
            return PhotoEditorImageProcessor.normalizeOrientation(image)
        }
        guard let cgImage = photo.cgImageRepresentation() else { return nil }
        let tagged = UIImage(
            cgImage: cgImage,
            scale: 1,
            orientation: PhotoEditorImageProcessor.uiImageOrientation(fromPhotoMetadata: photo.metadata)
        )
        return PhotoEditorImageProcessor.normalizeOrientation(tagged)
    }
}
