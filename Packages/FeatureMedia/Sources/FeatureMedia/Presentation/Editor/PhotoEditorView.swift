import DesignSystem
import Localization
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
    @State private var editingText = ""
    @State private var isEditingNewItem = false
    @State private var activeComposerTool: ComposerTool?
    @State private var showStickerPicker = false
    @State private var showMoreSheet = false
    @State private var toastMessage: String?
    @FocusState private var isTextFieldFocused: Bool

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
               activeComposerTool == .text || viewModel.activeTool == .text,
               viewModel.selectedTextID != nil {
                VStack {
                    Spacer()
                    textInputBar
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
        .animation(.easeOut(duration: 0.2), value: viewModel.activeTool)
        .animation(.easeOut(duration: 0.2), value: activeComposerTool)
        .editorStatusBarHidden(true)
        .sheet(isPresented: $showStickerPicker) {
            if let stickerPickerBuilder {
                stickerPickerBuilder(
                    { showStickerPicker = false },
                    { url in
                        showStickerPicker = false
                        Task { await importGif(from: url) }
                    },
                    { emoji in
                        showStickerPicker = false
                        viewModel.addSticker(.emoji(emoji))
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showMoreSheet) {
            EditorMoreOptionsSheet(viewModel: viewModel) {
                showMoreSheet = false
            }
            .environmentObject(languageService)
            .presentationDetents([.medium])
        }
        .onChange(of: viewModel.selectedTextID) { id in
            guard let id,
                  let item = viewModel.textItems.first(where: { $0.id == id }) else {
                isTextFieldFocused = false
                return
            }
            let isNew = item.text == EditorTextItem.placeholderText
            isEditingNewItem = isNew
            editingText = isNew ? "" : item.text
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }

    private var textInputBar: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            TextField(languageService.text(.mediaTextPlaceholder), text: $editingText)
                .textFieldStyle(.roundedBorder)
                .focused($isTextFieldFocused)
                .submitLabel(.done)
                .onSubmit(commitTextEditing)
                .onChange(of: editingText) { newValue in
                    guard let id = viewModel.selectedTextID else { return }
                    let displayText = newValue.isEmpty && isEditingNewItem
                        ? EditorTextItem.placeholderText
                        : newValue
                    viewModel.updateText(id, text: displayText)
                }

            Button(languageService.text(.commonDone), action: commitTextEditing)
                .font(SplickTheme.Typography.callout.weight(.semibold))
        }
        .padding(SplickTheme.Spacing.md)
        .background(.ultraThinMaterial)
    }

    private func handleComposerTool(_ tool: ComposerTool) {
        activeComposerTool = tool

        switch tool {
        case .text:
            viewModel.selectTool(.text)
        case .sticker:
            if stickerPickerBuilder != nil {
                showStickerPicker = true
            } else {
                viewModel.selectTool(.sticker)
            }
        case .audio:
            showToast(languageService.text(.mediaEditorComingSoon))
        case .effects:
            viewModel.selectTool(.filter)
        case .mention:
            showToast(languageService.text(.mediaEditorComingSoon))
        case .draw:
            viewModel.selectTool(.draw)
        case .download:
            Task { await downloadEditedImage() }
        case .more:
            showMoreSheet = true
        }
    }

    private func handleTextTap(at normalized: CGPoint) {
        activeComposerTool = .text
        viewModel.addText(at: normalized)
    }

    private func commitTextEditing() {
        guard let id = viewModel.selectedTextID else { return }
        if editingText.isEmpty && isEditingNewItem {
            viewModel.removeTextItem(id)
        } else {
            let finalText = editingText.isEmpty ? EditorTextItem.placeholderText : editingText
            viewModel.updateText(id, text: finalText)
            viewModel.commitTextEdit()
        }
        viewModel.selectedTextID = nil
        isTextFieldFocused = false
        isEditingNewItem = false
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

    private func importGif(from url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            await MainActor.run {
                viewModel.addGifSticker(data: data)
                activeComposerTool = .sticker
            }
        } catch {
            showToast(languageService.text(.mediaLoadFailed))
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
                EditorImageView(image: viewModel.baseImage)
                    .frame(width: metrics.displayFrame.width, height: metrics.displayFrame.height)
                    .position(x: metrics.displayFrame.midX, y: metrics.displayFrame.midY)
                    .scaleEffect(viewModel.rotatePulse ? 1.02 : 1)
                    .animation(.spring(response: 0.28, dampingFraction: 0.72), value: viewModel.rotatePulse)
                    .modifier(ChromeToggleTapModifier(
                        isEnabled: viewModel.shouldToggleChromeOnImageTap,
                        onTap: { viewModel.toggleChromeFromImageTap() }
                    ))

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
                .opacity(viewModel.activeTool == .draw ? 1 : 0)
                .allowsHitTesting(viewModel.activeTool == .draw)

                if !viewModel.drawing.bounds.isEmpty && viewModel.activeTool != .draw {
                    PhotoEditorDrawingOverlay(
                        drawing: viewModel.drawingForDisplay(canvasSize: metrics.displayFrame.size),
                        canvasSize: metrics.displayFrame.size
                    )
                    .frame(width: metrics.displayFrame.width, height: metrics.displayFrame.height)
                    .position(x: metrics.displayFrame.midX, y: metrics.displayFrame.midY)
                    .allowsHitTesting(false)
                    .transition(.identity)
                }

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
                            viewModel.showChrome()
                        }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .modifier(TextTapGestureModifier(
                isEnabled: viewModel.activeTool == .text && viewModel.selectedTextID == nil,
                metrics: metrics,
                onTextTap: onTextTap
            ))
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
                .highPriorityGesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            let frame = metrics.displayFrame
                            guard frame.contains(value.location) else { return }
                            let normalized = CGPoint(
                                x: (value.location.x - frame.minX) / frame.width,
                                y: (value.location.y - frame.minY) / frame.height
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
