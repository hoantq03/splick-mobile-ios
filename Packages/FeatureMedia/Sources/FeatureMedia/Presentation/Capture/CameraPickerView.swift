import SwiftUI
import UIKit

/// System camera UI (`UIImagePickerController`) with a fully custom control overlay.
///
/// Control placement:
///   - Top-left    : X / exit button
///   - Top-center  : Flash toggle (off → auto → on)
///   - Top-right   : Camera flip (front / rear)
///   - Bottom-center : Shutter
///   - Bottom-left   : Album picker
///   - Badge on album : number of accumulated captured photos
struct CameraPickerView: UIViewControllerRepresentable {
    enum Result: Equatable {
        case image(UIImage)
        case video(URL)
        case cancelled
        case openLibrary
    }

    let onResult: (Result) -> Void
    var accumulatedCount: Int = 0

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .camera) ?? ["public.image"]
        picker.videoMaximumDuration = 60
        picker.videoQuality = .typeHigh
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.showsCameraControls = false
        picker.cameraDevice = .rear
        picker.cameraCaptureMode = .photo
        picker.cameraFlashMode = .off
        picker.modalPresentationStyle = .fullScreen
        picker.view.backgroundColor = .black

        let overlay = CameraControlsOverlayView()
        overlay.frame = UIScreen.main.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.onCapture = { picker.takePicture() }
        overlay.onFlip = { context.coordinator.flipCamera() }
        overlay.onFlashToggle = {
            switch picker.cameraFlashMode {
            case .off:  picker.cameraFlashMode = .auto
            case .auto: picker.cameraFlashMode = .on
            default:    picker.cameraFlashMode = .off
            }
            overlay.setFlashMode(picker.cameraFlashMode)
        }
        overlay.onLibrary = { context.coordinator.onResult(.openLibrary) }
        overlay.onCancel   = { context.coordinator.onResult(.cancelled) }
        overlay.setAccumulatedCount(accumulatedCount)
        overlay.setFlashMode(picker.cameraFlashMode)
        CameraPickerView.applyFillTransform(picker)

        picker.cameraOverlayView = overlay
        context.coordinator.picker = picker
        context.coordinator.overlay = overlay

        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {
        context.coordinator.overlay?.setAccumulatedCount(accumulatedCount)
    }

    static func applyFillTransform(_ picker: UIImagePickerController) {
        let screen = UIScreen.main.bounds
        let cameraAspect: CGFloat = 4.0 / 3.0
        let screenAspect = screen.height / screen.width
        if screenAspect > cameraAspect {
            let scale = screenAspect / cameraAspect
            picker.cameraViewTransform = CGAffineTransform(scaleX: scale, y: scale)
        } else {
            picker.cameraViewTransform = .identity
        }
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onResult: (Result) -> Void
        var overlay: CameraControlsOverlayView?
        weak var picker: UIImagePickerController?

        init(onResult: @escaping (Result) -> Void) {
            self.onResult = onResult
        }

        func flipCamera() {
            guard let picker else { return }
            let next: UIImagePickerController.CameraDevice = picker.cameraDevice == .rear ? .front : .rear
            guard UIImagePickerController.isCameraDeviceAvailable(next) else { return }
            let overlay = picker.cameraOverlayView
            // UIImagePickerController ignores cameraDevice changes while a custom
            // overlay is attached; detach, switch, then restore.
            picker.cameraOverlayView = nil
            picker.cameraDevice = next
            CameraPickerView.applyFillTransform(picker)
            picker.cameraOverlayView = overlay
            if let overlayView = overlay as? CameraControlsOverlayView {
                overlayView.setFlashMode(picker.cameraFlashMode)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            finish(picker, result: .cancelled)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let mediaType = info[.mediaType] as? String, mediaType == "public.movie",
               let url = info[.mediaURL] as? URL {
                finish(picker, result: .video(MediaCaptureHelpers.copyVideoToTemporaryDirectory(url)))
                return
            }
            if let image = info[.originalImage] as? UIImage {
                let normalized = PhotoEditorImageProcessor.normalizeOrientation(image)
                finish(picker, result: .image(normalized))
                return
            }
            finish(picker, result: .cancelled)
        }

        private func finish(_ picker: UIImagePickerController, result: Result) {
            // Never call picker.dismiss() here. When CameraPickerView is used as a
            // UIViewControllerRepresentable inside a fullScreenCover, the picker is a
            // CHILD view controller of the SwiftUI hosting VC. Calling dismiss() on it
            // propagates up the presentation chain and closes the entire fullScreenCover
            // (the compose / capture container), skipping the preview screen entirely.
            // SwiftUI manages the VC lifecycle — just deliver the result and let the
            // caller (MediaCaptureView) update its route state.
            onResult(result)
        }
    }
}

// MARK: - Custom camera overlay (UIKit)

final class CameraControlsOverlayView: UIView {
    var onCapture: (() -> Void)?
    var onFlip: (() -> Void)?
    var onFlashToggle: (() -> Void)?
    var onLibrary: (() -> Void)?
    var onCancel: (() -> Void)?

    private var cancelButton: UIButton!
    private var flashButton: UIButton!
    private var flipButton: UIButton!
    private var shutterButton: UIButton!
    private var albumButton: UIButton!
    private var badgeView: UIView!
    private var badgeLabel: UILabel!
    private var topGradientLayer = CAGradientLayer()
    private var bottomGradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public API

    func setAccumulatedCount(_ count: Int) {
        badgeView?.isHidden = count == 0
        badgeLabel?.text = "\(count)"
    }

    func setFlashMode(_ mode: UIImagePickerController.CameraFlashMode) {
        let imageName: String
        switch mode {
        case .auto: imageName = "bolt.badge.automatic"
        case .on:   imageName = "bolt.fill"
        default:    imageName = "bolt.slash.fill"
        }
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        flashButton?.setImage(UIImage(systemName: imageName, withConfiguration: config), for: .normal)
    }

    // MARK: - Touch pass-through

    /// Only intercept touches that land directly on interactive buttons.
    /// Everything else is passed through to the underlying camera view.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for subview in subviews.reversed() {
            guard subview.isUserInteractionEnabled, !subview.isHidden else { continue }
            let subviewPoint = subview.convert(point, from: self)
            if let hit = subview.hitTest(subviewPoint, with: event) {
                return hit
            }
        }
        return nil
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }
        layoutControls()
    }

    private func layoutControls() {
        let w = bounds.width
        let h = bounds.height
        // safeAreaInsets are properly propagated after the view is in the hierarchy.
        let safeTop    = max(safeAreaInsets.top, 20)
        let safeBottom = max(safeAreaInsets.bottom, 16)

        // Gradient heights
        let topBarH: CGFloat = safeTop + 64
        let bottomBarH: CGFloat = safeBottom + 90

        topGradientLayer.frame = CGRect(x: 0, y: 0, width: w, height: topBarH)
        bottomGradientLayer.frame = CGRect(x: 0, y: h - bottomBarH, width: w, height: bottomBarH)

        let btnSize: CGFloat = 44
        let topBtnY = safeTop + 10

        // Cancel — top-left
        cancelButton.frame = CGRect(x: 16, y: topBtnY, width: btnSize, height: btnSize)
        cancelButton.layer.cornerRadius = btnSize / 2

        // Flash — top-center
        flashButton.frame = CGRect(x: (w - btnSize) / 2, y: topBtnY, width: btnSize, height: btnSize)
        flashButton.layer.cornerRadius = btnSize / 2

        // Flip — top-right
        flipButton.frame = CGRect(x: w - 16 - btnSize, y: topBtnY, width: btnSize, height: btnSize)
        flipButton.layer.cornerRadius = btnSize / 2

        // Shutter — bottom-center
        let shutterSize: CGFloat = 72
        let shutterY = h - safeBottom - shutterSize - 20
        shutterButton.frame = CGRect(
            x: (w - shutterSize) / 2,
            y: shutterY,
            width: shutterSize,
            height: shutterSize
        )
        shutterButton.layer.cornerRadius = shutterSize / 2

        // Album — bottom-left, vertically centered with shutter
        let albumSize: CGFloat = 50
        let albumY = shutterButton.frame.midY - albumSize / 2
        albumButton.frame = CGRect(x: 28, y: albumY, width: albumSize, height: albumSize)
        albumButton.layer.cornerRadius = albumSize / 2

        // Badge on album button
        let badgeSize: CGFloat = 22
        badgeView.frame = CGRect(
            x: albumButton.frame.maxX - badgeSize / 2,
            y: albumButton.frame.minY - badgeSize / 2,
            width: badgeSize,
            height: badgeSize
        )
        badgeView.layer.cornerRadius = badgeSize / 2
        badgeLabel.frame = badgeView.bounds
    }

    // MARK: - Setup

    private func setup() {
        backgroundColor = .clear
        isOpaque = false

        // Gradient overlays (non-interactive, add as sublayers not subviews)
        topGradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.55).cgColor,
            UIColor.clear.cgColor
        ]
        topGradientLayer.locations = [0, 1]
        layer.addSublayer(topGradientLayer)

        bottomGradientLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.55).cgColor
        ]
        bottomGradientLayer.locations = [0, 1]
        layer.addSublayer(bottomGradientLayer)

        // Buttons
        cancelButton = makeCircleButton(systemImage: "xmark", size: 18, weight: .bold)
        cancelButton.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)

        flashButton = makeCircleButton(systemImage: "bolt.slash.fill", size: 20, weight: .medium)
        flashButton.addTarget(self, action: #selector(didTapFlash), for: .touchUpInside)

        flipButton = makeCircleButton(systemImage: "arrow.triangle.2.circlepath", size: 20, weight: .medium)
        flipButton.addTarget(self, action: #selector(didTapFlip), for: .touchUpInside)

        shutterButton = makeShutterButton()

        albumButton = makeCircleButton(systemImage: "photo.on.rectangle", size: 20, weight: .medium)
        albumButton.addTarget(self, action: #selector(didTapAlbum), for: .touchUpInside)

        // Badge
        badgeView = UIView()
        badgeView.backgroundColor = UIColor.systemOrange
        badgeView.isUserInteractionEnabled = false
        badgeView.isHidden = true

        badgeLabel = UILabel()
        badgeLabel.textColor = .white
        badgeLabel.font = .systemFont(ofSize: 12, weight: .bold)
        badgeLabel.textAlignment = .center
        badgeView.addSubview(badgeLabel)

        addSubview(cancelButton)
        addSubview(flashButton)
        addSubview(flipButton)
        addSubview(shutterButton)
        addSubview(albumButton)
        addSubview(badgeView)
    }

    private func makeCircleButton(systemImage: String, size: CGFloat, weight: UIImage.SymbolWeight) -> UIButton {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: weight)
        btn.setImage(UIImage(systemName: systemImage, withConfiguration: config), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        return btn
    }

    private func makeShutterButton() -> UIButton {
        let btn = UIButton(type: .custom)
        btn.backgroundColor = .white
        btn.addTarget(self, action: #selector(shutterDown), for: .touchDown)
        btn.addTarget(self, action: #selector(shutterUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        btn.addTarget(self, action: #selector(didTapShutter), for: .touchUpInside)

        // Inner ring
        let ring = UIView()
        ring.backgroundColor = .clear
        ring.layer.borderColor = UIColor.black.withAlphaComponent(0.15).cgColor
        ring.layer.borderWidth = 3
        ring.frame = CGRect(x: 6, y: 6, width: 60, height: 60)
        ring.layer.cornerRadius = 30
        ring.isUserInteractionEnabled = false
        btn.addSubview(ring)

        return btn
    }

    // MARK: - Actions

    @objc private func didTapCancel() { onCancel?() }
    @objc private func didTapFlash()  { onFlashToggle?() }
    @objc private func didTapFlip()   { onFlip?() }
    @objc private func didTapShutter() { onCapture?() }
    @objc private func didTapAlbum()  { onLibrary?() }

    @objc private func shutterDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.08) { sender.transform = CGAffineTransform(scaleX: 0.9, y: 0.9) }
    }

    @objc private func shutterUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.12, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 8) {
            sender.transform = .identity
        }
    }
}

// MARK: - Shared helpers

enum MediaCaptureHelpers {
    static func copyVideoToTemporaryDirectory(_ sourceURL: URL) -> URL {
        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)

        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: destination)
        }

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            return destination
        } catch {
            return sourceURL
        }
    }
}
