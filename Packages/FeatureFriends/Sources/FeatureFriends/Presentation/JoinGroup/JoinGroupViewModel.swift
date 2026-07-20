import Foundation
import Localization
import SplickDomain

@MainActor
public final class JoinGroupViewModel: ObservableObject {
    @Published var inviteCode = ""
    @Published var isLoading = false
    @Published var successMessage: String?
    @Published var errorMessage: String?

    private let joinGroupUseCase: JoinGroupUseCaseProtocol
    private let languageService: LanguageService
    private let onSuccess: () -> Void

    public init(
        joinGroupUseCase: JoinGroupUseCaseProtocol,
        languageService: LanguageService,
        onSuccess: @escaping () -> Void
    ) {
        self.joinGroupUseCase = joinGroupUseCase
        self.languageService = languageService
        self.onSuccess = onSuccess
    }

    func joinByCode() async {
        let normalized = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else {
            errorMessage = languageService.text(.friendsJoinCodeRequired)
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let group = try await joinGroupUseCase.execute(inviteCode: normalized)
            successMessage = languageService.format(.friendsJoinSuccess, group.name)
            inviteCode = ""
            onSuccess()
        } catch {
            errorMessage = languageService.localizedMessage(for: error)
        }
    }

    func joinFromQR(_ payload: String) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let group = try await joinGroupUseCase.executeFromQRCode(payload)
            successMessage = languageService.format(.friendsJoinSuccess, group.name)
            onSuccess()
        } catch {
            errorMessage = languageService.localizedMessage(for: error)
        }
    }
}
