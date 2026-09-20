import ARKit
import DesignSystem
import Localization
import SwiftUI
import UIKit

/// Custom camera UI backed by `AVCaptureSession` + Metal preview.
struct CameraPickerView: View {
    enum Result: Equatable {
        case image(UIImage, initialFilter: FilterPreset = .none)
        case video(URL)
        case pendingVideo(PendingCapturedVideo)
        case cancelled
        case openLibrary
        case openTextCreation

        static func == (lhs: Result, rhs: Result) -> Bool {
            switch (lhs, rhs) {
            case (.image(let a, let af), .image(let b, let bf)):
                return a === b && af == bf
            case (.video(let a), .video(let b)):
                return a == b
            case (.pendingVideo(let a), .pendingVideo(let b)):
                return a.id == b.id
            case (.cancelled, .cancelled),
                 (.openLibrary, .openLibrary),
                 (.openTextCreation, .openTextCreation):
                return true
            default:
                return false
            }
        }
    }

    let onResult: (Result) -> Void
    var accumulatedCount: Int = 0
    var filterCatalogRepository: FilterCatalogRepositoryProtocol?

    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var cameraRevealProgress: CameraOpenRevealProgressSource
    @StateObject private var session = AVCameraSessionModel()
    @StateObject private var arHandle = ARCaptureHandle()
    @State private var arEffect: ARFaceEffect = .glasses
    @State private var isCapturing = false
    @State private var catalogItems: [FilterCatalogItem] = []
    @State private var toastMessage: String?
    @State private var timerModeSeconds = 0
    @State private var countdownRemaining = 0
    @State private var activePendingVideo: PendingCapturedVideo?
    @State private var didHandOffPendingVideo = false
    @State private var boomerangMode = false
    @State private var boomerangProgress: CGFloat = 0
    @State private var shutterPressActive = false
    @State private var shortVideoHoldStarted = false
    @State private var holdZoomTracking = false
    @State private var holdZoomBase: CGFloat = 1
    @State private var holdZoomStartTranslationY: CGFloat = 0

    private var revealProgress: CGFloat { cameraRevealProgress.value }

    /// Top/bottom chrome appears once the disk has left the shutter (no fade — avoids
    /// reading as “fog → solid” instead of a growing circle).
    private var chromeRevealOpacity: Double {
        revealProgress > 0.08 ? 1 : 0
    }

    /// Finder appears with the expanding disk — full opacity inside the circle.
    private var finderRevealOpacity: Double {
        revealProgress > 0.02 ? 1 : 0
    }

    private var faceTrackingSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }

    var body: some View {
        GeometryReader { geo in
            let metrics = CameraChromeLayout.metrics(
                in: geo.size,
                safeArea: CameraChromeLayout.windowSafeAreaInsets()
            )
            ZStack {
                // Water-masked chrome (atmosphere + finder + tools) lives under the shutter.
                SplickBrandAtmosphere()

                VStack(spacing: 0) {
                    topBar
                        .padding(.top, metrics.topPadding)
                        .opacity(chromeRevealOpacity)

                    finder(metrics: metrics, canvas: geo.size)
                        .opacity(finderRevealOpacity)

                    bottomBar(metrics: metrics, includeShutter: false)
                }

                // Capture button on a higher layer so it stays crisp above the soft water rim.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    shutterLayer(metrics: metrics)
                }
                .zIndex(20)

                if countdownRemaining > 0 {
                    Text(String(format: languageService.text(.mediaCameraTimerSeconds), countdownRemaining))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(chromeRevealOpacity)
                        .zIndex(30)
                }

                if isCapturing, !session.isRecordingBoomerang {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    SplickSpinner(size: .large, usesBrandColors: false)
                        .zIndex(40)
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
                    .zIndex(50)
                }
            }
            .coordinateSpace(name: "cameraCanvas")
        }
        .onAppear {
            // Let the water expand on black chrome before spinning up AVCapture —
            // starting the session on the same frame as mount is a major hitch.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(140))
                session.start()
            }
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
        .task(id: session.isRecordingBoomerang) {
            guard session.isRecordingBoomerang else {
                boomerangProgress = 0
                return
            }
            let started = Date()
            while session.isRecordingBoomerang {
                boomerangProgress = min(
                    Date().timeIntervalSince(started) / BoomerangTimeline.captureDuration,
                    1
                )
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
        .task(id: countdownRemaining) {
            guard countdownRemaining > 0 else { return }
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run {
                guard countdownRemaining > 0 else { return }
                if countdownRemaining == 1 {
                    countdownRemaining = 0
                    performCapture()
                } else {
                    countdownRemaining -= 1
                }
            }
        }
    }

    private func finder(metrics: CameraChromeMetrics, canvas: CGSize) -> some View {
        GeometryReader { geo in
            let lift = metrics.previewLift
            let zoomReserve: CGFloat = 44
            let maxWidth = geo.size.width - (metrics.previewInset * 2)
            let maxHeight = max(geo.size.height - lift - zoomReserve, 1)
            let frameWidth = min(maxWidth, maxHeight * CameraChromeLayout.previewAspect)
            let frameHeight = frameWidth / CameraChromeLayout.previewAspect
            let finderShape = RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous)
            let slot = geo.frame(in: .named("cameraCanvas"))
            let waterOrigin = CameraOpenRevealGeometry.origin(
                in: canvas,
                cameraSize: SplickTabBarMetrics.cameraSize,
                bottomInset: metrics.bottomPadding
            )
            let showZoom = !(session.filterPreset == .ar && faceTrackingSupported)
            let stackHeight = frameHeight + (showZoom ? zoomReserve : 0)
            let originInFinder = CGPoint(
                x: waterOrigin.x - slot.minX - (geo.size.width - frameWidth) / 2,
                y: waterOrigin.y - slot.minY - (geo.size.height - stackHeight) / 2 + lift
            )
            VStack(spacing: 10) {
                previewLayer(
                    cornerRadius: SplickTheme.CornerRadius.card,
                    waterOriginInView: originInFinder,
                    waterRadius: .greatestFiniteMagnitude,
                    waterFeather: 0
                )
                .frame(width: frameWidth, height: frameHeight)
                .clipShape(finderShape)
                .compositingGroup()
                .overlay {
                    ZStack {
                        finderShape.strokeBorder(SplickTheme.Colors.divider, lineWidth: 0.5)
                        if let indicator = session.focusIndicator {
                            CameraFocusReticle(indicator: indicator)
                        }
                    }
                }
                .contentShape(finderShape)
                .highPriorityGesture(
                    SpatialTapGesture()
                        .onEnded { event in
                            guard !(session.filterPreset == .ar && faceTrackingSupported) else { return }
                            session.focus(
                                at: event.location,
                                viewSize: CGSize(width: frameWidth, height: frameHeight)
                            )
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { session.updatePinch(magnification: $0) }
                        .onEnded { _ in session.endPinch() }
                )

                if showZoom {
                    CameraNativeZoomChrome(
                        displayZoom: session.zoomFactor,
                        onTap: { session.cycleZoomStep() }
                    )
                    .frame(height: 34)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .offset(y: -lift)
        }
    }

    @ViewBuilder
    private func previewLayer(
        cornerRadius: CGFloat,
        waterOriginInView: CGPoint,
        waterRadius: CGFloat,
        waterFeather: CGFloat
    ) -> some View {
        if session.filterPreset == .ar, faceTrackingSupported {
            ARCameraView(
                effect: $arEffect,
                captureHandle: arHandle,
                waterOriginInView: waterOriginInView,
                waterRadius: waterRadius,
                waterFeather: waterFeather,
                waterActive: false
            )
        } else {
            ZStack {
                MetalCameraPreviewView(
                    image: session.previewImage,
                    cornerRadius: cornerRadius,
                    waterOriginInView: waterOriginInView,
                    waterRadius: waterRadius,
                    waterFeather: waterFeather,
                    waterActive: false
                )
                if session.filterPreset == .ar {
                    VisionFaceOverlayView(
                        effect: arEffect,
                        faceRect: session.primaryFaceBounds,
                        mirrored: session.isFrontCamera
                    )
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
        .padding(.bottom, 6)
    }

    private func bottomBar(metrics: CameraChromeMetrics, includeShutter: Bool = true) -> some View {
        VStack(spacing: metrics.toolsToShutterSpacing) {
            CameraCaptureToolsRow(
                metrics: metrics,
                boomerangSelected: boomerangMode,
                timerSelected: timerModeSeconds > 0,
                timerSeconds: timerModeSeconds,
                onTextMode: { onResult(.openTextCreation) },
                onBoomerang: toggleBoomerang,
                onHandsFree: cycleHandsFree,
                onFilter: cycleFilter
            )
            .opacity(chromeRevealOpacity)

            HStack(alignment: .bottom, spacing: 16) {
                ZStack(alignment: .topTrailing) {
                    circleButton(
                        systemName: "photo.on.rectangle",
                        size: metrics.galleryDiameter
                    ) { onResult(.openLibrary) }
                    .padding(.bottom, shutterVerticalInset(metrics.shutterDiameter, metrics.galleryDiameter))
                    if accumulatedCount > 0 {
                        Text("\(accumulatedCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.orange))
                            .offset(x: 8, y: -8)
                    }
                }
                .opacity(chromeRevealOpacity)

                Spacer(minLength: 0)

                if includeShutter {
                    shutterCluster(metrics: metrics)
                } else {
                    Color.clear
                        .frame(width: metrics.shutterDiameter, height: metrics.shutterDiameter)
                }

                Spacer(minLength: 0)

                circleButton(systemName: "arrow.triangle.2.circlepath") { session.flipCamera() }
                    .padding(.bottom, shutterVerticalInset(metrics.shutterDiameter, metrics.sideControlDiameter))
                    .opacity(chromeRevealOpacity)
            }
            .padding(.horizontal, metrics.shutterRowHorizontalPadding)
        }
        .padding(.bottom, metrics.bottomPadding)
        .offset(y: -CameraOpenRevealGeometry.shutterRowLift(progress: revealProgress))
    }

    /// Floating shutter row — drawn above the water-masked chrome.
    private func shutterLayer(metrics: CameraChromeMetrics) -> some View {
        HStack(alignment: .bottom, spacing: 16) {
            Color.clear
                .frame(width: metrics.galleryDiameter, height: metrics.galleryDiameter)
            Spacer(minLength: 0)
            shutterCluster(metrics: metrics)
                // Tab-bar shutter owns the visible lift/scale; take over only at the end.
                .opacity(Double(min(max((revealProgress - 0.9) / 0.08, 0), 1)))
            Spacer(minLength: 0)
            Color.clear
                .frame(width: metrics.sideControlDiameter, height: metrics.sideControlDiameter)
        }
        .padding(.horizontal, metrics.shutterRowHorizontalPadding)
        .padding(.bottom, metrics.bottomPadding)
        .offset(y: -CameraOpenRevealGeometry.shutterRowLift(progress: revealProgress))
        .allowsHitTesting(revealProgress > 0.92)
    }

    private func shutterCluster(metrics: CameraChromeMetrics) -> some View {
        ZStack(alignment: .top) {
            shutterButton
                .accessibilityLabel(
                    boomerangMode
                        ? languageService.text(.mediaCameraToolBoomerang)
                        : languageService.text(.mediaTypePhoto)
                )

            if session.filterPreset != .none {
                CameraFilterNameBadge(title: activeFilterTitle)
                    .offset(y: -28)
                    .allowsHitTesting(false)
                    .opacity(chromeRevealOpacity)
            }
        }
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

    private func shutterVerticalInset(_ shutterDiameter: CGFloat, _ controlDiameter: CGFloat) -> CGFloat {
        max((shutterDiameter - controlDiameter) / 2, 0)
    }

    private var shutterButton: some View {
        let diameter = SplickTabBarMetrics.cameraSize
        let recording = session.isRecordingBoomerang
        let visual = ZStack {
            SplickCameraCaptureButton(size: diameter)
            if recording {
                Circle()
                    .trim(from: 0, to: boomerangProgress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90), anchor: .center)
                    .frame(width: diameter, height: diameter)
            }
        }
        .scaleEffect(
            ((isCapturing || recording) ? 0.9 : 1) *
                CameraOpenRevealGeometry.shutterOpenScale(progress: revealProgress)
        )

        return visual
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        shutterPressBegan()
                        applyHoldDragZoomIfRecording(translationY: value.translation.height)
                    }
                    .onEnded { _ in
                        holdZoomTracking = false
                        shutterPressEnded()
                    }
            )
            .disabled((isCapturing && !recording) || countdownRemaining > 0)
    }

    /// While hold-to-record is active, vertical drag zooms the lens (up = in, down = out).
    private func applyHoldDragZoomIfRecording(translationY: CGFloat) {
        guard session.isRecordingBoomerang else { return }
        if !holdZoomTracking {
            holdZoomTracking = true
            holdZoomBase = session.zoomFactor
            holdZoomStartTranslationY = translationY
        }
        let deltaY = translationY - holdZoomStartTranslationY
        session.setDisplayZoom(
            CameraZoom.applyVerticalDrag(
                base: holdZoomBase,
                deltaY: deltaY,
                travelPx: CameraZoom.holdDragTravelPx,
                hardware: session.zoomHardware
            ),
            animated: false
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
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .frame(width: size, height: size)
                .background(Circle().fill(SplickTheme.Colors.textPrimary.opacity(0.12)))
        }
    }

    private func toggleBoomerang() {
        guard !isCapturing else { return }
        boomerangMode.toggle()
        if boomerangMode, session.filterPreset == .ar {
            session.filterPreset = .none
            if !session.isRunning { session.start() }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func cycleHandsFree() {
        countdownRemaining = 0
        switch timerModeSeconds {
        case 0: timerModeSeconds = 5
        case 5: timerModeSeconds = 10
        case 10: timerModeSeconds = 15
        case 15: timerModeSeconds = 30
        default: timerModeSeconds = 0
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func cycleFilter() {
        let presets = CameraFilterPreset.allCases.filter { $0 != .ar }
        guard let index = presets.firstIndex(of: session.filterPreset) else {
            session.filterPreset = presets.first ?? .none
            return
        }
        withAnimation(.easeInOut(duration: 0.18)) {
            session.filterPreset = presets[(index + 1) % presets.count]
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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

    private func captureBoomerang() {
        guard !isCapturing else { return }
        isCapturing = true
        didHandOffPendingVideo = false
        let pending = PendingCapturedVideo(pingPong: true, previewImage: nil)
        activePendingVideo = pending
        Task {
            do {
                let frames = try await session.captureBoomerang()
                pending.deliverFrames(frames)
                await MainActor.run {
                    finishPendingVideoCapture(pending: pending, failed: false)
                }
            } catch {
                pending.fail(mapBoomerangFailure(error))
                await MainActor.run {
                    finishPendingVideoCapture(pending: pending, failed: true)
                    if !didHandOffPendingVideo {
                        toastMessage = languageService.text(.mediaCameraBoomerangFailed)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            toastMessage = nil
                        }
                    }
                }
            }
        }
    }

    private func captureShortVideo() {
        guard !isCapturing else { return }
        isCapturing = true
        didHandOffPendingVideo = false
        let pending = PendingCapturedVideo(pingPong: false, previewImage: nil)
        activePendingVideo = pending
        Task {
            do {
                let frames = try await session.captureBoomerang()
                pending.deliverFrames(frames)
                await MainActor.run {
                    finishPendingVideoCapture(pending: pending, failed: false)
                }
            } catch {
                pending.fail(mapBoomerangFailure(error))
                await MainActor.run {
                    finishPendingVideoCapture(pending: pending, failed: true)
                    if !didHandOffPendingVideo {
                        toastMessage = languageService.text(.mediaLoadFailed)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            toastMessage = nil
                        }
                    }
                }
            }
        }
    }

    /// Opens compose immediately on finger-up; frames keep flushing in the background.
    private func handOffPendingVideoIfNeeded() {
        guard let pending = activePendingVideo, !didHandOffPendingVideo else { return }
        didHandOffPendingVideo = true
        activePendingVideo = nil
        isCapturing = false
        onResult(.pendingVideo(pending))
    }

    private func finishPendingVideoCapture(pending: PendingCapturedVideo, failed: Bool) {
        if activePendingVideo?.id == pending.id {
            activePendingVideo = nil
        }
        isCapturing = false
        // Max-duration finish without finger-up — still hand off (or drop on failure).
        if !didHandOffPendingVideo {
            if failed { return }
            didHandOffPendingVideo = true
            onResult(.pendingVideo(pending))
        }
    }

    private func mapBoomerangFailure(_ error: Error) -> PendingCapturedVideo.Failure {
        if let cameraError = error as? CameraSessionError {
            switch cameraError {
            case .boomerangTooShort: return .tooShort
            case .busy, .captureFailed: return .captureFailed
            }
        }
        return .captureFailed
    }

    private func shutterPressBegan() {
        guard countdownRemaining == 0 else { return }
        if boomerangMode {
            beginBoomerangHold()
            return
        }
        guard !shutterPressActive else { return }
        shutterPressActive = true
        shortVideoHoldStarted = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            guard shutterPressActive, !boomerangMode, !isCapturing else { return }
            shortVideoHoldStarted = true
            captureShortVideo()
        }
    }

    private func shutterPressEnded() {
        if boomerangMode {
            endBoomerangHold()
            return
        }
        let startedVideo = shortVideoHoldStarted || session.isRecordingBoomerang || activePendingVideo != nil
        shutterPressActive = false
        shortVideoHoldStarted = false
        if startedVideo {
            session.stopBoomerangCapture()
            handOffPendingVideoIfNeeded()
        } else if !isCapturing {
            shutterTapped()
        }
    }

    private func beginBoomerangHold() {
        guard boomerangMode, !isCapturing, countdownRemaining == 0 else { return }
        captureBoomerang()
    }

    private func endBoomerangHold() {
        session.stopBoomerangCapture()
        handOffPendingVideoIfNeeded()
    }

    private func shutterTapped() {
        guard !boomerangMode else { return }
        guard !isCapturing, countdownRemaining == 0 else { return }
        if timerModeSeconds > 0 {
            countdownRemaining = timerModeSeconds
            return
        }
        performCapture()
    }

    private func performCapture() {
        if boomerangMode {
            return
        }
        isCapturing = true
        let fromFront = session.isFrontCamera
        if session.filterPreset == .ar, faceTrackingSupported, let snapshot = arHandle.snapshot() {
            isCapturing = false
            let framed = PhotoEditorImageProcessor.cropToAspectFill(
                PhotoEditorImageProcessor.normalizeOrientation(snapshot),
                aspectRatio: CameraChromeLayout.previewAspect
            )
            onResult(.image(
                PhotoEditorImageProcessor.matchSelfieFinder(framed, isFrontCamera: true),
                initialFilter: .none
            ))
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
                output = PhotoEditorImageProcessor.cropToAspectFill(
                    output,
                    aspectRatio: CameraChromeLayout.previewAspect
                )
                output = PhotoEditorImageProcessor.matchSelfieFinder(output, isFrontCamera: fromFront)
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
