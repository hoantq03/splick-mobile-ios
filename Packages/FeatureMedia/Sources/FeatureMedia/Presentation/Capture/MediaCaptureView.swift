import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Presents native capture (camera / library) and a Splick photo editor for images.
public struct MediaCaptureView: View {
    let onMediaCaptured: (CapturedMedia) -> Void
    let onCancel: () -> Void

    @State private var showSourceSheet = true
    @State private var showCamera = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var editingImage: UIImage?

    public init(
        onMediaCaptured: @escaping (CapturedMedia) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onMediaCaptured = onMediaCaptured
        self.onCancel = onCancel
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let editingImage {
                PhotoEditorView(
                    sourceImage: editingImage,
                    onDone: { edited in
                        self.editingImage = nil
                        onMediaCaptured(.image(edited))
                    },
                    onCancel: {
                        self.editingImage = nil
                        showSourceSheet = true
                    }
                )
            }
        }
        .sheet(isPresented: $showSourceSheet) {
            MediaSourceSheet(
                onCamera: {
                    showSourceSheet = false
                    showCamera = true
                },
                onCancel: onCancel,
                photoPickerItems: $photoPickerItems,
                onPhotoPicked: { items in
                    photoPickerItems = []
                    Task { await handlePhotoPickerItems(items) }
                }
            )
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView { result in
                showCamera = false
                handleCameraResult(result)
            }
            .ignoresSafeArea()
        }
    }

    @MainActor
    private func handlePhotoPickerItems(_ items: [PhotosPickerItem]) async {
        guard let item = items.first else { return }
        showSourceSheet = false

        let isVideo = item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) })
        if isVideo {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let url = writeTemporaryVideo(data)
                onMediaCaptured(.video(url))
            } else {
                showSourceSheet = true
            }
            return
        }

        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            editingImage = image
            return
        }

        showSourceSheet = true
    }

    private func handleCameraResult(_ result: CameraPickerView.Result) {
        switch result {
        case .image(let image):
            editingImage = image
        case .video(let url):
            onMediaCaptured(.video(url))
        case .cancelled:
            showSourceSheet = true
        }
    }

    private func writeTemporaryVideo(_ data: Data) -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        try? data.write(to: destination)
        return destination
    }
}
