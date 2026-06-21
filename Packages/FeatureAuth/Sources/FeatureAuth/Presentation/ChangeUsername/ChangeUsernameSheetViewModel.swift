import Foundation
import Common
import DesignSystem
import Localization
import SplickDomain

@MainActor
public final class ChangeUsernameSheetViewModel: ObservableObject {
    @Published var usernameDraft = ""
    @Published var usernameError: String?
    @Published private(set) var usernameStatus: FieldValidationStatus = .neutral
    @Published private(set) var isCheckingAvailability = false
    @Published private(set) var isSaving = false
    @Published var saveError: String?

    public var canSave: Bool {
        usernameStatus == .valid
            && !isCheckingAvailability
            && !isSaving
            && usernameDraft.trimmed != currentUsername
    }

    private let currentUsername: String
    private let checkUsernameAvailabilityUseCase: CheckUsernameAvailabilityUseCaseProtocol
    private let updateProfileUseCase: UpdateProfileUseCaseProtocol
    private let languageService: LanguageService

    private var availabilityTask: Task<Void, Never>?

    private static let minUsernameLength = 3
    private static let debounceNanoseconds: UInt64 = 400_000_000

    public init(
        currentUsername: String,
        checkUsernameAvailabilityUseCase: CheckUsernameAvailabilityUseCaseProtocol,
        updateProfileUseCase: UpdateProfileUseCaseProtocol,
        languageService: LanguageService
    ) {
        self.currentUsername = currentUsername
        self.checkUsernameAvailabilityUseCase = checkUsernameAvailabilityUseCase
        self.updateProfileUseCase = updateProfileUseCase
        self.languageService = languageService
        self.usernameDraft = currentUsername
    }

    public func prepareForPresentation() {
        usernameDraft = currentUsername
        usernameError = nil
        saveError = nil
        usernameStatus = .neutral
        availabilityTask?.cancel()
    }

    public func onUsernameChanged() {
        availabilityTask?.cancel()
        validateFormat()

        let candidate = usernameDraft.trimmed
        guard usernameError == nil, !candidate.isEmpty else {
            usernameStatus = .neutral
            isCheckingAvailability = false
            return
        }

        if candidate == currentUsername {
            usernameStatus = .valid
            isCheckingAvailability = false
            return
        }

        usernameStatus = .neutral
        isCheckingAvailability = true

        availabilityTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.debounceNanoseconds)
            guard !Task.isCancelled else { return }
            await self?.checkAvailability(for: candidate)
        }
    }

    public func save() async -> User? {
        guard canSave else { return nil }

        isSaving = true
        saveError = nil
        defer { isSaving = false }

        do {
            return try await updateProfileUseCase.execute(
                displayName: nil,
                avatarUrl: nil,
                preferredLocale: nil,
                dateOfBirth: nil,
                username: usernameDraft.trimmed
            )
        } catch {
            saveError = languageService.localizedMessage(for: error)
            return nil
        }
    }

    private func validateFormat() {
        let value = usernameDraft.trimmed
        if value.isEmpty {
            usernameError = nil
            return
        }
        if value.count < Self.minUsernameLength {
            usernameError = languageService.text(.profileUsernameTooShort)
        } else if value.count > AppConstants.Validation.maxUsernameLength {
            usernameError = languageService.text(.profileUsernameTooLong)
        } else if !value.isValidUsername {
            usernameError = languageService.text(.profileUsernameInvalid)
        } else {
            usernameError = nil
        }
    }

    private func checkAvailability(for candidate: String) async {
        do {
            let available = try await checkUsernameAvailabilityUseCase.execute(username: candidate)
            guard !Task.isCancelled else { return }
            guard usernameDraft.trimmed == candidate else { return }

            isCheckingAvailability = false
            if available {
                usernameError = nil
                usernameStatus = .valid
            } else {
                usernameError = languageService.text(.errorAuthUsernameExists)
                usernameStatus = .neutral
            }
        } catch {
            guard !Task.isCancelled else { return }
            guard usernameDraft.trimmed == candidate else { return }
            isCheckingAvailability = false
            usernameError = languageService.localizedMessage(for: error)
            usernameStatus = .neutral
        }
    }
}
