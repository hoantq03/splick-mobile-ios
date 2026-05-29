import SwiftUI
import UIKit

/// System camera UI (`UIImagePickerController`) — edge-to-edge preview and native controls.
struct CameraPickerView: UIViewControllerRepresentable {
    enum Result: Equatable {
        case image(UIImage)
        case video(URL)
        case cancelled
    }

    let onResult: (Result) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .camera) ?? ["public.image"]
        picker.videoMaximumDuration = 60
        picker.videoQuality = .typeHigh
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.showsCameraControls = true
        picker.cameraDevice = .rear
        picker.cameraCaptureMode = .photo
        picker.modalPresentationStyle = .fullScreen
        picker.view.isOpaque = true
        picker.view.backgroundColor = .black
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onResult: (Result) -> Void

        init(onResult: @escaping (Result) -> Void) {
            self.onResult = onResult
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            finish(picker, result: .cancelled)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let mediaType = info[.mediaType] as? String, mediaType == "public.movie",
               let url = info[.mediaURL] as? URL {
                finish(picker, result: .video(MediaCaptureHelpers.copyVideoToTemporaryDirectory(url)))
                return
            }

            if let image = info[.originalImage] as? UIImage {
                let normalized = PhotoEditorImageProcessor.normalizeOrientation(image)
                finish(picker, result: .image(normalized))
                return
            }

            finish(picker, result: .cancelled)
        }

        private func finish(_ picker: UIImagePickerController, result: Result) {
            let deliver = { self.onResult(result) }
            if picker.presentingViewController != nil {
                picker.dismiss(animated: true, completion: deliver)
            } else {
                deliver()
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
