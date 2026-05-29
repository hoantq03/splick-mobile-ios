import DesignSystem
import SwiftUI
import UIKit

struct PhotoEditorView: View {
    @State private var viewModel: PhotoEditorViewModel
    @State private var containerSize: CGSize = .zero

    let onDone: (UIImage) -> Void
    let onCancel: () -> Void

    init(sourceImage: UIImage, onDone: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        _viewModel = State(initialValue: PhotoEditorViewModel(sourceImage: sourceImage))
        self.onDone = onDone
        self.onCancel = onCancel
    }

    private var displayMetrics: ImageDisplayMetrics {
        ImageDisplayMetrics.aspectFit(imageSize: viewModel.baseImage.size, in: containerSize)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { proxy in
                let metrics = ImageDisplayMetrics.aspectFit(
                    imageSize: viewModel.baseImage.size,
                    in: proxy.size
                )

                ZStack {
                    Image(uiImage: viewModel.baseImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: metrics.displayFrame.width, height: metrics.displayFrame.height)
                        .position(x: metrics.displayFrame.midX, y: metrics.displayFrame.midY)

                    PhotoEditorDrawCanvas(
                        viewModel: viewModel,
                        isEnabled: viewModel.activeTool == .draw
                    ) {
                        viewModel.drawingDidChange()
                    }
                    .frame(width: metrics.displayFrame.width, height: metrics.displayFrame.height)
                    .position(x: metrics.displayFrame.midX, y: metrics.displayFrame.midY)

                    PhotoEditorTextLayer(viewModel: viewModel, displayMetrics: metrics)

                    if viewModel.activeTool == .crop {
                        PhotoEditorCropView(viewModel: viewModel, displayMetrics: metrics)
                    }
                }
                .contentShape(Rectangle())
                .gesture(textPlacementGesture(metrics: metrics))
                .onAppear { containerSize = proxy.size }
                .onChange(of: proxy.size) { _, newSize in
                    containerSize = newSize
                }
            }

            VStack {
                Spacer()
                EditorToolbar(
                    viewModel: viewModel,
                    onDone: {
                        let image = viewModel.finalize(displayMetrics: displayMetrics)
                        onDone(image)
                    },
                    onCancel: onCancel
                )
            }
        }
    }

    private func textPlacementGesture(metrics: ImageDisplayMetrics) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                guard viewModel.activeTool == .text else { return }
                let frame = metrics.displayFrame
                guard frame.contains(value.location) else { return }

                let normalized = CGPoint(
                    x: (value.location.x - frame.minX) / frame.width,
                    y: (value.location.y - frame.minY) / frame.height
                )
                viewModel.addText(at: normalized)
            }
    }
}
