import SwiftUI
import DesignSystem
import Common

public struct CameraView: View {
    @StateObject private var viewModel: CameraViewModel
    @State private var showImagePicker = false

    public init(viewModel: @autoclosure @escaping () -> CameraViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: SplickTheme.Spacing.lg) {
                if let image = viewModel.capturedImage {
                    previewSection(image: image)
                } else {
                    captureSection
                }
            }
            .padding(SplickTheme.Spacing.lg)
            .navigationTitle("New Post")
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $viewModel.capturedImage)
            }
        }
    }

    private var captureSection: some View {
        VStack(spacing: SplickTheme.Spacing.lg) {
            Spacer()

            Image(systemName: "camera.fill")
                .font(.system(size: 64))
                .foregroundStyle(SplickTheme.Colors.textTertiary)

            Text("Capture a moment")
                .font(SplickTheme.Typography.title)
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            SplickButton("Open Camera", style: .primary) {
                showImagePicker = true
            }

            Spacer()
        }
    }

    private func previewSection(image: UIImage) -> some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
                .frame(maxHeight: 400)

            SplickTextField("Add a caption...", text: $viewModel.caption)

            HStack(spacing: SplickTheme.Spacing.md) {
                SplickButton("Retake", style: .secondary) {
                    viewModel.reset()
                }

                SplickButton(
                    "Share",
                    isLoading: viewModel.uploadState.isLoading
                ) {
                    Task { await viewModel.uploadPhoto() }
                }
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            parent.image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
