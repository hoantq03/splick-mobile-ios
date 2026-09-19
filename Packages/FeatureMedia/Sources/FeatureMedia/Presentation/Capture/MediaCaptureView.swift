import AVFoundation
import DesignSystem
import Localization
import SwiftUI
import UIKit

/// Orchestrates camera capture, album picker, and photo editor.
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

    private let maxLibrarySelection: Int

    public init(
        onMediaCaptured: @escaping (CapturedMedia) -> Void,
        onCancel: @escaping () -> Void,
        stickerPickerBuilder: MediaStickerPickerBuilder? = nil,
        filterCatalogRepository: FilterCatalogRepositoryProtocol? = nil,
        maxLibrarySelection: Int = 10
    ) {
        self.onMediaCaptured = onMediaCaptured
        self.onCancel = onCancel
        self.stickerPickerBuilder = stickerPickerBuilder
        self.filterCatalogRepository = filterCatalogRepository
        self.maxLibrarySelection = max(1, maxLibrarySelection)
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
                    .transition(.opacity)
                } else {
                    cameraUnavailableView
                }

            case .library:
                MultiPhotoLibraryPickerView(
                    maxSelectionCount: maxLibrarySelection,
                    onConfirm: { items in handleLibraryMedia(items) },
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
                        route = .editor
                    }
                )
                .transition(.opacity)

            case .editor:
                if let workingImage {
                    PhotoEditorView(
                        sourceImage: workingImage,
                        initialFilter: workingFilter,
                        stickerPickerBuilder: stickerPickerBuilder,
                        onDone: { edited in onMediaCaptured(.image(edited)) },
                        onCancel: {
                            self.workingImage = nil
                            self.workingFilter = .none
                            reopenCamera()
                        }
                    )
                    .ignoresSafeArea(.keyboard)
                    .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Group {
                if route == .camera {
                    SplickTheme.Colors.background
                } else {
                    Color.black
                }
            }
            .ignoresSafeArea()
        )
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
                .foregroundStyle(SplickTheme.Colors.textTertiary)

            VStack(spacing: SplickTheme.Spacing.sm) {
                Text(languageService.text(.mediaCameraUnavailable))
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Text(languageService.text(.mediaCameraUnavailableHint))
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
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
                .foregroundStyle(SplickTheme.Colors.textSecondary)
        }
        .padding(SplickTheme.Spacing.xl)
    }

    private func reopenCamera() {
        cameraSessionID = UUID()
        route = .camera
    }

    private func handleLibraryMedia(_ items: [LibraryPickedMedia]) {
        guard !items.isEmpty else {
            if isCameraAccessible { reopenCamera() } else { route = .camera }
            return
        }
        let images = items.compactMap { item -> UIImage? in
            if case .image(let image) = item { return image }
            return nil
        }
        let videos = items.compactMap { item -> URL? in
            if case .video(let url) = item { return url }
            return nil
        }
        if videos.isEmpty {
            onMediaCaptured(images.count == 1 ? .image(images[0]) : .images(images))
        } else if images.isEmpty, videos.count == 1 {
            onMediaCaptured(.video(videos[0]))
        } else {
            onMediaCaptured(.mixed(images: images, videos: videos))
        }
    }

    private func handleCameraResult(_ result: CameraPickerView.Result) {
        switch result {
        case .image(let image, let filter):
            workingImage = image
            workingFilter = filter
            route = .editor
        case .video(let url):
            onMediaCaptured(.video(url))
        case .cancelled:
            onCancel()
        case .openLibrary:
            route = .library
        case .openTextCreation:
            route = .textCreation
        }
    }
}

private enum CaptureRoute: Equatable {
    case camera
    case library
    case textCreation
    case editor
}
