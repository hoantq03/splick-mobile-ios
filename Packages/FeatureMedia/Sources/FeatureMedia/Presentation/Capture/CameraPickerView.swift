import ARKit
import Localization
import SwiftUI
import UIKit

/// Custom camera UI backed by `AVCaptureSession` + Metal preview.
struct CameraPickerView: View {
    enum Result: Equatable {
        case image(UIImage, initialFilter: FilterPreset = .none)
        case video(URL)
        case cancelled
        case openLibrary
        case openTextCreation
        case openLayoutCapture
    }

    let onResult: (Result) -> Void
    var accumulatedCount: Int = 0
    var filterCatalogRepository: FilterCatalogRepositoryProtocol?

    @EnvironmentObject private var languageService: LanguageService
    @StateObject private var session = AVCameraSessionModel()
    @StateObject private var arHandle = ARCaptureHandle()
    @State private var arEffect: ARFaceEffect = .glasses
    @State private var isCapturing = false
    @State private var publishMode: CameraPublishMode = .post
    @State private var catalogItems: [FilterCatalogItem] = []
    @State private var toastMessage: String?
    @State private var handsFreeSeconds = 0

    private var faceTrackingSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            previewLayer
                .ignoresSafeArea()
                .gesture(
                    MagnificationGesture()
                        .onChanged { session.updatePinch(magnification: $0) }
                        .onEnded { _ in session.endPinch() }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { session.updatePan(translationX: $0.translation.width, translationY: $0.translation.height) }
                        .onEnded { _ in session.endPan() }
                )
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded { session.cycleZoomStep() }
                )

            VStack(spacing: 0) {
                topBar
                Spacer()
                CameraZoomBadge(
                    zoom: session.zoomFactor,
                    onToggle: { session.cycleZoomStep() }
                )
                .padding(.bottom, 12)
                HStack(alignment: .bottom, spacing: 0) {
                    CameraLeftToolbar(
                        onTextMode: { onResult(.openTextCreation) },
                        onBoomerang: { showComingSoon() },
                        onLayout: { onResult(.openLayoutCapture) },
                        onHandsFree: cycleHandsFree
                    )
                    .padding(.bottom, 24)

                    Spacer()

                    VStack(spacing: 12) {
                        CameraModeStrip(
                            selected: publishMode,
                            onSelect: { publishMode = $0 },
                            onComingSoon: showComingSoon
                        )
                        bottomBar
                    }

                    Spacer(minLength: 56)
                }
            }

            if handsFreeSeconds > 0 {
                Text(String(format: languageService.text(.mediaCameraTimerSeconds), handsFreeSeconds))
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
            }

            if let toastMessage {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.75)))
                        .padding(.bottom, 140)
                }
            }
        }
        .onAppear {
            session.start()
            Task { await loadFilterCatalog() }
        }
        .onDisappear { session.stop() }
        .onChange(of: session.filterPreset) { preset in
            if preset == .ar && faceTrackingSupported {
                session.stop()
            } else if !session.isRunning {
                session.start()
            }
        }
        .task(id: handsFreeSeconds) {
            guard handsFreeSeconds > 0 else { return }
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run {
                guard handsFreeSeconds > 0 else { return }
                if handsFreeSeconds == 1 {
                    handsFreeSeconds = 0
                    capture()
                } else {
                    handsFreeSeconds -= 1
                }
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
        HStack(alignment: .bottom, spacing: 16) {
            ZStack(alignment: .topTrailing) {
                circleButton(
                    systemName: "photo.on.rectangle",
                    size: CameraBottomBarMetrics.galleryDiameter
                ) { onResult(.openLibrary) }
                .padding(.bottom, shutterVerticalInset(for: CameraBottomBarMetrics.galleryDiameter))
                if accumulatedCount > 0 {
                    Text("\(accumulatedCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.orange))
                        .offset(x: 8, y: -8)
                }
            }

            VStack(spacing: 10) {
                CameraFilterNameBadge(title: activeFilterTitle)
                    .animation(.easeInOut(duration: 0.18), value: session.filterPreset)

                Button(action: capture) {
                    Circle()
                        .fill(Color.white)
                        .frame(
                            width: CameraBottomBarMetrics.shutterDiameter,
                            height: CameraBottomBarMetrics.shutterDiameter
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.15), lineWidth: 3)
                                .padding(6)
                        )
                        .scaleEffect(isCapturing ? 0.9 : 1)
                }
                .disabled(isCapturing)
            }

            FilterCarouselBar(
                preset: $session.filterPreset,
                catalogItems: catalogItems
            )

            circleButton(systemName: "arrow.triangle.2.circlepath") { session.flipCamera() }
                .padding(.bottom, shutterVerticalInset(for: CameraBottomBarMetrics.sideControlDiameter))
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 20)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
        )
    }

    private var activeFilterTitle: String {
        if let catalogMatch = catalogItems.first(where: {
            $0.slug.replacingOccurrences(of: "-", with: "") == session.filterPreset.rawValue
                || $0.slug == session.filterPreset.rawValue
        }) {
            return catalogMatch.name
        }
        return languageService.text(session.filterPreset.titleKey)
    }

    private func shutterVerticalInset(for controlDiameter: CGFloat) -> CGFloat {
        max((CameraBottomBarMetrics.shutterDiameter - controlDiameter) / 2, 0)
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

    private func showComingSoon() {
        toastMessage = languageService.text(.mediaEditorComingSoon)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            toastMessage = nil
        }
    }

    private func cycleHandsFree() {
        switch handsFreeSeconds {
        case 0: handsFreeSeconds = 3
        case 3: handsFreeSeconds = 10
        default: handsFreeSeconds = 0
        }
    }

    private func loadFilterCatalog() async {
        guard let filterCatalogRepository else { return }
        do {
            let items = try await filterCatalogRepository.listFilters()
            await MainActor.run { catalogItems = items }
        } catch {
            // Fall back to bundled presets only.
        }
    }

    private func capture() {
        isCapturing = true
        if session.filterPreset == .ar, faceTrackingSupported, let snapshot = arHandle.snapshot() {
            isCapturing = false
            let screen = UIScreen.main.bounds
            let framed = PhotoEditorImageProcessor.cropToAspectFill(
                PhotoEditorImageProcessor.normalizeOrientation(snapshot),
                aspectRatio: screen.width / max(screen.height, 1)
            )
            onResult(.image(framed, initialFilter: .none))
            return
        }
        Task {
            do {
                let image = try await session.capturePhoto()
                var output = PhotoEditorImageProcessor.normalizeOrientation(image)
                var initialFilter = FilterPreset(session.filterPreset)
                if session.filterPreset == .ar, let bounds = session.primaryFaceBounds {
                    output = VisionFaceOverlayCompositor.composite(image: output, effect: arEffect, faceRect: bounds)
                    initialFilter = .none
                } else if session.filterPreset == .beauty, let ci = CIImage(image: output) {
                    let filtered = session.filterEngine.apply(
                        ci,
                        preset: .beauty,
                        intensity: session.filterIntensity
                    )
                    output = session.filterEngine.renderUIImage(from: filtered) ?? output
                    initialFilter = .none
                }
                let screen = UIScreen.main.bounds
                output = PhotoEditorImageProcessor.cropToAspectFill(
                    output,
                    aspectRatio: screen.width / max(screen.height, 1)
                )
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
