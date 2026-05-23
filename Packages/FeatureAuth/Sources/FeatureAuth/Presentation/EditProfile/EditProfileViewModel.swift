import Foundation
import SwiftUI
import PhotosUI
import Common
import DesignSystem
import SplickDomain

public typealias ProfileImageUploader = @Sendable (Data) async throws -> URL

@MainActor
public final class EditProfileViewModel: ObservableObject {
    @Published var displayName: String
    @Published var avatarUrlText: String
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var previewImage: UIImage?
    @Published var state: LoadingState<User> = .idle
    @Published var errorMessage: String?

    private let updateProfileUseCase: UpdateProfileUseCaseProtocol
    private let uploadImage: ProfileImageUploader?

    public init(
        user: User,
        updateProfileUseCase: UpdateProfileUseCaseProtocol,
        uploadImage: ProfileImageUploader? = nil
    ) {
        self.displayName = user.displayName
        self.avatarUrlText = user.avatarURL?.absoluteString ?? ""
        self.updateProfileUseCase = updateProfileUseCase
        self.uploadImage = uploadImage
    }

    func onPhotoItemChanged() async {
        guard let selectedPhotoItem else {
            previewImage = nil
            return
        }
        guard let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) else {
            errorMessage = "Could not load the selected photo."
            return
        }
        previewImage = UIImage(data: data)
    }

    func save() async -> User? {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        var resolvedAvatar = avatarUrlText.trimmingCharacters(in: .whitespacesAndNewlines)
        if resolvedAvatar.isEmpty { resolvedAvatar = "" }

        if trimmedName.isEmpty && resolvedAvatar.isEmpty && previewImage == nil {
            errorMessage = "Enter a display name or choose a photo."
            return nil
        }

        state = .loading
        errorMessage = nil
        defer {
            if case .loading = state { state = .idle }
        }

        do {
            var avatarToSend: String? = resolvedAvatar.isEmpty ? nil : resolvedAvatar

            if let previewImage, let uploadImage {
                guard let jpeg = previewImage.jpegData(compressionQuality: 0.85) else {
                    errorMessage = "Could not process the photo."
                    state = .idle
                    return nil
                }
                let uploaded = try await uploadImage(jpeg)
                avatarToSend = uploaded.absoluteString
            }

            let nameToSend = trimmedName.isEmpty ? nil : trimmedName
            if nameToSend == nil && avatarToSend == nil {
                errorMessage = "Nothing to update."
                state = .idle
                return nil
            }

            let user = try await updateProfileUseCase.execute(
                displayName: nameToSend,
                avatarUrl: avatarToSend
            )
            state = .loaded(user)
            return user
        } catch {
            errorMessage = error.localizedDescription
            state = .failed(error.localizedDescription)
            return nil
        }
    }
}
