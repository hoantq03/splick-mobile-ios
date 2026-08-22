import AVFoundation
import CoreImage
import DesignSystem
import Localization
import SwiftUI
import UIKit

/// Orchestrates camera capture, album picker, photo preview, and editor.
public struct MediaCaptureView: View {
    @EnvironmentObject private var languageService: LanguageService
    let onMediaCaptured: (CapturedMedia) -> Void
    let onCancel: () -> Void
    let stickerPickerBuilder: MediaStickerPickerBuilder?
    let filterCatalogRepository: FilterCatalogRepositoryProtocol?

    @State private var route: CaptureRoute = .camera
    @State private var workingImage: UIImage?
    @State private var workingFilter: FilterPreset = .none
    @State private var cameraSessionID = UUID()

    private let maxLibrarySelection = 5

    public init(
        onMediaCaptured: @escaping (CapturedMedia) -> Void,
        onCancel: @escaping () -> Void,
        stickerPickerBuilder: MediaStickerPickerBuilder? = nil,
        filterCatalogRepository: FilterCatalogRepositoryProtocol? = nil
    ) {
        self.onMediaCaptured = onMediaCaptured
        self.onCancel = onCancel
        self.stickerPickerBuilder = stickerPickerBuilder
        self.filterCatalogRepository = filterCatalogRepository
    }

    public var body: some View {
        Group {
            switch route {
            case .camera:
                if isCameraAccessible {
                    CameraPickerView(
                        onResult: { handleCameraResult($0) },
                        filterCatalogRepository: filterCatalogRepository
                    )
                    .id(cameraSessionID)
                    .ignoresSafeArea()
                    .transition(.opacity)
                } else {
                    cameraUnavailableView
                }

            case .library:
                MultiPhotoLibraryPickerView(
                    maxSelectionCount: maxLibrarySelection,
                    onConfirm: { images in handleLibraryImages(images) },
                    onCancel: {
                        if isCameraAccessible {
                            reopenCamera()
                        } else {
                            route = .camera
                        }
                    }
                )
                .transition(.opacity)

            case .textCreation:
                TextCreationView(
                    onBack: { reopenCamera() },
                    onCreated: { image in
                        workingImage = image
                        workingFilter = .none
                        route = .preview
                    }
                )
                .transition(.opacity)

            case .layoutCapture:
                LayoutCaptureView(
                    onBack: { reopenCamera() },
                    onCreated: { image in
                        workingImage = image
                        workingFilter = .none
                        route = .preview
                    }
                )
                .transition(.opacity)

            case .preview:
                if let workingImage {
                    CapturePreviewView(
                        image: filteredPreview(workingImage, filter: workingFilter),
                        onRetake: {
                            self.workingImage = nil
                            self.workingFilter = .none
                            reopenCamera()
                        },
                        onEdit: { route = .editor },
                        onUsePhoto: {
                            onMediaCaptured(.image(filteredPreview(workingImage, filter: workingFilter)))
                        },
                        onCancel: {
                            self.workingImage = nil
                            self.workingFilter = .none
                            reopenCamera()
                        }
                    )
                    .transition(.opacity)
                }

            case .editor:
                if let workingImage {
                    PhotoEditorView(
                        sourceImage: workingImage,
                        initialFilter: workingFilter,
                        stickerPickerBuilder: stickerPickerBuilder,
                        onDone: { edited in onMediaCaptured(.image(edited)) },
                        onCancel: { route = .preview }
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

    private var isCameraAccessible: Bool {
        guard AVCaptureDevice.default(for: .video) != nil else { return false }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized, .notDetermined:
            return true
        default:
            return false
        }
    }

    private var cameraUnavailableView: some View {
        VStack(spacing: SplickTheme.Spacing.lg) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.5))

            VStack(spacing: SplickTheme.Spacing.sm) {
                Text(languageService.text(.mediaCameraUnavailable))
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(.white)
                Text(languageService.text(.mediaCameraUnavailableHint))
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }

            Button {
                route = .library
            } label: {
                Label(languageService.text(.mediaPickFromLibrary), systemImage: "photo.on.rectangle.angled")
                    .font(SplickTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SplickTheme.Spacing.sm)
                    .background(Capsule().fill(SplickTheme.Colors.primaryGradient))
            }
            .buttonStyle(.plain)

            Button(languageService.text(.commonBack), action: onCancel)
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(SplickTheme.Spacing.xl)
    }

    private func reopenCamera() {
        cameraSessionID = UUID()
        route = .camera
    }

    private func handleLibraryImages(_ images: [UIImage]) {
        guard !images.isEmpty else {
            if isCameraAccessible { reopenCamera() } else { route = .camera }
            return
        }
        onMediaCaptured(images.count == 1 ? .image(images[0]) : .images(images))
    }

    private func handleCameraResult(_ result: CameraPickerView.Result) {
        switch result {
        case .image(let image, let filter):
            workingImage = image
            workingFilter = filter
            route = .preview
        case .video(let url):
            onMediaCaptured(.video(url))
        case .cancelled:
            onCancel()
        case .openLibrary:
            route = .library
        case .openTextCreation:
            route = .textCreation
        case .openLayoutCapture:
            route = .layoutCapture
        }
    }

    private func filteredPreview(_ image: UIImage, filter: FilterPreset) -> UIImage {
        guard filter != .none, let ciImage = CIImage(image: image) else { return image }
        let filtered = FilterEngine.apply(ciImage, preset: filter, intensity: 1)
        return FilterEngine.renderUIImage(from: filtered) ?? image
    }
}

private enum CaptureRoute: Equatable {
    case camera
    case library
    case textCreation
    case layoutCapture
    case preview
    case editor
}
