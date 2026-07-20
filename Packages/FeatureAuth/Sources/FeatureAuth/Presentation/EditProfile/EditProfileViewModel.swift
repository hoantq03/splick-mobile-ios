import Foundation
import SwiftUI
import PhotosUI
import UIKit
import Common
import DesignSystem
import Localization
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
    private let languageService: LanguageService

    public init(
        user: User,
        updateProfileUseCase: UpdateProfileUseCaseProtocol,
        languageService: LanguageService,
        uploadAvatar: UserAvatarUploader? = nil
    ) {
        self.displayName = user.displayName
        self.existingAvatarURL = user.avatarURL
        self.updateProfileUseCase = updateProfileUseCase
        self.languageService = languageService
        self.uploadAvatar = uploadAvatar
    }

    func onPhotoItemChanged() async {
        guard let selectedPhotoItem else {
            previewImage = nil
            return
        }
        guard let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) else {
            errorMessage = languageService.text(.profileAvatarLoadFailed)
            return
        }
        previewImage = UIImage(data: data)
    }

    func save() async -> User? {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty && previewImage == nil {
            errorMessage = languageService.text(.profileEditNothingEntered)
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
                errorMessage = languageService.text(.profileEditNothingToUpdate)
                state = .idle
                return nil
            }

            let user = try await updateProfileUseCase.execute(
                displayName: nameToSend,
                avatarUrl: avatarToSend,
                preferredLocale: nil,
                dateOfBirth: nil,
                username: nil
            )
            state = .loaded(user)
            return user
        } catch {
            let message = languageService.localizedMessage(for: error)
            errorMessage = message
            state = .failed(message)
            return nil
        }
    }
}
