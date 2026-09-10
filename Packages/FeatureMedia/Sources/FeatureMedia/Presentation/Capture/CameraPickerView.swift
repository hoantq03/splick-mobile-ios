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
        case cancelled
        case openLibrary
        case openTextCreation
    }

    let onResult: (Result) -> Void
    var accumulatedCount: Int = 0
    var filterCatalogRepository: FilterCatalogRepositoryProtocol?

    @EnvironmentObject private var languageService: LanguageService
    @StateObject private var session = AVCameraSessionModel()
    @StateObject private var arHandle = ARCaptureHandle()
    @State private var arEffect: ARFaceEffect = .glasses
    @State private var isCapturing = false
    @State private var catalogItems: [FilterCatalogItem] = []
    @State private var toastMessage: String?
    @State private var timerModeSeconds = 0
    @State private var countdownRemaining = 0
    @State private var boomerangMode = false
    @State private var boomerangProgress: CGFloat = 0
    @State private var shutterPressActive = false
    @State private var shortVideoHoldStarted = false

    private var faceTrackingSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }

    private var finderShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous)
    }

    var body: some View {
        GeometryReader { geo in
            let metrics = CameraChromeLayout.metrics(
                in: geo.size,
                safeArea: CameraChromeLayout.windowSafeAreaInsets()
            )
            ZStack {
                SplickTheme.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                        .padding(.top, metrics.topPadding)

                    finder(metrics: metrics)

                    bottomBar(metrics: metrics)
                }

                if countdownRemaining > 0 {
                    Text(String(format: languageService.text(.mediaCameraTimerSeconds), countdownRemaining))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                }

                if isCapturing, !session.isRecordingBoomerang {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.2)
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

    private func finder(metrics: CameraChromeMetrics) -> some View {
        GeometryReader { geo in
            let lift = metrics.previewLift
            let zoomReserve: CGFloat = 44
            let maxWidth = geo.size.width - (metrics.previewInset * 2)
            let maxHeight = max(geo.size.height - lift - zoomReserve, 1)
            let frameWidth = min(maxWidth, maxHeight * CameraChromeLayout.previewAspect)
            let frameHeight = frameWidth / CameraChromeLayout.previewAspect
            ZStack {
                previewLayer
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .offset(y: -lift)

                if !(session.filterPreset == .ar && faceTrackingSupported) {
                    CameraNativeZoomChrome(
                        displayZoom: session.zoomFactor,
                        onTap: { session.cycleZoomStep() }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 4)
                }
            }
            .clipped()
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

    private func bottomBar(metrics: CameraChromeMetrics) -> some View {
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

                Spacer(minLength: 0)

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
                    }
                }

                Spacer(minLength: 0)

                circleButton(systemName: "arrow.triangle.2.circlepath") { session.flipCamera() }
                    .padding(.bottom, shutterVerticalInset(metrics.shutterDiameter, metrics.sideControlDiameter))
            }
            .padding(.horizontal, metrics.shutterRowHorizontalPadding)
        }
        .padding(.bottom, metrics.bottomPadding)
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
        let diameter = CameraBottomBarMetrics.shutterDiameter
        let recording = session.isRecordingBoomerang
        let visual = ZStack {
            Circle()
                .fill(boomerangMode ? SplickTheme.Colors.primary : (recording ? Color.red : Color.white))
                .frame(width: diameter, height: diameter)
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.15), lineWidth: 3)
                        .padding(6)
                )
            if recording {
                Circle()
                    .trim(from: 0, to: boomerangProgress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: diameter, height: diameter)
            }
        }
        .scaleEffect((isCapturing || recording) ? 0.9 : 1)

        return visual
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in shutterPressBegan() }
                    .onEnded { _ in shutterPressEnded() }
            )
            .disabled((isCapturing && !recording) || countdownRemaining > 0)
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
        Task {
            do {
                let frames = try await session.captureBoomerang()
                let url = try await BoomerangClipComposer.writeLoopingClip(images: frames)
                await MainActor.run {
                    isCapturing = false
                    onResult(.video(url))
                }
            } catch {
                await MainActor.run {
                    isCapturing = false
                    toastMessage = languageService.text(.mediaCameraBoomerangFailed)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        toastMessage = nil
                    }
                }
            }
        }
    }

    private func captureShortVideo() {
        guard !isCapturing else { return }
        isCapturing = true
        Task {
            do {
                let frames = try await session.captureBoomerang()
                let url = try await BoomerangClipComposer.writeForwardClip(images: frames)
                await MainActor.run {
                    isCapturing = false
                    onResult(.video(url))
                }
            } catch {
                await MainActor.run {
                    isCapturing = false
                    toastMessage = languageService.text(.mediaLoadFailed)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        toastMessage = nil
                    }
                }
            }
        }
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
        let startedVideo = shortVideoHoldStarted || session.isRecordingBoomerang
        shutterPressActive = false
        shortVideoHoldStarted = false
        if startedVideo {
            session.stopBoomerangCapture()
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
