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

    let filterEngine = FilterEngine()

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.splick.media.capture")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var photoContinuation: CheckedContinuation<UIImage, Error>?

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
}

enum CameraSessionError: Error {
    case busy
    case captureFailed
}

extension AVCameraSessionModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    private var isDetectingFace = false

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let raw = CIImage(cvPixelBuffer: pixelBuffer)
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
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        sessionQueue.async {
            try? handler.perform([request])
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
        guard let data = photo.fileDataRepresentation(),
              let uiImage = UIImage(data: data)
        else {
            continuation?.resume(throwing: CameraSessionError.captureFailed)
            return
        }
        let normalized = PhotoEditorImageProcessor.normalizeOrientation(uiImage)
        guard let ci = CIImage(image: normalized) else {
            continuation?.resume(returning: normalized)
            return
        }
        let filtered = filterEngine.apply(ci, preset: filterPreset, intensity: filterIntensity)
        let rendered = filterEngine.renderUIImage(from: filtered) ?? normalized
        continuation?.resume(returning: rendered)
    }
}
