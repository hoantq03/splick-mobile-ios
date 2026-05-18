import AVFoundation
import UIKit

@MainActor
final class CameraSessionModel: NSObject, ObservableObject {
    enum Phase: Equatable {
        case preparing
        case ready
        case unavailable(String)
        case permissionDenied
    }

    @Published private(set) var phase: Phase = .preparing
    @Published var flashMode: AVCaptureDevice.FlashMode = .auto
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    @Published private(set) var isCapturing = false

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "splick.camera.session", qos: .userInitiated)
    private let photoOutput = AVCapturePhotoOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var photoContinuation: CheckedContinuation<UIImage?, Never>?

    var isLivePreviewAvailable: Bool {
        phase == .ready && videoInput != nil
    }

    static var prefersAlbumOnly: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    func prepare() async {
        phase = .preparing

        if Self.prefersAlbumOnly {
            phase = .unavailable("Simulator không hỗ trợ camera trực tiếp. Dùng Album hoặc test trên iPhone thật.")
            return
        }

        let authorized = await requestCameraAccess()
        guard authorized else {
            phase = .permissionDenied
            return
        }

        let configured = await configureSession(position: cameraPosition)
        if configured {
            phase = .ready
            start()
        } else {
            phase = .unavailable(
                "Không tìm thấy camera. Trên Mac, hãy bật camera cho Simulator (I/O → Camera) hoặc chọn ảnh từ Album."
            )
        }
    }

    func start() {
        guard isLivePreviewAvailable else { return }
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func toggleCamera() {
        guard isLivePreviewAvailable else { return }
        cameraPosition = cameraPosition == .back ? .front : .back
        Task {
            stop()
            let configured = await configureSession(position: cameraPosition)
            if configured {
                phase = .ready
                start()
            }
        }
    }

    func cycleFlash() {
        switch flashMode {
        case .auto: flashMode = .on
        case .on: flashMode = .off
        default: flashMode = .auto
        }
    }

    var flashIconName: String {
        switch flashMode {
        case .on: return "bolt.fill"
        case .off: return "bolt.slash.fill"
        default: return "bolt.badge.automatic.fill"
        }
    }

    func focus(at viewPoint: CGPoint, in previewBounds: CGSize) {
        guard previewBounds.width > 0, previewBounds.height > 0,
              let device = videoInput?.device
        else { return }

        let x = viewPoint.y / previewBounds.height
        let y = 1 - (viewPoint.x / previewBounds.width)
        let point = CGPoint(x: x, y: y)

        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }
                device.unlockForConfiguration()
            } catch { }
        }
    }

    func capturePhoto() async -> UIImage? {
        guard isLivePreviewAvailable, !isCapturing else { return nil }
        isCapturing = true
        defer { isCapturing = false }

        return await withCheckedContinuation { continuation in
            photoContinuation = continuation
            let settings = AVCapturePhotoSettings()
            if photoOutput.supportedFlashModes.contains(flashMode) {
                settings.flashMode = flashMode
            }
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }
                guard self.session.isRunning else {
                    continuation.resume(returning: nil)
                    return
                }
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    private func requestCameraAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    @discardableResult
    private func configureSession(position: AVCaptureDevice.Position) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }

                if self.session.isRunning {
                    self.session.stopRunning()
                }

                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                for input in self.session.inputs {
                    self.session.removeInput(input)
                }
                for output in self.session.outputs {
                    self.session.removeOutput(output)
                }

                self.videoInput = nil

                let device = Self.discoverCamera(position: position)
                var success = false

                if let device,
                   let input = try? AVCaptureDeviceInput(device: device),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.videoInput = input
                    success = true
                }

                if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                }

                self.session.commitConfiguration()
                continuation.resume(returning: success)
            }
        }
    }

  /// Tries back/front, then any video device (Mac webcam / Simulator virtual camera).
    private static func discoverCamera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let prioritized: [AVCaptureDevice.Position] = position == .back
            ? [.back, .front, .unspecified]
            : [.front, .back, .unspecified]

        for pos in prioritized {
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: pos) {
                return device
            }
        }

        var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(iOS 17.0, *) {
            deviceTypes.append(contentsOf: [.builtInDualCamera, .builtInTripleCamera, .continuityCamera, .external])
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices.first
    }
}

extension CameraSessionModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let image = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
        Task { @MainActor in
            photoContinuation?.resume(returning: image)
            photoContinuation = nil
        }
    }
}
