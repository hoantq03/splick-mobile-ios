import ARKit
import SwiftUI
import UIKit

/// Custom camera UI backed by `AVCaptureSession` + Metal preview.
/// Public `Result` API matches the previous `UIImagePickerController` wrapper.
struct CameraPickerView: View {
    enum Result: Equatable {
        case image(UIImage, initialFilter: FilterPreset = .none)
        case video(URL)
        case cancelled
        case openLibrary
    }

    let onResult: (Result) -> Void
    var accumulatedCount: Int = 0

    @StateObject private var session = AVCameraSessionModel()
    @StateObject private var arHandle = ARCaptureHandle()
    @State private var arEffect: ARFaceEffect = .glasses
    @State private var isCapturing = false

    private var faceTrackingSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            previewLayer
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                FilterStripView(
                    preset: $session.filterPreset,
                    intensity: $session.filterIntensity,
                    arEffect: $arEffect,
                    faceTrackingSupported: faceTrackingSupported
                )
                .padding(.bottom, 8)
                bottomBar
            }
        }
        .onAppear { session.start() }
        .onDisappear { session.stop() }
        .onChange(of: session.filterPreset) { preset in
            if preset == .ar && faceTrackingSupported {
                session.stop()
            } else if !session.isRunning {
                session.start()
            }
        }
    }

    @ViewBuilder
    private var previewLayer: some View {
        if session.filterPreset == .ar, faceTrackingSupported {
            ARCameraView(effect: $arEffect, captureHandle: arHandle)
        } else {
            ZStack {
                MetalCameraPreviewView(image: session.previewImage)
                if session.filterPreset == .ar {
                    VisionFaceOverlayView(effect: arEffect, faceRect: session.primaryFaceBounds)
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            circleButton(systemName: "xmark") { onResult(.cancelled) }
            Spacer()
            circleButton(systemName: flashSymbol) { session.cycleFlash() }
            Spacer()
            circleButton(systemName: "arrow.triangle.2.circlepath") { session.flipCamera() }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .background(
            LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 96)
                .ignoresSafeArea(edges: .top),
            alignment: .top
        )
    }

    private var bottomBar: some View {
        HStack {
            ZStack(alignment: .topTrailing) {
                circleButton(systemName: "photo.on.rectangle", size: 50) { onResult(.openLibrary) }
                if accumulatedCount > 0 {
                    Text("\(accumulatedCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.orange))
                        .offset(x: 8, y: -8)
                }
            }
            Spacer()
            Button(action: capture) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 3).padding(6))
                    .scaleEffect(isCapturing ? 0.9 : 1)
            }
            .disabled(isCapturing)
            Spacer()
            Color.clear.frame(width: 50, height: 50)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 20)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
        )
    }

    private var flashSymbol: String {
        switch session.flashMode {
        case .auto: return "bolt.badge.automatic"
        case .on: return "bolt.fill"
        case .off: return "bolt.slash.fill"
        }
    }

    private func circleButton(systemName: String, size: CGFloat = 44, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(Color.black.opacity(0.3)))
        }
    }

    private func capture() {
        isCapturing = true
        if session.filterPreset == .ar, faceTrackingSupported, let snapshot = arHandle.snapshot() {
            isCapturing = false
            onResult(.image(PhotoEditorImageProcessor.normalizeOrientation(snapshot), initialFilter: .none))
            return
        }
        Task {
            do {
                let image = try await session.capturePhoto()
                var output = image
                var initialFilter = FilterPreset(session.filterPreset)
                if session.filterPreset == .ar, let bounds = session.primaryFaceBounds {
                    output = VisionFaceOverlayCompositor.composite(image: image, effect: arEffect, faceRect: bounds)
                    initialFilter = .none
                } else if session.filterPreset == .beauty, let ci = CIImage(image: image) {
                    let filtered = session.filterEngine.apply(
                        ci,
                        preset: .beauty,
                        intensity: session.filterIntensity
                    )
                    output = session.filterEngine.renderUIImage(from: filtered) ?? image
                    initialFilter = .none
                }
                await MainActor.run {
                    isCapturing = false
                    onResult(.image(output, initialFilter: initialFilter))
                }
            } catch {
                await MainActor.run { isCapturing = false }
            }
        }
    }
}

enum VisionFaceOverlayCompositor {
    static func composite(image: UIImage, effect: ARFaceEffect, faceRect: CGRect) -> UIImage {
        let size = image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            image.draw(in: CGRect(origin: .zero, size: size))
            let frame = CGRect(
                x: faceRect.minX * size.width,
                y: (1 - faceRect.maxY) * size.height,
                width: faceRect.width * size.width,
                height: faceRect.height * size.height
            )
            switch effect {
            case .glasses:
                UIColor.black.withAlphaComponent(0.45).setFill()
                let lensW = frame.width * 0.32
                let lensH = frame.height * 0.18
                let y = frame.minY + frame.height * 0.33
                UIBezierPath(roundedRect: CGRect(x: frame.minX + frame.width * 0.12, y: y, width: lensW, height: lensH), cornerRadius: lensH / 2).fill()
                UIBezierPath(roundedRect: CGRect(x: frame.maxX - frame.width * 0.12 - lensW, y: y, width: lensW, height: lensH), cornerRadius: lensH / 2).fill()
            case .sparkle:
                UIColor.systemYellow.setFill()
                for offset in [0.25, 0.5, 0.75] {
                    UIBezierPath(ovalIn: CGRect(x: frame.minX + frame.width * offset - 6, y: frame.minY + 4, width: 12, height: 12)).fill()
                }
            }
        }
    }
}

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
