import DesignSystem
import Localization
import Networking
import SwiftUI
import UIKit

enum EditorLayout {
    static let topBarHeight: CGFloat = 56
    static let bottomBarHeight: CGFloat = 92
    static let drawOptionsHeight: CGFloat = 56
    static let stickerOptionsHeight: CGFloat = 280

    /// Fixed insets keep the image frame stable while chrome fades in/out.
    static func canvasTopInset() -> CGFloat { topBarHeight }

    static func canvasBottomInset() -> CGFloat { bottomBarHeight }
}

struct PhotoEditorView: View {
    @EnvironmentObject private var languageService: LanguageService
    @StateObject private var viewModel: PhotoEditorViewModel
    @State private var layoutMetrics = ImageDisplayMetrics(imageSize: .zero, displayFrame: .zero)
    @State private var activeComposerTool: ComposerTool?
    @State private var showStickerPicker = false
    @State private var toastMessage: String?

    let stickerPickerBuilder: MediaStickerPickerBuilder?
    let onDone: (UIImage) -> Void
    let onCancel: () -> Void

    init(
        sourceImage: UIImage,
        initialFilter: FilterPreset = .none,
        stickerPickerBuilder: MediaStickerPickerBuilder? = nil,
        onDone: @escaping (UIImage) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: PhotoEditorViewModel(sourceImage: sourceImage, initialFilter: initialFilter))
        self.stickerPickerBuilder = stickerPickerBuilder
        self.onDone = onDone
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            EditorCanvasView(
                viewModel: viewModel,
                onLayout: { layoutMetrics = $0 },
                onTextTap: handleTextTap
            )

            EditorToolbar(
                viewModel: viewModel,
                activeComposerTool: activeComposerTool,
                onComposerTool: handleComposerTool,
                onDone: {
                    viewModel.prepareForFinalize()
                    Task {
                        let image = await viewModel.finalizeAsync()
                        onDone(image)
                    }
                },
                onCancel: onCancel
            )
            .opacity(viewModel.isChromeVisible ? 1 : 0)
            .allowsHitTesting(viewModel.isChromeVisible)

            if viewModel.isChromeVisible,
               activeComposerTool == .sticker || viewModel.activeTool == .sticker {
                VStack {
                    Spacer()
                    EditorStickerPickerBar(
                        viewModel: viewModel,
                        onOpenGifPack: stickerPickerBuilder == nil ? nil : { showStickerPicker = true }
                    )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if viewModel.isExporting {
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
                        .font(SplickTheme.Typography.captionBold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, SplickTheme.Spacing.md)
                        .padding(.vertical, SplickTheme.Spacing.sm)
                        .background(Capsule().fill(Color.black.opacity(0.75)))
                        .padding(.bottom, 120)
                }
                .transition(.opacity)
            }
        }
        .ignoresSafeArea(.keyboard)
        .animation(.easeOut(duration: 0.2), value: viewModel.activeTool)
        .animation(.easeOut(duration: 0.2), value: activeComposerTool)
        .editorStatusBarHidden(true)
        .sheet(isPresented: $showStickerPicker) {
            if let stickerPickerBuilder {
                stickerPickerBuilder(
                    {
                        Task { @MainActor in
                            showStickerPicker = false
                        }
                    },
                    { url in
                        Task { @MainActor in
                            showStickerPicker = false
                            await importStickerMedia(from: url)
                        }
                    },
                    { emoji in
                        Task { @MainActor in
                            showStickerPicker = false
                            viewModel.addSticker(.emoji(emoji))
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .presentationDetents([.large, .medium])
                .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: viewModel.selectedTextID) { id in
            guard id != nil else { return }
            activeComposerTool = .text
            if viewModel.activeTool != .text {
                viewModel.selectTool(.text)
            }
        }
    }

    private func handleComposerTool(_ tool: ComposerTool) {
        activeComposerTool = tool

        switch tool {
        case .text:
            viewModel.selectTool(.text)
            if viewModel.selectedTextID == nil {
                viewModel.addText(at: CGPoint(x: 0.5, y: 0.42))
            }
        case .sticker:
            viewModel.selectTool(.sticker)
        case .effects:
            viewModel.selectTool(.filter)
        case .draw:
            viewModel.selectTool(.draw)
        case .download:
            Task { await downloadEditedImage() }
        case .edit:
            viewModel.clearCanvasTool()
            activeComposerTool = .edit
        }
    }

    private func handleTextTap(at normalized: CGPoint) {
        activeComposerTool = .text
        viewModel.addText(at: normalized)
    }

    private func downloadEditedImage() async {
        viewModel.prepareForFinalize()
        let image = await viewModel.finalizeAsync()
        let saved = await MediaGallerySaver.saveImage(image)
        showToast(
            saved
                ? languageService.text(.mediaEditorSavedToGallery)
                : languageService.text(.mediaLoadFailed)
        )
    }

    private func importStickerMedia(from url: URL) async {
        do {
            let (data, response) = try await URLSession.splick.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200 ... 299).contains(status), !data.isEmpty else {
                await MainActor.run {
                    showToast(languageService.text(.mediaLoadFailed))
                }
                return
            }
            await MainActor.run {
                let before = viewModel.stickerItems.count
                viewModel.addMediaSticker(data: data)
                if viewModel.stickerItems.count == before {
                    showToast(languageService.text(.mediaLoadFailed))
                    return
                }
                activeComposerTool = .sticker
                viewModel.selectTool(.sticker)
            }
        } catch {
            await MainActor.run {
                showToast(languageService.text(.mediaLoadFailed))
            }
        }
    }

    private func showToast(_ message: String) {
        withAnimation {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }
}

private struct EditorCanvasView: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    let onLayout: (ImageDisplayMetrics) -> Void
    let onTextTap: (CGPoint) -> Void

    var body: some View {
        GeometryReader { proxy in
            let topInset = EditorLayout.canvasTopInset()
            let bottomInset = EditorLayout.canvasBottomInset()
            let canvasSize = CGSize(
                width: proxy.size.width,
                height: max(proxy.size.height - topInset - bottomInset, 1)
            )
            let metrics = ImageDisplayMetrics.aspectFit(
                imageSize: viewModel.baseImage.size,
                in: canvasSize,
                containerOrigin: CGPoint(x: 0, y: topInset)
            )

            ZStack {
                EditorImageView(image: viewModel.baseImage, adjustments: viewModel.adjustments)
                    .frame(width: metrics.displayFrame.width, height: metrics.displayFrame.height)
                    .position(x: metrics.displayFrame.midX, y: metrics.displayFrame.midY)
                    .scaleEffect(viewModel.rotatePulse ? 1.02 : 1)
                    .animation(.spring(response: 0.28, dampingFraction: 0.72), value: viewModel.rotatePulse)
                    .modifier(ChromeToggleTapModifier(
                        isEnabled: viewModel.shouldToggleChromeOnImageTap,
                        onTap: { viewModel.toggleChromeFromImageTap() }
                    ))
                    .modifier(TextTapGestureModifier(
                        isEnabled: viewModel.activeTool == .text && viewModel.selectedTextID == nil,
                        metrics: metrics,
                        onTextTap: onTextTap
                    ))

                Color.clear
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.deselectCanvasOverlays()
                    }
                    .allowsHitTesting(viewModel.selectedTextID != nil || viewModel.selectedStickerID != nil)

                PhotoEditorDrawCanvas(
                    drawing: viewModel.drawingForDisplay(canvasSize: metrics.displayFrame.size),
                    isEnabled: viewModel.activeTool == .draw,
                    inkColor: viewModel.inkColor,
                    inkWidth: viewModel.inkWidth,
                    flushToken: viewModel.finalizeFlushToken,
                    drawingSyncRevision: viewModel.drawingSyncRevision,
                    onStrokeEnded: { viewModel.commitDrawing($0) }
                )
                .frame(width: metrics.displayFrame.width, height: metrics.displayFrame.height)
                .position(x: metrics.displayFrame.midX, y: metrics.displayFrame.midY)
                .allowsHitTesting(viewModel.activeTool == .draw)

                if !viewModel.textItems.isEmpty || viewModel.activeTool == .text {
                    PhotoEditorTextLayer(viewModel: viewModel, displayMetrics: metrics)
                }

                if !viewModel.stickerItems.isEmpty || viewModel.activeTool == .sticker {
                    PhotoEditorStickerLayer(
                        viewModel: viewModel,
                        displayMetrics: metrics,
                        isEditing: viewModel.activeTool == .sticker
                    )
                }

                if viewModel.activeTool == .crop {
                    PhotoEditorCropView(viewModel: viewModel, displayMetrics: metrics)
                }

                if !viewModel.isChromeVisible {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if viewModel.selectedTextID != nil || viewModel.selectedStickerID != nil {
                                viewModel.deselectCanvasOverlays()
                            }
                            viewModel.showChrome()
                        }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .ignoresSafeArea(.keyboard)
            .onAppear { reportLayout(containerSize: proxy.size) }
            .onChange(of: proxy.size.width) { _ in reportLayout(containerSize: proxy.size) }
            .onChange(of: proxy.size.height) { _ in reportLayout(containerSize: proxy.size) }
            .onChange(of: viewModel.baseImage.size.width) { _ in reportLayout(containerSize: proxy.size) }
            .onChange(of: viewModel.baseImage.size.height) { _ in reportLayout(containerSize: proxy.size) }
        }
    }

    private func reportLayout(containerSize: CGSize) {
        let topInset = EditorLayout.canvasTopInset()
        let bottomInset = EditorLayout.canvasBottomInset()
        let canvasSize = CGSize(
            width: containerSize.width,
            height: max(containerSize.height - topInset - bottomInset, 1)
        )
        let metrics = ImageDisplayMetrics.aspectFit(
            imageSize: viewModel.baseImage.size,
            in: canvasSize,
            containerOrigin: CGPoint(x: 0, y: topInset)
        )
        onLayout(metrics)
        viewModel.updateDisplayMetrics(metrics)
    }
}

private struct TextTapGestureModifier: ViewModifier {
    let isEnabled: Bool
    let metrics: ImageDisplayMetrics
    let onTextTap: (CGPoint) -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            let size = metrics.displayFrame.size
                            guard size.width > 0, size.height > 0 else { return }
                            let normalized = CGPoint(
                                x: min(max(value.location.x / size.width, 0), 1),
                                y: min(max(value.location.y / size.height, 0), 1)
                            )
                            onTextTap(normalized)
                        }
                )
        } else {
            content
        }
    }
}

private struct ChromeToggleTapModifier: ViewModifier {
    let isEnabled: Bool
    let onTap: () -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.onTapGesture(perform: onTap)
        } else {
            content
        }
    }
}
