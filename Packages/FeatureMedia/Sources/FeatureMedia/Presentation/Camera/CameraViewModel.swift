import Foundation
import SwiftUI
import Common

@MainActor
public final class CameraViewModel: ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var caption = ""
    @Published var uploadState: LoadingState<MediaUploadResult> = .idle
    @Published var showCamera = false

    private let uploadMediaUseCase: UploadMediaUseCaseProtocol

    public init(uploadMediaUseCase: UploadMediaUseCaseProtocol) {
        self.uploadMediaUseCase = uploadMediaUseCase
    }

    func uploadPhoto() async {
        guard let image = capturedImage,
              let data = image.jpegData(compressionQuality: AppConstants.Media.compressionQuality)
        else {
            uploadState = .failed("No image to upload")
            return
        }

        uploadState = .loading
        do {
            let result = try await uploadMediaUseCase.execute(imageData: data)
            uploadState = .loaded(result)
            Log.info("Photo uploaded: \(result.id)", category: .media)
        } catch {
            uploadState = .failed(error.localizedDescription)
            Log.error(error, category: .media)
        }
    }

    func reset() {
        capturedImage = nil
        caption = ""
        uploadState = .idle
    }
}
