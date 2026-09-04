import Foundation
import Localization
import SplickDomain

@MainActor
public final class AddFriendViewModel: ObservableObject {
    @Published var username = ""
    @Published var message = ""
    @Published var isLoading = false
    @Published var successMessage: String?
    @Published var errorMessage: String?

    private let addFriendUseCase: AddFriendUseCaseProtocol
    private let languageService: LanguageService
    private let onSuccess: () -> Void

    public init(
        addFriendUseCase: AddFriendUseCaseProtocol,
        languageService: LanguageService,
        onSuccess: @escaping () -> Void
    ) {
        self.addFriendUseCase = addFriendUseCase
        self.languageService = languageService
        self.onSuccess = onSuccess
    }

    func addByUsername() async {
        let normalized = username.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
        guard !normalized.isEmpty else {
            errorMessage = languageService.text(.friendsAddUsernameRequired)
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
            let user = try await addFriendUseCase.execute(
                username: normalized,
                message: trimmedMessage.isEmpty ? nil : trimmedMessage
            )
            successMessage = languageService.format(.friendsAddSuccess, user.displayName)
            username = ""
            onSuccess()
        } catch {
            errorMessage = languageService.localizedMessage(for: error)
        }
    }

    func addFromQR(_ payload: String) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let user = try await addFriendUseCase.executeFromQRCode(payload, message: nil)
            successMessage = languageService.format(.friendsAddSuccess, user.displayName)
            onSuccess()
        } catch {
            errorMessage = languageService.localizedMessage(for: error)
        }
    }
}
