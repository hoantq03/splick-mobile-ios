import Foundation
import SwiftUI
import PhotosUI
import UIKit
import Common
import DesignSystem
import Localization
import SplickDomain

@MainActor
public final class CompleteOAuthProfileViewModel: ObservableObject {
    @Published var displayName: String
    @Published var dateOfBirth: Date?
    @Published var dateOfBirthDraft: Date
    @Published var dateOfBirthError: String?
    @Published var displayNameError: String?
    @Published var existingAvatarURL: URL?
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var previewImage: UIImage?
    @Published var state: LoadingState<User> = .idle
    @Published var errorMessage: String?

    private let originalUser: User
    private let updateProfileUseCase: UpdateProfileUseCaseProtocol
    private let uploadAvatar: UserAvatarUploader?
    private let languageService: LanguageService

    private static let minimumAgeYears = 13
    private static var defaultDateOfBirthDraft: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    }

    public init(
        user: User,
        updateProfileUseCase: UpdateProfileUseCaseProtocol,
        languageService: LanguageService,
        uploadAvatar: UserAvatarUploader? = nil
    ) {
        self.originalUser = user
        self.displayName = OAuthDisplayName.resolved(current: user.displayName, email: user.email)
        self.dateOfBirth = user.dateOfBirth
        self.dateOfBirthDraft = user.dateOfBirth ?? Self.defaultDateOfBirthDraft
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
        guard let data = try? await selectedPhotoItem.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            errorMessage = languageService.text(.profileAvatarLoadFailed)
            return
        }
        previewImage = image
        errorMessage = nil
    }

    func prepareDateOfBirthPicker() {
        dateOfBirthDraft = dateOfBirth ?? Self.defaultDateOfBirthDraft
    }

    func confirmDateOfBirth() {
        dateOfBirth = dateOfBirthDraft
        validateDateOfBirth()
    }

    func clearDateOfBirth() {
        dateOfBirth = nil
        dateOfBirthError = nil
    }

    func validateDisplayName() {
        let value = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.count > OAuthDisplayName.maxLength {
            displayNameError = languageService.text(.authDisplayNameTooLong)
            return
        }
        displayNameError = nil
    }

    func validateDateOfBirth() {
        guard let dateOfBirth else {
            dateOfBirthError = nil
            return
        }
        let minimumBirthDate = Calendar.current.date(
            byAdding: .year,
            value: -Self.minimumAgeYears,
            to: Date()
        ) ?? Date()
        if dateOfBirth > minimumBirthDate {
            dateOfBirthError = languageService.text(.profileBirthdayAgeError)
            return
        }
        dateOfBirthError = nil
    }

    func setupLater() -> User {
        originalUser
    }

    func save() async -> User? {
        validateDisplayName()
        validateDateOfBirth()
        if displayNameError != nil || dateOfBirthError != nil {
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

            let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let nameToSend = trimmedName.isEmpty
                ? OAuthDisplayName.emailLocalPart(originalUser.email)
                : trimmedName

            let user = try await updateProfileUseCase.execute(
                displayName: nameToSend,
                avatarUrl: avatarToSend,
                preferredLocale: nil,
                dateOfBirth: dateOfBirth,
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
