import DesignSystem
import SwiftUI
import UIKit

/// Opens the system camera immediately; multi-select library is available from preview flow.
public struct MediaCaptureView: View {
    let onMediaCaptured: (CapturedMedia) -> Void
    let onCancel: () -> Void

    @State private var route: CaptureRoute = .camera
    @State private var workingImage: UIImage?
    @State private var cameraSessionID = UUID()

    private let maxLibrarySelection = 5

    public init(
        onMediaCaptured: @escaping (CapturedMedia) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onMediaCaptured = onMediaCaptured
        self.onCancel = onCancel
    }

    public var body: some View {
        Group {
            switch route {
            case .camera:
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    CameraPickerView(onResult: { handleCameraResult($0) })
                        .id(cameraSessionID)
                        .ignoresSafeArea()
                        .transition(.opacity)
                } else {
                    cameraUnavailableView
                }

            case .library:
                MultiPhotoLibraryPickerView(
                    maxSelectionCount: maxLibrarySelection,
                    onConfirm: { images in
                        handleLibraryImages(images)
                    },
                    onCancel: {
                        route = .camera
                    }
                )
                .transition(.opacity)

            case .preview:
                if let workingImage {
                    CapturePreviewView(
                        image: workingImage,
                        onRetake: { reopenCamera() },
                        onChooseAnother: {
                            self.workingImage = nil
                            route = .library
                        },
                        onEdit: {
                            route = .editor
                        },
                        onUsePhoto: {
                            onMediaCaptured(.image(workingImage))
                        },
                        onCancel: {
                            self.workingImage = nil
                            reopenCamera()
                        }
                    )
                    .transition(.opacity)
                }

            case .editor:
                if let workingImage {
                    PhotoEditorView(
                        sourceImage: workingImage,
                        onDone: { edited in
                            onMediaCaptured(.image(edited))
                        },
                        onCancel: {
                            route = .preview
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: route)
        .editorStatusBarHidden(true)
    }

    private var cameraUnavailableView: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.5))
            Text("Camera không khả dụng")
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(.white)
            Button("Quay lại", action: onCancel)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func reopenCamera() {
        cameraSessionID = UUID()
        route = .camera
    }

    private func handleLibraryImages(_ images: [UIImage]) {
        guard !images.isEmpty else {
            reopenCamera()
            return
        }
        onMediaCaptured(images.count == 1 ? .image(images[0]) : .images(images))
    }

    private func handleCameraResult(_ result: CameraPickerView.Result) {
        switch result {
        case .image(let image):
            workingImage = image
            route = .preview
        case .video(let url):
            onMediaCaptured(.video(url))
        case .cancelled:
            onCancel()
        }
    }
}

private enum CaptureRoute: Equatable {
    case camera
    case library
    case preview
    case editor
}
