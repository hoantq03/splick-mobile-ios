import DesignSystem
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
    @StateObject private var viewModel: PhotoEditorViewModel
    @State private var layoutMetrics = ImageDisplayMetrics(imageSize: .zero, displayFrame: .zero)
    @State private var editingText = ""
    @FocusState private var isTextFieldFocused: Bool

    let onDone: (UIImage) -> Void
    let onCancel: () -> Void

    init(sourceImage: UIImage, onDone: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: PhotoEditorViewModel(sourceImage: sourceImage))
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
                onDone: {
                    viewModel.prepareForFinalize()
                    DispatchQueue.main.async {
                        let image = viewModel.finalize(displayMetrics: layoutMetrics)
                        onDone(image)
                    }
                },
                onCancel: onCancel
            )
            .opacity(viewModel.isChromeVisible ? 1 : 0)
            .allowsHitTesting(viewModel.isChromeVisible)

            if viewModel.isChromeVisible,
               viewModel.activeTool == .text,
               viewModel.selectedTextID != nil {
                VStack {
                    Spacer()
                    textInputBar
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.activeTool)
        .editorStatusBarHidden(true)
        .onChange(of: viewModel.selectedTextID) { id in
            guard let id,
                  let item = viewModel.textItems.first(where: { $0.id == id }) else {
                isTextFieldFocused = false
                return
            }
            editingText = item.text
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }

    private var textInputBar: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            TextField("Nhập chữ...", text: $editingText)
                .textFieldStyle(.roundedBorder)
                .focused($isTextFieldFocused)
                .submitLabel(.done)
                .onSubmit(commitTextEditing)
                .onChange(of: editingText) { newValue in
                    guard let id = viewModel.selectedTextID else { return }
                    viewModel.updateText(id, text: newValue)
                }

            Button("Xong", action: commitTextEditing)
                .font(SplickTheme.Typography.callout.weight(.semibold))
        }
        .padding(SplickTheme.Spacing.md)
        .background(.ultraThinMaterial)
    }

    private func handleTextTap(at normalized: CGPoint) {
        viewModel.addText(at: normalized)
    }

    private func commitTextEditing() {
        guard let id = viewModel.selectedTextID else { return }
        viewModel.updateText(id, text: editingText.isEmpty ? "Nhập chữ" : editingText)
        viewModel.commitTextEdit()
        viewModel.selectedTextID = nil
        isTextFieldFocused = false
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
                    .modifier(ChromeToggleTapModifier(
                        isEnabled: viewModel.shouldToggleChromeOnImageTap,
                        onTap: { viewModel.toggleChromeFromImageTap() }
                    ))

                if viewModel.activeTool == .draw {
                    PhotoEditorDrawCanvas(
                        drawing: viewModel.drawing,
                        isEnabled: true,
                        inkColor: viewModel.inkColor,
                        inkWidth: viewModel.inkWidth,
                        flushToken: viewModel.finalizeFlushToken,
                        drawingSyncRevision: viewModel.drawingSyncRevision,
                        onStrokeEnded: { viewModel.commitDrawing($0) }
                    )
                    .frame(width: metrics.displayFrame.width, height: metrics.displayFrame.height)
                    .position(x: metrics.displayFrame.midX, y: metrics.displayFrame.midY)
                } else if !viewModel.drawing.bounds.isEmpty {
                    PhotoEditorDrawingOverlay(
                        drawing: viewModel.drawing,
                        canvasSize: metrics.displayFrame.size
                    )
                        .frame(width: metrics.displayFrame.width, height: metrics.displayFrame.height)
                        .position(x: metrics.displayFrame.midX, y: metrics.displayFrame.midY)
                        .allowsHitTesting(false)
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
