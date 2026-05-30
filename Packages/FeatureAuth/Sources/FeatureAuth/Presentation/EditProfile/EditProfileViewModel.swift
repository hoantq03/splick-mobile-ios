import Foundation
import SwiftUI
import PhotosUI
import UIKit
import Common
import DesignSystem
import SplickDomain

public typealias UserAvatarUploader = @Sendable (UIImage) async throws -> URL

@MainActor
public final class EditProfileViewModel: ObservableObject {
    @Published var displayName: String
    @Published var existingAvatarURL: URL?
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var previewImage: UIImage?
    @Published var state: LoadingState<User> = .idle
    @Published var errorMessage: String?

    private let updateProfileUseCase: UpdateProfileUseCaseProtocol
    private let uploadAvatar: UserAvatarUploader?

    public init(
        user: User,
        updateProfileUseCase: UpdateProfileUseCaseProtocol,
        uploadAvatar: UserAvatarUploader? = nil
    ) {
        self.displayName = user.displayName
        self.existingAvatarURL = user.avatarURL
        self.updateProfileUseCase = updateProfileUseCase
        self.uploadAvatar = uploadAvatar
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

        if trimmedName.isEmpty && previewImage == nil {
            errorMessage = "Enter a display name or choose a photo."
            return nil
        }

        state = .loading
        errorMessage = nil
        defer {
            if case .loading = state { state = .idle }
        }

        do {
            var avatarToSend: String?

            if let previewImage, let uploadAvatar {
                let uploaded = try await uploadAvatar(previewImage)
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
                avatarUrl: avatarToSend,
                preferredLocale: nil
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
