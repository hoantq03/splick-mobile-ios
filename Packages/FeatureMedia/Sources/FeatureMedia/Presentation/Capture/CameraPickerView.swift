import SwiftUI
import UIKit

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
        picker.mediaTypes = ["public.image", "public.movie"]
        picker.videoMaximumDuration = 60
        picker.videoQuality = .typeHigh
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onResult: (Result) -> Void

        init(onResult: @escaping (Result) -> Void) {
            self.onResult = onResult
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                self.onResult(.cancelled)
            }
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let deliver: (Result) -> Void = { result in
                picker.dismiss(animated: true) {
                    self.onResult(result)
                }
            }

            if let mediaType = info[.mediaType] as? String {
                if mediaType == "public.movie", let url = info[.mediaURL] as? URL {
                    deliver(.video(MediaCaptureHelpers.copyVideoToTemporaryDirectory(url)))
                    return
                }
            }

            if let image = info[.originalImage] as? UIImage {
                deliver(.image(image))
                return
            }

            deliver(.cancelled)
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
